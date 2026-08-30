extends Node3D

@onready var shrine: MeshInstance3D = $ReturnShrine
@onready var prompt: Label = $HUD/Prompt
@onready var objective: Label = $HUD/Objective
@onready var location_label: Label = $HUD/Location
@onready var target_label: Label = $HUD/Target
@onready var crystals: Array[MeshInstance3D] = [$CrystalDestination, $CrystalShardForest, $CrystalShardMeadow]
@onready var sun: DirectionalLight3D = $Sun
@onready var river: MeshInstance3D = $WhisperingRiver
@onready var campfire_light: OmniLight3D = $BaseCamp/Campfire/FireLight
@onready var shrine_light: OmniLight3D = $ReturnShrine/ShrineLight

const PLAYER_SCENE := preload("res://scenes/player_3d.tscn")
const SAVE_PATH := "user://forest_world_state.json"
const TREE_OBSTACLES := ["TreeA", "TreeB", "TreeC", "TreeD", "TreeE", "TreeF", "TreeG", "TreeH", "TreeI", "TreeJ", "TreeK"]
const ROCK_OBSTACLES := ["RockA", "RockB", "AncientClearing/MonolithA", "AncientClearing/MonolithB", "AncientClearing/MonolithC", "ForestStoneA", "ForestStoneB"]
const LARGE_WORLD_PROPS := ["Bridge", "BaseCamp/Tent", "BaseCamp/Campfire", "BaseCamp/CampSign", "AncientClearing/MonolithA", "AncientClearing/MonolithB", "AncientClearing/MonolithC", "AncientClearing/ClearingSign", "RockA", "RockB", "RiverCliffA", "RiverCliffB", "RiverCliffC", "RiverCliffD", "ForestStoneA", "ForestStoneB", "FenceNorthA", "FenceNorthB", "FenceNorthC", "FenceSouthA", "FenceSouthB", "FenceSouthC"]
const PATH_PROPS := ["PathToClearing/Path01", "PathToClearing/Path02", "PathToClearing/Path03", "PathToClearing/Path04", "PathToClearing/Path05", "PathToClearing/Path06"]
const GROUND_DETAILS := ["GrassA", "GrassB", "GrassC", "GrassD", "GrassE", "FlowerA", "FlowerB", "FlowerC", "MushroomsA", "MushroomsB"]
var players: Dictionary = {}
var player: CharacterBody3D
var crystals_collected := 0
var adventure_complete := false
var interact_released := true
var test_mode := ""
var test_move_sent := false
var test_packet_received := false
var world_time := 0.0
var crystal_base_positions: Array[Vector3] = []
var crystal_locations := ["Ancient Clearing", "Shadowwood Grove", "Sunlit Meadow"]

func _ready() -> void:
	Network.session_started.connect(_on_session_started)
	Network.player_joined.connect(_spawn_player)
	Network.player_left.connect(_remove_player)
	Network.session_ended.connect(_on_session_ended)
	Network.state_requested.connect(_on_state_requested)
	_scale_environment_assets()
	_create_landmark_colliders()
	for crystal in crystals:
		crystal_base_positions.append(crystal.position)
	_load_world_state()
	_spawn_player(1)
	for argument in OS.get_cmdline_user_args():
		if argument == "--network-test-host": test_mode = "host"
		if argument == "--network-test-client": test_mode = "client"
	if not test_mode.is_empty():
		call_deferred("_start_network_test")

func _process(delta: float) -> void:
	_animate_environment(delta)
	if not is_instance_valid(player):
		return
	_update_target_label()
	if test_mode == "client" and not test_move_sent and multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() > 1:
		player.global_position += Vector3(2, 0, 0)
		submit_player_state.rpc_id(1, player.global_position, 0.0)
		test_move_sent = true
		print("NETWORK_TEST: client sent 3D position update")
	_update_location_label()
	if adventure_complete:
		prompt.text = "Adventure complete! Press R to begin again"
		if Input.is_key_pressed(KEY_R) and interact_released:
			_request_reset()
			interact_released = false
		if not Input.is_key_pressed(KEY_R):
			interact_released = true
		return
	if crystals_collected == crystals.size():
		var at_shrine := player.global_position.distance_to(shrine.global_position) < 2.5
		prompt.text = "Press E to restore the shrine" if at_shrine else "Return all crystals to the blue shrine"
		if Input.is_key_pressed(KEY_E) and interact_released and at_shrine:
			_request_restore()
			interact_released = false
		if not Input.is_key_pressed(KEY_E): interact_released = true
		return
	var nearby_index := _get_nearby_crystal_index()
	prompt.text = "Press E to collect a forest crystal" if nearby_index >= 0 else ""
	if Input.is_key_pressed(KEY_E) and interact_released and nearby_index >= 0:
		_request_collect(nearby_index)
		interact_released = false
	if not Input.is_key_pressed(KEY_E):
		interact_released = true

func _get_nearby_crystal_index() -> int:
	for index in crystals.size():
		var candidate := crystals[index]
		if candidate.visible and player.global_position.distance_to(candidate.global_position) < 2.3:
			return index
	return -1

func _update_location_label() -> void:
	var position := player.global_position
	if position.z > 3.0:
		location_label.text = "Base Camp"
	elif position.x > 12.0 and position.z < -10.0:
		location_label.text = "Ancient Clearing"
	elif position.z < -1.0:
		location_label.text = "Whispering River"
	else:
		location_label.text = "Wildflower Meadow"

func _update_target_label() -> void:
	if adventure_complete:
		target_label.text = "Quest complete — press R to replay"
		return
	if crystals_collected == crystals.size():
		var shrine_distance := roundi(player.global_position.distance_to(shrine.global_position))
		target_label.text = "Return to Blue Shrine • %dm" % shrine_distance
		return
	var nearest_index := -1
	var nearest_distance := INF
	for index in crystals.size():
		if crystals[index].visible:
			var distance := player.global_position.distance_to(crystals[index].global_position)
			if distance < nearest_distance:
				nearest_index = index
				nearest_distance = distance
	if nearest_index >= 0:
		target_label.text = "Nearest crystal: %s • %dm" % [crystal_locations[nearest_index], roundi(nearest_distance)]

func _animate_environment(delta: float) -> void:
	world_time += delta
	for index in crystals.size():
		var crystal := crystals[index]
		crystal.position = crystal_base_positions[index] + Vector3(0, sin(world_time * 2.0 + index) * 0.16, 0)
		crystal.rotate_y(delta * 1.5)
	river.position.y = 0.28 + sin(world_time * 1.4) * 0.025
	campfire_light.light_energy = 1.55 + sin(world_time * 8.0) * 0.22 + sin(world_time * 13.0) * 0.1
	sun.light_energy = 1.05 + sin(world_time * 0.08) * 0.15

func _create_landmark_colliders() -> void:
	for node_path in TREE_OBSTACLES:
		_add_landmark_collider(node_path, 1.35, 5.0)
	for node_path in ROCK_OBSTACLES:
		_add_landmark_collider(node_path, 1.1, 3.0)

func _scale_environment_assets() -> void:
	for node_path in TREE_OBSTACLES:
		_scale_environment_asset(node_path, 5.0)
	for node_path in LARGE_WORLD_PROPS:
		_scale_environment_asset(node_path, 3.2)
	for node_path in PATH_PROPS:
		_scale_environment_asset(node_path, 2.6)
	for node_path in GROUND_DETAILS:
		_scale_environment_asset(node_path, 2.8)
	$BaseCamp/Campfire/FireLight.position = Vector3(0, 0.55, 0)

func _scale_environment_asset(node_path: NodePath, scale_factor: float) -> void:
	var asset := get_node_or_null(node_path) as Node3D
	if is_instance_valid(asset):
		asset.scale = Vector3.ONE * scale_factor

func _add_landmark_collider(node_path: NodePath, radius: float, height: float) -> void:
	var landmark := get_node_or_null(node_path) as Node3D
	if not is_instance_valid(landmark):
		return
	var body := StaticBody3D.new()
	body.name = "%sCollider" % landmark.name
	body.position = landmark.position + Vector3(0, height * 0.5 - 0.25, 0)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _reset_adventure() -> void:
	crystals_collected = 0
	adventure_complete = false
	for candidate in crystals:
		candidate.visible = true
	objective.text = "Forest crystals: 0/%d" % crystals.size()
	prompt.text = ""

func _request_collect(index: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_collect.rpc_id(1, index)
	else:
		_apply_collect(index)
		_broadcast_world_state()

func _request_restore() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_restore.rpc_id(1)
	else:
		adventure_complete = true
		objective.text = "You restored the shrine"
		_broadcast_world_state()

func _request_reset() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_reset.rpc_id(1)
	else:
		_reset_adventure()
		_broadcast_world_state()

func _apply_collect(index: int) -> void:
	if index < 0 or index >= crystals.size() or not crystals[index].visible:
		return
	crystals[index].visible = false
	crystals[index].get_node("CrystalLight").visible = false
	crystals_collected += 1
	prompt.text = "Crystal collected!"
	objective.text = "Forest crystals: %d/%d" % [crystals_collected, crystals.size()]

func _on_state_requested(peer_id: int) -> void:
	if multiplayer.is_server():
		sync_world_state.rpc_id(peer_id, _collected_indices(), adventure_complete)

func _collected_indices() -> Array[int]:
	var collected: Array[int] = []
	for index in crystals.size():
		if not crystals[index].visible:
			collected.append(index)
	return collected

func _broadcast_world_state() -> void:
	_persist_world_state()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_world_state.rpc(_collected_indices(), adventure_complete)

@rpc("any_peer", "call_remote", "reliable")
func request_collect(index: int) -> void:
	if not multiplayer.is_server():
		return
	var remote_player = players.get(multiplayer.get_remote_sender_id()) as CharacterBody3D
	if is_instance_valid(remote_player) and index >= 0 and index < crystals.size() and remote_player.global_position.distance_to(crystals[index].global_position) < 2.3:
		_apply_collect(index)
		_broadcast_world_state()

@rpc("any_peer", "call_remote", "reliable")
func request_restore() -> void:
	if not multiplayer.is_server():
		return
	var remote_player = players.get(multiplayer.get_remote_sender_id()) as CharacterBody3D
	if is_instance_valid(remote_player) and crystals_collected == crystals.size() and remote_player.global_position.distance_to(shrine.global_position) < 2.5:
		adventure_complete = true
		objective.text = "You restored the shrine"
		_broadcast_world_state()

@rpc("any_peer", "call_remote", "reliable")
func request_reset() -> void:
	if multiplayer.is_server():
		_reset_adventure()
		_broadcast_world_state()

@rpc("authority", "call_remote", "reliable")
func sync_world_state(collected: Array[int], complete: bool) -> void:
	_apply_world_state(collected, complete)

func _apply_world_state(collected: Array[int], complete: bool) -> void:
	crystals_collected = collected.size()
	adventure_complete = complete
	for index in crystals.size():
		crystals[index].visible = not collected.has(index)
		crystals[index].get_node("CrystalLight").visible = not collected.has(index)
	shrine_light.light_color = Color(0.35, 1.0, 0.62, 1) if complete else Color(0.2, 0.45, 1, 1)
	shrine_light.light_energy = 3.4 if complete else 2.0
	objective.text = "You restored the shrine" if complete else "Forest crystals: %d/%d" % [crystals_collected, crystals.size()]

func _persist_world_state() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"collected": _collected_indices(), "complete": adventure_complete}))

func _load_world_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return
	var collected: Array[int] = []
	for index in parsed.get("collected", []):
		collected.append(int(index))
	_apply_world_state(collected, bool(parsed.get("complete", false)))

func _on_session_started(initial_players: Array) -> void:
	_clear_players()
	for peer_id in initial_players:
		_spawn_player(peer_id)

func _on_session_ended() -> void:
	_clear_players()
	_spawn_player(1)

func _spawn_player(peer_id: int) -> void:
	if players.has(peer_id):
		return
	var new_player := PLAYER_SCENE.instantiate() as CharacterBody3D
	new_player.name = "Player%d" % peer_id
	new_player.set("peer_id", peer_id)
	new_player.position = Vector3(-1.5 + players.size() * 3.0, 1.2, 4)
	$Players.add_child(new_player)
	new_player.movement_updated.connect(_on_player_movement.bind(peer_id))
	players[peer_id] = new_player
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if peer_id == local_id:
		player = new_player
	if not test_mode.is_empty():
		print("NETWORK_TEST: %s spawned player %d" % [test_mode, peer_id])

func _remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	if players[peer_id] == player:
		player = null
	players[peer_id].queue_free()
	players.erase(peer_id)

func _clear_players() -> void:
	for existing_player in players.values():
		existing_player.queue_free()
	players.clear()
	player = null

func _on_player_movement(position: Vector3, visual_yaw: float, peer_id: int) -> void:
	if multiplayer.is_server():
		sync_player_state.rpc(peer_id, position, visual_yaw)
	else:
		submit_player_state.rpc_id(1, position, visual_yaw)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_player_state(position: Vector3, visual_yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if test_mode == "host" and not test_packet_received:
		print("NETWORK_TEST: host received player state packet from %d" % peer_id)
		test_packet_received = true
	if players.has(peer_id):
		players[peer_id].global_position = position
		players[peer_id].get_node("Visual").rotation.y = visual_yaw
		sync_player_state.rpc(peer_id, position, visual_yaw)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sync_player_state(peer_id: int, position: Vector3, visual_yaw: float) -> void:
	if players.has(peer_id):
		players[peer_id].global_position = position
		players[peer_id].get_node("Visual").rotation.y = visual_yaw

func _start_network_test() -> void:
	if test_mode == "host":
		Network.host()
	else:
		Network.join("127.0.0.1", Network.DEFAULT_PORT)
	get_tree().create_timer(4.0).timeout.connect(get_tree().quit)

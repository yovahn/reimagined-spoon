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

const PLAYER_SCENE := preload("res://scenes/player_3d.tscn")
const SAVE_PATH := "user://forest_world_state.json"
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

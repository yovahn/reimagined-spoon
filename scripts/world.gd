extends Node2D

const WORLD_SIZE := Vector2(1920, 1080)
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const GATE_RECT := Rect2(920, 438, 48, 156)
const CRYSTAL_POSITION := Vector2(1480, 720)
const SAVE_PATH := "user://shared_world.json"
var obstacles := [Rect2(0, -32, 1920, 32), Rect2(0, 1080, 1920, 32), Rect2(-32, 0, 32, 1080), Rect2(1920, 0, 32, 1080), Rect2(280, 180, 410, 72), Rect2(280, 180, 72, 280), Rect2(1230, 190, 330, 78), Rect2(1370, 580, 220, 64), Rect2(360, 760, 480, 64)]
var players: Dictionary = {}
var gate_body: StaticBody2D
var world_state := {"gate_open": false, "crystal_collected": false}
var test_mode := ""
var test_move_sent := false

func _ready() -> void:
	for index in obstacles.size(): _add_obstacle(obstacles[index], index)
	_create_gate_collision()
	_load_world_state()
	Network.session_started.connect(_on_session_started)
	Network.player_joined.connect(_spawn_player)
	Network.player_left.connect(_remove_player)
	Network.session_ended.connect(_on_session_ended)
	Network.interaction_requested.connect(_on_interaction_requested)
	Network.state_requested.connect(_on_state_requested)
	Network.world_state_received.connect(_apply_world_state)
	_apply_world_state(world_state)
	_spawn_player(1)
	for argument in OS.get_cmdline_user_args():
		if argument == "--network-test-host": test_mode = "host"
		if argument == "--network-test-client": test_mode = "client"
	if not test_mode.is_empty(): call_deferred("_start_network_test")
	queue_redraw()

func _process(_delta: float) -> void:
	if test_mode == "client" and not test_move_sent and multiplayer.has_multiplayer_peer():
		var local_id := multiplayer.get_unique_id()
		if players.has(local_id):
			players[local_id].position += Vector2(50, 0)
			players[local_id].sync_position.rpc(players[local_id].position)
			test_move_sent = true
			print("NETWORK_TEST: client sent position update")

func _start_network_test() -> void:
	if test_mode == "host": Network.host()
	else: Network.join("127.0.0.1", Network.DEFAULT_PORT)
	get_tree().create_timer(4.0).timeout.connect(get_tree().quit)

func _on_session_started(initial_players: Array) -> void:
	_clear_players()
	for peer_id in initial_players: _spawn_player(peer_id)
	if multiplayer.is_server(): Network.broadcast_world_state(world_state)

func _on_session_ended() -> void:
	_clear_players()
	_spawn_player(1)

func _on_state_requested(peer_id: int) -> void:
	Network.send_world_state_to(peer_id, world_state)

func request_interaction(_peer_id: int, position: Vector2) -> void:
	Network.request_interaction(position)

func _on_interaction_requested(_peer_id: int, position: Vector2) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
	if not world_state.gate_open and position.distance_to(GATE_RECT.get_center()) < 90:
		world_state.gate_open = true
		_commit_state()
	elif not world_state.crystal_collected and position.distance_to(CRYSTAL_POSITION) < 70:
		world_state.crystal_collected = true
		_commit_state()

func _commit_state() -> void:
	_apply_world_state(world_state)
	_save_world_state()
	Network.broadcast_world_state(world_state)

func _apply_world_state(state: Dictionary) -> void:
	world_state = state.duplicate(true)
	if is_instance_valid(gate_body): gate_body.get_node("CollisionShape2D").set_deferred("disabled", world_state.gate_open)
	queue_redraw()

func _save_world_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(world_state))

func _load_world_state() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary: world_state = parsed

func _spawn_player(peer_id: int) -> void:
	if players.has(peer_id): return
	var player := PLAYER_SCENE.instantiate()
	player.name = "Player%d" % peer_id
	player.peer_id = peer_id
	player.position = Vector2(128 + players.size() * 64, 540)
	add_child(player)
	players[peer_id] = player
	if not test_mode.is_empty(): print("NETWORK_TEST: spawned player %d" % peer_id)

func _remove_player(peer_id: int) -> void:
	if players.has(peer_id):
		players[peer_id].queue_free()
		players.erase(peer_id)

func _clear_players() -> void:
	for player in players.values():
		remove_child(player)
		player.queue_free()
	players.clear()

func _create_gate_collision() -> void:
	gate_body = StaticBody2D.new()
	gate_body.position = GATE_RECT.get_center()
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = GATE_RECT.size
	collision.shape = shape
	gate_body.add_child(collision)
	add_child(gate_body)

func _add_obstacle(rect: Rect2, index: int) -> void:
	var body := StaticBody2D.new()
	body.name = "Boundary" if index < 4 else "Obstacle%d" % index
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("9bcf7a"))
	for x in range(0, 1920, 64):
		for y in range(0, 1080, 64):
			if (x / 64 + y / 64) as int % 2 == 0: draw_rect(Rect2(x, y, 64, 64), Color("a8d687"))
	for index in range(4, obstacles.size()): draw_rect(obstacles[index], Color("497c52"))
	if not world_state.gate_open: draw_rect(GATE_RECT, Color("8a5735"))
	if not world_state.crystal_collected:
		var points := PackedVector2Array([CRYSTAL_POSITION + Vector2(0, -24), CRYSTAL_POSITION + Vector2(18, 0), CRYSTAL_POSITION + Vector2(0, 24), CRYSTAL_POSITION + Vector2(-18, 0)])
		draw_colored_polygon(points, Color("c97cff"))

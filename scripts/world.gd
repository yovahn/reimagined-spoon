extends Node2D

const WORLD_SIZE := Vector2(960, 540)
const BORDER_THICKNESS := 32.0
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var obstacles := [
	# Screen boundaries.
	Rect2(0, -BORDER_THICKNESS, WORLD_SIZE.x, BORDER_THICKNESS),
	Rect2(0, WORLD_SIZE.y, WORLD_SIZE.x, BORDER_THICKNESS),
	Rect2(-BORDER_THICKNESS, 0, BORDER_THICKNESS, WORLD_SIZE.y),
	Rect2(WORLD_SIZE.x, 0, BORDER_THICKNESS, WORLD_SIZE.y),
	# Visible obstacles.
	Rect2(230, 120, 210, 46),
	Rect2(600, 220, 110, 190),
	Rect2(250, 385, 240, 48),
]
var players: Dictionary = {}
var test_mode := ""
var test_move_sent := false


func _ready() -> void:
	for index in obstacles.size():
		_add_obstacle(obstacles[index], index)
	Network.session_started.connect(_on_session_started)
	Network.player_joined.connect(_spawn_player)
	Network.player_left.connect(_remove_player)
	Network.session_ended.connect(_on_session_ended)
	_spawn_player(1)
	for argument in OS.get_cmdline_user_args():
		if argument == "--network-test-host":
			test_mode = "host"
		if argument == "--network-test-client":
			test_mode = "client"
	if not test_mode.is_empty():
		call_deferred("_start_network_test")
	queue_redraw()


func _start_network_test() -> void:
	if test_mode == "host":
		Network.host()
	else:
		Network.join("127.0.0.1", Network.DEFAULT_PORT)
	get_tree().create_timer(4.0).timeout.connect(get_tree().quit)


func _process(_delta: float) -> void:
	# Used only by the headless verification command. It proves that a client
	# can send a position update which the host receives.
	if test_mode != "client" or test_move_sent or not multiplayer.has_multiplayer_peer():
		return
	var local_peer_id := multiplayer.get_unique_id()
	if not players.has(local_peer_id):
		return
	var local_player = players[local_peer_id]
	local_player.position += Vector2(50, 0)
	local_player.sync_position.rpc(local_player.position)
	test_move_sent = true
	print("NETWORK_TEST: client sent position update")


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
	var player := PLAYER_SCENE.instantiate()
	player.name = "Player%d" % peer_id
	player.peer_id = peer_id
	player.position = Vector2(96 + (players.size() * 56), 270)
	add_child(player)
	players[peer_id] = player
	if not test_mode.is_empty():
		print("NETWORK_TEST: spawned player %d" % peer_id)


func _remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	players[peer_id].queue_free()
	players.erase(peer_id)


func _clear_players() -> void:
	for player in players.values():
		remove_child(player)
		player.queue_free()
	players.clear()


func _add_obstacle(rect: Rect2, index: int) -> void:
	var body := StaticBody2D.new()
	body.name = "WorldBoundary" if index < 4 else "Obstacle%d" % index
	body.position = rect.get_center()

	var collision_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	add_child(body)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("9bcf7a"))

	# A faint grid makes movement easier to read while we have no art assets.
	for x in range(0, int(WORLD_SIZE.x) + 1, 48):
		draw_line(Vector2(x, 0), Vector2(x, WORLD_SIZE.y), Color(0.2, 0.4, 0.22, 0.13), 1.0)
	for y in range(0, int(WORLD_SIZE.y) + 1, 48):
		draw_line(Vector2(0, y), Vector2(WORLD_SIZE.x, y), Color(0.2, 0.4, 0.22, 0.13), 1.0)

	for index in range(4, obstacles.size()):
		draw_rect(obstacles[index], Color("497c52"))
		draw_rect(obstacles[index], Color("2e593a"), false, 2.0)

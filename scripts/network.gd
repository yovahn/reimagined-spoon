extends Node

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 2

signal session_started(initial_players: Array)
signal session_ended
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal status_changed(message: String)

var connected_players: Array[int] = []
var status_text := "Offline — host or join a two-player test."


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host(port: int = DEFAULT_PORT) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		_set_status("Could not host on UDP port %d (error %d)." % [port, error])
		return
	multiplayer.multiplayer_peer = peer
	connected_players = [1]
	session_started.emit([1])
	_set_status("Hosting on UDP port %d — waiting for one player." % port)


func join(address: String, port: int = DEFAULT_PORT) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		_set_status("Could not connect to %s:%d (error %d)." % [address, port, error])
		return
	multiplayer.multiplayer_peer = peer
	session_started.emit([])
	_set_status("Connecting to %s:%d…" % [address, port])


func leave() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	connected_players.clear()


func _on_connected_to_server() -> void:
	_set_status("Connected. Waiting for player data…")


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_set_status("Connection failed. Check the address and port.")
	session_ended.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	_set_status("Disconnected from host.")
	session_ended.emit()


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for existing_peer_id in connected_players:
		announce_player.rpc_id(peer_id, existing_peer_id)
	connected_players.append(peer_id)
	announce_player.rpc(peer_id)
	player_joined.emit(peer_id)
	_set_status("Two players connected.")


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	connected_players.erase(peer_id)
	remove_player.rpc(peer_id)
	player_left.emit(peer_id)
	_set_status("Player disconnected.")


@rpc("authority", "call_remote", "reliable")
func announce_player(peer_id: int) -> void:
	player_joined.emit(peer_id)
	_set_status("Two players connected.")


@rpc("authority", "call_remote", "reliable")
func remove_player(peer_id: int) -> void:
	player_left.emit(peer_id)
	_set_status("Player disconnected.")


func _set_status(message: String) -> void:
	status_text = message
	status_changed.emit(message)

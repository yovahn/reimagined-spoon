extends CharacterBody2D

@export var speed := 230.0
var peer_id := 1


func _ready() -> void:
	set_multiplayer_authority(peer_id)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	var direction := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	).normalized()

	velocity = direction * speed
	move_and_slide()
	if multiplayer.has_multiplayer_peer():
		sync_position.rpc(position)


@rpc("authority", "call_remote", "unreliable_ordered")
func sync_position(new_position: Vector2) -> void:
	position = new_position
	if "--network-test-host" in OS.get_cmdline_user_args():
		print("NETWORK_TEST: host received remote position %s" % new_position)


func _draw() -> void:
	# A temporary character: replace this with a sprite later.
	var locally_owned := not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	var color := Color("ef8354") if locally_owned else Color("5b8def")
	draw_circle(Vector2.ZERO, 18.0, color)
	draw_circle(Vector2(6, -4), 3.0, Color("17211a"))

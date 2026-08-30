extends CharacterBody2D

@export var speed := 230.0
var peer_id := 1


func _ready() -> void:
	set_multiplayer_authority(peer_id)
	$Camera2D.enabled = not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	$Camera2D.limit_right = 1920
	$Camera2D.limit_bottom = 1080
	_add_name_label()
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


func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		get_parent().request_interaction(peer_id, position)


func _add_name_label() -> void:
	var label := Label.new()
	label.text = "Host" if peer_id == 1 else "Guest"
	label.position = Vector2(-30, -46)
	label.size = Vector2(60, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)


@rpc("authority", "call_remote", "unreliable_ordered")
func sync_position(new_position: Vector2) -> void:
	position = new_position
	if "--network-test-host" in OS.get_cmdline_user_args():
		print("NETWORK_TEST: host received remote position %s" % new_position)


func _draw() -> void:
	# A temporary character: replace this with a sprite later.
	var locally_owned := not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()
	var color := Color("ef8354") if peer_id == 1 else Color("5b8def")
	draw_circle(Vector2.ZERO, 18.0, color)
	draw_circle(Vector2(6, -4), 3.0, Color("17211a"))

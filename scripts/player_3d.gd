extends CharacterBody3D

@export var speed := 6.0
@export var sprint_speed := 10.0
@export var gravity := 18.0
@export var jump_velocity := 7.0
@export var mouse_sensitivity := 0.003

@onready var camera_pivot: Node3D = $CameraPivot

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(-55.0), deg_to_rad(-15.0))
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	var input := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	var forward := -camera_pivot.global_transform.basis.z
	var right := camera_pivot.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	var direction := (right.normalized() * input.x - forward.normalized() * input.y).normalized()
	var active_speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else speed
	velocity.x = direction.x * active_speed
	velocity.z = direction.z * active_speed
	if not is_on_floor(): velocity.y -= gravity * delta
	else:
		velocity.y = -0.1
		if Input.is_key_pressed(KEY_SPACE): velocity.y = jump_velocity
	move_and_slide()

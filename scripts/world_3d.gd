extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var crystal: MeshInstance3D = $CrystalDestination
@onready var shrine: MeshInstance3D = $ReturnShrine
@onready var prompt: Label = $HUD/Prompt
@onready var objective: Label = $HUD/Objective

var crystal_collected := false
var adventure_complete := false
var interact_released := true

func _process(_delta: float) -> void:
	if adventure_complete:
		return
	if crystal_collected:
		var at_shrine := player.global_position.distance_to(shrine.global_position) < 2.5
		prompt.text = "Press E to return the crystal" if at_shrine else "Return to the blue shrine"
		if Input.is_key_pressed(KEY_E) and interact_released and at_shrine:
			adventure_complete = true
			prompt.text = "Adventure complete!"
			objective.text = "You restored the shrine"
			interact_released = false
		if not Input.is_key_pressed(KEY_E): interact_released = true
		return
	var nearby := player.global_position.distance_to(crystal.global_position) < 2.2
	prompt.text = "Press E to collect the crystal" if nearby else ""
	if Input.is_key_pressed(KEY_E) and interact_released and nearby:
		crystal_collected = true
		crystal.visible = false
		prompt.text = "Crystal collected!"
		objective.text = "Objective complete — explore the clearing"
		interact_released = false
	if not Input.is_key_pressed(KEY_E):
		interact_released = true

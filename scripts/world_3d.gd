extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var crystal: MeshInstance3D = $CrystalDestination
@onready var prompt: Label = $HUD/Prompt
@onready var objective: Label = $HUD/Objective

var crystal_collected := false
var interact_released := true

func _process(_delta: float) -> void:
	if crystal_collected:
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

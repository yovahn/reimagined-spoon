extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var shrine: MeshInstance3D = $ReturnShrine
@onready var prompt: Label = $HUD/Prompt
@onready var objective: Label = $HUD/Objective
@onready var location_label: Label = $HUD/Location
@onready var crystals: Array[MeshInstance3D] = [$CrystalDestination, $CrystalShardForest, $CrystalShardMeadow]

var crystals_collected := 0
var adventure_complete := false
var interact_released := true

func _process(_delta: float) -> void:
	_update_location_label()
	if adventure_complete:
		prompt.text = "Adventure complete! Press R to begin again"
		if Input.is_key_pressed(KEY_R) and interact_released:
			_reset_adventure()
			interact_released = false
		if not Input.is_key_pressed(KEY_R):
			interact_released = true
		return
	if crystals_collected == crystals.size():
		var at_shrine := player.global_position.distance_to(shrine.global_position) < 2.5
		prompt.text = "Press E to restore the shrine" if at_shrine else "Return all crystals to the blue shrine"
		if Input.is_key_pressed(KEY_E) and interact_released and at_shrine:
			adventure_complete = true
			objective.text = "You restored the shrine"
			interact_released = false
		if not Input.is_key_pressed(KEY_E): interact_released = true
		return
	var nearby_crystal := _get_nearby_crystal()
	prompt.text = "Press E to collect a forest crystal" if nearby_crystal else ""
	if Input.is_key_pressed(KEY_E) and interact_released and nearby_crystal:
		nearby_crystal.visible = false
		crystals_collected += 1
		prompt.text = "Crystal collected!"
		objective.text = "Forest crystals: %d/%d" % [crystals_collected, crystals.size()]
		interact_released = false
	if not Input.is_key_pressed(KEY_E):
		interact_released = true

func _get_nearby_crystal() -> MeshInstance3D:
	for candidate in crystals:
		if candidate.visible and player.global_position.distance_to(candidate.global_position) < 2.3:
			return candidate
	return null

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

func _reset_adventure() -> void:
	crystals_collected = 0
	adventure_complete = false
	for candidate in crystals:
		candidate.visible = true
	objective.text = "Forest crystals: 0/%d" % crystals.size()
	prompt.text = ""

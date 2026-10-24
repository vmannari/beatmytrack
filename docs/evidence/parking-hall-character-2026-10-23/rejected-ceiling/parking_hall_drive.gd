extends "res://core/game.gd"
## Reuses the real car, canonical handling, input, audio and camera. No race sink.
const HallData = preload("res://garage/parking_hall_data.gd")
const HallVisual = preload("res://garage/parking_hall_visual.gd")

func _init() -> void:
	production_mode = true
	editor_test = true
	free_drive_mode = true
	yard = HallData.new()

func _build_ground(world: Node3D) -> void:
	# Command-line handling-track fixtures cannot replace the garage facility.
	native_track = null
	yard = HallData.new()
	bridge_presentation = null
	var visual := HallVisual.new()
	world.add_child(visual)
	visual.build(yard)
	track_ground = visual

func _update_weather() -> void:
	biome_light.rotation_degrees = Vector3(-78,-20,0)
	biome_light.light_color = Color("dce7eb")
	biome_light.light_energy = 0.48
	biome_environment.background_color = Color("252e34")
	biome_environment.ambient_light_color = Color("bfcbd1")
	biome_environment.ambient_light_energy = 0.63

func _process(delta: float) -> void:
	super._process(delta)
	if preparation_complete and is_instance_valid(car) and is_instance_valid(track_ground):
		track_ground.present_focus(Vector2(car.position.x,-car.position.z))

func restart() -> void:
	super.restart()
	hud.title.text = "Parking hall"
	hud.message_label.text = ""

func _save_condition(_background: bool = false) -> void:
	# Experimenting in the hall never overwrites the garage's saved condition.
	condition_save_elapsed = 0.0

func toggle_pause(capture: bool = true) -> void:
	super.toggle_pause(capture)
	if hud != null: hud.message_label.text = ""

extends "res://tests/test_volt_night_glass_shape.gd"
func native_checks() -> void:
	var source: Shader = GLASS
	var original: String = source.code
	source.code = FileAccess.get_file_as_string("res://../docs/evidence/volt-night-glass-shape-2026-11-06/candidate-elevation.gdshader.txt")
	await super.native_checks()
	source.code = original

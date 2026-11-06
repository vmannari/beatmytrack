extends RefCounted
## Test-only packed Game with the task-start queue and otherwise current code.
static func create() -> PackedScene:
	var code: String = FileAccess.get_file_as_string("res://core/game.gd")
	var needle: String = 'preload("res://race/world_render_preparation.gd").new()'
	if code.count(needle) != 1: push_error("Missing exact world queue constructor"); return null
	var script := GDScript.new()
	script.source_code = code.replace(needle,'preload("res://../docs/evidence/graphics-preparation-2026-11-04/before/game/race/world_render_preparation.gd").new()')
	if script.reload() != OK: return null
	var original: Node = load("res://core/game.tscn").instantiate()
	original.set_script(script)
	var scene := PackedScene.new()
	var error: Error = scene.pack(original)
	original.free()
	return scene if error == OK else null

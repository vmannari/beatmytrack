extends "res://tests/test_editor_t01_t04.gd"
func run() -> void:
	var doc: Dictionary = circuit()
	print("FIXTURE ",JSON.stringify({"errors":TrackDocument.validate(doc),"document":doc}))
	quit()

extends "res://tests/test_script_parse.gd"
## Production boundary; the unchanged broad suite retains archived fixture failures.
func scan(path: String) -> void:
	if path.begins_with("res://tests"): return
	super.scan(path)

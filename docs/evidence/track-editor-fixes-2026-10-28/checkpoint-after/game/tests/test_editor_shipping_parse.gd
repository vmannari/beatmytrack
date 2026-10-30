extends "res://tests/test_script_parse.gd"
## Supplement the unmodified whole-tree check with the exportable source scope.
func scan(path: String) -> void:
	if path == "res://tests": return
	super.scan(path)

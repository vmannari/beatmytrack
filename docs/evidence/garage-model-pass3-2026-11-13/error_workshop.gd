extends "res://tests/bake_garage_architecture.gd"
var injected: bool = false
func _sources() -> Dictionary:
	var result: Dictionary = super._sources()
	if not injected:
		injected = true
		push_error("EXPECTED_BAKE_ERROR_INJECTION")
	return result

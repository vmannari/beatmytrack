extends "res://tests/bake_garage_architecture.gd"
var reads: int = 0
func _sources() -> Dictionary:
	var result: Dictionary = super._sources()
	reads += 1
	if reads > 1: result["injected-source-mutation"] = "changed"
	return result

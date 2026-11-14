extends "res://../scripts/bake_garage_previews.gd"
var reads: int = 0
func _sources() -> Dictionary:
	var result: Dictionary = super._sources()
	reads += 1
	if reads > 1: result["injected-source-mutation"] = "changed"
	return result

extends SceneTree
func _initialize()->void:
	var scene: PackedScene=load("res://assets/vehicles/modular_car_bases_v1/compact_simple_fixed.scn")
	var holder: Node=scene.instantiate()
	FileAccess.open("res://../docs/evidence/asset-optimisation-2026-11-08/baked-sources.json",FileAccess.WRITE).store_string(JSON.stringify(holder.get_meta("modular_car_base").sources,"\t"))
	holder.free();quit()

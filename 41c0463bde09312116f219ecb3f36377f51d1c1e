extends SceneTree
func _initialize()->void:
	var scene: PackedScene=load("res://assets/vehicles/modular_car_bases_v1/compact_simple_fixed.scn")
	if scene==null:quit(1);return
	var holder: Node=scene.instantiate();var data: Dictionary=holder.get_meta("modular_car_base",{})
	print("METADATA_KEYS ",holder.get_meta_list()," ",data.keys())
	var now: Dictionary=preload("res://vehicle/modular_car_base.gd").source_hashes("compact")
	var old: Dictionary=data.get("sources",{})
	for key: Variant in now:
		if old.get(key)!=now[key]:print("SOURCE_CHANGE ",key," OLD ",old.get(key)," NOW ",now[key])
	holder.free();quit()

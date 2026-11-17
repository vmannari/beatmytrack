extends SceneTree
func _initialize() -> void:
	var checks: int=0;var tagged: int=0
	for id: String in ["compact","kart","hovercraft"]:
		var path: String="res://assets/vehicles/modular_car_bases_v1/"+id+"_simple_fixed.scn"
		var helper=load("res://tests/support/car_refinement_lods.gd").new();helper.remember(path)
		var holder: Node=load(path).instantiate()
		for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
			if not part.mesh.has_meta("car_mechanics_added_levels"):continue
			tagged+=1
			for packet: Dictionary in part.mesh.get("_surfaces"):
				var stored: Array=packet.get("lods",[])
				if not stored.is_empty():print("REGIONAL_INDEX_STORAGE ",id," type=",type_string(typeof(stored[1]))," units=",stored[1].size())
			var code: String=helper.master_key(part.mesh)
			if not helper.previous.has(code):continue
			for entry: Array in part.mesh.get_meta("car_mechanics_added_levels"):
				var levels: Array=helper.previous[code][int(entry[0])]
				for at: int in range(0,levels.size(),2):
					assert(levels[at]!=entry[1],"Old regional indices cannot be reused across same-threshold revisions");checks+=1
		holder.free()
	assert(tagged>=7,"Every scoped regional group survives actual preparation");checks+=1
	print("MECHANICS_LOD_REUSE ",checks," checks; ",tagged," tagged parts; 0 failures");quit()

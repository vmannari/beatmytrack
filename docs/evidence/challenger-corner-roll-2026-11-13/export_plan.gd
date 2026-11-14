extends SceneTree
func _initialize() -> void:
	var result: Dictionary = {}
	var before: bool="--before" in OS.get_cmdline_user_args()
	var candidate: bool="--candidate" in OS.get_cmdline_user_args()
	var base: String="res://../docs/evidence/challenger-corner-roll-2026-11-13/before/" if before else SuperRallyModel.ROOT
	if candidate:base="res://../build/challenger-corner-roll-2026-11-13/native/"
	for tier: String in ["simple","full"]:
		var parts: Dictionary = {}
		for role: String in ["body_paint","hood_paint"]:
			var mesh: Mesh = ResourceLoader.load(base+tier+"_"+role+".res","",ResourceLoader.CACHE_MODE_IGNORE)
			var values: Array = []
			for v: Vector3 in mesh.get_faces():values.append([v.x,v.y,v.z])
			parts[role] = values
			if role=="body_paint":
				var normals: Array=[]
				for surface: int in range(mesh.get_surface_count()):
					var data: Array=mesh.surface_get_arrays(surface)
					var vertex_normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
					for index: int in data[Mesh.ARRAY_INDEX]:
						var n: Vector3=vertex_normals[index];normals.append([n.x,n.y,n.z])
				parts[role+"_normals"]=normals
		result[tier] = parts
	var path: String = "res://../build/challenger-corner-roll-2026-11-13/native-plan"+("-before" if before else "-candidate" if candidate else "")+".json"
	var f := FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(result));f.close()
	print("NATIVE_PLAN_EXPORT: both native paint tiers")
	quit()

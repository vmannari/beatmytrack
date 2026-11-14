extends SceneTree
func _initialize() -> void:
	var result: Dictionary = {}
	var before: bool="--before" in OS.get_cmdline_user_args()
	var candidate: bool="--candidate" in OS.get_cmdline_user_args()
	var base: String="res://../docs/evidence/challenger-surface-simplification-2026-11-14/before/game/assets/vehicles/challenger_hellcat_v1/" if before else SuperRallyModel.ROOT
	if candidate:base="res://../build/challenger-surface-simplification-2026-11-14/native/"
	for tier: String in ["simple","full"]:
		var parts: Dictionary = {}
		for role: String in ["body_paint","hood_paint"]:
			var mesh_path: String = base+tier+"_"+role+".res"
			if not FileAccess.file_exists(mesh_path): mesh_path = SuperRallyModel.ROOT+tier+"_"+role+".res"
			var mesh: Mesh = ResourceLoader.load(mesh_path,"",ResourceLoader.CACHE_MODE_IGNORE)
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
	var path: String = "res://../build/challenger-surface-simplification-2026-11-14/native-plan"+("-before" if before else "-candidate" if candidate else "")+".json"
	var f := FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(result));f.close()
	print("NATIVE_PLAN_EXPORT: both native paint tiers")
	quit()

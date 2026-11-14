extends SceneTree
func _initialize() -> void:
	var result: Dictionary = {}
	var before: bool="--before" in OS.get_cmdline_user_args()
	var base: String="res://../docs/evidence/challenger-nose-curve-2026-11-13/before/" if before else SuperRallyModel.ROOT
	for tier: String in ["simple","full"]:
		var parts: Dictionary = {}
		for role: String in ["body_paint","hood_paint"]:
			var mesh: Mesh = ResourceLoader.load(base+tier+"_"+role+".res","",ResourceLoader.CACHE_MODE_IGNORE)
			var values: Array = []
			for v: Vector3 in mesh.get_faces():values.append([v.x,v.y,v.z])
			parts[role] = values
		result[tier] = parts
	var path: String = "res://../build/challenger-nose-curve-2026-11-13/native-plan"+("-before" if before else "")+".json"
	var f := FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(result));f.close()
	print("NATIVE_PLAN_EXPORT: both native paint tiers")
	quit()

extends SceneTree

func _initialize() -> void:
	var prefix: String="res://../build/challenger-rear-surface-2026-11-17/native/"
	if "--production" in OS.get_cmdline_user_args():
		prefix=SuperRallyModel.ROOT
	SuperRallyModel.hood_profile=JSON.parse_string(FileAccess.get_file_as_string(prefix+"hood_profile.json"))
	var checks: int=0
	var maximum_error: float=0
	for tier: String in ["simple","full"]:
		var mesh: ArrayMesh=load(prefix+tier+"_hood_paint.res")
		var skin: TriangleMesh=mesh.generate_triangle_mesh()
		for across: float in [-1.0,-.90,-.35,-.15,0.0,.15,.35,.90,1.0]:
			for along: float in [.35,.57,.70,.91]:
				var point: Vector3=SuperRallyModel.hood_point(across,along)
				var hit: Dictionary=skin.intersect_ray(Vector3(point.x,2,point.z),Vector3.DOWN)
				checks+=1
				assert(not hit.is_empty(),"Fitted bonnet point must land on the replacement skin")
				var error: float=absf(point.y-(hit.position as Vector3).y)
				maximum_error=maxf(maximum_error,error)
				checks+=1
				if error>=.002:print("FITTING_MISS ",tier," ",across," ",along," ",point," actual=",hit.position," error_mm=",error*1000)
	assert(maximum_error<.002,"Every fitted bonnet point must follow the replacement within 2mm")
	print("CHALLENGER_HOOD_FITTING ",checks," checks, 0 failures, maximum_mm=",maximum_error*1000)
	quit()

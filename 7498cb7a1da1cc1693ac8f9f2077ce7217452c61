extends "res://../build/asset-optimisation-2026-11-08/native.gd"
func cars()->void:
	for id: String in VehicleCatalog.IDS:
		for fitted: bool in [false,true]:
			var a: CarVisual=await car(id,fitted,false);var b: CarVisual=await car(id,fitted,true)
			pose_motion(a,b)
			await compare(a,b,id+("-fitted" if fitted else "-stock")+"-moving",5.0,Vector3(0,0.7,0))
			a.free();b.free();await process_frame

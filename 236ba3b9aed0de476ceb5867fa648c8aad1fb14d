extends "res://../build/asset-optimisation-2026-11-08/native.gd"
func cars()->void:
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		var a: CarVisual=await car(id,false,false);var b: CarVisual=await car(id,false,false)
		var paint: Dictionary=VehicleLivery.defaults(id);paint.colors.body="a14739";a.apply_livery(paint);b.apply_livery(paint)
		a.set_night_headlights(true);b.set_night_headlights(true)
		for repeat: int in range(3):await compare(a,b,id+"-unchanged-control-"+str(repeat),5.0,Vector3(0,0.7,0))
		a.free();b.free();await process_frame

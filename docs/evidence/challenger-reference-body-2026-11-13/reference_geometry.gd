extends "res://../docs/evidence/challenger-panels-2026-11-12/panel_geometry.gd"
func warp(z: float) -> float:return SuperRallyModel._nose_z(z,0.90)
func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	var folder: String = "res://../docs/evidence/challenger-reference-body-2026-11-13/"
	var base: String = folder+"before/" if before else "res://assets/vehicles/challenger_hellcat_v1/"
	var metrics: Array = []
	for tier: String in ["simple","full"]:
		var mesh: Mesh = load(base+tier+"_body_paint.res")
		var collider: StaticBody3D = collision(mesh,1)
		var dark: Mesh = load(base+tier+"_body_dark.res")
		var carrier: StaticBody3D = collision(dark,2)
		await physics_frame;await physics_frame
		for station: Vector2 in [Vector2(-1.70,0.802),Vector2(-1.25,0.823),Vector2(-0.35,0.833),Vector2(0.20,0.835),Vector2(0.80,0.880),Vector2(1.15,0.918),Vector2(1.55,0.931)]:
			for side: float in [-1.0,1.0]:
				var angles: Array[float] = [];var heights: Array[float] = []
				for i: int in range(61):
					var y: float = station.y-0.030+i*0.001
					var hit: Dictionary = cast(Vector3(side*2,y,warp(station.x)),Vector3(0,y,warp(station.x)),1)
					if hit.is_empty():hit = cast(Vector3(side*2,y,warp(station.x)+0.00001),Vector3(0,y,warp(station.x)+0.00001),1)
					check(not hit.is_empty(),tier+" continuous reference shoulder skin "+str(Vector2(station.x,y)))
					if hit.is_empty():continue
					var n: Vector3 = shade(mesh,hit)
					angles.append(rad_to_deg(atan2(n.y,absf(n.x))));heights.append(y)
				if angles.size()<50:continue
				var lower: float = angles[10];var upper: float = angles[angles.size()-11]
				var contrast: float = upper-lower
				check(contrast>25.0,tier+" distinct upper/lower shoulder planes z="+str(station.x)+" contrast="+str(contrast))
				var start: float = 0;var finish: float = 0;var peak: float = 0;var peak_y: float = 0
				for i: int in range(angles.size()):
					if start==0 and angles[i]>=lower+contrast*0.10:start=heights[i]
					if finish==0 and angles[i]>=lower+contrast*0.90:finish=heights[i]
					if i>0 and angles[i]-angles[i-1]>peak:peak=angles[i]-angles[i-1];peak_y=(heights[i]+heights[i-1])*0.5
				var width: float = finish-start if finish>start else 1.0
				check(width<0.014,tier+" tight shoulder bend instead of broad roll z="+str(station.x)+" width="+str(width))
				check(absf(peak_y-station.y)<0.008,tier+" crease follows reference-guided station "+str(station))
				metrics.append({"tier":tier,"side":side,"z":station.x,"plane_change_degrees":contrast,"transition_metres":width,"peak_height":peak_y})
		for z: float in [-1.86,-1.74]:
			for y: float in [0.57,0.64,0.71]:
				# The separate optical aperture is checked as a dark carrier,
				# rather than incorrectly requiring paint through the headlamps.
				if z< -1.94 and y>0.62:continue
				if z> -1.80 and y<0.60:continue # Rounded arch return, not the flat nose flank.
				for side: float in [-1.0,1.0]:
					var hit: Dictionary = cast(Vector3(side*2,y,warp(z)),Vector3(0,y,warp(z)),1)
					check(not hit.is_empty(),tier+" continuous nose side")
					if hit.is_empty():continue
					check(absf(hit.position.x-0.005052)>0.855,tier+" full-width nose flank "+str(Vector2(y,z)))
					check(absf(shade(mesh,hit).y)<0.35,tier+" upright outer nose wall "+str(Vector2(y,z)))
		var front_min: float = 0;var front_max: float = -10
		for x: float in [-0.78,-0.63,-0.45,-0.20,0.0,0.20,0.45,0.63,0.78]:
			var hit: Dictionary = cast(Vector3(x,0.76,-3),Vector3(x,0.76,-1.70),2)
			check(not hit.is_empty(),tier+" complete optical carrier across front width "+str(x))
			if hit.is_empty():continue
			front_min=minf(front_min,hit.position.z);front_max=maxf(front_max,hit.position.z)
			check(hit.position.z< -2.16,tier+" optical face sits forward in squared nose "+str(x))
			check(shade(dark,hit).z< -0.90,tier+" nearly upright optical face "+str(x))
		check(front_max-front_min<0.045,tier+" shallow front-face sweep "+str(front_max-front_min))
		collider.free();carrier.free();await physics_frame
	var file := FileAccess.open(folder+("before" if before else "after")+"-reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"));file.close()
	print("CHALLENGER_REFERENCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

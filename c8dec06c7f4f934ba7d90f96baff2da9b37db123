extends "res://../docs/evidence/challenger-panels-2026-11-12/panel_geometry.gd"
func run() -> void:
	var old: bool = "--before" in OS.get_cmdline_user_args()
	var base: String = "res://../docs/evidence/challenger-panels-2026-11-12/before/game/assets/vehicles/challenger_hellcat_v1/" if old else "res://assets/vehicles/challenger_hellcat_v1/"
	var metrics: Array = []
	for tier: String in ["simple","full"]:
		var glass: Mesh = load(base+tier+"_body_glass.res")
		var colliders: Array[StaticBody3D] = [collision(glass,4)]
		colliders.append(collision(load(base+tier+"_window_seal_glass.res"),16))
		for role: String in ["accent","dark","lens_red","reverse"]:
			var mesh: Mesh = load(base+tier+"_body_"+role+".res")
			var node: StaticBody3D = collision(mesh,8); node.set_meta("role",role);colliders.append(node)
		await physics_frame;await physics_frame
		var rear_jump: float = 0
		for y: float in [1.15,1.20,1.25]:
			var previous: Vector3 = Vector3.ZERO
			for i: int in range(23):
				var x: float = -0.55+i*0.05
				var hit: Dictionary = cast(Vector3(x,y,2),Vector3(x,y,0.8),4)
				check(not hit.is_empty(),tier+" rear pane covers inspected station")
				if hit.is_empty():continue
				var normal: Vector3 = shade(glass,hit)
				var backing: Dictionary = cast(Vector3(x,y,2),Vector3(x,y,0.8),16)
				check(backing.is_empty() or backing.position.z<hit.position.z-0.0005,tier+" glazing backing stays behind the rear pane")
				var under: Dictionary = cast(hit.position-Vector3(0,0,0.0001),hit.position-Vector3(0,0,0.035),4)
				check(under.is_empty(),tier+" rear glass has one exterior skin without an intersecting inner shell")
				check(normal.z>0.30 and normal.y>0.20,tier+" rear glass keeps its own outward tangent")
				if previous != Vector3.ZERO:
					var jump: float = rad_to_deg(normal.angle_to(previous));rear_jump = maxf(rear_jump,jump)
					check(jump<4.0,tier+" rear glass reflection is continuous x="+str(x)+" y="+str(y)+" jump="+str(jump))
				previous = normal
		for side: float in [-1.0,1.0]:
			for x: float in [-0.20,-0.10,0.0,0.10,0.20]:
				for y: float in [-0.018,0.018]:
					var hit: Dictionary = cast(Vector3(side*0.475+0.005+x,0.862+y,3),Vector3(side*0.475+0.005+x,0.862+y,2),8)
					check(not hit.is_empty() and hit.collider.get_meta("role","")=="lens_red",tier+" smoked tail lens is clear of old overlapping trim")
		for y: float in [0.785,0.920]:
			for i: int in range(15):
				var x: float = -0.70+i*0.10
				var hit: Dictionary = cast(Vector3(x,y,3),Vector3(x,y,2),8)
				check(not hit.is_empty() and hit.collider.get_meta("role","")=="dark",tier+" rear applique has no overlapping original accent trim")
		metrics.append({"tier":tier,"rear_window_max_adjacent_normal_degrees":rear_jump})
		for node: StaticBody3D in colliders:node.free()
		await physics_frame
	var file := FileAccess.open("res://../docs/evidence/challenger-panels-2026-11-12/shading-"+("before" if old else "after")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"));file.close()
	print("CHALLENGER_SHADING: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(metrics)])
	quit(1 if failures else 0)

extends SceneTree
## KDA01: sample the actual boot triangles against the actual authored pedals.
const OUT: String = "res://../docs/evidence/kart-driver-anatomy-2026-11-08"
var checks: int = 0
var failures: int = 0
var measurements: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("DRIVER_CONTACT_FAIL ",label)

func run() -> void:
	var path: String = "res://../build/kart-driver-anatomy-2026-11-08/candidate/driver.res"
	if "--shipping" in OS.get_cmdline_user_args(): path = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"
	if "--before" in OS.get_cmdline_user_args(): path = OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"
	var driver: ArrayMesh = load(path)
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var pedals: Array[MeshInstance3D] = []
		var rim: MeshInstance3D
		var seat_pan: MeshInstance3D
		for child: Node in car.body.find_children("*","MeshInstance3D",true,false):
			if str(child.name).begins_with("PedalPlate"): pedals.append(child)
			if str(child.name).begins_with("SteeringRim"): rim = child
			if str(child.name).begins_with("SeatPanPaddingV2"): seat_pan = child
		# Godot gives the repeated right-hand node an automatic unique name.
		if pedals.size() == 1:
			for child: Node in car.body.find_children("*","MeshInstance3D",true,false):
				if child != pedals[0] and child.mesh == pedals[0].mesh: pedals.append(child)
		check(pedals.size() == 2,"two real pedal plates in quality "+str(simple))
		var faces: PackedVector3Array = driver.get_faces()
		check(seat_pan != null,"actual padded seat pan present")
		if seat_pan != null:
			var transform: Transform3D = car.body.global_transform.affine_inverse()*seat_pan.global_transform
			var pan_height: float = INF
			for point: Vector3 in seat_pan.mesh.get_faces(): pan_height = minf(pan_height,(transform*point).y)
			var pelvis_height: float = INF
			for point: Vector3 in faces:
				if absf(point.x) < 0.18 and point.z > -0.18 and point.z < 0.20 and point.y < 0.37: pelvis_height = minf(pelvis_height,point.y)
			check(pelvis_height >= pan_height-0.008,"pelvis lower envelope stays above seat pan")
			check(pelvis_height <= pan_height+0.025,"pelvis lower envelope rests at seat pan")
			measurements.append({"simple":simple,"pelvis_height":pelvis_height,"seat_pan_height":pan_height})
		for pedal: MeshInstance3D in pedals:
			var transform: Transform3D = car.body.global_transform.affine_inverse()*pedal.global_transform
			var normal: Vector3 = transform.basis.z.normalized()
			var up: Vector3 = transform.basis.y.normalized()
			var center: Vector3 = transform.origin+normal*pedal.mesh.get_aabb().end.z
			var side: float = signf(center.x)
			var coverage: int = 0
			var max_gap: float = 0.0
			for x: float in [-0.03,0.0,0.03]:
				for y: float in [-0.035,0.0,0.035]:
					var sample: Vector3 = center+transform.basis.x.normalized()*x+up*y
					var closest: float = INF
					for triangle: int in range(0,faces.size(),3):
						var a: Vector3 = faces[triangle]
						if a.x*side < 0.06 or a.z > -0.76 or a.y > 0.46: continue
						var hit: Variant = Geometry3D.ray_intersects_triangle(sample+normal*0.10,-normal,a,faces[triangle+1],faces[triangle+2])
						if hit != null: closest = minf(closest,absf((hit-sample).dot(normal)))
					if closest <= 0.003: coverage += 1
					max_gap = maxf(max_gap,closest)
			check(coverage == 9,"sole covers all nine pedal contact samples, side "+str(side)+" tier "+str(simple))
			measurements.append({"simple":simple,"side":side,"contact_samples":coverage,"max_gap_mm":max_gap*1000 if is_finite(max_gap) else -1})
			var sole_normal_found: bool = false
			var min_clearance: float = INF
			for triangle: int in range(0,faces.size(),3):
				var a: Vector3 = faces[triangle]
				var b: Vector3 = faces[triangle+1]
				var c: Vector3 = faces[triangle+2]
				if a.x*side < 0.06 or a.z > -0.76 or a.y > 0.46: continue
				var n: Vector3 = (b-a).cross(c-a).normalized()
				if absf(n.dot(normal)) > 0.995 and absf((a-center).dot(normal)) < 0.003: sole_normal_found = true
				min_clearance = minf(min_clearance,(a-center).dot(normal))
			check(sole_normal_found,"actual sole triangles parallel to pedal")
			check(min_clearance >= -0.003,"boot does not penetrate pedal")
		check(rim != null,"real steering rim present")
		if rim != null:
			var transform: Transform3D = car.body.global_transform.affine_inverse()*rim.global_transform
			var rim_points: PackedVector3Array = rim.mesh.get_faces()
			for index: int in range(rim_points.size()): rim_points[index] = transform*rim_points[index]
			for side: float in [-1.0,1.0]:
				var touching: int = 0
				var nearest: float = INF
				for surface: int in range(driver.get_surface_count()):
					if driver.surface_get_material(surface).resource_name != "RT_Gloves": continue
					for point: Vector3 in driver.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						if point.x*side < 0.06: continue
						var distance: float = INF
						for rim_point: Vector3 in rim_points: distance = minf(distance,point.distance_to(rim_point))
						nearest = minf(nearest,distance)
						if distance < 0.012: touching += 1
				check(touching >= 3,"glove has multiple contact vertices on steering rim, side "+str(side))
				measurements.append({"simple":simple,"hand_side":side,"rim_gap_mm":nearest*1000,"contact_vertices":touching})
		car.free()
	check(driver.get_aabb().position.y >= 0.157,"boot heels stay at floor level")
	var report: Dictionary = {"checks":checks,"failures":failures,"mesh":path,"measurements":measurements}
	FileAccess.open(OUT+"/contact-"+("before" if "--before" in OS.get_cmdline_user_args() else "final")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DRIVER_CONTACT ",JSON.stringify(report))
	quit(1 if failures else 0)

extends SceneTree
## KCP01/KCP03: actual back-pad support and centre-fairing clearance.
const OUT: String = "res://../docs/evidence/kart-driver-cockpit-fit-2026-11-08"
var checks: int = 0
var failures: int = 0
var measurements: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("COCKPIT_FAIL ",label)

func crossing(faces: PackedVector3Array, tree: TriangleMesh, transform: Transform3D, bounds: AABB) -> Vector3:
	var inverse: Transform3D = transform.affine_inverse()
	for triangle: int in range(0,faces.size(),3):
		var a: Vector3 = faces[triangle]
		var b: Vector3 = faces[triangle+1]
		var c: Vector3 = faces[triangle+2]
		var box: AABB = AABB(a,Vector3.ZERO).expand(b).expand(c).grow(0.00001)
		if not bounds.intersects(box): continue
		for edge: Array in [[a,b],[b,c],[c,a]]:
			var origin: Vector3 = inverse*edge[0]
			var delta: Vector3 = inverse*edge[1]-origin
			if delta.length_squared() < 1e-14: continue
			var hit: Dictionary = tree.intersect_ray(origin,delta.normalized())
			if not hit.is_empty() and origin.distance_to(hit.position) <= delta.length()+0.000001:
				return transform*hit.position
	return Vector3(INF,INF,INF)

func run() -> void:
	var path: String = "res://../build/kart-driver-cockpit-fit-2026-11-08/candidate/driver.res"
	if "--shipping" in OS.get_cmdline_user_args(): path = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"
	if "--before" in OS.get_cmdline_user_args(): path = OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"
	var mesh: Mesh = load(path)
	var driver_tree: TriangleMesh = mesh.generate_triangle_mesh()
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var variants: Array[Dictionary] = []
	for category: String in ["hood","body"]:
		for option: Array in VehicleCustomisation.options(category,"kart"):
			if category == "body" and option[0] == "stock": continue
			variants.append({"category":category,"option":option[0]})
	for simple: bool in [false,true]:
		for variant: Dictionary in variants:
			var option: Array = [variant.option]
			var car := CarVisual.new()
			car.vehicle_id = "kart"
			car.simple_model = simple
			car.batch_parts = false
			car.customisation = VehicleCustomisation.defaults()
			car.customisation[variant.category] = option[0]
			root.add_child(car)
			while not car.model_ready: await process_frame
			var back: MeshInstance3D
			var beam: MeshInstance3D
			var bucket: MeshInstance3D
			var pods: Array[MeshInstance3D] = []
			for child: Node in car.body.find_children("*","MeshInstance3D",true,false):
				if str(child.name).begins_with("MouldedSeatBucketOpenV2"): bucket = child
				if str(child.name).begins_with("FormedSidePod"): pods.append(child)
				if str(child.name).begins_with("SeatBackPaddingV2"): back = child
				if str(child.name).begins_with("NassauFairing"): beam = child
			check(back != null and beam != null,"actual back pad and centre fairing present")
			if bucket != null and variant.category == "hood" and option[0] == "stock":
				var helmet := AABB()
				var first: bool = true
				for surface: int in range(mesh.get_surface_count()):
					if mesh.surface_get_material(surface).resource_name != "RT_Helemt": continue
					for point: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						if first: helmet = AABB(point,Vector3.ZERO); first = false
						else: helmet = helmet.expand(point)
				var seat_box: AABB = (car.body.global_transform.affine_inverse()*bucket.global_transform)*bucket.mesh.get_aabb()
				check(helmet.end.z <= seat_box.end.z+helmet.size.z*0.5+0.010,"helmet rear fits actual seat-back envelope")
			if back != null and variant.category == "hood" and option[0] == "stock":
				var tree: TriangleMesh = back.mesh.generate_triangle_mesh()
				var transform: Transform3D = car.body.global_transform.affine_inverse()*back.global_transform
				for x: float in [-0.075,0.075]:
					for y: float in [0.45,0.52,0.59]:
						var suit: Dictionary = driver_tree.intersect_ray(Vector3(x,y,2),Vector3.FORWARD)
						var pad: Dictionary = tree.intersect_ray(transform.affine_inverse()*Vector3(x,y,-1),transform.basis.inverse()*Vector3.BACK)
						var gap: float = INF
						if not suit.is_empty() and not pad.is_empty(): gap = (transform*pad.position).z-suit.position.z
						check(gap >= -0.003 and gap <= 0.012,"lumbar/scapula support within padding tolerance")
						measurements.append({"simple":simple,"back_x":x,"back_y":y,"back_gap_mm":gap*1000 if is_finite(gap) else -999})
			if beam != null:
				var tree: TriangleMesh = beam.mesh.generate_triangle_mesh()
				var transform: Transform3D = car.body.global_transform.affine_inverse()*beam.global_transform
				var inverse: Transform3D = transform.affine_inverse()
				var faces: PackedVector3Array = mesh.get_faces()
				var forward_hit: Vector3 = crossing(faces,tree,transform,transform*beam.mesh.get_aabb())
				var beam_faces: PackedVector3Array = beam.mesh.get_faces()
				for index: int in range(beam_faces.size()): beam_faces[index] = transform*beam_faces[index]
				var reverse_hit: Vector3 = crossing(beam_faces,driver_tree,Transform3D.IDENTITY,mesh.get_aabb())
				check(not forward_hit.is_finite() and not reverse_hit.is_finite(),"no driver/fairing triangle-edge crossings "+str(option[0]))
				measurements.append({"simple":simple,"category":variant.category,"variant":option[0],"driver_edge_crossing":str(forward_hit),"fairing_edge_crossing":str(reverse_hit)})
				var clearance: float = INF
				var samples: int = 0
				var worst := Vector3.ZERO
				for triangle: int in range(0,faces.size(),3):
					var a: Vector3 = faces[triangle]
					var b: Vector3 = faces[triangle+1]
					var c: Vector3 = faces[triangle+2]
					for p: Vector3 in [a,(a+b)*0.5,(b+c)*0.5,(c+a)*0.5,(a+b+c)/3.0]:
						if p.z < -0.90 or p.z > -0.34 or p.y < 0.27 or p.y > 0.61 or absf(p.x) < 0.055: continue
						var side: float = signf(p.x)
						var origin: Vector3 = Vector3(side*1.0,p.y,p.z)
						var hit: Dictionary = tree.intersect_ray(inverse*origin,transform.basis.inverse()*Vector3(-side,0,0))
						if hit.is_empty(): continue
						samples += 1
						var distance: float = (p.x-(transform*hit.position).x)*side
						if distance < clearance: worst = p
						clearance = minf(clearance,distance)
				check(clearance >= 0.006,"driver limbs clear actual centre-fairing surface "+str(option[0]))
				measurements.append({"simple":simple,"category":variant.category,"variant":option[0],"lateral_samples":samples,"worst_point":str(worst),"minimum_clearance_mm":clearance*1000 if is_finite(clearance) else -999})
			check(pods.size() == 2,"two actual side pods present")
			for pod: MeshInstance3D in pods:
				var transform: Transform3D = car.body.global_transform.affine_inverse()*pod.global_transform
				var tree: TriangleMesh = pod.mesh.generate_triangle_mesh()
				var hit: Vector3 = crossing(mesh.get_faces(),tree,transform,transform*pod.mesh.get_aabb())
				var pod_faces: PackedVector3Array = pod.mesh.get_faces()
				for index: int in range(pod_faces.size()): pod_faces[index] = transform*pod_faces[index]
				var reverse: Vector3 = crossing(pod_faces,driver_tree,Transform3D.IDENTITY,mesh.get_aabb())
				check(not hit.is_finite() and not reverse.is_finite(),"driver clears side-pod shell "+str(option[0]))
				var side: float = signf(transform.origin.x)
				var outside: bool = false
				for point: Vector3 in mesh.get_faces(): outside = outside or point.x*side >= absf(transform.origin.x)
				check(not outside,"driver remains inboard of actual pod centre")
			car.free()
	print("COCKPIT_FIT ",checks," checks, ",failures," failures")
	FileAccess.open(OUT+"/cockpit-"+("before" if "--before" in OS.get_cmdline_user_args() else "candidate")+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	quit(1 if failures else 0)

extends SceneTree
## Top-view profile, actual prepared seams, and front-wheel arch clearance.
const BODY = preload("res://vehicle/electric_reference_body.gd")
const MESH = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func edge(mesh: ArrayMesh, axis: int, value: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
	for i: int in range(vertices.size()):
		if absf(uvs[i][axis] - value) < 0.00001:
			result.append({"u": uvs[i][1-axis], "point": vertices[i]})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.u < b.u)
	return result

func seam_gap(a: Array[Dictionary], b: Array[Dictionary]) -> float:
	var gap := 0.0
	for point: Dictionary in a:
		var nearest := INF
		for i: int in range(b.size()-1):
			var p: Vector3 = Geometry3D.get_closest_point_to_segment(point.point, b[i].point, b[i+1].point)
			nearest = minf(nearest, p.distance_to(point.point))
		gap = maxf(gap, nearest)
	return gap

func get_mesh(car: CarVisual, name_value: String) -> ArrayMesh:
	var node: MeshInstance3D = car.body.get_node_or_null(name_value.replace(".","_"))
	if node == null or not node.mesh is ArrayMesh:
		return null
	return node.mesh

func run() -> void:
	var cowl: float = BODY.side_width(-0.90, BODY.shoulder(-0.90))
	var previous: float = cowl
	var monotone := true
	for i: int in range(1, 101):
		var z: float = lerpf(-0.90, BODY.FRONT, float(i)/100.0)
		var width: float = BODY.side_width(z, BODY.shoulder(z))
		if width > previous + 0.00001:
			monotone = false
		previous = width
	check(monotone, "hood shoulders taper continuously from the cowl to the nose")
	check(cowl-previous > 0.10, "nose shoulders are visibly narrower than the cowl")
	check(BODY.nose_edge(0.0) < BODY.nose_edge(1.0)-0.48, "leading edge has a deep, rounded plan-view arc")
	for u: float in [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]:
		check(BODY.hood_point(u,0.0).distance_to(BODY.cap_point(false,u,1.0)) < 0.00001, "procedural hood/front join " + str(u))
		var left: Vector3 = BODY.hood_point(u,0.4)
		var right: Vector3 = BODY.hood_point(1.0-u,0.4)
		check(absf(left.x+right.x) < 0.00001 and absf(left.z-right.z) < 0.00001, "hood remains symmetric " + str(u))
	for simple: bool in [false,true]:
		MESH.use_baked = true
		MESH.meshes.clear()
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var tag: String = "simple" if simple else "full"
		var hood: ArrayMesh = get_mesh(car,"ReferenceHood")
		var front: ArrayMesh = get_mesh(car,"ReferenceFrontUpper")
		check(hood != null and front != null, tag + " hood and front exist")
		if hood == null or front == null:
			car.free()
			continue
		var key: String = "ReferenceHood" + ("_simple" if simple else "")
		var path: String = MESH.ASSET_ROOT.path_join(key.sha256_text().left(24)+".res")
		check(ResourceLoader.exists(path) and hood == load(path), tag + " uses the prepared hood")
		var hood_center: Array[Dictionary] = edge(hood,1,0.0)
		var max_error := 0.0
		for entry: Dictionary in hood_center:
			max_error = maxf(max_error,(entry.point as Vector3).distance_to(BODY.hood_point(entry.u,0.0)))
		check(max_error < 0.00001, tag + " prepared hood reflects current nose geometry")
		var front_gap: float = seam_gap(hood_center,edge(front,1,1.0))
		check(front_gap < 0.004, tag + " hood/front seam gap " + str(front_gap))
		for side: float in [-1.0,1.0]:
			var flank: ArrayMesh = get_mesh(car,"ReferenceSide"+str(side))
			var arch: ArrayMesh = get_mesh(car,"ReferenceArch"+str(side)+str(-BODY.AXLE))
			check(flank != null and arch != null,tag + " side and front arch exist " + str(side))
			if flank == null or arch == null: continue
			var flank_gap: float = seam_gap(edge(hood,0,0.0 if side < 0 else 1.0),edge(flank,1,1.0))
			check(flank_gap < 0.004,tag + " hood/side seam gap " + str(flank_gap))
			var wheel_name: String = "FrontLeftWheel" if side < 0 else "FrontRightWheel"
			var wheel: Node3D = car.get_node_or_null(wheel_name)
			check(wheel != null,tag + " front wheel exists " + str(side))
			if wheel == null: continue
			var spin: Node3D = wheel.get_node_or_null("WheelSpin")
			check(spin != null,tag + " rolling wheel exists " + str(side))
			if spin == null: continue
			var tire_top := -INF
			for tire: MeshInstance3D in spin.find_children("*","MeshInstance3D",true,false):
				if tire.mesh == null: continue
				var box: AABB = tire.mesh.get_aabb()
				for corner: int in range(8):
					var p: Vector3 = car.to_local(tire.to_global(box.get_endpoint(corner)))
					tire_top = maxf(tire_top,p.y)
			check(is_finite(tire_top),tag + " wheel geometry exists " + str(side))
			if not is_finite(tire_top): continue
			var arch_points: Array[Dictionary] = edge(arch,1,0.0)
			var arch_y := -INF
			for entry: Dictionary in arch_points:
				arch_y = maxf(arch_y,(entry.point as Vector3).y)
			var clearance: float = arch_y-tire_top
			check(clearance > 0.02 and clearance < 0.12,tag + " wheel arch clears the tyre top " + str(clearance))
		car.free()
	print("VOLT_PLAN_TAPER: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

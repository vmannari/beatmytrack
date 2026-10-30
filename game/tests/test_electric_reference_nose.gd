extends SceneTree
## Inspect the actual hood, openings and lamp meshes in both detail levels.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func triangle_samples(node: MeshInstance3D) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for surface: int in range(node.mesh.get_surface_count()):
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for n: int in range(0,indices.size(),3):
			var a: int = indices[n]
			var b: int = indices[n+1]
			var c: int = indices[n+2]
			samples.append({"a":node.transform*vertices[a],"b":node.transform*vertices[b],"c":node.transform*vertices[c],"uv":(uv[a]+uv[b]+uv[c])/3.0})
	return samples

func nearest_sample(tris: Array[Dictionary],uv: Vector2) -> Vector3:
	var best := INF
	var point := Vector3.ZERO
	for tri: Dictionary in tris:
		var distance: float = (tri.uv as Vector2).distance_squared_to(uv)
		if distance < best:
			best = distance
			point = (tri.a+tri.b+tri.c)/3.0
	return point

func clear_front(point: Vector3, blockers: Array[Dictionary]) -> bool:
	var start := point + Vector3.FORWARD*3.0
	for tri: Dictionary in blockers:
		var hit: Variant = Geometry3D.segment_intersects_triangle(start,point,tri.a,tri.b,tri.c)
		if hit != null and (hit as Vector3).distance_to(point) > 0.001:
			return false
	return true

func boundary(node: MeshInstance3D,v: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i: int in range(vertices.size()):
		if absf(uvs[i].y-v) < 0.00001:
			result.append({"u":uvs[i].x,"point":node.transform*vertices[i]})
	result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.u < b.u)
	return result

func boundary_gap(a: Array[Dictionary],b: Array[Dictionary]) -> float:
	var maximum := 0.0
	for entry: Dictionary in a:
		var nearest := INF
		for i: int in range(b.size()-1):
			var p: Vector3 = Geometry3D.get_closest_point_to_segment(entry.point,b[i].point,b[i+1].point)
			nearest = minf(nearest,p.distance_to(entry.point))
		maximum = maxf(maximum,nearest)
	return maximum

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	M.use_baked = prepared
	M.meshes.clear()
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var detail: String = "simple="+str(simple)
		var hood: MeshInstance3D = car.body.get_node_or_null("ReferenceHood")
		var upper: MeshInstance3D = car.body.get_node_or_null("ReferenceFrontUpper")
		var lamp: MeshInstance3D = car.body.get_node_or_null("ReferenceFrontLightbar")
		var housing: MeshInstance3D = car.body.get_node_or_null("ReferenceFrontLampHousing")
		check(hood != null and upper != null and lamp != null and housing != null,"hood, upper fascia and optics exist "+detail)
		if hood == null or upper == null or lamp == null or housing == null:
			car.free()
			continue
		var gap: float = boundary_gap(boundary(hood,0.0),boundary(upper,1.0))
		check(gap < 0.004,"actual hood meets upper fascia; maximum gap "+str(gap)+" "+detail)
		var body_blockers: Array[Dictionary] = []
		for node: MeshInstance3D in car.body.find_children("ReferenceFront*","MeshInstance3D",false,false):
			if node.material_override == car.paint_materials.body:
				body_blockers.append_array(triangle_samples(node))
		check(not body_blockers.is_empty(),"actual front paint meshes found "+detail)
		var optical_blockers: Array[Dictionary] = body_blockers.duplicate()
		optical_blockers.append_array(triangle_samples(housing))
		var light: Array[Dictionary] = triangle_samples(lamp)
		for u: float in [0.10,0.25,0.5,0.75,0.90]:
			check(clear_front(nearest_sample(light,Vector2(u,0.5)),optical_blockers),"lightbar is visible at "+str(u)+" "+detail)
		for name_value: String in ["ReferenceLowerIntakeBack","ReferenceAirCurtain-1_0Back","ReferenceAirCurtain1_0Back"]:
			var back: MeshInstance3D = car.body.get_node_or_null(name_value)
			check(back != null,"recess back exists "+name_value+" "+detail)
			if back != null:
				var tris: Array[Dictionary] = triangle_samples(back)
				for sample: Vector2 in [Vector2(0.25,0.5),Vector2(0.5,0.5),Vector2(0.75,0.5)]:
					check(clear_front(nearest_sample(tris,sample),body_blockers),"actual opening is not covered by paint "+name_value+" "+str(sample)+" "+detail)
		for name_value: String in ["ReferenceLowerIntakeReturn","ReferenceAirCurtain-1_0Return","ReferenceAirCurtain1_0Return"]:
			for edge: int in range(4):
				check(car.body.get_node_or_null(name_value+str(edge)) != null,"opening has a return "+name_value+str(edge)+" "+detail)
		car.free()
	print("ELECTRIC_REFERENCE_NOSE: ",checks," checks, ",failures," failures; prepared=",prepared)
	quit(1 if failures else 0)

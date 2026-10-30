extends SceneTree
## Check real full/racing triangle arrays and the independently moving fan frames.
const OUTPUT: String = "res://../docs/evidence/hovercraft-sport-redesign-2026-10-29"
const SOURCES: Array[String] = ["res://vehicle/hovercraft_model.gd","res://vehicle/hovercraft_sport_hull.gd","res://vehicle/hovercraft_sport_drive.gd","res://vehicle/hovercraft_sport_surface.gd"]
const SPAN: Array[float] = [-0.20,-0.12,-0.06,0.0,0.06,0.12,0.20]
var checks: int = 0
var failures: int = 0

class Triangle:
	var a: Vector3
	var b: Vector3
	var c: Vector3
	var determinant: float
	var min_x: float
	var max_x: float
	var min_z: float
	var max_z: float
	func _init(p: Vector3,q: Vector3,r: Vector3) -> void:
		a = p; b = q; c = r
		determinant = (b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		min_x = minf(a.x,minf(b.x,c.x)); max_x = maxf(a.x,maxf(b.x,c.x))
		min_z = minf(a.z,minf(b.z,c.z)); max_z = maxf(a.z,maxf(b.z,c.z))
	func height(x: float,z: float) -> float:
		if absf(determinant) < 0.000000000001 or x < min_x-0.000001 or x > max_x+0.000001 or z < min_z-0.000001 or z > max_z+0.000001: return INF
		var wa: float = ((b.z-c.z)*(x-c.x)+(c.x-b.x)*(z-c.z))/determinant
		var wb: float = ((c.z-a.z)*(x-c.x)+(a.x-c.x)*(z-c.z))/determinant
		var wc: float = 1.0-wa-wb
		if minf(wa,minf(wb,wc)) < -0.00001: return INF
		return wa*a.y+wb*b.y+wc*c.y

func _initialize() -> void: run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func triangles(node: MeshInstance3D,body: Node3D) -> Array[Triangle]:
	var result: Array[Triangle] = []
	var pose: Transform3D = body.global_transform.affine_inverse()*node.global_transform
	for surface: int in range(node.mesh.get_surface_count()):
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		for index: int in range(0,count,3):
			var i: int = indices[index] if not indices.is_empty() else index
			var j: int = indices[index+1] if not indices.is_empty() else index+1
			var k: int = indices[index+2] if not indices.is_empty() else index+2
			var triangle := Triangle.new(pose*vertices[i],pose*vertices[j],pose*vertices[k])
			if absf(triangle.determinant) > 0.000000000001: result.append(triangle)
	return result

func sample(mesh: Array[Triangle],x: float,z: float,highest: bool) -> float:
	var value: float = -INF if highest else INF
	var hit: bool = false
	for triangle: Triangle in mesh:
		var y: float = triangle.height(x,z)
		if y == INF: continue
		value = maxf(value,y) if highest else minf(value,y)
		hit = true
	return value if hit else INF

func frame_vertices(node: MeshInstance3D,body: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	var pose: Transform3D = body.global_transform.affine_inverse()*node.global_transform
	for surface: int in range(node.mesh.get_surface_count()):
		var arrays: Array = node.mesh.surface_get_arrays(surface)
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: result.append(pose*point)
	return result

func source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCES: result[path] = FileAccess.get_sha256(path)
	return result

func wall_fit(body: Node3D,deck: Array[Triangle],side: int,edge: int,label: String) -> Dictionary:
	var wall: MeshInstance3D = body.get_node_or_null("SportNacelleSide%d_%d"%[side,edge])
	var fairing: MeshInstance3D = body.get_node_or_null("SportNacelleFairing%d"%side)
	check(wall != null and wall.mesh != null and wall.mesh.get_surface_count() > 0,label+" side wall exists")
	if wall == null or wall.mesh == null or fairing == null: return {"exists":false}
	var wall_arrays: Array = wall.mesh.surface_get_arrays(0)
	var fairing_arrays: Array = fairing.mesh.surface_get_arrays(0)
	var wall_uv: PackedVector2Array = wall_arrays[Mesh.ARRAY_TEX_UV]
	var fairing_uv: PackedVector2Array = fairing_arrays[Mesh.ARRAY_TEX_UV]
	var wall_points: PackedVector3Array = frame_vertices(wall,body)
	var fairing_points: PackedVector3Array = frame_vertices(fairing,body)
	var edge_points := PackedVector3Array()
	for index: int in range(fairing_uv.size()):
		if absf(fairing_uv[index].x-(0.0 if edge < 0 else 1.0)) < 0.00001: edge_points.append(fairing_points[index])
	var top_samples: int = 0
	var bottom_samples: int = 0
	var maximum_top_gap: float = 0.0
	var maximum_bottom_gap: float = -INF
	for index: int in range(wall_uv.size()):
		var p: Vector3 = wall_points[index]
		if wall_uv[index].y > 0.99999:
			var distance: float = INF
			for segment: int in range(edge_points.size()-1):
				var a: Vector3 = edge_points[segment]
				var b: Vector3 = edge_points[segment+1]
				var delta: Vector3 = b-a
				var t: float = clampf((p-a).dot(delta)/maxf(delta.length_squared(),0.000000001),0.0,1.0)
				distance = minf(distance,p.distance_to(a+delta*t))
			maximum_top_gap = maxf(maximum_top_gap,distance)
			top_samples += 1
		elif wall_uv[index].y < 0.00001:
			var deck_height: float = sample(deck,p.x,p.z,true)
			if deck_height != INF:
				maximum_bottom_gap = maxf(maximum_bottom_gap,p.y-deck_height)
				bottom_samples += 1
	check(top_samples >= 8 and maximum_top_gap <= 0.003,label+" wall meets the actual fairing edge")
	check(bottom_samples >= 4 and maximum_bottom_gap <= 0.002,label+" wall foot meets or enters the actual deck")
	return {"exists":true,"top_samples":top_samples,"max_top_gap_m":maximum_top_gap,"bottom_samples":bottom_samples,"max_wall_above_deck_m":maximum_bottom_gap}

func support_fit(body: Node3D,side: int,y: int,label: String) -> Dictionary:
	var support: MeshInstance3D = body.get_node_or_null("SportRudderSupport%d_%d"%[side,y])
	var rudder: Node3D = body.get_node_or_null("RudderLeft" if side < 0 else "RudderRight")
	var hinge: MeshInstance3D = rudder.get_node_or_null("SportVaneHinge%d_%d"%[side,y]) if rudder != null else null
	check(support != null and support.mesh != null and support.mesh.get_surface_count() > 0,label+" rudder support exists")
	if support == null or support.mesh == null or hinge == null or hinge.mesh == null: return {"exists":false}
	var inverse: Transform3D = body.global_transform.affine_inverse()
	var support_box: AABB = inverse*support.global_transform*support.mesh.get_aabb()
	var hinge_box: AABB = inverse*hinge.global_transform*hinge.mesh.get_aabb()
	var meets_hinge: bool = support_box.grow(0.002).intersects(hinge_box)
	check(meets_hinge,label+" support reaches its steering hinge")
	return {"exists":true,"meets_hinge":meets_hinge,"support_z_min":support_box.position.z,"support_z_max":support_box.end.z}

func inspect_lod(simple: bool) -> Dictionary:
	var label: String = "simple" if simple else "detailed"
	var car := CarVisual.new()
	car.vehicle_id = "hovercraft"
	car.simple_model = simple
	car.batch_parts = false
	car.cache_rest_pose = false
	root.add_child(car)
	while not car.model_ready: await process_frame
	car.force_update_transform()
	for node: Node3D in car.find_children("*","Node3D",true,false): node.force_update_transform()
	var body: Node3D = car.body
	var deck_node: MeshInstance3D = body.get_node_or_null("SportCrownedDeck")
	check(deck_node != null and deck_node.mesh != null,label+" actual deck mesh exists")
	if deck_node == null or deck_node.mesh == null:
		car.free()
		return {"deck_exists":false}
	var deck: Array[Triangle] = triangles(deck_node,body)
	var sides: Array = []
	for side: int in [-1,1]:
		var name: String = label+" "+("left" if side < 0 else "right")
		var rotor: Node3D = body.get_node_or_null("FanRotor/FanRotorLeft" if side < 0 else "FanRotor/FanRotorRight")
		var duct: MeshInstance3D = body.get_node_or_null("SportDuct%d"%side)
		var liner: MeshInstance3D = body.get_node_or_null("SportDuctLiner%d"%side)
		check(rotor != null and duct != null and liner != null,name+" rotor, duct and liner exist")
		if rotor == null or duct == null or liner == null: continue
		var center: Vector3 = body.global_transform.affine_inverse()*rotor.global_position
		var blade_radius: float = 0.0
		var blade_count: int = 0
		for blade: MeshInstance3D in rotor.find_children("SportBlade*","MeshInstance3D",true,false):
			blade_count += 1
			for point: Vector3 in frame_vertices(blade,body): blade_radius = maxf(blade_radius,Vector2(point.x-center.x,point.y-center.y).length())
		var liner_radius: float = INF
		for point: Vector3 in frame_vertices(liner,body): liner_radius = minf(liner_radius,Vector2(point.x-center.x,point.y-center.y).length())
		check(blade_count >= 10 and blade_radius > 0.0 and liner_radius-blade_radius > 0.001,name+" real blades clear their inner duct")
		var minimum_clearance: float = INF
		var sample_count: int = 0
		var outside_count: int = 0
		var worst: Vector3 = Vector3.ZERO
		for offset_z: float in SPAN:
			for index: int in range(-16,17):
				var dx: float = blade_radius*float(index)/16.0
				var y: float = center.y-sqrt(maxf(0.0,blade_radius*blade_radius-dx*dx))
				var x: float = center.x+dx
				var z: float = center.z+offset_z
				var deck_height: float = sample(deck,x,z,true)
				if deck_height == INF:
					outside_count += 1
					continue
				var clearance: float = y-deck_height
				if clearance < minimum_clearance:
					minimum_clearance = clearance
					worst = Vector3(x,y,z)
				sample_count += 1
		check(sample_count >= 100,name+" deck triangles cover meaningful envelope samples")
		check(sample_count > 0 and minimum_clearance > 0.001,name+" rotating blade envelope clears actual deck at seven axial sections")
		var duct_triangles: Array[Triangle] = triangles(duct,body)
		var seat: Array = []
		for offset_z: float in [-0.08,0.0,0.08]:
			var z: float = center.z+offset_z
			var deck_height: float = sample(deck,center.x,z,true)
			var duct_bottom: float = sample(duct_triangles,center.x,z,false)
			var depth: float = deck_height-duct_bottom
			check(deck_height != INF and duct_bottom != INF and depth >= -0.002 and depth <= 0.050,name+" duct bottom seats into deck at z="+str(z))
			seat.append({"z":z,"deck_y":deck_height,"duct_bottom_y":duct_bottom,"depth_m":depth})
		var walls: Array = []
		for edge: int in [-1,1]: walls.append(wall_fit(body,deck,side,edge,name+" edge "+str(edge)))
		var supports: Array = []
		for y: int in [-18,18]: supports.append(support_fit(body,side,y,name+" hinge "+str(y)))
		sides.append({"side":side,"center":str(center),"blade_meshes":blade_count,"blade_radius_m":blade_radius,"liner_radius_m":liner_radius,"radial_clearance_m":liner_radius-blade_radius,"envelope_samples":sample_count,"outside_deck_samples":outside_count,"min_deck_clearance_m":minimum_clearance,"worst_envelope_point":str(worst),"duct_seating":seat,"walls":walls,"rudder_supports":supports})
	car.free()
	await process_frame
	return {"lod":label,"deck_triangles":deck.size(),"sides":sides}

func run() -> void:
	var initial_sources: Dictionary = source_hashes()
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/hovercraft_sport_surface.gd").use_baked = false
	var results: Array = []
	for simple: bool in [false,true]: results.append(await inspect_lod(simple))
	check(source_hashes() == initial_sources,"reviewed source files stay exact during the audit")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = OUTPUT.path_join("fit-audit-"+RenderingServer.get_current_rendering_method()+".json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sources":initial_sources,"results":results},"\t"))
	file.close()
	print("HOVERCRAFT_SPORT_FIT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

extends "res://tests/register_volt_front_door.gd"
const B = preload("res://vehicle/electric_reference_body.gd")
const C = preload("res://vehicle/electric_reference_cabin.gd")
const Source = preload("res://tests/support/volt_hood_outline_source.gd")
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks: int = 0
var failures: int = 0
var observations: int = 0
var counts: Array = []

func nearest_distance(point: Vector3, faces: PackedVector3Array) -> float:
	var nearest: float = INF
	for at: int in range(0, faces.size(), 3):
		var a: Vector3 = faces[at]
		var ab: Vector3 = faces[at + 1] - a
		var ac: Vector3 = faces[at + 2] - a
		var normal: Vector3 = ab.cross(ac).normalized()
		var projected: Vector3 = point - normal * normal.dot(point - a)
		var offset: Vector3 = projected - a
		var determinant: float = ab.length_squared() * ac.length_squared() - pow(ab.dot(ac), 2)
		if determinant > 0.000000000000001:
			var v: float = (ac.length_squared() * offset.dot(ab) - ab.dot(ac) * offset.dot(ac)) / determinant
			var w: float = (ab.length_squared() * offset.dot(ac) - ab.dot(ac) * offset.dot(ab)) / determinant
			if minf(1.0 - v - w, minf(v, w)) >= 0.0: nearest = minf(nearest, point.distance_to(projected))
		for edge: int in range(3):
			var start: Vector3 = faces[at + edge]
			var delta: Vector3 = faces[at + (edge + 1) % 3] - start
			var fraction: float = clampf((point - start).dot(delta) / maxf(delta.length_squared(), 0.000000000001), 0, 1)
			nearest = minf(nearest, point.distance_to(start + delta * fraction))
	return nearest

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("VFD_FAIL ", label)

func detail(group: Dictionary) -> void:
	check(raw.has(key(group)), "All unrelated raw frame members exact")
	if raw.has(key(group)):
		check(D.recipe("electric", group.code).get("parts", {}) == raw[key(group)].recipe.get("parts", {}), "All detail reduction rows retained")
	D.apply_group(group)

func surface(group: Dictionary) -> void:
	check(post.has(key(group)), "All unrelated post-detail frame members exact")
	var path: String = S.ROOT.path_join("electric_" + group.code + ".json")
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"parts": {}}
	if post.has(key(group)):
		for entry: Dictionary in group.entries:
			for changed: Dictionary in post[key(group)].changed_rows:
				if changed.name != str(entry.part.name): continue
				var row: Dictionary = current.parts.get(entry.code, {})
				check(not row.is_empty(), "Reduced glass recipe retained")
				if row.is_empty(): continue
				var old: Mesh = load(S.ROOT.path_join(changed.row.mesh))
				var updated: Mesh = load(S.ROOT.path_join(row.mesh))
				var before: Array = old.surface_get_arrays(0)
				var after: Array = updated.surface_get_arrays(0)
				check(before[Mesh.ARRAY_INDEX] == after[Mesh.ARRAY_INDEX], "Glass index topology retained")
				check(before[Mesh.ARRAY_TEX_UV] == after[Mesh.ARRAY_TEX_UV], "Glass UV chart retained")
	for entry: Dictionary in group.entries:
		if selected(str(entry.part.name)): current.parts.erase(entry.code)
	if post.has(key(group)):
		check(current.parts == post[key(group)].recipe.parts, "All unaffected surface reduction rows retained")
	S.apply_group(group, D)

func observe(car: CarVisual, holders: Variant) -> void:
	if holders != null: return
	observations += 1
	var target: float = B.cabin_z(B.WINDOW_B_FOOT)
	for side: float in [-1.0, 1.0]:
		var suffix: String = str(side).replace(".", "_")
		var skin: MeshInstance3D = car.body.get_node(NodePath("ReferenceSide" + suffix))
		var tree: TriangleMesh = skin.mesh.generate_triangle_mesh()
		var strip_count: int = 0
		for part: MeshInstance3D in car.body.find_children("*", "MeshInstance3D", false, false):
			var label: String = str(part.name)
			if label.begins_with("ReferenceFrontSideGlass" + suffix) or label.begins_with("ReferenceRearSideGlass" + suffix):
				var native: Mesh = M.meshes[label.replace("_", ".") + ("_simple" if car.simple_model else "")]
				var pane: TriangleMesh = native.generate_triangle_mesh()
				var native_faces: PackedVector3Array = native.get_faces()
				var faces: PackedVector3Array = part.mesh.get_faces()
				for at: int in range(0, faces.size(), 3):
					for point: Vector3 in [faces[at], faces[at + 1], faces[at + 2], (faces[at] + faces[at + 1] + faces[at + 2]) / 3.0]:
						var hit: Dictionary = pane.intersect_ray(point + Vector3(side * 0.20, 0, 0), Vector3(-side, 0, 0))
						var distance: float = point.distance_to(hit.position) if not hit.is_empty() else nearest_distance(point, native_faces)
						check(distance < 0.0018, "Glass remapping retains 1.8mm surface tolerance")
			if not (label.begins_with("ReferenceDoorSeam" + suffix) or label.begins_with("RefHandleOutline" + suffix) or label.begins_with("RefHandlePull" + suffix)): continue
			strip_count += 1
			if car.simple_model:
				check(part.mesh.get_meta("car_keep_master", false), "Racing contours retain distance geometry")
				check(part.mesh.get_meta("volt_contour_backing", "") == D.mesh_key(skin.mesh), "Exact racing backing identity")
			var points: PackedVector3Array = part.mesh.get_faces()
			for at: int in range(0, points.size(), 3):
				for point: Vector3 in [points[at], points[at + 1], points[at + 2], (points[at] + points[at + 1] + points[at + 2]) / 3.0]:
					var hit: Dictionary = tree.intersect_ray(point + Vector3(side * 0.20, 0, 0), Vector3(-side, 0, 0))
					check(not hit.is_empty(), "Door and handle contour backing")
					if not hit.is_empty():
						var gap: float = side * (point.x - hit.position.x)
						check(gap >= 0.00030 and gap <= 0.0020, "Flush exposed contour " + label)
		check(strip_count == 7, "Three seams and two complete handles per side")
		var seam: MeshInstance3D = car.body.get_node(NodePath("ReferenceDoorSeam" + suffix + "1"))
		var a: Array = seam.mesh.surface_get_arrays(0)
		var p: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var t: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		for at: int in range(p.size()):
			var center: Vector3 = p[at] - Vector3(t[at * 4], t[at * 4 + 1], t[at * 4 + 2]) * uv[at].y
			check(absf(center.z - target) < 0.00001, "Straight rearward front-door edge")
		var handles: Array[Node] = car.body.find_children("RefHandleOutline" + suffix + "*", "MeshInstance3D", false, false)
		check(handles.size() == 2, "Both door handles retained")
		for handle: MeshInstance3D in handles:
			if handle.mesh.get_aabb().get_center().z > 0.5: continue
			var box: AABB = handle.mesh.get_aabb()
			var clearance: float = target - box.end.z
			check(clearance > 0.025 and clearance < 0.15, "Front handle follows its extended door")
		for height: float in [0.0, 0.5, 1.0]:
			check(absf(C.side_point(side, C.b_center(height), height).z - target) < 0.000001, "Window divider follows full-height door edge")

func run() -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("frame-registry.json")))
	raw = registry.raw
	post = registry.post
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	D.offline = detail
	S.offline = surface
	Source.observer = observe
	for simple: bool in [true, false]:
		var car = Source.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var triangles: int = 0
		for part: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
			if part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				triangles += part.mesh.get_faces().size() / 3
		counts.append({"simple": simple, "triangles": triangles})
		car.free()
		await process_frame
	check(observations == 2, "Both source model qualities observed")
	var previous: Script = load(WORK.path_join("before/game/vehicle/electric_reference_body.gd"))
	var shift: float = B.cabin_z(B.WINDOW_B_FOOT) - previous.cabin_z(previous.WINDOW_B_FOOT)
	check(shift > 0.13 and shift < 0.16, "Reference-led modest rearward extension")
	FileAccess.open(OUT.path_join("geometry.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "counts": counts, "waist_shift_m": shift, "bottom_shift_m": B.cabin_z(B.WINDOW_B_FOOT) - 0.05}, "  "))
	print("VFD_GEOMETRY ", checks, " checks, ", failures, " failures ", counts)
	quit(1 if failures else 0)

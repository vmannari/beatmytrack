extends "res://tests/test_modular_car_assets.gd"
## Diagnostic only: group transformed corners by position, then compare their
## normals, UVs and colors without relying on node/surface or triangle order.

func collect(car: CarVisual) -> Dictionary:
	var inverse: Transform3D = car.global_transform.affine_inverse()
	var groups: Dictionary = {}
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null or not node.is_visible_in_tree() or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var pose: Transform3D = inverse * node.global_transform
		var normals_matrix: Basis = pose.basis.inverse().transposed()
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for element: int in range(count):
				var index: int = indices[element] if not indices.is_empty() else element
				var point: Vector3 = (pose*vertices[index]).snapped(Vector3.ONE*0.00001)
				if not groups.has(point): groups[point] = {"normal":{},"uv":{},"color":{}}
				var data: Dictionary = groups[point]
				var normal: Variant = (normals_matrix*normals[index]).normalized().snapped(Vector3.ONE*0.00001) if index < normals.size() else "missing"
				var tex: Variant = uv[index].snapped(Vector2.ONE*0.00001) if index < uv.size() else "missing"
				var tint: Variant = colors[index] if index < colors.size() else "missing"
				for item: Array in [["normal",normal],["uv",tex],["color",tint]]:
					data[item[0]][item[1]] = int(data[item[0]].get(item[1],0))+1
	return groups

func compare_groups(a: Dictionary, b: Dictionary) -> void:
	for field: String in ["normal","uv","color"]:
		var changed: int = 0
		var max_nearest: float = 0.0
		var samples: Array = []
		for point: Variant in a:
			if not b.has(point): continue
			var left: Dictionary = a[point][field]
			var right: Dictionary = b[point][field]
			if left == right: continue
			changed += 1
			if samples.size() < 6: samples.append({"at":point,"before":left,"after":right})
			for value: Variant in left:
				if value is not Vector2 and value is not Vector3: continue
				var nearest: float = INF
				for candidate: Variant in right:
					if typeof(candidate) == typeof(value): nearest = minf(nearest,value.distance_to(candidate))
				if nearest != INF: max_nearest = maxf(max_nearest,nearest)
		print("ATTRIBUTE_COMPONENT ",field," changed_positions=",changed," max_nearest=",max_nearest," examples=",samples)

func triangles(car: CarVisual) -> Dictionary:
	var inverse: Transform3D = car.global_transform.affine_inverse()
	var groups: Dictionary = {}
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null or not node.is_visible_in_tree() or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var pose: Transform3D = inverse * node.global_transform
		var normals_matrix: Basis = pose.basis.inverse().transposed()
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for t: int in range(count/3):
				var corners: Array = []
				for c: int in range(3):
					var index: int = indices[t*3+c] if not indices.is_empty() else t*3+c
					corners.append([(pose*vertices[index]).snapped(Vector3.ONE*0.00001),uv[index] if index < uv.size() else null,colors[index] if index < colors.size() else null,(normals_matrix*normals[index]).normalized() if index < normals.size() else null])
				corners.sort_custom(func(left: Array,right: Array) -> bool:
					if left[0] != right[0]: return left[0] < right[0]
					return str([left[1],left[2]]) < str([right[1],right[2]]))
				var key: String = var_to_bytes([corners[0][0],corners[1][0],corners[2][0]]).hex_encode()
				if not groups.has(key): groups[key] = []
				groups[key].append(corners)
	return groups

func compare_triangles(before: Dictionary, after: Dictionary, label: String) -> void:
	var count: int = 0
	var missing: int = 0
	var different_uv_color: int = 0
	var max_normal_degrees: float = 0.0
	for key: String in before:
		if not after.has(key): missing += before[key].size(); continue
		var candidates: Array = after[key].duplicate()
		for left: Array in before[key]:
			var match_index: int = -1
			var best: float = INF
			for index: int in range(candidates.size()):
				var right: Array = candidates[index]
				var angle: float = 0.0
				var valid: bool = true
				for corner: int in range(3):
					if left[corner][1] != right[corner][1] or left[corner][2] != right[corner][2] or (left[corner][3] == null) != (right[corner][3] == null): valid = false; break
					if left[corner][3] != null:
						var delta: float = left[corner][3].distance_to(right[corner][3])
						angle = maxf(angle,rad_to_deg(2.0*asin(minf(1.0,delta*0.5))))
				if valid and angle < best: match_index = index; best = angle
			if match_index < 0:
				different_uv_color += 1
				continue
			candidates.remove_at(match_index)
			max_normal_degrees = maxf(max_normal_degrees,best)
			count += 1
		missing += candidates.size()
	for key: String in after:
		if not before.has(key): missing += after[key].size()
	print("ATTRIBUTE_TRIANGLES ",label," matched=",count," unmatched_geometry=",missing," unmatched_uv_or_color=",different_uv_color," max_normal_degrees=",max_normal_degrees)

func run() -> void:
	var id: String = "compact"
	var category: String = "hood"
	var editable: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--vehicle="): id = arg.trim_prefix("--vehicle=")
		if arg.begins_with("--category="): category = arg.trim_prefix("--category=")
		if arg == "--editable": editable = true
	Garage.enabled = false
	var parts: Dictionary = VehicleCustomisation.defaults()
	if category == "all":
		for item: String in VehicleCustomisation.CATEGORIES: parts[item] = VehicleCustomisation.options(item,id)[1][0]
	else: parts[category] = VehicleCustomisation.options(category,id)[1][0]
	var control: CarVisual = await make_car(id,false,editable,parts,false)
	var before: int = Base.hits
	var after: CarVisual = await make_car(id,false,editable,parts,true)
	print("ATTRIBUTE_CASE ",id," ",category," editable=",editable," base_hit=",Base.hits-before)
	if Base.hits == before:
		control.free(); after.free()
		push_error("No modular base was used; diagnostic would compare procedural fallbacks")
		quit(1)
		return
	var a: Dictionary = collect(control)
	var b: Dictionary = collect(after)
	compare_groups(a,b)
	a.clear(); b.clear()
	var expected: Dictionary = triangles(control)
	var current: Dictionary = triangles(after)
	compare_triangles(expected,current,"procedural/modular")
	current.clear()
	var second: CarVisual = await make_car(id,false,editable,parts,false)
	current = triangles(second)
	compare_triangles(expected,current,"procedural/procedural")
	second.free()
	control.free(); after.free()
	quit()

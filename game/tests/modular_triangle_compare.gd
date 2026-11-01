extends RefCounted
## Verify corresponding triangle corners independent of batch/scene order.
## Position keys are rounded to 10 micrometres in model space; UV and color
## values compare exactly. Normal error is measured in degrees per corner.

static func meshes(car: CarVisual, roots: Array = []) -> Array:
	if roots.is_empty(): return car.find_children("*","MeshInstance3D",true,false)
	var result: Array = []
	for root: Node in roots:
		if root is MeshInstance3D: result.append(root)
		result.append_array(root.find_children("*","MeshInstance3D",true,false))
	return result

static func collect(car: CarVisual, roots: Array = []) -> Dictionary:
	var inverse: Transform3D = car.global_transform.affine_inverse()
	var groups: Dictionary = {}
	for node: MeshInstance3D in meshes(car,roots):
		if node.mesh == null or not node.is_visible_in_tree() or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var pose: Transform3D = inverse * node.global_transform
		var normal_matrix: Basis = pose.basis.inverse().transposed()
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for triangle: int in range(count/3):
				var corners: Array = []
				for corner: int in range(3):
					var index: int = indices[triangle*3+corner] if not indices.is_empty() else triangle*3+corner
					corners.append([(pose*vertices[index]).snapped(Vector3.ONE*0.00001),uv[index] if index < uv.size() else null,colors[index] if index < colors.size() else null,(normal_matrix*normals[index]).normalized() if index < normals.size() else null])
				corners.sort_custom(func(left: Array,right: Array) -> bool:
					if left[0] != right[0]: return left[0] < right[0]
					return str([left[1],left[2]]) < str([right[1],right[2]]))
				var key: String = var_to_bytes([corners[0][0],corners[1][0],corners[2][0]]).hex_encode()
				if not groups.has(key): groups[key] = []
				groups[key].append(corners)
	return groups

static func compare(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {"matched":0,"unmatched_geometry":0,"unmatched_uv_color":0,"max_normal_degrees":0.0}
	for key: String in before:
		if not after.has(key): result.unmatched_geometry += before[key].size(); continue
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
				result.unmatched_uv_color += 1
				continue
			candidates.remove_at(match_index)
			result.max_normal_degrees = maxf(result.max_normal_degrees,best)
			result.matched += 1
		result.unmatched_geometry += candidates.size()
	for key: String in after:
		if not before.has(key): result.unmatched_geometry += after[key].size()
	return result

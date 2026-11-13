extends SceneTree
## RBC03: offset plates stay inside their outline and form closed, outward solids.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func run() -> void:
	CompactKits.use_baked = false
	var builder: Script = preload("res://vehicle/compact_aero.gd")
	if "--before" in OS.get_cmdline_user_args():
		builder = GDScript.new()
		builder.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rally-body-cleanup-2026-11-08/before-source/compact_aero.gd").replace("class_name CompactAero", "")
		assert(builder.reload()==OK)
	var outlines: Array = [
		[Vector2(0.23,1.78),Vector2(0.35,2.16),Vector2(0.20,2.16),Vector2(0.21,1.78)],
		[Vector2(0.27,-1.9),Vector2(0.33,-2.0),Vector2(0.30,-2.1),Vector2(0.27,-2.1)],
		[Vector2(-0.1,-0.2),Vector2(0.1,-0.15),Vector2(0.08,0.2),Vector2(-0.1,0.23)]]
	for simple: bool in [false,true]:
		CompactKits.simple_parts = simple
		for index: int in range(outlines.size()):
			var outline: Array[Vector2] = []
			outline.assign(outlines[index])
			var parent := Node3D.new()
			builder._plate(parent,"regression/"+str(index),Vector3.ZERO,outline,0.009,StandardMaterial3D.new())
			var part: MeshInstance3D = parent.get_child(0)
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var low := Vector2(INF,INF)
			var high := Vector2(-INF,-INF)
			for point: Vector2 in outline:
				low = low.min(point)
				high = high.max(point)
			var bounded: bool = true
			for point: Vector3 in points:
				bounded = bounded and point.y>=low.x-0.000001 and point.y<=high.x+0.000001 and point.z>=low.y-0.000001 and point.z<=high.y+0.000001
			var edges: Dictionary = {}
			var winding: bool = true
			var volume: float = 0.0
			for triangle: int in range(0,indices.size(),3):
				var a: Vector3 = points[indices[triangle]]
				var b: Vector3 = points[indices[triangle+1]]
				var c: Vector3 = points[indices[triangle+2]]
				var face: Vector3 = (b-a).cross(c-a)
				# Godot uses clockwise front faces, opposite the cross-product normal.
				winding = winding and face.length_squared()>1e-20 and face.normalized().dot(normals[indices[triangle]])< -0.99
				volume += a.cross(b).dot(c)/6.0
				for edge: int in range(3):
					var p: String = str(Vector3i((points[indices[triangle+edge]]*1000000).round()))
					var q: String = str(Vector3i((points[indices[triangle+(edge+1)%3]]*1000000).round()))
					var key: String = p+q if p<q else q+p
					edges[key] = int(edges.get(key,0))+1
			var closed: bool = true
			for count: int in edges.values(): closed = closed and count==2
			var label: String = str(index)+" simple="+str(simple)
			check(bounded,label+" no faces reach outside the outline")
			check(closed,label+" watertight edges")
			check(winding,label+" nondegenerate triangles and outward normals")
			check(volume< -0.00001,label+" outward closed solid volume")
			parent.free()
	print("RALLY_PLATE_SOLIDS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

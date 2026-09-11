class_name NativeTrackVisual
extends Node3D

const COLORS: Array[Color] = [Color("545c5a"), Color("56634a"), Color("8b7755"), Color("47717b"), Color("a09f91"), Color("b8b6a1"), Color("689095")]


func build(track: NativeTrack) -> void:
	VisualGeometry.box(self, Vector3(1000, 0.1, 1000), Vector3(0, -0.15, 0), VisualGeometry.material(COLORS[1]))
	_build_rectangles(track, track.rectangles, 0.0)
	_build_rectangles(track, track.deck_rectangles, track.bridge_height)
	var side := Vector2(track.finish_forward.y, -track.finish_forward.x)
	var paint := VisualGeometry.material(Color("ddd8bf"))
	for i: int in range(ceili(track.finish_half_width * 2 / track.cell_size)):
		var point: Vector2 = track.finish_center + side * (-track.finish_half_width + (i + 0.5) * track.cell_size)
		if track.cell_at(point) in [0, 2, 5, 6]:
			var stripe := VisualGeometry.box(self, Vector3(track.cell_size, 0.03, 0.2), VisualGeometry.world(point) + Vector3.UP * 0.03, paint)
			stripe.rotation.y = -track.spawn_heading


func _build_rectangles(track: NativeTrack, rectangles: Array, base_height: float) -> void:
	for kind: int in range(COLORS.size()):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count: int = 0
		for r: Array in rectangles:
			if int(r[4]) != kind:
				continue
			var x: float = float(r[0]) * track.cell_size - track.half_extent.x
			var z: float = float(r[1]) * track.cell_size - track.half_extent.y
			var w: float = float(r[2]) * track.cell_size
			var h: float = float(r[3]) * track.cell_size
			var height: float = base_height + (0.65 if kind == 4 else 0.0)
			var a := Vector3(x, height, z)
			var b := Vector3(x + w, height, z)
			var c := Vector3(x + w, height, z + h)
			var d := Vector3(x, height, z + h)
			for v: Vector3 in [a,c,b,a,d,c]:
				surface.add_vertex(v)
			if kind == 4:
				for edge: Array in [[a,b],[b,c],[c,d],[d,a]]:
					var low_a: Vector3 = edge[0] - Vector3.UP * 0.65
					var low_b: Vector3 = edge[1] - Vector3.UP * 0.65
					for v: Vector3 in [edge[0],edge[1],low_b,edge[0],low_b,low_a]:
						surface.add_vertex(v)
			count += 1
		if count:
			surface.generate_normals()
			var instance := MeshInstance3D.new()
			instance.mesh = surface.commit()
			var material := VisualGeometry.material(COLORS[kind])
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			instance.material_override = material
			add_child(instance)

extends Node3D
## Bounded, mesh-sharing history markers. Never read by simulation/collision.
var ghosts: Array[MeshInstance3D] = []
var labels: Array[Dictionary] = []
var path := MeshInstance3D.new()
var track: NativeTrack
var bridge: BridgePresentation
var entries: Array[Dictionary] = []
var origin_tick: int = 0

func configure(car: CarVisual, road: NativeTrack, heights: BridgePresentation, history: Array[Dictionary], tick: int) -> void:
	track = road
	bridge = heights
	entries = history
	origin_tick = tick
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flatten the selected vehicle once, then share it between four ghost instances.
	_append_meshes(car,car.global_transform.affine_inverse(),tool)
	tool.generate_normals()
	var mesh: ArrayMesh = tool.commit()
	var surface := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, blend_mix, cull_back; void fragment(){ float edge=pow(1.0-abs(dot(NORMAL,VIEW)),2.0); ALBEDO=mix(vec3(0.12,0.32,0.45),vec3(0.35,0.78,1.0),edge); ALPHA=0.13+edge*0.43; }"
	surface.shader = shader
	for i: int in range(4):
		var ghost := MeshInstance3D.new()
		ghost.name = "HistoryCar%d" % i
		ghost.mesh = mesh
		ghost.material_override = surface
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.scale = car.scale
		add_child(ghost)
		ghosts.append(ghost)
	var line_surface := StandardMaterial3D.new()
	line_surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_surface.albedo_color = Color("48b8e4")
	line_surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_surface.albedo_color.a = 0.65
	line_surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	path.material_override = line_surface
	path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(path)

func _append_meshes(node: Node, inverse: Transform3D, tool: SurfaceTool) -> void:
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null:
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var transform: Transform3D = inverse*node.global_transform
			# Source batches mix indexed/unindexed surfaces and vertex formats.
			# Expand triangles into one consistent format before sharing the mesh.
			if indices.is_empty():
				for vertex: Vector3 in vertices: tool.add_vertex(transform*vertex)
			else:
				for index: int in indices: tool.add_vertex(transform*vertices[index])
	for child: Node in node.get_children(): _append_meshes(child,inverse,tool)

func world(state: Dictionary) -> Vector3:
	var point: Vector2 = state.position
	var height: float = bridge.height_at(point,int(state.route_index),1 if state.track_elevated else 0)
	height += float(state.jump_height)
	return Vector3(point.x,height+0.05,-point.y)

func present(selected: int) -> void:
	labels.clear()
	for ghost: MeshInstance3D in ghosts: ghost.hide()
	if entries.is_empty(): return
	var index: int = clampi(selected,0,entries.size()-1)
	var anchor: Vector2 = entries[index].state.position
	var last: Vector2 = anchor
	var picks: Array[int] = []
	# Prefer past positions; near the beginning, show available future positions.
	var direction: int = -1 if index >= 8 else 1
	var cursor: int = index+direction
	while cursor >= 0 and cursor < entries.size() and picks.size() < 4:
		var point: Vector2 = entries[cursor].state.position
		if point.distance_to(anchor) > 29.0: break
		if point.distance_to(last) >= 5.5:
			picks.append(cursor)
			last = point
		cursor += direction
	for i: int in range(picks.size()):
		var entry: Dictionary = entries[picks[i]]
		ghosts[i].position = world(entry.state)
		ghosts[i].rotation.y = -float(entry.state.heading)
		ghosts[i].show()
		labels.append({"world":ghosts[i].position,"seconds":(origin_tick-int(entry.tick))/120.0})
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start: int = mini(index,cursor+1)
	var end: int = maxi(index,cursor-1)
	for i: int in range(maxi(0,start),mini(entries.size()-1,end)):
		var a: Vector3 = world(entries[i].state)
		var b: Vector3 = world(entries[i+1].state)
		var side: Vector3 = (b-a).cross(Vector3.UP).normalized()*0.065
		for vertex: Vector3 in [a-side,a+side,b+side,a-side,b+side,b-side]: tool.add_vertex(vertex)
	path.mesh = tool.commit() if end > start else null

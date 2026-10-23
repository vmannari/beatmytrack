extends RefCounted
## Immutable cosmetic elevation. Never supplied to canonical bridge flight.
const VERSION: String = "desert-road-relief-1"
const DEPTH: float = 0.18
const MAX_FIELD_BYTES: int = 8*1024*1024
const MAX_EDGE: float = 1.0
var track: NativeTrack
var field := PackedFloat32Array()
var bounds: Rect2
var _samples: Dictionary = {}

func _init(data: NativeTrack) -> void:
	track = data
	if data.metadata.get("theme","pine") != "desert": return
	if data.cells.size()*4 > MAX_FIELD_BYTES: return
	field.resize(data.cells.size()); field.fill(1000.0)
	var w: int = data.grid_width; var h: int = data.grid_height
	for i: int in range(field.size()):
		if data.cells[i] == 0 or data.deck_cells[i] >= 0: field[i] = 0.0
	# A bounded chamfer field keeps both authored and painted road footprints.
	# The metre-wide flat bed covers original sub-cell contour/raster offsets.
	var diagonal: float = data.cell_size*sqrt(2.0)
	for pass_index: int in range(2):
		var step: int = 1 if pass_index == 0 else -1
		for row: int in range(h):
			var y: int = row if step == 1 else h-1-row
			for column: int in range(w):
				var x: int = column if step == 1 else w-1-column; var i: int = y*w+x
				if x-step >= 0 and x-step < w: field[i] = minf(field[i],field[i-step]+data.cell_size)
				if y-step < 0 or y-step >= h: continue
				field[i] = minf(field[i],field[i-step*w]+data.cell_size)
				for side: int in [-1,1]:
					if x+side >= 0 and x+side < w: field[i] = minf(field[i],field[i-step*w+side]+diagonal)
	var first: bool = true
	for y: int in range(h):
		for x: int in range(w):
			var i: int = y*w+x; field[i] = -DEPTH*(1.0-smoothstep(1.0,3.0,field[i]))
			if field[i] == 0.0: continue
			var p := Vector2((x+0.5)*data.cell_size-data.half_extent.x,data.half_extent.y-(y+0.5)*data.cell_size)
			if first: bounds = Rect2(p,Vector2.ZERO); first = false
			else: bounds = bounds.expand(p)
	if not first: bounds = bounds.grow(data.cell_size*2.0)

func height(point: Vector2) -> float:
	if field.is_empty(): return 0.0
	var cell: Vector2 = Vector2((point.x+track.half_extent.x)/track.cell_size,(track.half_extent.y-point.y)/track.cell_size)-Vector2.ONE*0.5
	var x: int = floori(cell.x); var y: int = floori(cell.y)
	var fx: float = cell.x-x; var fy: float = cell.y-y
	return lerpf(lerpf(_cell(x,y),_cell(x+1,y),fx),lerpf(_cell(x,y+1),_cell(x+1,y+1),fx),fy)

func _cell(x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= track.grid_width or y >= track.grid_height: return 0.0
	return field[y*track.grid_width+x]

func sample(point: Vector2) -> Vector3:
	if _samples.has(point): return _samples[point]
	var value: float = height(point)
	var step: float = track.cell_size*0.25
	var result := Vector3((height(point+Vector2(step,0))-height(point-Vector2(step,0)))/(step*2.0),value,(height(point+Vector2(0,-step))-height(point+Vector2(0,step)))/(step*2.0))
	if _samples.size() < 32768: _samples[point] = result
	return result

func apply(root: Node3D, sliced: bool = false) -> void:
	if field.is_empty(): return
	await _apply_node(root,root.global_transform.affine_inverse(),sliced)
	_samples.clear()

func _apply_node(node: Node, inverse: Transform3D, sliced: bool) -> void:
	if node is Node3D and node.has_meta("prop_origin"):
		# Movable props remain rigid; their presenter owns subsequent support.
		if not node.has_meta("desert_road_relief"):
			var p: Vector3 = inverse*node.global_position
			node.position += node.get_parent_node_3d().global_basis.inverse()*Vector3.UP*height(Vector2(p.x,-p.z))
			node.set_meta("desert_road_relief",true)
		return
	if node is MultiMeshInstance3D and node.multimesh != null:
		var original: MultiMesh = node.multimesh
		if not original.has_meta("desert_road_relief"):
			# Construct formats/count before the buffer. Resource.duplicate can
			# assign these in the wrong order, and headless has no backing buffer.
			var batch := MultiMesh.new()
			batch.transform_format = original.transform_format
			batch.use_colors = original.use_colors; batch.use_custom_data = original.use_custom_data
			batch.mesh = original.mesh; batch.instance_count = original.instance_count
			batch.visible_instance_count = original.visible_instance_count
			var buffer: PackedFloat32Array = original.buffer
			if not buffer.is_empty(): batch.buffer = buffer
			var to_world: Transform3D = inverse*node.global_transform
			for i: int in range(batch.instance_count):
				var pose: Transform3D = batch.get_instance_transform(i)
				var p: Vector3 = to_world*pose.origin
				pose.origin += to_world.basis.inverse()*Vector3.UP*height(Vector2(p.x,-p.z))
				batch.set_instance_transform(i,pose)
			# Preserve automatic bounds for moving instances. Only authored
			# custom bounds need the extra downward extent.
			if original.custom_aabb != AABB():
				var aabb: AABB = original.custom_aabb
				aabb.position.y -= DEPTH; aabb.size.y += DEPTH
				batch.custom_aabb = aabb
			batch.set_meta("desert_road_relief",VERSION); node.multimesh = batch
	elif node is MeshInstance3D and node.mesh != null:
		if node.is_in_group("contact_lighting") or node.is_in_group("race_bridge_rendering") and node.name.contains("Shadow"):
			if not node.has_meta("desert_road_relief"):
				var p: Vector3 = inverse*node.global_position
				node.position += node.get_parent_node_3d().global_basis.inverse()*Vector3.UP*height(Vector2(p.x,-p.z)); node.set_meta("desert_road_relief",true)
		elif not node.mesh.has_meta("desert_road_relief"):
			var to_world: Transform3D = inverse*node.global_transform
			var material: ShaderMaterial = node.material_override as ShaderMaterial
			var refine: bool = material != null and not node.is_in_group("race_bridge_rendering")
			# Refine terrain/skirts across their interior so an unchanged large
			# source triangle cannot remain as a flat lid over the recessed road.
			node.mesh = deform(node.mesh,to_world,refine)
		if sliced and node.is_inside_tree(): await node.get_tree().process_frame
	for child: Node in node.get_children(): await _apply_node(child,inverse,sliced)

func deform(source: Mesh, transform: Transform3D, refine: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new(); var inverse: Transform3D = transform.affine_inverse()
	for surface: int in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		for first: int in range(0,count,3):
			var triangle: Array = []
			for j: int in range(3):
				var i: int = indices[first+j] if not indices.is_empty() else first+j
				triangle.append([transform*vertices[i],transform.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][i] if arrays[Mesh.ARRAY_NORMAL] != null else Vector3.UP,arrays[Mesh.ARRAY_TEX_UV][i] if arrays[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO,arrays[Mesh.ARRAY_TEX_UV2][i] if arrays[Mesh.ARRAY_TEX_UV2] != null else Vector2.ZERO,arrays[Mesh.ARRAY_COLOR][i] if arrays[Mesh.ARRAY_COLOR] != null else Color.WHITE])
			_triangle(tool,triangle,inverse,refine,0)
		tool.index(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,tool.commit_to_arrays())
		mesh.surface_set_material(surface,source.surface_get_material(surface))
	mesh.set_meta("desert_road_relief",VERSION)
	return mesh

func _triangle(tool: SurfaceTool, triangle: Array, inverse: Transform3D, refine: bool, depth: int) -> void:
	var a: Vector3 = triangle[0][0]; var b: Vector3 = triangle[1][0]; var c: Vector3 = triangle[2][0]
	var lengths: Array[float] = [Vector2(a.x-b.x,a.z-b.z).length_squared(),Vector2(b.x-c.x,b.z-c.z).length_squared(),Vector2(c.x-a.x,c.z-a.z).length_squared()]
	var longest: int = 0
	if lengths[1] > lengths[longest]: longest = 1
	if lengths[2] > lengths[longest]: longest = 2
	if refine and depth < 28 and lengths[longest] > MAX_EDGE*MAX_EDGE:
		var rectangle := Rect2(Vector2(a.x,-a.z),Vector2.ZERO).expand(Vector2(b.x,-b.z)).expand(Vector2(c.x,-c.z))
		if rectangle.intersects(bounds,true):
			var values: Array[float] = []
			for p: Vector3 in [a,b,c,(a+b)*0.5,(b+c)*0.5,(c+a)*0.5,(a+b+c)/3.0]: values.append(height(Vector2(p.x,-p.z)))
			var uniform: bool = values.min() == values.max()
			if not uniform or lengths[longest] > 16.0:
				var next: int = (longest+1)%3; var other: int = (longest+2)%3
				var mid: Array = []
				for attr: int in range(5): mid.append(triangle[longest][attr].lerp(triangle[next][attr],0.5))
				_triangle(tool,[triangle[longest],mid,triangle[other]],inverse,refine,depth+1)
				_triangle(tool,[mid,triangle[next],triangle[other]],inverse,refine,depth+1)
				return
	for row: Array in triangle:
		var p: Vector3 = row[0]; var n: Vector3 = row[1]; var relief: Vector3 = sample(Vector2(p.x,-p.z))
		p.y += relief.y
		n = Vector3(n.x-relief.x*n.y,n.y,n.z-relief.z*n.y).normalized()
		tool.set_normal((inverse.basis.inverse().transposed()*n).normalized()); tool.set_uv(row[2]); tool.set_uv2(row[3]); tool.set_color(row[4]); tool.add_vertex(inverse*p)

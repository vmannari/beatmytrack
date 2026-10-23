class_name PropGeometry
extends RefCounted
## Original opaque, vertex-coloured prop geometry. No collision or simulation data.

# Opt in only while assembling one immutable prop. The cores are strictly
# inside closed boxes; they are never inferred from open foliage or a mesh AABB.
static func model(clearance: float = 0.045) -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if clearance >= 0.0:
		tool.set_meta("prop_solid_cores",[])
		tool.set_meta("prop_clearance",clearance)
	return tool

static func finish(tool: SurfaceTool, generate: bool = true) -> ArrayMesh:
	if generate: tool.generate_normals()
	var source: ArrayMesh = tool.commit()
	var hidden: Dictionary = {}
	for triangle: int in tool.get_meta("prop_hidden_triangles",PackedInt32Array()): hidden[triangle] = true
	var complete: bool = tool.get_meta("prop_plan_complete",false) and int(tool.get_meta("prop_triangle_count",-1))*3 == source.surface_get_array_len(0)
	if tool.has_meta("prop_solid_cores") and not complete:
		var data: Array = source.surface_get_arrays(0)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var cores: Array = tool.get_meta("prop_solid_cores")
		# Bound the transient acceleration table. Very long solids use the
		# broad list, so authored run lengths cannot explode the grid.
		var grid: Dictionary = {}; var broad: Array = []; var entries: int = 0
		for core: SolidBox in cores:
			var low := Vector3i(core.bounds.position.floor())
			var high := Vector3i(core.bounds.end.floor())
			var extent: Vector3i = high-low+Vector3i.ONE
			var cells: int = extent.x*extent.y*extent.z
			if cores.size() < 16 or cells > 256 or entries+cells > 8192:
				broad.append(core)
				continue
			for x: int in range(low.x,high.x+1):
				for y: int in range(low.y,high.y+1):
					for z: int in range(low.z,high.z+1):
						var cell := Vector3i(x,y,z)
						if not grid.has(cell): grid[cell] = []
						grid[cell].append(core)
			entries += cells
		for i: int in range(0,vertices.size(),3):
			if hidden.has(i/3): continue
			var a: Vector3 = vertices[i]; var b: Vector3 = vertices[i+1]; var c: Vector3 = vertices[i+2]
			if (b-a).cross(c-a) == Vector3.ZERO:
				hidden[i/3] = true
				continue
			if enclosed(a,b,c,grid.get(Vector3i(a.floor()),[])) or enclosed(a,b,c,broad): hidden[i/3] = true
	source.set_meta("prop_hidden_triangles",PackedInt32Array(hidden.keys()))
	source.set_meta("prop_plan_complete",tool.has_meta("prop_solid_cores") or tool.get_meta("prop_plan_complete",false))
	return source

static func enclosed(a: Vector3, b: Vector3, c: Vector3, cores: Array) -> bool:
	for core: SolidBox in cores:
		if core.bounds.has_point(a) and core.contains(a) and core.contains(b) and core.contains(c): return true
	return false

static func append_mesh(destination: SurfaceTool, mesh: ArrayMesh, pose: Transform3D) -> void:
	# Carry removal ordinals through the existing unindexed assembly. Keep all
	# faces until the receiving builder has generated its original normals.
	var offset: int = int(destination.get_meta("prop_triangle_count",-1))
	if offset < 0:
		var existing: Array = destination.commit_to_arrays()
		offset = 0 if existing[Mesh.ARRAY_VERTEX] == null else existing[Mesh.ARRAY_VERTEX].size()/3
	var hidden: PackedInt32Array = destination.get_meta("prop_hidden_triangles",PackedInt32Array())
	for triangle: int in mesh.get_meta("prop_hidden_triangles",PackedInt32Array()): hidden.append(offset+triangle)
	destination.append_from(mesh,0,pose)
	destination.set_meta("prop_hidden_triangles",hidden)
	destination.set_meta("prop_triangle_count",offset+mesh.surface_get_array_len(0)/3)
	destination.set_meta("prop_plan_complete",(offset == 0 or destination.get_meta("prop_plan_complete",false)) and mesh.get_meta("prop_plan_complete",false))

static func arrays(tool: SurfaceTool) -> Array:
	return prune(tool.commit_to_arrays(),tool.get_meta("prop_hidden_triangles",PackedInt32Array()))

static func prune(source: Array, hidden: PackedInt32Array) -> Array:
	var data: Array = source.duplicate()
	if hidden.is_empty(): return data
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = (indices.size() if not indices.is_empty() else vertices.size())/3
	if indices.is_empty():
		indices.resize(count*3)
		for i: int in range(indices.size()): indices[i] = i
	var ordered: PackedInt32Array = hidden.duplicate(); ordered.sort()
	var kept := PackedInt32Array(); var start: int = 0
	for triangle: int in ordered:
		var end: int = triangle*3
		if end > start: kept.append_array(indices.slice(start,end))
		start = end+3
	if start < indices.size(): kept.append_array(indices.slice(start))
	if kept.is_empty(): return data
	# Retain the original shared vertex streams. Contiguous index slices remove
	# only the enclosed faces without a per-vertex GDScript copy or re-encoding
	# normals/colours. Unreferenced vertices perform no rendering work.
	data[Mesh.ARRAY_INDEX] = kept
	return data

static func commit(tool: SurfaceTool) -> ArrayMesh:
	if not tool.has_meta("prop_hidden_triangles") or tool.get_meta("prop_hidden_triangles").is_empty(): return tool.commit()
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays(tool))
	return result

class SolidBox extends RefCounted:
	var center: Vector3
	var half: Vector3
	var bevel: float
	var clearance: float
	var cut_flat: float
	var cut_cap: float
	var bounds: AABB

	func _init(p: Vector3, extent: Vector3, b: float, margin: float) -> void:
		center = p; half = extent; bevel = b; clearance = margin
		cut_flat = minf(b,minf(half.x,half.z)*0.4)
		cut_cap = minf(b,minf(half.x-b,half.z-b)*0.4)
		bounds = AABB(p-half,half*2.0)

	func contains(point: Vector3) -> bool:
		# This is the actual convex octagonal cross-section of box(), including
		# its sloping bevels. Padding in all axes also encloses the ink extrusion.
		var q: Vector3 = (point-center).abs()+Vector3.ONE*clearance
		if q.y >= half.y: return false
		var inset: float = maxf(0.0,q.y-half.y+bevel)
		var cut: float = lerpf(cut_flat,cut_cap,inset/bevel) if bevel > 0 else 0.0
		return q.x < half.x-inset and q.z < half.z-inset and q.x+q.z < half.x+half.z-inset*2.0-cut

static func face(tool: SurfaceTool, points: Array, color: Color, outward: Vector3 = Vector3.ZERO) -> void:
	tool.set_color(color)
	tool.set_smooth_group(-1)
	var flip: bool = outward != Vector3.ZERO and (points[1]-points[0]).cross(points[2]-points[0]).dot(outward) < 0
	for i: int in range(1,points.size()-1):
		for j: int in ([0,i,i+1] if flip else [0,i+1,i]): tool.add_vertex(points[j])

static func box(tool: SurfaceTool, p: Vector3, size: Vector3, color: Color, bevel: float = 0.025) -> void:
	var half: Vector3 = size*0.5
	var b: float = minf(bevel,minf(half.x,minf(half.y,half.z))*0.6)
	if tool.has_meta("prop_solid_cores"):
		# 22 mm ink extrusion at the minimum authored scale (0.5), plus
		# clearance. Retain thin shells, bevels and all touching faces.
		var cores: Array = tool.get_meta("prop_solid_cores")
		cores.append(SolidBox.new(p,half,b,float(tool.get_meta("prop_clearance"))))
	var loops: Array = []
	for row: int in range(4):
		var inset: float = b if row in [0,3] else 0.0
		var x: float = half.x-inset
		var z: float = half.z-inset
		var y: float = [-half.y,-half.y+b,half.y-b,half.y][row]
		var cut: float = minf(b,minf(x,z)*0.4)
		var ring: Array[Vector3] = []
		for q: Vector2 in [Vector2(-x+cut,-z),Vector2(x-cut,-z),Vector2(x,-z+cut),Vector2(x,z-cut),Vector2(x-cut,z),Vector2(-x+cut,z),Vector2(-x,z-cut),Vector2(-x,-z+cut)]:
			ring.append(p+Vector3(q.x,y,q.y))
		loops.append(ring)
	for row: int in range(3):
		for i: int in range(8):
			var j: int = (i+1)%8
			var normal: Vector3 = (loops[row][j]+loops[row][i]+loops[row+1][i]+loops[row+1][j])*0.25-p
			face(tool,[loops[row][j],loops[row][i],loops[row+1][i],loops[row+1][j]],color.lightened(0.07 if row == 2 else 0).darkened(0.10 if row == 0 else 0),normal)
	face(tool,loops[3],color.lightened(0.06),Vector3.UP)
	var bottom: Array = loops[0].duplicate(); bottom.reverse()
	face(tool,bottom,color.darkened(0.15),Vector3.DOWN)

static func beam(tool: SurfaceTool, a: Vector3, b: Vector3, width: float, depth: float, color: Color) -> void:
	var axis: Vector3 = (b-a).normalized()
	var across: Vector3 = axis.cross(Vector3.UP).normalized()
	if across.length_squared() < 0.01: across = Vector3.RIGHT
	var normal: Vector3 = across.cross(axis).normalized()
	var loops: Array = []
	for p: Vector3 in [a,b]:
		loops.append([p-across*width*0.5-normal*depth*0.5,p+across*width*0.5-normal*depth*0.5,p+across*width*0.5+normal*depth*0.5,p-across*width*0.5+normal*depth*0.5])
	for i: int in range(4):
		var j: int = (i+1)%4
		var side_normal: Vector3 = (loops[0][i]+loops[0][j]+loops[1][j]+loops[1][i])*0.25-(a+b)*0.5
		face(tool,[loops[0][i],loops[0][j],loops[1][j],loops[1][i]],color,side_normal)
	face(tool,loops[0],color.darkened(0.1),-axis)
	var cap: Array = loops[1].duplicate(); cap.reverse(); face(tool,cap,color.lightened(0.05),axis)

static func tube(tool: SurfaceTool, a: Vector3, b: Vector3, radius_a: float, radius_b: float, color: Color, segments: int = 10) -> void:
	var axis: Vector3 = (b-a).normalized()
	var u: Vector3 = axis.cross(Vector3.UP).normalized()
	if u.length_squared() < 0.01: u = Vector3.RIGHT
	var v: Vector3 = axis.cross(u).normalized()
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i: int in range(segments):
		var radial: Vector3 = u*cos(TAU*i/segments)+v*sin(TAU*i/segments)
		lo.append(a+radial*radius_a); hi.append(b+radial*radius_b)
	for i: int in range(segments):
		var j: int = (i+1)%segments
		var normal: Vector3 = (lo[j]+lo[i]+hi[i]+hi[j])*0.25-(a+b)*0.5
		face(tool,[lo[j],lo[i],hi[i],hi[j]],color.lightened(0.025*(i%3)),normal)
	face(tool,hi,color.lightened(0.07),axis); face(tool,lo,color.darkened(0.10),-axis)

static func ring(tool: SurfaceTool, center: Vector3, axis: Vector3, outer: float, inner: float, width: float, color: Color, segments: int = 24) -> void:
	var u: Vector3 = axis.cross(Vector3.UP).normalized()
	if u.length_squared() < 0.01: u = Vector3.RIGHT
	var v: Vector3 = axis.cross(u).normalized()
	for i: int in range(segments):
		var p: Vector3 = u*cos(TAU*i/segments)+v*sin(TAU*i/segments)
		var q: Vector3 = u*cos(TAU*(i+1)/segments)+v*sin(TAU*(i+1)/segments)
		var a: Vector3 = center-axis*width*0.5
		var b: Vector3 = center+axis*width*0.5
		face(tool,[a+q*outer,a+p*outer,b+p*outer,b+q*outer],color.darkened(0.10),p+q)
		face(tool,[a+p*inner,a+q*inner,b+q*inner,b+p*inner],color.darkened(0.24),-p-q)
		face(tool,[b+q*outer,b+p*outer,b+p*inner,b+q*inner],color.lightened(0.13),axis)
		face(tool,[a+p*outer,a+q*outer,a+q*inner,a+p*inner],color,-axis)

static func append_transformed(destination: SurfaceTool, local: SurfaceTool, center: Vector3, scale: float, turn: float) -> void:
	# Keep the source unindexed until the complete destination is assembled.
	# Mixing indexed and unindexed appends omits earlier faces from the indices.
	var mesh: ArrayMesh = finish(local)
	append_mesh(destination,mesh,Transform3D(Basis(Vector3.UP,turn).scaled(Vector3.ONE*scale),center))

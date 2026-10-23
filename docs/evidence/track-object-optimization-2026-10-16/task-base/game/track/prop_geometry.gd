class_name PropGeometry
extends RefCounted
## Original opaque, vertex-coloured prop geometry. No collision or simulation data.

static func face(tool: SurfaceTool, points: Array, color: Color, outward: Vector3 = Vector3.ZERO) -> void:
	tool.set_color(color)
	tool.set_smooth_group(-1)
	var flip: bool = outward != Vector3.ZERO and (points[1]-points[0]).cross(points[2]-points[0]).dot(outward) < 0
	for i: int in range(1,points.size()-1):
		for j: int in ([0,i,i+1] if flip else [0,i+1,i]): tool.add_vertex(points[j])

static func box(tool: SurfaceTool, p: Vector3, size: Vector3, color: Color, bevel: float = 0.025) -> void:
	var half: Vector3 = size*0.5
	var b: float = minf(bevel,minf(half.x,minf(half.y,half.z))*0.6)
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
	local.generate_normals()
	# Keep the source unindexed until the complete destination is assembled.
	# Mixing indexed and unindexed appends omits earlier faces from the indices.
	var mesh: ArrayMesh = local.commit()
	destination.append_from(mesh,0,Transform3D(Basis(Vector3.UP,turn).scaled(Vector3.ONE*scale),center))

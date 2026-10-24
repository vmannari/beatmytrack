extends RefCounted
## A five-millimetre rounded lip and closed dark side in the existing road draw.
const RADIUS: float = 0.005
const SIDE_SHADE: float = 0.80
const STEPS: int = 3

static func append(tool: SurfaceTool, a: Vector3, b: Vector3, outward_a: Vector3, outward_b: Vector3, bottom_a: float, bottom_b: float, uv_a: Vector2 = Vector2.ZERO, uv_b: Vector2 = Vector2.ZERO, uv2: Vector2 = Vector2.RIGHT, wall: bool = true, across_uv: Vector2 = Vector2.ZERO, up: Vector3 = Vector3.UP) -> void:
	for step: int in range(STEPS):
		var first: float = PI*0.5*step/STEPS
		var last: float = PI*0.5*(step+1)/STEPS
		var d0: float = RADIUS*sin(first)
		var d1: float = RADIUS*sin(last)
		var y0: float = RADIUS*(cos(first)-1.0)
		var y1: float = RADIUS*(cos(last)-1.0)
		var na0: Vector3 = (outward_a.normalized()*sin(first)+up*cos(first)).normalized()
		var nb0: Vector3 = (outward_b.normalized()*sin(first)+up*cos(first)).normalized()
		var na1: Vector3 = (outward_a.normalized()*sin(last)+up*cos(last)).normalized()
		var nb1: Vector3 = (outward_b.normalized()*sin(last)+up*cos(last)).normalized()
		var shade0: float = lerpf(SIDE_SHADE,1.0,cos(first))
		var shade1: float = lerpf(SIDE_SHADE,1.0,cos(last))
		_quad(tool,[a+outward_a*d0+Vector3.UP*y0,b+outward_b*d0+Vector3.UP*y0,b+outward_b*d1+Vector3.UP*y1,a+outward_a*d1+Vector3.UP*y1],
			[na0,nb0,nb1,na1],[shade0,shade0,shade1,shade1],[uv_a+across_uv*d0,uv_b+across_uv*d0,uv_b+across_uv*d1,uv_a+across_uv*d1],uv2)
	if wall:
		var pa: Vector3 = a+outward_a*RADIUS-Vector3.UP*RADIUS
		var pb: Vector3 = b+outward_b*RADIUS-Vector3.UP*RADIUS
		_quad(tool,[pa,pb,Vector3(pb.x,bottom_b,pb.z),Vector3(pa.x,bottom_a,pa.z)],
			[outward_a.normalized(),outward_b.normalized(),outward_b.normalized(),outward_a.normalized()],
			[SIDE_SHADE,SIDE_SHADE,SIDE_SHADE,SIDE_SHADE],[uv_a,uv_b,uv_b,uv_a],uv2)

static func _quad(tool: SurfaceTool, points: Array[Vector3], normals: Array[Vector3], shades: Array[float], uv: Array[Vector2], uv2: Vector2) -> void:
	var order: Array[int] = [0,2,1,0,3,2]
	if (points[2]-points[0]).cross(points[1]-points[0]).dot(normals[0]+normals[1]+normals[2]) < 0.0: order = [0,1,2,0,2,3]
	for i: int in order:
		tool.set_normal(normals[i])
		tool.set_color(Color(1.0,1.0,1.0,shades[i]))
		tool.set_uv(uv[i]); tool.set_uv2(uv2)
		tool.add_vertex(points[i])

static func append_arrays(tool: SurfaceTool, arrays: Array) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in range(vertices.size()):
		tool.set_normal(arrays[Mesh.ARRAY_NORMAL][i])
		tool.set_color(arrays[Mesh.ARRAY_COLOR][i])
		tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][i])
		tool.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][i])
		tool.add_vertex(vertices[i])

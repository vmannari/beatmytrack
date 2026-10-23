extends ShoulderMesh
## Cosmetic Grass verge; clipping and parallel solving remain in ShoulderMesh.
## Stones and blades use the same draw, masks, prepared arrays and cache budget.
const INNER_HEIGHT: float = 0.027
const OUTER_HEIGHT: float = -0.038
const ROAD_OFFSET: float = 0.365 # Marking centre to outside of rounded asphalt lip.
const MAX_DETAILS: int = 2048
const DETAIL_GRID: float = 0.34
var detail_count: int = 0
var _cells_emitted: Dictionary = {}
var _points := PackedVector2Array()
var _across := PackedFloat32Array()

static func width(point: Vector2) -> float:
	return ROAD_OFFSET+0.475+0.085*sin(point.x*0.43+point.y*0.19)+0.04*sin(point.y*0.91-point.x*0.57)

func _emit_vertex(tool: SurfaceTool, point: Vector2, uv: Vector2) -> void:
	_points.append(point); _across.append(uv.y)
	if _points.size() < 3: return
	var u: Vector2 = _points[1]-_points[0]
	var v: Vector2 = _points[2]-_points[0]
	# Boolean subtraction leaves repeated vertices or sub-10-micrometre
	# ribbons at shared borders. Omit these cosmetic slivers before applying
	# height; the unchanged asphalt solver retains its original triangles.
	var twice_area: float = absf(float(u.x)*float(v.y)-float(u.y)*float(v.x))
	var longest: float = maxf(u.length(),maxf(v.length(),(_points[2]-_points[1]).length()))
	if twice_area <= longest*0.00001:
		_points.clear(); _across.clear(); return
	var vertices: Array[Vector3] = []
	for i: int in range(3): vertices.append(VisualGeometry.world(_points[i])+Vector3.UP*lerpf(INNER_HEIGHT,OUTER_HEIGHT,_across[i]))
	var normal: Vector3 = (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
	if normal.y < 0.0: normal = -normal
	for i: int in range(3):
		tool.set_uv(Vector2(0,_across[i])); tool.set_normal(normal); tool.set_color(Color.WHITE); tool.add_vertex(vertices[i])
	if detail_count < MAX_DETAILS: _details(tool,normal)
	_points.clear(); _across.clear()

func _details(tool: SurfaceTool, normal: Vector3) -> void:
	var bounds := Rect2(_points[0],Vector2.ZERO).expand(_points[1]).expand(_points[2])
	var u: Vector2 = _points[1]-_points[0]
	var v: Vector2 = _points[2]-_points[0]
	var determinant: float = u.cross(v)
	if absf(determinant) < 0.0000001: return
	var gradient := Vector2((_across[1]-_across[0])*v.y-(_across[2]-_across[0])*u.y,u.x*(_across[2]-_across[0])-v.x*(_across[1]-_across[0]))/determinant
	for y: int in range(floori(bounds.position.y/DETAIL_GRID),floori(bounds.end.y/DETAIL_GRID)+1):
		for x: int in range(floori(bounds.position.x/DETAIL_GRID),floori(bounds.end.x/DETAIL_GRID)+1):
			if detail_count >= MAX_DETAILS: return
			var cell := Vector2i(x,y)
			if _cells_emitted.has(cell): continue
			var seed_value: int = ((x*73856093) ^ (y*19349663)) & 0x7fffffff
			var point := Vector2(x+0.15+float(seed_value%701)/1000.0,y+0.15+float((seed_value/701)%701)/1000.0)*DETAIL_GRID
			var t: float = gradient.dot(point-_points[0])+_across[0]
			if t < 0.10 or t > 0.97: continue
			var radius: float = 0.009+float((seed_value/491401)%19)*0.001
			var clear: bool = true
			for offset: Vector2 in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
				if not Geometry2D.is_point_in_polygon(point+offset,_points): clear = false; break
			if not clear: continue
			_cells_emitted[cell] = true
			var center: Vector3 = VisualGeometry.world(point)+Vector3.UP*(lerpf(INNER_HEIGHT,OUTER_HEIGHT,t)-0.001)
			if t > 0.58 and seed_value%3 != 0: _grass(tool,center,t,seed_value,normal)
			else: _stone(tool,center,t,seed_value,radius,normal)
			detail_count += 1

func _stone(tool: SurfaceTool, center: Vector3, t: float, seed_value: int, radius: float, slope: Vector3) -> void:
	var shade: float = float(seed_value%17)/16.0
	var tint: Color = Color("69665b").lerp(Color("c9bd99"),shade)
	var angle: float = float(seed_value%628)*0.01
	var peak: Vector3 = center+Vector3.UP*radius*0.70
	for side: int in range(5):
		var a: Vector3 = center+Vector3(cos(angle+TAU*side/5.0)*radius,0,sin(angle+TAU*side/5.0)*radius*0.72)
		var b: Vector3 = center+Vector3(cos(angle+TAU*(side+1)/5.0)*radius,0,sin(angle+TAU*(side+1)/5.0)*radius*0.72)
		# Seat every rim on the same sloping plane as its foot.
		a.y -= Vector2(slope.x,slope.z).dot(Vector2(a.x-center.x,a.z-center.z))/maxf(slope.y,0.01)
		b.y -= Vector2(slope.x,slope.z).dot(Vector2(b.x-center.x,b.z-center.z))/maxf(slope.y,0.01)
		_triangle(tool,[a,peak,b],Vector2(-1,t),tint)

func _grass(tool: SurfaceTool, center: Vector3, t: float, seed_value: int, slope: Vector3) -> void:
	for blade: int in range(3):
		var angle: float = float(seed_value%628)*0.01+blade*2.399
		var axis := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-axis.z,0,axis.x)*0.007
		var base: Vector3 = center+axis*0.008
		base.y -= Vector2(slope.x,slope.z).dot(Vector2(base.x-center.x,base.z-center.z))/maxf(slope.y,0.01)
		var tip: Vector3 = base+axis*0.025+Vector3.UP*(0.045+float((seed_value+blade)%5)*0.008)
		_triangle(tool,[base-side,tip,base+side],Vector2(-2,t),Color("69733d").lerp(Color("9a9956"),float(blade)/3.0))

func _triangle(tool: SurfaceTool, vertices: Array[Vector3], uv: Vector2, tint: Color) -> void:
	var normal: Vector3 = (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
	if normal.y < 0.0: normal = -normal
	for point: Vector3 in vertices:
		tool.set_uv(uv); tool.set_color(tint.srgb_to_linear()); tool.set_normal(normal); tool.add_vertex(point)

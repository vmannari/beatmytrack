extends RefCounted
## Connected eroded deposits with buried feet; no canonical collision changes.
const OFFSETS: Array[float] = [0.65,0.88,1.12,1.42,1.65,1.85,2.15,2.60,3.10]
const PROFILE: Array[float] = [0.0,0.08,0.30,0.64,0.93,1.0,0.80,0.34,0.0]
const LEAN: Array[float] = [0.0,0.08,0.30,0.68,0.95,1.0,0.80,0.36,0.0]
const CHIP_LIMIT: int = 240
var sites: Dictionary = {}
var count: int = 0
var sections: int = 0
static var erosion: FastNoiseLite = make_noise()

static func make_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 122033
	noise.frequency = 0.32
	noise.fractal_octaves = 2
	return noise

static func crown(anchor: Vector2) -> float:
	var broad: float = erosion.get_noise_2dv(anchor)
	var broken: float = erosion.get_noise_2dv(anchor*3.3+Vector2(7,13))
	var deposit: float = smoothstep(-0.38,-0.08,erosion.get_noise_2dv(anchor*0.55+Vector2(61,29)))
	return clampf(0.30+broad*0.13+broken*0.065,0.13,0.34)*(0.10+deposit*0.90)

static func profile(anchor: Vector2, normal: Vector2) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	var outer: Vector2 = normal.normalized()
	var height: float = crown(anchor)
	var width: float = 1.0+erosion.get_noise_2dv(anchor*0.7+Vector2(31,17))*0.45
	var toe: float = erosion.get_noise_2dv(anchor*1.5+Vector2(11,37))*0.32
	var lean: float = erosion.get_noise_2dv(anchor*1.25+Vector2(19,71))*0.90
	var previous_offset: float = -INF
	for i: int in range(OFFSETS.size()):
		var offset: float = (OFFSETS[i] if i < 2 else 0.80+(OFFSETS[i]-0.80)*width)+toe+lean*LEAN[i]
		offset = maxf(offset,previous_offset+0.05)
		previous_offset = offset
		var worn: float = 1.0+erosion.get_noise_2dv(anchor*4.0+Vector2(i*7,31))*0.10*LEAN[i]
		vertices.append(VisualGeometry.world(anchor+outer*offset)+Vector3.UP*(-0.025+height*PROFILE[i]*worn))
	return vertices

func add_section(tool: SurfaceTool, a: Vector2, b: Vector2, na: Vector2, nb: Vector2, outlines: Array[Dictionary], track: NativeTrack) -> void:
	var p: PackedVector3Array = profile(a,na)
	var q: PackedVector3Array = profile(b,nb)
	for vertex: Vector3 in p+q:
		if not clear(Vector2(vertex.x,-vertex.z),outlines,track): return
	for i: int in range(OFFSETS.size()-1):
		var vertices: Array[Vector3] = [p[i],q[i+1],q[i],p[i],p[i+1],q[i+1]]
		var band: Array[int] = [i,i+1,i,i,i+1,i+1]
		for j: int in range(6):
			var row: PackedVector3Array = p if j in [0,3,4] else q
			var k: int = band[j]
			var left: Vector3 = row[maxi(0,k-1)]
			var right: Vector3 = row[mini(OFFSETS.size()-1,k+1)]
			var slope: float = (right.y-left.y)/maxf(Vector2(right.x-left.x,right.z-left.z).length(),0.001)
			var outward: Vector3 = VisualGeometry.world(na.normalized() if j in [0,3,4] else nb.normalized())
			tool.set_normal(Vector3.UP if k in [0,OFFSETS.size()-1] else (Vector3.UP-outward*slope).normalized())
			tool.set_uv(Vector2(-1.0,float(k)/float(OFFSETS.size()-1)))
			tool.add_vertex(vertices[j])
	sections += 1
	add_chip(tool,(a+b)*0.5,(na+nb).normalized(),outlines,track)

static func clear(point: Vector2, outlines: Array[Dictionary], track: NativeTrack) -> bool:
	if track.cell_at(point) == 0: return false
	for outline: Dictionary in outlines:
		if outline.hole or not outline.bounds.has_point(point): continue
		if Geometry2D.is_point_in_polygon(point,outline.polygon): return false
	return true

func add_chip(tool: SurfaceTool, anchor: Vector2, normal: Vector2, outlines: Array[Dictionary], track: NativeTrack) -> void:
	if count >= CHIP_LIMIT or crown(anchor) < 0.09: return
	var cell := Vector2i(floori(anchor.x/1.1),floori(anchor.y/1.1))
	if sites.has(cell): return
	sites[cell] = true
	var seed_value: int = absi(cell.x*73856093 ^ cell.y*19349663 ^ 12967)
	if seed_value%11 < 9: return
	var tangent: Vector2 = normal.orthogonal()
	var crest: PackedVector3Array = profile(anchor,normal)
	var crest_center: Vector3 = (crest[4]+crest[5])*0.5
	var center: Vector2 = Vector2(crest_center.x,-crest_center.z)+tangent*(float((seed_value>>7)%9)-4.0)*0.028
	var radius: float = 0.065+float((seed_value>>11)%11)*0.008
	var base_height: float = crest_center.y
	var top: Vector3 = VisualGeometry.world(center)+Vector3.UP*minf(0.36,base_height+0.065+radius*0.18)
	for side: int in range(7):
		var angle: float = TAU*side/7.0
		var next: float = TAU*(side+1)/7.0
		var irregular: float = 0.72+float((seed_value+side*37)%17)*0.024
		var p: Vector3 = VisualGeometry.world(center+Vector2.from_angle(angle)*radius*irregular)+Vector3.UP*(base_height-0.028)
		var q: Vector3 = VisualGeometry.world(center+Vector2.from_angle(next)*radius*irregular)+Vector3.UP*(base_height-0.028)
		if not clear(Vector2(p.x,-p.z),outlines,track) or not clear(Vector2(q.x,-q.z),outlines,track): continue
		var face: Vector3 = (q-p).cross(top-p).normalized()
		if face.y < 0.0: face = -face
		for vertex: Vector3 in [p,q,top]:
			tool.set_normal(face)
			tool.set_uv(Vector2(-1.0,0.45))
			tool.add_vertex(vertex)
	count += 1

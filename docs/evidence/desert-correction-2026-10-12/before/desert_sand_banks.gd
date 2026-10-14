extends RefCounted
## Low, non-colliding deposits seeded in world space, independent of road samples.
const LIMIT: int = 600
const SIDES: int = 12
var sites: Dictionary = {}
var count: int = 0

func add(tool: SurfaceTool, edge: Vector2, normal: Vector2, outlines: Array[Dictionary], track: NativeTrack) -> void:
	if count >= LIMIT or normal.length_squared() < 0.01: return
	var cell := Vector2i(floori(edge.x/2.2),floori(edge.y/2.2))
	if sites.has(cell): return
	sites[cell] = true
	var seed_value: int = absi(cell.x*73856093 ^ cell.y*19349663 ^ 9371)
	if seed_value%11 < 4: return
	var outward: Vector2 = normal.normalized()
	var tangent: Vector2 = outward.orthogonal()
	var length: float = 0.85+float((seed_value>>4)%17)*0.10
	var width: float = 0.52+float((seed_value>>9)%13)*0.026
	var center: Vector2 = edge+outward*(width+0.68)+tangent*(float((seed_value>>14)%11)-5.0)*0.045
	var height: float = 0.13+float((seed_value>>19)%13)*0.011
	var vertices: PackedVector3Array = shape(center,tangent,outward,length,width,height,seed_value)
	# Whole footprint must remain outside every visible road polygon, including
	# adjacent pieces and intersections. No colliders or surface-map edits.
	var normals: Dictionary = {}
	for i: int in range(0,vertices.size(),3):
		var normal_face: Vector3 = (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
		if normal_face.y < 0.0: normal_face = -normal_face
		for j: int in range(3): normals[vertices[i+j]] = Vector3(normals.get(vertices[i+j],Vector3.ZERO))+normal_face
	for vertex: Vector3 in normals:
		var point := Vector2(vertex.x,-vertex.z)
		if track.cell_at(point) == 0: return
		for outline: Dictionary in outlines:
			if outline.hole or not outline.bounds.has_point(point): continue
			if Geometry2D.is_point_in_polygon(point,outline.polygon): return
	for vertex: Vector3 in vertices:
		tool.set_normal(Vector3.UP if vertex.y < -0.019 else Vector3(normals[vertex]).normalized())
		tool.set_uv(Vector2(-1.0,1.0 if vertex.y < -0.019 else 0.35))
		tool.add_vertex(vertex)
	count += 1

static func shape(center: Vector2, tangent: Vector2, outward: Vector2, length: float, width: float, height: float, seed_value: int) -> PackedVector3Array:
	var rings: Array[PackedVector3Array] = []
	for band: int in range(3):
		var ring := PackedVector3Array()
		var radius: float = [1.0,0.64,0.26][band]
		for side: int in range(SIDES):
			var angle: float = TAU*float(side)/SIDES
			var irregular: float = 0.73+float((seed_value+side*37)%17)*0.027
			var offset: Vector2 = tangent*cos(angle)*length+outward*sin(angle)*width
			var point: Vector2 = center+offset*radius*irregular-outward*float(band)*0.065
			var erosion: float = 0.70+float((seed_value+side*71+band*19)%13)*0.025
			var y: float = -0.025 if band == 0 else height*([0.0,0.52,0.90][band])*erosion
			ring.append(VisualGeometry.world(point)+Vector3.UP*y)
		rings.append(ring)
	var crown: Vector3 = VisualGeometry.world(center-outward*0.14+tangent*0.09)+Vector3.UP*height
	var result := PackedVector3Array()
	for side: int in range(SIDES):
		var next: int = (side+1)%SIDES
		for band: int in range(2):
			result.append_array(PackedVector3Array([rings[band][side],rings[band][next],rings[band+1][next],rings[band][side],rings[band+1][next],rings[band+1][side]]))
		result.append_array(PackedVector3Array([rings[2][side],rings[2][next],crown]))
	return result

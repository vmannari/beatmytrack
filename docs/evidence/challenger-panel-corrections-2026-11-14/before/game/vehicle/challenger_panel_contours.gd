extends RefCounted
## Flush marking over the native bonnet gap; original exterior stays immutable.
const CONTOUR = preload("res://vehicle/panel_contour.gd")
const OUTLINE = preload("res://assets/vehicles/challenger_hellcat_v1/bonnet_contour.json")
static var meshes: Dictionary = {}

static func mesh(source: ArrayMesh,simple: bool) -> ArrayMesh:
	if meshes.has(source): return meshes[source]
	if meshes.size() >= 4: meshes.clear()
	var base: ArrayMesh = CONTOUR.mesh(source)
	var arrays: Array = base.surface_get_arrays(0)
	var p: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangent: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var first: int = p.size()
	var outline: Array = OUTLINE.data.points
	var count: int = outline.size()
	var tier: String = "simple" if simple else "full"
	var hood: TriangleMesh = (load("res://assets/vehicles/challenger_hellcat_v1/"+tier+"_hood_paint.res") as ArrayMesh).generate_triangle_mesh()
	var body: TriangleMesh = (load("res://assets/vehicles/challenger_hellcat_v1/"+tier+"_body_paint.res") as ArrayMesh).generate_triangle_mesh()
	for i: int in range(count):
		var previous: Array = outline[posmod(i-1,count)]
		var current: Array = outline[i]
		var next: Array = outline[(i+1)%count]
		var direction := Vector3(next[0]-previous[0],next[1]-previous[1],next[2]-previous[2])
		var across: Vector3 = direction.cross(Vector3.UP).normalized()
		var center := Vector3(current[0],current[1],current[2])
		var row: Array[Vector3] = []
		for side: float in [-1.0,1.0]:
			var point: Vector3 = center+across*side*0.00125
			# Border returns and bonnet are separate native skins. Fit to the
			# outer one at each edge, retaining their existing physical join.
			for skin: TriangleMesh in [hood,body]:
				var hit: Dictionary = skin.intersect_ray(point+Vector3.UP*0.03,Vector3.DOWN)
				if not hit.is_empty(): point.y=maxf(point.y,hit.position.y)
			point.y+=0.0018
			row.append(point)
		var half: Vector3 = (row[1]-row[0])*0.5
		for index: int in range(2):
			var side: float = -1.0 if index == 0 else 1.0
			p.append(row[index])
			n.append(Vector3.UP)
			uv.append(Vector2(side,half.length()))
			var t: Vector3 = half.normalized()*side
			tangent.append_array(PackedFloat32Array([t.x,t.y,t.z,1.0]))
		var a: int = first+i*2
		var b: int = first+((i+1)%count)*2
		indices.append_array(PackedInt32Array([a,b+1,a+1,a,b,b+1]))
	arrays[Mesh.ARRAY_VERTEX]=p; arrays[Mesh.ARRAY_NORMAL]=n
	arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_TANGENT]=tangent
	arrays[Mesh.ARRAY_INDEX]=indices
	arrays[Mesh.ARRAY_COLOR]=null; arrays[Mesh.ARRAY_TEX_UV2]=null
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.set_meta("pixel_integrated_contour",true)
	result.set_meta("original_contour_vertices",first)
	result.set_meta("bonnet_segments",count)
	meshes[source]=result
	return result

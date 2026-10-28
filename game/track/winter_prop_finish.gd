extends RefCounted
## Original fitted snow caps and eave ice, baked into the existing opaque draw.
## Existing WinterScenery nature and Winter craft keep their own authored snow.
const KINDS: Array[String] = ["pebbles","cliff","log","barrier","cone","chevron","braking_board","flag","light","gantry","shed","hut"]
const SNOW := Color("e1eaf0")
const SHADE := Color("afc6d8")

static func apply(source: ArrayMesh, kind: String, length: float = -1.0) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i: int in range(colors.size()): colors[i] = colors[i].lerp(SHADE,maxf(0.0,normals[i].y)*0.12)
	arrays[Mesh.ARRAY_COLOR] = colors
	var base := ArrayMesh.new(); base.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	for key: StringName in source.get_meta_list(): base.set_meta(key,source.get_meta(key))
	var snow := SurfaceTool.new(); snow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span: float = length if length >= 0 else 6.0
	match kind:
		"pebbles", "cliff": _stone_caps(snow,source,0.018 if kind == "pebbles" else 0.085,0.025 if kind == "pebbles" else 2.9)
		"log": _sheet(snow,Vector3(0,0.40,0),3.88,0.64,0.07,2)
		"barrier": _sheet(snow,Vector3(0,0.944,0),span,0.37,0.065)
		"cone":
			_sheet(snow,Vector3(0,0.131,0),0.69,0.69,0.025)
			_sheet(snow,Vector3(0,0.881,0),0.10,0.10,0.025)
		"chevron", "braking_board": _sheet(snow,Vector3(0,1.552,0),1.54,0.17,0.06)
		"flag":
			_sheet(snow,Vector3(0,0.141,0),0.31,0.31,0.045)
			_sheet(snow,Vector3(0,3.065,0),0.065,0.065,0.025)
		"light": _sheet(snow,Vector3(0.4,4.937,0),0.92,0.35,0.07)
		"gantry":
			for z: float in [-0.30,0.30]: _sheet(snow,Vector3(0,5.243,z),11.4,0.18,0.065)
			for x: float in [-5.7,5.7]: _sheet(snow,Vector3(x,0.302,0),0.62,1.02,0.065)
		"shed", "hut":
			var width: float = 7.0 if kind == "shed" else 2.5
			var depth: float = 5.0 if kind == "shed" else 2.5
			_sheet(snow,Vector3(0,4.025,0),width+0.32,depth+0.32,0.11,1)
			for side: float in [-1.0,1.0]:
				for i: int in range(1,mini(10,ceili(width))+1):
					var x: float = lerpf(-width*0.46,width*0.46,float(i)/(mini(10,ceili(width))+1))
					var top := Vector3(x,3.10,side*(depth*0.5+0.16))
					PropGeometry.tube(snow,top,top-Vector3.UP*(0.09+0.035*(i%4)),0.026,0.002,Color("b9d2e3"),5)
		"tyre_stack": PropGeometry.ring(snow,Vector3(0,0.607,0),Vector3.UP,0.454,0.245,0.044,SNOW,32)
	snow.generate_normals()
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	PropGeometry.append_mesh(tool,base,Transform3D.IDENTITY)
	PropGeometry.append_mesh(tool,snow.commit(),Transform3D.IDENTITY)
	var result: ArrayMesh = PropGeometry.finish(tool,false)
	result.set_meta("winter_variant",kind)
	result.set_meta("winter_added_vertices",result.surface_get_array_len(0)-source.surface_get_array_len(0))
	return result

static func _point(center: Vector3, x: float, z: float, width: float, depth: float, thickness: float, shape: int) -> Vector3:
	var base: float = center.y
	if shape == 1: base -= absf(z)/(depth*0.5)*0.98
	elif shape == 2: base += sqrt(maxf(0.0,0.373*0.373-z*z))
	var edge: float = maxf(absf(x)/(width*0.5),absf(z)/(depth*0.5))
	var wind: float = 0.91+0.09*sin(x*5.4+z*3.1)
	return center+Vector3(x,base-center.y+thickness*wind*(1.0-0.32*edge*edge),z)

static func _sheet(tool: SurfaceTool, center: Vector3, width: float, depth: float, thickness: float, shape: int = 0) -> void:
	# Five cross-sections give snow a soft crown and fitted sloping edges.
	var count: int = clampi(ceili(width/0.48),2,96)
	for i: int in range(count):
		var x0: float = lerpf(-width*0.5,width*0.5,float(i)/count)
		var x1: float = lerpf(-width*0.5,width*0.5,float(i+1)/count)
		for j: int in range(4):
			var z0: float = lerpf(-depth*0.5,depth*0.5,float(j)/4)
			var z1: float = lerpf(-depth*0.5,depth*0.5,float(j+1)/4)
			var a: Vector3 = _point(center,x0,z0,width,depth,thickness,shape)
			var b: Vector3 = _point(center,x1,z0,width,depth,thickness,shape)
			var c: Vector3 = _point(center,x1,z1,width,depth,thickness,shape)
			var d: Vector3 = _point(center,x0,z1,width,depth,thickness,shape)
			PropGeometry.face(tool,[a,b,c,d],SNOW.darkened(0.018*(i%3)),Vector3.UP)
			if j == 0: _edge(tool,a,b,thickness)
			if j == 3: _edge(tool,c,d,thickness)
			if i == 0: _edge(tool,d,a,thickness)
			if i == count-1: _edge(tool,b,c,thickness)

static func _edge(tool: SurfaceTool, a: Vector3, b: Vector3, thickness: float) -> void:
	PropGeometry.face(tool,[a,b,b-Vector3.UP*thickness,a-Vector3.UP*thickness],SHADE)

static func _stone_caps(tool: SurfaceTool, source: ArrayMesh, thickness: float, minimum: float) -> void:
	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var edges: Dictionary = {}
	# These source models are unindexed; each cap remains on its original facet.
	for i: int in range(0,vertices.size(),3):
		var normal: Vector3 = (normals[i]+normals[i+1]+normals[i+2])/3.0
		var center: Vector3 = (vertices[i]+vertices[i+1]+vertices[i+2])/3.0
		if normal.y < 0.45 or center.y < minimum: continue
		var points: Array[Vector3] = []
		for j: int in range(3): points.append(vertices[i+j]+Vector3.UP*thickness)
		PropGeometry.face(tool,points,SNOW.darkened(0.016*(i%3)),Vector3.UP)
		for j: int in range(3):
			var edge: Array = [points[j],points[(j+1)%3]]
			var reverse: Array = [edge[1],edge[0]]
			if edges.has(reverse): edges.erase(reverse)
			else: edges[edge] = true
	# Only the exposed rim needs thickness; internal facet edges share the cap.
	for edge: Array in edges: _edge(tool,edge[0],edge[1],thickness)

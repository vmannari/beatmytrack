class_name CompactHoodKits
extends RefCounted
## Pressed replacement panels with genuine recesses and modest blended intakes.

static func build(root: Node3D, kind: String, paint: Material, accent: Material) -> void:
	var key: String = "hood6/"+kind+"/"
	var dark: Material = CompactFinish.rubber(Color("171e21"))
	var holes: Array[Rect2] = []
	match kind:
		"louvres": holes = [Rect2(0.15,0.29,0.18,0.44),Rect2(0.67,0.29,0.18,0.44)]
		"scoop": holes = [Rect2(0.36,0.30,0.28,0.44)]
		"extractor": holes = [Rect2(0.30,0.30,0.40,0.40)]
		"cowl": holes = [Rect2(0.34,0.855,0.32,0.043)]
		"twin_scoop": holes = [Rect2(0.17,0.33,0.21,0.39),Rect2(0.62,0.33,0.21,0.39)]
		"reverse": holes = [Rect2(0.33,0.29,0.34,0.44)]
		"vented": holes = [Rect2(0.13,0.34,0.15,0.35),Rect2(0.72,0.34,0.15,0.35)]
	var sheet: MeshInstance3D = CompactKits._patch(root,key+"sheet",func(u: float,v: float) -> Vector3: return CompactKits.hood_sample(kind,u,v),paint,Vector3.UP,88,32,false,holes)
	for index: int in range(holes.size()):
		var hole: Rect2 = holes[index]
		var prefix: String = key+"opening"+str(index)+"/"
		_recess(root,prefix,kind,hole,dark)
		if kind in ["louvres","extractor","vented"]:
			_louvres(root,prefix,kind,hole,paint)
		elif kind=="cowl":
			for bar: int in range(9):
				var u: float = lerpf(hole.position.x+0.012,hole.end.x-0.012,bar/8.0)
				CompactKitSurface.solid(root,prefix+"grille"+str(bar),func(t: float,v: float) -> Vector3:
					var p: Vector3 = CompactKits.hood_sample(kind,u,lerpf(hole.position.y,hole.end.y,t))
					return p+Vector3(cos(v*TAU)*0.002,0.001+sin(v*TAU)*0.002,0),paint,4,8)
		else: _scoop(root,prefix,kind,hole,paint,dark)
	if kind in ["dome","vented"]:
		# A narrow fitted crown insert, with tapered ends rather than a rectangle
		# laid over the whole hood; the owner's accent pigment remains independent.
		_crown_insert(root,key+"crowninsert",sheet.mesh as ArrayMesh,accent)
	for side: float in [-1,1]:
		CompactKitSurface.solid(root,key+"panelgap"+str(side),func(u: float,v: float) -> Vector3:
			return CompactKits.hood_sample(kind,0.5+side*0.494,u)+Vector3(cos(v*TAU)*0.0015,0.0008+sin(v*TAU)*0.0015,0),dark,32,8)

static func _crown_insert(root: Node3D, key: String, sheet: ArrayMesh, accent: Material) -> void:
	if CompactKits.simple_parts: key += "/simple"
	CompactKits._load_prepared(key)
	if not CompactKits.meshes.has(key):
		# Clip the existing tapered outline against the final hood triangles.
		# Every resulting face stays parallel to its supporting sheet face, even
		# when the simple hood uses a coarser grid than the accent outline.
		var outline := PackedVector2Array()
		for side: float in [-1,1]:
			for index: int in range(25):
				var v: float = index/24.0 if side<0 else 1-index/24.0
				var span: float = 0.16*(0.25+0.75*smoothstep(0,0.15,v)*(1-smoothstep(0.85,1,v)))
				outline.append(Vector2(0.5+side*span*0.5,lerpf(0.24,0.78,v)))
		var arrays: Array = sheet.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index: int in range(0,indices.size(),3):
			var a: int = indices[index]
			var b: int = indices[index+1]
			var c: int = indices[index+2]
			var triangle := PackedVector2Array([uvs[a],uvs[b],uvs[c]])
			var bounds := Rect2(triangle[0],Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
			if not bounds.intersects(Rect2(0.42,0.24,0.16,0.54),true): continue
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(triangle,outline):
				var faces: PackedInt32Array = Geometry2D.triangulate_polygon(clipped)
				for face: int in range(0,faces.size(),3):
					var points: Array[Vector3] = []
					var shades: Array[Vector3] = []
					var mapping: Array[Vector2] = []
					for corner: int in range(3):
						var uv: Vector2 = clipped[faces[face+corner]]
						var denom: float = (uvs[b]-uvs[a]).cross(uvs[c]-uvs[a])
						var wb: float = (uv-uvs[a]).cross(uvs[c]-uvs[a])/denom
						var wc: float = (uvs[b]-uvs[a]).cross(uv-uvs[a])/denom
						var wa: float = 1-wb-wc
						points.append(vertices[a]*wa+vertices[b]*wb+vertices[c]*wc+Vector3.UP*0.0012)
						shades.append((normals[a]*wa+normals[b]*wb+normals[c]*wc).normalized())
						mapping.append(uv)
					var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0])
					if normal.length_squared()<1e-20: continue
					var order: Array = [0,2,1] if normal.y>0 else [0,1,2]
					for corner: int in order:
						tool.set_normal(shades[corner])
						tool.set_uv(mapping[corner])
						tool.add_vertex(points[corner])
		tool.index()
		tool.generate_tangents()
		CompactKits.meshes[key] = tool.commit()
	CompactAero._attach(root,key,accent)

static func _recess(root: Node3D, key: String, kind: String, hole: Rect2, dark: Material) -> void:
	var corners: Array[Vector2] = [hole.position,Vector2(hole.end.x,hole.position.y),hole.end,Vector2(hole.position.x,hole.end.y)]
	for edge: int in range(4):
		var a: Vector2 = corners[edge]
		var b: Vector2 = corners[(edge+1)%4]
		var hint: Vector3 = CompactKits.hood_sample(kind,hole.get_center().x,hole.get_center().y)-CompactKits.hood_sample(kind,(a.x+b.x)*0.5,(a.y+b.y)*0.5)
		CompactKits._patch(root,key+"wall"+str(edge),func(u: float,v: float) -> Vector3:
			var t: Vector2 = a.lerp(b,u)
			return CompactKits.hood_sample(kind,t.x,t.y)-Vector3.UP*v*0.031,dark,Vector3(hint.x,0,hint.z),16,2)
	CompactKits._patch(root,key+"recess",func(u: float,v: float) -> Vector3:
		var t: Vector2 = hole.position+hole.size*Vector2(u,v)
		return CompactKits.hood_sample(kind,t.x,t.y)-Vector3.UP*0.032,dark,Vector3.UP,16,8)

static func _louvres(root: Node3D, key: String, kind: String, hole: Rect2, paint: Material) -> void:
	var count: int = 6 if kind=="louvres" else 4 if kind=="extractor" else 4
	var pitch: float = hole.size.y/count
	var rise: float = 0.015 if kind!="extractor" else 0.022
	for index: int in range(count):
		var start: float = hole.position.y+0.008+index*pitch
		var section: Array[Vector2] = [Vector2(0,0.002),Vector2(pitch*0.70,rise),Vector2(pitch*0.74,rise-0.003),Vector2(0,-0.001)]
		CompactKitSurface.solid(root,key+"louvre"+str(index),func(u: float,v: float) -> Vector3:
			var q: Vector2 = CompactKitSurface.contour(section,v,0.0015)
			var x: float = lerpf(hole.position.x-0.004,hole.end.x+0.004,u)
			var p: Vector3 = CompactKits.hood_sample(kind,x,start+q.x)
			p.y += q.y*(0.18+0.82*sin(u*PI))
			return p,paint,18,16)

static func _scoop(root: Node3D, key: String, kind: String, hole: Rect2, paint: Material, dark: Material) -> void:
	var reverse: bool = kind=="reverse"
	var rise: float = 0.054 if kind=="twin_scoop" else 0.069 if kind=="scoop" else 0.060
	var mouth: float = 1.0 if reverse else 0.0
	var crown: Callable = func(u: float,v: float) -> Vector3:
		var along: float = 1-v if reverse else v
		var x: float = hole.position.x+hole.size.x*u
		var y: float = hole.position.y+hole.size.y*v
		var p: Vector3 = CompactKits.hood_sample(kind,x,y)
		p.y += rise*(0.78+0.22*sin(u*PI))*(1-smoothstep(0.04,1,along))
		return p
	CompactKits._patch(root,key+"crown",crown,paint,Vector3.UP,28,20)
	for side: float in [0.0,1.0]:
		CompactKitSurface.panel(root,key+"blendedcheek"+str(side),func(u: float,v: float) -> Vector3:
			var edge: float = hole.position.x+side*hole.size.x
			var y: float = hole.position.y+u*hole.size.y
			var top: Vector3 = crown.call(side,u)
			var height: float = top.y-CompactKits.hood_sample(kind,edge,y).y
			var x: float = edge+(v-1)*(0.013 if side==0 else -0.013)*height/rise
			return CompactKits.hood_sample(kind,x,y)+Vector3.UP*height*v,paint,Vector3(-1 if side==0 else 1,0,0),24,8)
	# Dark intake is recessed behind the rolled mouth; it reads as a cavity.
	CompactKits._patch(root,key+"intake",func(u: float,v: float) -> Vector3:
		var top: Vector3 = crown.call(u,mouth)
		var base: Vector3 = CompactKits.hood_sample(kind,hole.position.x+hole.size.x*u,hole.position.y+mouth*hole.size.y)-Vector3.UP*0.006
		return base.lerp(top,v)+Vector3(0,0,-0.018 if reverse else 0.018),dark,Vector3.BACK if reverse else Vector3.FORWARD,24,6)
	CompactKitSurface.solid(root,key+"mouthreturn",func(u: float,v: float) -> Vector3:
		return (crown.call(u,mouth) as Vector3)+Vector3(0,cos(v*TAU)*0.003,sin(v*TAU)*0.006),paint,28,12)
	# One horizontal grille rail keeps the mouth open and restrained.
	CompactKitSurface.solid(root,key+"intakerail",func(u: float,v: float) -> Vector3:
		var p: Vector3 = crown.call(u,mouth)
		p.y -= rise*0.48
		return p+Vector3(0,cos(v*TAU)*0.0018,(0.006 if reverse else -0.006)+sin(v*TAU)*0.0018),paint,24,8)

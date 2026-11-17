extends RefCounted
## Generic sampled mesh builder for the new reference-based Electric car.
const ASSET_ROOT := "res://assets/vehicles/electric_rear_lamp_gaps_v1"
static var meshes: Dictionary = {}
static var use_baked: bool = true

static func normal_at(sample: Callable,u: float,v: float,hint: Vector3) -> Vector3:
	var du: Vector3=sample.call(minf(1,u+0.001),v)-sample.call(maxf(0,u-0.001),v)
	var dv: Vector3=sample.call(u,minf(1,v+0.001))-sample.call(u,maxf(0,v-0.001))
	var n: Vector3=du.cross(dv).normalized()
	return -n if n.dot(hint)<0 else n

static func patch(parent: Node3D,label: String,columns: int,rows: int,sample: Callable,material: Material,hint: Vector3,simple: bool=false,_normal_at: Callable=Callable(),_normal_uv: Callable=Callable()) -> void:
	var key: String=label+("_simple" if simple else "")
	var path: String=ASSET_ROOT.path_join(key.sha256_text().left(24)+".res")
	if use_baked and not meshes.has(key) and ResourceLoader.exists(path): meshes[key]=load(path) as ArrayMesh
	if not meshes.has(key):
		if simple:
			columns=maxi(4,columns/2)
			rows=maxi(2,rows/2)
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(rows):
			for column: int in range(columns):
				var uv: Array[Vector2]=[Vector2(float(column)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row+1)/rows),Vector2(float(column)/columns,float(row+1)/rows)]
				var p: Array[Vector3]=[]
				for q: Vector2 in uv: p.append(sample.call(q.x,q.y))
				for triangle: Array in [[0,1,2],[0,2,3]]:
					var face: Vector3=(p[triangle[1]]-p[triangle[0]]).cross(p[triangle[2]]-p[triangle[0]])
					if face.length_squared()<1e-18: continue
					var order: Array=triangle.duplicate()
					var facing: Vector3=_normal_uv.call((uv[0].x+uv[2].x)*0.5,(uv[0].y+uv[2].y)*0.5) if _normal_uv.is_valid() else hint
					if face.dot(facing)>0: order.reverse()
					for index: int in order:
						var t: Vector2=uv[index]
						var n: Vector3=_normal_uv.call(t.x,t.y) if _normal_uv.is_valid() else _normal_at.call(p[index]) if _normal_at.is_valid() else normal_at(sample,t.x,t.y,hint)
						tool.set_normal(n)
						tool.set_uv(t)
						tool.add_vertex(p[index])
		tool.index()
		tool.generate_tangents()
		meshes[key]=tool.commit()
	var node:=MeshInstance3D.new()
	node.name=label
	node.mesh=meshes[key]
	node.material_override=material
	parent.add_child(node)

static func ribbon(parent: Node3D,label: String,sample: Callable,count: int,radius: float,material: Material,simple: bool=false) -> void:
	patch(parent,label,count,6,func(u: float,v: float) -> Vector3:
		var p: Vector3=sample.call(u)
		var tangent: Vector3=(sample.call(minf(1,u+0.0001))-sample.call(maxf(0,u-0.0001))).normalized()
		var n: Vector3=tangent.cross(Vector3.UP).normalized()
		if n.length_squared()<0.1: n=Vector3.RIGHT
		var b: Vector3=tangent.cross(n).normalized()
		return p+radius*(n*cos(v*TAU)+b*sin(v*TAU)),material,Vector3.UP,simple,Callable(),func(u: float,v: float)->Vector3:
		var tangent: Vector3=(sample.call(minf(1,u+0.0001))-sample.call(maxf(0,u-0.0001))).normalized()
		var n: Vector3=tangent.cross(Vector3.UP).normalized()
		if n.length_squared()<0.1: n=Vector3.RIGHT
		return n*cos(v*TAU)+tangent.cross(n).normalized()*sin(v*TAU))

static func fitted_line(parent: Node3D,label: String,skin: MeshInstance3D,sample: Callable,count: int,width: float,material: Material,outward: Vector3,simple: bool) -> void:
	# Thin flush strips follow the triangles actually rendered, including the
	# lower-density exterior. An analytical offset can sink below those chords.
	var key: String = label+"_fitted_v2"+("_simple" if simple else "")
	var path: String = ASSET_ROOT.path_join(key.sha256_text().left(24)+".res")
	if use_baked and not meshes.has(key) and ResourceLoader.exists(path): meshes[key] = load(path)
	if not meshes.has(key):
		assert(skin!=null and skin.mesh!=null,"Contour requires its actual exterior backing")
		var tree: TriangleMesh = skin.mesh.generate_triangle_mesh()
		var stations: Array = []
		for index: int in range(count+1):
			var t: float = index/float(count)
			stations.append({"t":t,"row":_fitted_station(tree,sample,t,width,outward)})
		# The two ends can lie above a panel while their joining chord crosses
		# a crease. Refine only those intervals, keeping the same flush offset.
		for pass_index: int in range(8):
			var refined: Array = []
			var changed: bool = false
			for index: int in range(stations.size()-1):
				refined.append(stations[index])
				if _fitted_chord_clear(tree,stations[index].row,stations[index+1].row,outward): continue
				var t: float = (float(stations[index].t)+float(stations[index+1].t))*0.5
				refined.append({"t":t,"row":_fitted_station(tree,sample,t,width,outward)})
				changed = true
			refined.append(stations[-1])
			stations = refined
			if not changed: break
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index: int in range(stations.size()-1):
			var a: Array = stations[index].row; var b: Array = stations[index+1].row
			if null in a or null in b: continue
			var points: Array = [a[0],a[1],b[1],b[0]]
			for triangle: Array in [[0,1,2],[0,2,3]]:
				var cross: Vector3 = (points[triangle[1]]-points[triangle[0]]).cross(points[triangle[2]]-points[triangle[0]])
				if cross.length_squared()<1e-20: continue
				var order: Array = triangle.duplicate()
				if cross.dot(outward)>0: order.reverse()
				for corner: int in order:
					var other: int = [1,0,3,2][corner]
					var half: Vector3 = (points[corner]-points[other])*0.5
					tool.set_normal(outward)
					tool.set_uv(Vector2(-1.0 if corner in [0,3] else 1.0,half.length()))
					tool.set_tangent(Plane(half.normalized(),1.0))
					tool.add_vertex(points[corner])
		tool.index()
		meshes[key] = tool.commit()
		meshes[key].set_meta("pixel_integrated_contour",true)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = meshes[key]
	node.material_override = preload("res://vehicle/panel_contour.gd").material(material)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

static func _fitted_station(tree: TriangleMesh,sample: Callable,t: float,width: float,outward: Vector3) -> Array:
	var center: Vector3 = sample.call(t)
	var tangent: Vector3 = sample.call(minf(1,t+0.0001))-sample.call(maxf(0,t-0.0001))
	var across: Vector3 = tangent.cross(outward).normalized()*width*0.5
	var row: Array = []
	for edge: float in [-1.0,1.0]:
		var hit: Dictionary = tree.intersect_ray(center+across*edge+outward*0.20,-outward)
		row.append(hit.position+outward*0.0008 if not hit.is_empty() else null)
	return row

static func _fitted_chord_clear(tree: TriangleMesh,a: Array,b: Array,outward: Vector3) -> bool:
	if null in a or null in b: return true
	for along: float in [0.25,0.5,0.75]:
		for across: float in [0.0,0.5,1.0]:
			var p: Vector3 = (a[0] as Vector3).lerp(a[1],across).lerp((b[0] as Vector3).lerp(b[1],across),along)
			var hit: Dictionary = tree.intersect_ray(p+outward*0.10,-outward)
			if not hit.is_empty():
				var exposure: float = (p-hit.position).dot(outward)
				if exposure < 0.00035 or exposure > 0.0015: return false
	return true

static func _clip_patch_polygon(points: Array, a: Vector2, b: Vector2) -> Array:
	var result: Array = []
	if points.is_empty(): return result
	var previous: Dictionary = points[-1]
	var previous_distance: float = (b - a).cross(previous.uv - a)
	for current: Dictionary in points:
		var distance: float = (b - a).cross(current.uv - a)
		if (distance >= 0.0) != (previous_distance >= 0.0):
			var weight: float = previous_distance / (previous_distance - distance)
			result.append({"uv": previous.uv.lerp(current.uv, weight), "point": previous.point.lerp(current.point, weight), "normal": previous.normal.lerp(current.normal, weight).normalized()})
		if distance >= 0.0: result.append(current)
		previous = current
		previous_distance = distance
	return result

static func fitted_patch(parent: Node3D, label: String, skin: MeshInstance3D, outline: Array[Vector2], material: Material, outward: Vector3, simple: bool) -> void:
	# Clip the existing backing triangles in their UV chart. Every overlay
	# triangle shares its plane with the metal beneath it, including at creases.
	skin.mesh.set_meta("car_keep_master", true)
	skin.mesh.set_meta("car_authored_far", true)
	skin.mesh.set_meta("car_surface_guide_locked", true)
	var key: String = label + ("_simple" if simple else "")
	if not meshes.has(key):
		var arrays: Array = skin.mesh.surface_get_arrays(0)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for at: int in range(0, indices.size(), 3):
			var polygon: Array = []
			for corner: int in range(3):
				var index: int = indices[at + corner]
				polygon.append({"uv": uv[index], "point": positions[index], "normal": normals[index]})
			for edge: int in range(outline.size()):
				polygon = _clip_patch_polygon(polygon, outline[edge], outline[(edge + 1) % outline.size()])
			for triangle: int in range(1, polygon.size() - 1):
				var a: Vector3 = polygon[0].point
				var b: Vector3 = polygon[triangle].point
				var c: Vector3 = polygon[triangle + 1].point
				if (b-a).cross(c-a).length_squared() < 0.000000000000000001: continue
				for corner: int in [0, triangle, triangle + 1]:
					var vertex: Dictionary = polygon[corner]
					tool.set_uv(vertex.uv)
					tool.set_normal(vertex.normal)
					tool.add_vertex(vertex.point + outward * 0.0008)
		tool.index()
		tool.generate_tangents()
		var mesh: ArrayMesh = tool.commit()
		mesh.set_meta("car_keep_master", true)
		mesh.set_meta("car_authored_far", true)
		mesh.set_meta("car_surface_guide_locked", true)
		meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = meshes[key]
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

static func rounded(parent: Node3D,label: String,size: Vector3,center: Vector3,radius: float,material: Material) -> void:
	var half: Vector3=size*0.5
	var r: float=minf(radius,minf(half.x,minf(half.y,half.z))*0.95)
	for n: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		patch(parent,label+str(n)+str(center),6,4,func(u: float,v: float) -> Vector3:
			var p:=Vector3(n.x,2*u-1,2*v-1) if n.x!=0 else Vector3(2*u-1,n.y,2*v-1) if n.y!=0 else Vector3(2*u-1,2*v-1,n.z)
			p*=half
			var q: Vector3=p.clamp(-half+Vector3.ONE*r,half-Vector3.ONE*r)
			return center+q+(p-q).normalized()*r,material,n)


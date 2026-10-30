extends RefCounted
## Generic sampled mesh builder for the new reference-based Electric car.
const ASSET_ROOT := "res://assets/vehicles/electric_reference_straight_sides_v1"
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

static func rounded(parent: Node3D,label: String,size: Vector3,center: Vector3,radius: float,material: Material) -> void:
	var half: Vector3=size*0.5
	var r: float=minf(radius,minf(half.x,minf(half.y,half.z))*0.95)
	for n: Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		patch(parent,label+str(n)+str(center),6,4,func(u: float,v: float) -> Vector3:
			var p:=Vector3(n.x,2*u-1,2*v-1) if n.x!=0 else Vector3(2*u-1,n.y,2*v-1) if n.y!=0 else Vector3(2*u-1,2*v-1,n.z)
			p*=half
			var q: Vector3=p.clamp(-half+Vector3.ONE*r,half-Vector3.ONE*r)
			return center+q+(p-q).normalized()*r,material,n)


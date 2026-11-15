extends RefCounted
## VSR01: common paint normal fields, sampled independently of patch UV charts.
const B=preload("res://vehicle/electric_reference_body.gd")
const C=preload("res://vehicle/electric_reference_cabin.gd")
const M=preload("res://vehicle/electric_reference_mesh.gd")

static func side_normal(p: Vector3) -> Vector3:
	var side: float=signf(p.x)
	var z: float=p.z
	for iteration: int in range(8): z+=p.z-B.flank_point(side,z,p.y).z
	var h: float=0.0001
	var a: Vector3=B.flank_point(side,z+h,p.y)-B.flank_point(side,z-h,p.y)
	var b: Vector3=B.flank_point(side,z,p.y+h)-B.flank_point(side,z,p.y-h)
	var n: Vector3=a.cross(b).normalized()
	return n if n.x*side>0 else -n

static func cabin_normal(side: float,t: float,v: float) -> Vector3:
	var sample: Callable=func(u: float,w: float)->Vector3:return C.side_point(side,u,w)
	var n: Vector3=M.normal_at(sample,t,v,Vector3(side,0.2,0))
	var edge: Vector3=C.side_point(side,t,0)
	return side_normal(edge).slerp(n,smoothstep(0.0,0.22,v)).normalized()

static func repaired(source: ArrayMesh,label: String) -> ArrayMesh:
	var a: Array=source.surface_get_arrays(0)
	var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
	for at: int in range(points.size()):
		var p: Vector3=points[at];var q: Vector2=uv[at];var n: Vector3=normals[at]
		var side: float=signf(p.x)
		if label.begins_with("ReferenceSide"): n=side_normal(p)
		elif label.begins_with("ReferenceArch"):
			var axle: float=-B.AXLE if "-1_397" in label else B.AXLE
			var sample: Callable=func(u: float,v: float)->Vector3:return B.fender_point(side,axle,u,v)
			var native: Vector3=M.normal_at(sample,q.x,q.y,Vector3(side,0,0))
			n=side_normal(p).slerp(native,smoothstep(0.0,0.8,q.y)).normalized()
		elif label.begins_with("ReferenceWindowBottom"):n=cabin_normal(side,q.x,q.y*0.075)
		elif label.begins_with("ReferenceAPillar"):
			var v: float=lerpf(0.075,0.945,q.y)
			n=cabin_normal(side,lerpf(0.0,C.glass_start(v),q.x),v)
		elif label.begins_with("ReferenceRearQuarterPanel") or label.begins_with("ReferenceRearPillar"):
			var v: float=lerpf(0.075,0.945,q.y)
			var t: float=lerpf(C.c_center(v)+0.008,C.glass_end(v),q.x) if label.begins_with("ReferenceRearQuarterPanel") else lerpf(C.glass_end(v),1.0,q.x)
			n=cabin_normal(side,t,v)
		normals[at]=n
	a[Mesh.ARRAY_NORMAL]=normals
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	result.custom_aabb=source.get_aabb()
	for key: StringName in source.get_meta_list():result.set_meta(key,source.get_meta(key))
	return result

extends RefCounted
## VRC01: retain the rendered door region; restore native rear skin locally.
const CUT: float=1.20
const END: float=1.42
const EPS: float=0.0000005

static func records(mesh: Mesh, old: bool) -> Array:
	var a: Array=mesh.surface_get_arrays(0);var result: Array=[]
	for at: int in range(a[Mesh.ARRAY_VERTEX].size()):
		var t: PackedFloat32Array=a[Mesh.ARRAY_TANGENT]
		result.append({"p":a[Mesh.ARRAY_VERTEX][at],"n":a[Mesh.ARRAY_NORMAL][at],"uv":a[Mesh.ARRAY_TEX_UV][at],"t":Vector4(t[at*4],t[at*4+1],t[at*4+2],t[at*4+3]),"old":at if old else -1})
	return result

static func mix_record(a: Dictionary,b: Dictionary,weight: float) -> Dictionary:
	var tangent: Vector4=a.t.lerp(b.t,weight)
	var axis:=Vector3(tangent.x,tangent.y,tangent.z).normalized()
	return {"p":a.p.lerp(b.p,weight),"n":a.n.lerp(b.n,weight).normalized(),"uv":a.uv.lerp(b.uv,weight),"t":Vector4(axis.x,axis.y,axis.z,a.t.w),"old":-1}

static func clip(poly: Array, rear: bool, plane: float=CUT) -> Array:
	var result: Array=[]
	for at: int in range(poly.size()):
		var a: Dictionary=poly[at];var b: Dictionary=poly[(at+1)%poly.size()]
		var inside: bool=a.p.z>=plane-EPS if rear else a.p.z<=plane+EPS
		var next_inside: bool=b.p.z>=plane-EPS if rear else b.p.z<=plane+EPS
		if inside:result.append(a)
		if inside!=next_inside:
			var r: Dictionary=mix_record(a,b,(plane-a.p.z)/(b.p.z-a.p.z));r.p.z=plane;result.append(r)
	return result

static func triangles(mesh: Mesh, verts: Array, rear: bool) -> Array:
	var indices: PackedInt32Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX];var polys: Array=[]
	for at: int in range(0,indices.size(),3):
		var poly: Array=clip([verts[indices[at]],verts[indices[at+1]],verts[indices[at+2]]],rear)
		if poly.size()>=3:polys.append(poly)
	return polys

static func profile(polys: Array) -> Array:
	var points: Array=[]
	for poly: Array in polys:
		for r: Dictionary in poly:
			if absf(r.p.z-CUT)<EPS:points.append(r)
	points.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.p.y<b.p.y)
	var result: Array=[]
	for r: Dictionary in points:
		if result.is_empty() or absf(r.p.y-result[-1].p.y)>EPS:result.append(r)
	assert(result.size()>=2)
	var low: float=result[0].p.y;var span: float=result[-1].p.y-low
	for r: Dictionary in result:r["v"]=(r.p.y-low)/span
	return result

static func at_profile(rows: Array,v: float) -> Dictionary:
	for at: int in range(rows.size()-1):
		if v<=rows[at+1].v+EPS:
			return mix_record(rows[at],rows[at+1],clampf((v-rows[at].v)/(rows[at+1].v-rows[at].v),0,1))
	return rows[-1].duplicate()

static func refine_edge(poly: Array, rows: Array, common: Array) -> Array:
	var result: Array=[];var low: float=rows[0].p.y;var span: float=rows[-1].p.y-low
	for at: int in range(poly.size()):
		var a: Dictionary=poly[at];var b: Dictionary=poly[(at+1)%poly.size()];result.append(a)
		if absf(a.p.z-CUT)>EPS or absf(b.p.z-CUT)>EPS:continue
		var va: float=(a.p.y-low)/span;var vb: float=(b.p.y-low)/span
		var stations: Array=common.duplicate()
		if va>vb:stations.reverse()
		for v: float in stations:
			if v>minf(va,vb)+EPS and v<maxf(va,vb)-EPS:result.append(at_profile(rows,v))
	return result

static func side(current: ArrayMesh,native: ArrayMesh) -> ArrayMesh:
	var original: Array=records(current,true);var dense: Array=records(native,false)
	var leading: Array=triangles(current,original,false);var rear: Array=[]
	for polygon: Array in triangles(native,dense,true):
		var low: float=INF;var high: float=-INF
		for r: Dictionary in polygon:low=minf(low,r.p.z);high=maxf(high,r.p.z)
		if low<END-EPS and high>END+EPS:
			rear.append(clip(polygon,false,END));rear.append(clip(polygon,true,END))
		else:rear.append(polygon)
	var left: Array=profile(leading);var right: Array=profile(rear);var common: Array=[]
	for r: Dictionary in left+right:
		var found: bool=false
		for v: float in common:
			if absf(v-r.v)<EPS:found=true;break
		if not found:common.append(r.v)
	common.sort()
	var extra: Array=[];var mapped:=PackedInt32Array()
	for section: int in range(2):
		for polygon: Array in (leading if section==0 else rear):
			var poly: Array=refine_edge(polygon,left if section==0 else right,common)
			if section==1:
				for at: int in range(poly.size()):
					var r: Dictionary=poly[at].duplicate();var weight: float=1.0-smoothstep(CUT,END,r.p.z)
					if weight>0:
						var v: float=clampf((r.p.y-right[0].p.y)/(right[-1].p.y-right[0].p.y),0,1)
						var was: Dictionary=at_profile(right,v);var now: Dictionary=at_profile(left,v)
						r.p+=(now.p-was.p)*weight;r.n=r.n.slerp(now.n,weight).normalized();r.uv+=(now.uv-was.uv)*weight
					poly[at]=r
				# Native positions/fields behind END are copied without fitting.
			var pivot: int=0
			for at: int in range(1,poly.size()):
				if absf(poly[at].p.z-CUT)>absf(poly[pivot].p.z-CUT):pivot=at
			var rotated: Array=poly.slice(pivot)+poly.slice(0,pivot)
			for at: int in range(1,rotated.size()-1):
				var tri: Array=[rotated[0],rotated[at],rotated[at+1]]
				if (tri[1].p-tri[0].p).cross(tri[2].p-tri[0].p).length_squared()<1e-18:continue
				for r: Dictionary in tri:
					if r.old>=0:mapped.append(r.old)
					else:mapped.append(original.size()+extra.size());extra.append(r)
	var a: Array=[];a.resize(Mesh.ARRAY_MAX)
	var points:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var tangent:=PackedFloat32Array()
	for r: Dictionary in extra:
		points.append(r.p);normals.append(r.n);uv.append(r.uv);tangent.append_array(PackedFloat32Array([r.t.x,r.t.y,r.t.z,r.t.w]))
	a[Mesh.ARRAY_VERTEX]=points;a[Mesh.ARRAY_NORMAL]=normals;a[Mesh.ARRAY_TEX_UV]=uv;a[Mesh.ARRAY_TANGENT]=tangent
	var added:=ArrayMesh.new();added.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	var old: Dictionary=RenderingServer.mesh_get_surface(current.get_rid(),0).duplicate(true)
	var fresh: Dictionary=RenderingServer.mesh_get_surface(added.get_rid(),0)
	assert((int(old.format)&~Mesh.ARRAY_FORMAT_INDEX)==(int(fresh.format)&~Mesh.ARRAY_FORMAT_INDEX),"Matching encoded field formats")
	var ps: int=RenderingServer.mesh_surface_get_format_vertex_stride(old.format,old.vertex_count)
	var ns: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(old.format,old.vertex_count)
	var positions: PackedByteArray=old.vertex_data.slice(0,int(old.vertex_count)*ps)
	positions.append_array(fresh.vertex_data.slice(0,int(fresh.vertex_count)*ps))
	positions.append_array(old.vertex_data.slice(int(old.vertex_count)*ps))
	positions.append_array(fresh.vertex_data.slice(int(fresh.vertex_count)*ps))
	old.vertex_data=positions;old.attribute_data.append_array(fresh.attribute_data)
	old.vertex_count=int(old.vertex_count)+int(fresh.vertex_count)
	var stride: int=2 if old.vertex_count<=65536 else 4;var indices:=PackedByteArray();indices.resize(mapped.size()*stride)
	for at: int in range(mapped.size()):
		if stride==2:indices.encode_u16(at*stride,mapped[at])
		else:indices.encode_u32(at*stride,mapped[at])
	old.index_data=indices;old.index_count=mapped.size();old.format=int(old.format)|Mesh.ARRAY_FORMAT_INDEX;old.erase("lods")
	var result:=ArrayMesh.new();result.set("_surfaces",[old]);result.custom_aabb=current.get_aabb()
	result=preload("res://tests/support/car_static_reduction_bake.gd").new().compact(result)
	for property: StringName in current.get_meta_list():result.set_meta(property,current.get_meta(property))
	result.set_meta("volt_rear_restore_cut",CUT);result.set_meta("volt_rear_restore_end",END)
	return result

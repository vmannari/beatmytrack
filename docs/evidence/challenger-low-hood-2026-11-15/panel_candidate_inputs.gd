extends SceneTree
## Verify actual flush backing and pixel coverage attributes at both detail tiers.
const CONTOUR = preload("res://vehicle/panel_contour.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://vehicle/electric_reference_mesh.gd").use_baked=false
	for reduced: bool in [false,true]:
		for id: String in ["electric","super_rally"]:
			var car:=CarVisual.new()
			car.vehicle_id=id;car.simple_model=reduced;car.batch_parts=false
			root.add_child(car)
			while not car.model_ready:await process_frame
			var marked: int=0
			for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
				var material: Material=part.material_override
				if not material is ShaderMaterial or material.shader!=CONTOUR.SHADER:continue
				marked+=1
				var label: String=id+" "+str(part.name)+" reduced="+str(reduced)
				check(part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,label+" markings do not cast artificial shadows")
				var arrays: Array=part.mesh.surface_get_arrays(0)
				var p: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
				var tangent: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
				check(uv.size()==p.size() and tangent.size()==p.size()*4,label+" every contour vertex has coverage data")
				var valid: bool=true
				for i: int in range(p.size()):
					valid=valid and absf(uv[i].x)==1.0 and uv[i].y>0.0 and uv[i].y<0.006
				check(valid,label+" physical ribbon width stays below12mm with paired sides")
				if id=="super_rally":
					var source: ArrayMesh=load("res://../build/challenger-low-hood-2026-11-15/native/"+("simple" if reduced else "full")+"_body_contour.res")
					var original: Array=source.surface_get_arrays(0)
					var original_p: PackedVector3Array=original[Mesh.ARRAY_VERTEX]
					var original_indices: PackedInt32Array=original[Mesh.ARRAY_INDEX]
					check(p.slice(0,original_p.size())==original_p and arrays[Mesh.ARRAY_INDEX].slice(0,original_indices.size())==original_indices,label+" original marking geometry remains exact")
					if bool(source.get_meta("bonnet_contour_baked",false)):
						check(p.size()==original_p.size() and arrays[Mesh.ARRAY_INDEX].size()==original_indices.size(),label+" baked bonnet adds no runtime geometry")
					else:
						check(p.size()-original_p.size()==200 and arrays[Mesh.ARRAY_INDEX].size()-original_indices.size()==600,label+" bonnet adds exactly100segments/200triangles")
					check_bonnet(part,source,reduced,label)
					continue
				var skin: MeshInstance3D=car.find_child("ReferenceHood" if "Bonnet" in str(part.name) else "ReferenceSide-1_0" if "-1_0" in str(part.name) else "ReferenceSide1_0",true,false)
				check(skin!=null,label+" matching backing exists")
				if skin==null:continue
				var tree: TriangleMesh=skin.mesh.generate_triangle_mesh()
				var faces: PackedVector3Array=part.mesh.get_faces()
				var buried: int=0;var minimum: float=INF
				for offset: int in range(0,faces.size(),3):
					var point: Vector3=(faces[offset]+faces[offset+1]+faces[offset+2])/3.0
					var outward:=Vector3.UP if "Bonnet" in str(part.name) else Vector3(signf(point.x),0,0)
					var hit: Dictionary=tree.intersect_ray(point+outward*0.1,-outward)
					if hit.is_empty():continue
					var gap: float=(point-hit.position).dot(outward)
					minimum=minf(minimum,gap)
					if gap<0.0:buried+=1
				check(buried==0,label+" no contour triangle centroid sinks below the exterior; min_mm="+str(minimum*1000.0))
			check(marked==(15 if id=="electric" else 1),id+" expected independent unbatched contour surfaces")
			car.free();await process_frame
	print("PANEL_CONTOURS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func precise_bonnet_hit(mesh: Mesh,point: Vector3) -> Dictionary:
	# TriangleMesh ray tests reject some narrow, valid CDT triangles. Evaluate
	# their rendered clockwise faces directly without changing fit tolerances.
	var faces: PackedVector3Array=mesh.get_faces()
	var height: float=-INF
	for i: int in range(0,faces.size(),3):
		var a: Vector3=faces[i];var b: Vector3=faces[i+1];var c: Vector3=faces[i+2]
		var u:=Vector2(b.x-a.x,b.z-a.z);var v:=Vector2(c.x-a.x,c.z-a.z)
		var denominator: float=u.cross(v)
		if denominator<=0.000000000001:continue
		var offset:=Vector2(point.x-a.x,point.z-a.z)
		var s: float=offset.cross(v)/denominator;var t: float=u.cross(offset)/denominator
		if s<0 or t<0 or s+t>1:continue
		height=maxf(height,a.y+s*(b.y-a.y)+t*(c.y-a.y))
	return {"position":Vector3(point.x,height,point.z)} if is_finite(height) else {}

func check_bonnet(part: MeshInstance3D,source: ArrayMesh,reduced: bool,label: String) -> void:
	var outline: Dictionary=preload("res://../build/challenger-low-hood-2026-11-15/native/bonnet_contour.json").data
	var source_path: String="res://../build/challenger-low-hood-2026-11-15/native/"+str(outline.source_mesh)
	check(FileAccess.get_sha256(source_path)==outline.source_sha256,label+" outline provenance matches immutable native bonnet")
	if bool(source.get_meta("bonnet_contour_baked",false)):
		check(bool(outline.get("baked",false)) and float(outline.physical_width_metres)==0.0025,label+" native bonnet marking uses its physical-width contract")
		var tier: String="simple" if reduced else "full"
		var hood_mesh: ArrayMesh=load("res://../build/challenger-low-hood-2026-11-15/native/"+tier+"_hood_paint.res")
		var hood: TriangleMesh=hood_mesh.generate_triangle_mesh()
		var native: PackedVector3Array=source.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var samples: int=0;var supported: bool=true;var fitted: bool=true
		var misses: int=0;var low_gap: float=INF;var high_gap: float=-INF
		for point: Vector3 in native:
			if point.z>=-0.74 or point.y<=0.80:continue
			samples+=1
			var hit: Dictionary=hood.intersect_ray(point+Vector3.UP*0.03,Vector3.DOWN)
			if hit.is_empty():hit=precise_bonnet_hit(hood_mesh,point)
			if hit.is_empty():
				supported=false;misses+=1
			else:
				low_gap=minf(low_gap,point.y-hit.position.y);high_gap=maxf(high_gap,point.y-hit.position.y)
				supported=supported and point.y-hit.position.y>=0.0005 and point.y-hit.position.y<=0.004
			var distance: float=INF
			var q:=Vector2(point.x,point.z)
			for i: int in range(outline.points.size()):
				var a: Array=outline.points[i];var b: Array=outline.points[(i+1)%outline.points.size()]
				var start:=Vector2(a[0],a[2]);var edge:=Vector2(b[0]-a[0],b[2]-a[2])
				var t: float=clampf((q-start).dot(edge)/maxf(edge.length_squared(),0.000000001),0,1)
				distance=minf(distance,q.distance_to(start+edge*t))
			fitted=fitted and distance>=0.001 and distance<=0.0045
		check(samples>200 and supported,label+" every native bonnet marking vertex is supported above the hood; misses="+str(misses)+" gap_mm="+str(Vector2(low_gap,high_gap)*1000))
		check(fitted,label+" native marking follows the new smooth edge with a narrow inset")
		return
	check(outline.points.size()==100 and float(outline.maximum_boundary_error_metres)<0.000875,label+" measured boundary fit stays below0.875mm")
	var arrays: Array=part.mesh.surface_get_arrays(0)
	var p: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var first: int=source.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	var fit: bool=true
	for i: int in range(100):
		var center: Vector3=(p[first+i*2]+p[first+i*2+1])*0.5
		var target: Array=outline.points[i]
		fit=fit and Vector2(center.x,center.z).distance_to(Vector2(target[0],target[2]))<0.000001
	check(fit,label+" fitted marking retains measured bonnet boundary in plan")
	var tier: String="simple" if reduced else "full"
	var hood: TriangleMesh=(load("res://../build/challenger-low-hood-2026-11-15/native/"+tier+"_hood_paint.res") as ArrayMesh).generate_triangle_mesh()
	var body: TriangleMesh=(load("res://../build/challenger-low-hood-2026-11-15/native/"+tier+"_body_paint.res") as ArrayMesh).generate_triangle_mesh()
	var faces: PackedVector3Array=part.mesh.get_faces()
	var original_faces: int=source.get_faces().size()
	var buried: int=0;var minimum: float=INF
	for offset: int in range(original_faces,faces.size(),3):
		var center: Vector3=(faces[offset]+faces[offset+1]+faces[offset+2])/3.0
		for skin: TriangleMesh in [hood,body]:
			var hit: Dictionary=skin.intersect_ray(center+Vector3.UP*0.03,Vector3.DOWN)
			if hit.is_empty():continue
			minimum=minf(minimum,center.y-hit.position.y)
			if center.y<hit.position.y:buried+=1
	check(buried==0,label+" bonnet marking stays above both existing skins; minimum_mm="+str(minimum*1000.0))

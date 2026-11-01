extends SceneTree
## Verify the actual light and housing meshes meet and follow the nose sides.
const M=preload("res://vehicle/electric_reference_mesh.gd")
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)
func edge(node: MeshInstance3D, x: float) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var arrays: Array=node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	for i: int in vertices.size():
		if absf(uvs[i].x-x)<0.00001:
			result.append({"t":uvs[i].y,"p":node.transform*vertices[i]})
	result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.t<b.t)
	return result
func gap(first: Array[Dictionary],second: Array[Dictionary]) -> float:
	if first.is_empty() or second.size()<2: return INF
	var largest:=0.0
	for sample: Dictionary in first:
		var nearest:=INF
		for i: int in range(second.size()-1):
			nearest=minf(nearest,(sample.p as Vector3).distance_to(Geometry3D.get_closest_point_to_segment(sample.p,second[i].p,second[i+1].p)))
		largest=maxf(largest,nearest)
	return largest
func fit_to_flank(wrap: MeshInstance3D, flank: MeshInstance3D, side: float) -> float:
	var arrays: Array=wrap.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var triangles: PackedVector3Array=flank.mesh.get_faces()
	var worst:=0.0
	var count:=0
	for uv_target: float in [0.15,0.5,0.85]:
		var selected:=Vector3.INF
		var nearest:=INF
		for i: int in vertices.size():
			var d: float=uvs[i].distance_squared_to(Vector2(uv_target,0.5))
			if d<nearest:
				nearest=d
				selected=wrap.transform*vertices[i]
		var start:=Vector3(side*2.0,selected.y,selected.z)
		var end:=Vector3(0,selected.y,selected.z)
		var best:=INF
		for i: int in range(0,triangles.size(),3):
			var a: Vector3=flank.transform*triangles[i]
			var b: Vector3=flank.transform*triangles[i+1]
			var c: Vector3=flank.transform*triangles[i+2]
			if selected.z<minf(a.z,minf(b.z,c.z))-0.0001 or selected.z>maxf(a.z,maxf(b.z,c.z))+0.0001: continue
			if selected.y<minf(a.y,minf(b.y,c.y))-0.0001 or selected.y>maxf(a.y,maxf(b.y,c.y))+0.0001: continue
			var hit: Variant=Geometry3D.segment_intersects_triangle(start,end,a,b,c)
			if hit!=null: best=minf(best,selected.distance_to(hit))
		worst=maxf(worst,best)
		count+=1
	return worst if count==3 else INF
func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-source="):
			var code: String=FileAccess.get_file_as_string(arg.trim_prefix("--baseline-source="))
			assert(not code.is_empty())
			var script: GDScript=load("res://vehicle/electric_reference_body.gd")
			script.source_code=code
			assert(script.reload()==OK)
	M.use_baked="--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for side: float in [-1.0,1.0]:
			var suffix: String=str(side).replace(".","_")
			var flank: MeshInstance3D=car.body.get_node("ReferenceSide"+suffix)
			for lit: bool in [false,true]:
				var strip: MeshInstance3D=car.body.get_node("ReferenceFrontLightbar" if lit else "ReferenceFrontLampHousing")
				var corner: MeshInstance3D=car.body.get_node(("ReferenceLightCorner" if lit else "ReferenceLightCornerHousing")+suffix)
				var wrap: MeshInstance3D=car.body.get_node(("ReferenceLightWrap" if lit else "ReferenceLightWrapHousing")+suffix)
				var entry: float=0.0 if side<0 else 1.0
				var strip_edge:=edge(strip,entry)
				var corner_in:=edge(corner,0.0)
				var corner_out:=edge(corner,1.0)
				var wrap_edge:=edge(wrap,0.0)
				var g0: float=maxf(gap(strip_edge,corner_in),gap(corner_in,strip_edge))
				var g1: float=maxf(gap(corner_out,wrap_edge),gap(wrap_edge,corner_out))
				var fitted: float=fit_to_flank(wrap,flank,side)
				var label: String=" side="+str(side)+" lit="+str(lit)+" simple="+str(simple)
				print("SPORT_OPTICS ",label," joins=",g0,",",g1," side_fit=",fitted)
				check(g0<0.004 and g1<0.004,"light strip, corner and side wrap meet"+label)
				check(fitted<0.015,"side wrap is fitted to actual flank"+label)
		car.free()
	print("VOLT_SPORT_OPTICS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

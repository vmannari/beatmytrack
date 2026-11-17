extends "res://tests/register_volt_hood_outline.gd"
const B=preload("res://vehicle/electric_reference_body.gd")
const M=preload("res://vehicle/electric_reference_mesh.gd")
const K=preload("res://vehicle/electric_kits.gd")
const WORK: String="res://../build/volt-hood-outline-2026-11-16"
var checks: int=0;var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("VHO_FAIL ",label)
func has_line(group: Dictionary) -> bool:
	for entry: Dictionary in group.entries:
		if str(entry.part.name)=="SportBonnetShutLine":return true
	return false
func detail(group: Dictionary) -> void:
	if has_line(group):
		var before: Dictionary=raw.get(key(group,false),{})
		check(not before.is_empty(),"all other raw members exact")
		check(D.recipe("electric",group.code).get("parts",{})==before.get("recipe",{}).get("parts",{}),"every detail reduction row retained")
	D.apply_group(group)
func surface(group: Dictionary) -> void:
	if has_line(group):
		var before: Dictionary=post.get(key(group,true),{})
		check(not before.is_empty(),"all other final paint/glass/door members exact")
		var path: String=S.ROOT.path_join("electric_"+group.code+".json")
		var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(current.parts==before.get("recipe",{}).get("parts",{}),"every surface reduction row retained")
	S.apply_group(group,D)
func centres(mesh: Mesh) -> PackedVector3Array:
	var a: Array=mesh.surface_get_arrays(0);var p: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var t: PackedFloat32Array=a[Mesh.ARRAY_TANGENT];var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV];var result:=PackedVector3Array()
	for at: int in range(p.size()):result.append(p[at]-Vector3(t[at*4],t[at*4+1],t[at*4+2])*uv[at].y)
	return result
func side_bow(points: PackedVector3Array,side: float) -> float:
	var selected: Array=[]
	for p: Vector3 in points:
		if p.x*side>0.55 and p.z>-2.10 and p.z<-1.10:selected.append(p)
	check(selected.size()>20,"long side sampling")
	var z: float=0;var x: float=0
	for p: Vector3 in selected:z+=p.z;x+=p.x
	z/=selected.size();x/=selected.size()
	var numerator: float=0;var denominator: float=0
	for p: Vector3 in selected:numerator+=(p.z-z)*(p.x-x);denominator+=(p.z-z)*(p.z-z)
	var slope: float=numerator/denominator;var maximum: float=0
	for p: Vector3 in selected:maximum=maxf(maximum,absf(p.x-(x+slope*(p.z-z))))
	return maximum
func run() -> void:
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("frame-registry.json")));raw=registry.raw;post=registry.post;targets["SportBonnetShutLine"]=true
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false;D.offline=detail;S.offline=surface
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="electric";car.editable_kits=editable;car.cache_rest_pose=false;root.add_child(car)
		while not car.model_ready:await process_frame
		car.free();await process_frame
	var results: Array=[]
	for simple: bool in [true,false]:
		var car:=CarVisual.new();car.simple_model=simple;var parent:=Node3D.new()
		B.build_hood(car,parent,CompactFinish.paint(Color.WHITE),CompactFinish.rubber(Color.BLACK))
		var skin: MeshInstance3D=parent.get_child(0);var line: MeshInstance3D=parent.get_child(1);var tree: TriangleMesh=skin.mesh.generate_triangle_mesh()
		check(line.mesh.get_faces().size()/3==384,"same 384-triangle contour budget")
		var points: PackedVector3Array=centres(line.mesh)
		var bow: float=maxf(side_bow(points,-1),side_bow(points,1))
		check(bow<0.00001,"long plan-view edges straight within 10 micrometres")
		for point: Vector3 in line.mesh.get_faces():
			var hit: Dictionary=tree.intersect_ray(point+Vector3.UP*0.1,Vector3.DOWN)
			check(not hit.is_empty(),"complete bonnet backing")
			if not hit.is_empty():check(point.y-hit.position.y>=0.00035 and point.y-hit.position.y<=0.0015,"flush exposed contour")
		results.append({"simple":simple,"side_bow_m":bow,"triangles":384})
		parent.free();car.free()
	check(K.hood_mesh_bank_valid(),"actual optional-hood bank guard is current")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK.path_join("before/game/assets/vehicles/electric_hoods_v5/manifest.json")))
	for row: Dictionary in before.meshes:
		var mesh: Mesh=load(K.HOOD_MESH_ROOT.path_join(row.file))
		check(var_to_bytes(mesh.surface_get_arrays(0)).hex_encode().sha256_text()==row.arrays_sha256,"unchanged optional hood arrays "+str(row.key))
	# The original builder supplies a genuine rejected curvature control.
	var legacy: Script=load(WORK.path_join("before/game/vehicle/electric_reference_body.gd"))
	M.meshes.erase("SportBonnetShutLine_fitted_v2_simple");M.use_baked=false
	var control:=CarVisual.new();control.simple_model=true;var holder:=Node3D.new()
	legacy.build_hood(control,holder,CompactFinish.paint(Color.WHITE),CompactFinish.rubber(Color.BLACK))
	var old_bow: float=maxf(side_bow(centres(holder.get_child(1).mesh),-1),side_bow(centres(holder.get_child(1).mesh),1))
	check(old_bow>0.01,"previous curved sides reject the straight-edge gate")
	holder.free();control.free()
	FileAccess.open(OUT.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":results,"old_side_bow_m":old_bow},"  "))
	print("VHO_GEOMETRY ",checks," checks, ",failures," failures; old side bow=",old_bow);quit(1 if failures else 0)

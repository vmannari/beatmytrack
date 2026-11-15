extends SceneTree
## Fit the fourteen visible door/handle strips to the final racing side meshes.
const Source=preload("res://tests/support/car_step10_source.gd")
const Detail=preload("res://vehicle/car_detail_reduction.gd")
const M=preload("res://vehicle/electric_reference_mesh.gd")
const B=preload("res://vehicle/electric_reference_body.gd")
const WORK: String="res://../build/car-step10-2026-11-15"
const OUT: String="res://../docs/evidence/car-step10-2026-11-15"
var files: Dictionary={}
var rows: Array=[]
var applied: bool=false
func _initialize() -> void: run.call_deferred()
func line(car: CarVisual,skin: MeshInstance3D,side: float,label: String,sample: Callable,count: int,width: float) -> void:
	var original: MeshInstance3D=car.body.get_node(NodePath(label.replace(".","_")))
	assert(original!=null)
	var key: String=label+"_fitted_v2_simple"
	var old: Mesh=original.mesh
	var tree: TriangleMesh=skin.mesh.generate_triangle_mesh()
	var hits: int=0;var buried: int=0
	for t: int in range(101):
		var target: Vector3=sample.call(float(t)/100.0)
		var hit: Dictionary=tree.intersect_ray(target+Vector3(side*0.20,0,0),Vector3(-side,0,0))
		if not hit.is_empty():hits+=1
	assert(hits==101,"Complete contour must project onto actual racing body: "+label+" "+str(hits))
	for surface: int in range(old.get_surface_count()):
		for point: Vector3 in old.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var hit: Dictionary=tree.intersect_ray(point+Vector3(side*0.20,0,0),Vector3(-side,0,0))
			if not hit.is_empty() and side*(point.x-hit.position.x)<0.00035:buried+=1
	M.meshes.erase(key)
	var previous: bool=M.use_baked;M.use_baked=false
	var holder:=Node3D.new();car.body.add_child(holder)
	M.fitted_line(holder,label,skin,sample,count,width,CompactFinish.rubber(Color("152025")),Vector3(side,0,0),true)
	M.use_baked=previous
	var result: MeshInstance3D=holder.get_child(0)
	var mesh: ArrayMesh=result.mesh
	mesh.set_meta("car_authored_far",true);mesh.set_meta("car_surface_guide_locked",true)
	mesh.set_meta("volt_contour_backing",Detail.mesh_key(skin.mesh))
	var file: String=key.sha256_text().left(24)+".res"
	var target: String="game/"+M.ASSET_ROOT.trim_prefix("res://").path_join(file)
	assert(ResourceSaver.save(mesh,WORK.path_join("volt-fixed").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
	files[file]=target
	original.mesh=mesh
	rows.append({"name":label,"file":file,"backing":Detail.mesh_key(skin.mesh),"before":old.get_faces().size()/3,"after":mesh.get_faces().size()/3,"buried_before_vertices":buried,"sample_hits":hits})
	holder.free()
func observe(car: CarVisual,holders: Variant) -> void:
	if applied or holders!=null:return
	applied=true
	for side: float in [-1.0,1.0]:
		var skin: MeshInstance3D=car.body.get_node(NodePath("ReferenceSide"+str(side).replace(".","_")))
		for seam: int in range(3):
			var sample: Callable=func(t: float)->Vector3:
				var start: float=B.cabin_z([B.WINDOW_A_FOOT,B.WINDOW_B_FOOT,B.WINDOW_C_FOOT][seam])
				var z: float=lerpf(start,[-0.88,0.05,0.75][seam],t)
				return B.side_point(side,z,lerpf(minf(0.96,B.shoulder(z)-0.002),0.31,t))
			line(car,skin,side,"ReferenceDoorSeam"+str(side)+str(seam),sample,32,0.0028)
		for z: float in [-0.16,0.86]:
			var outline: Callable=func(t: float)->Vector3:
				var c: float=cos(TAU*t);var s: float=sin(TAU*t)
				return B.side_point(side,z+0.080*signf(c)*pow(absf(c),0.35),B.shoulder(z)-0.082+0.016*signf(s)*pow(absf(s),0.35))
			line(car,skin,side,"RefHandleOutline"+str(side)+str(z),outline,40,0.0022)
			var pull: Callable=func(t: float)->Vector3:return B.side_point(side,z+lerpf(-0.045,0.045,t),B.shoulder(z)-0.089-0.002*sin(PI*t))
			line(car,skin,side,"RefHandlePull"+str(side)+str(z),pull,12,0.0016)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("volt-fixed")))
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Source.observer=observe
	var car=Source.new();car.vehicle_id="electric";car.simple_model=true;car.cache_rest_pose=false
	root.add_child(car)
	while not car.model_ready:await process_frame
	assert(rows.size()==14)
	FileAccess.open(OUT.path_join("volt-fix-staged.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":files,"rows":rows},"  "))
	print("VOLT_CONTOURS_STAGED ",rows.size()," parts; original buried vertices=",rows.reduce(func(total: int,row: Dictionary)->int:return total+int(row.buried_before_vertices),0))
	car.free();quit()

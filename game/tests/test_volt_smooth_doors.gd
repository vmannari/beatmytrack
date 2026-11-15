extends SceneTree
const Source=preload("res://tests/support/volt_smooth_source.gd")
const Detail=preload("res://vehicle/car_detail_reduction.gd")
var checks: int=0;var failures: int=0;var seen: bool=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("STEP10_VOLT_FAIL ",label)
func observe(car: CarVisual,holders: Variant) -> void:
	if seen or holders!=null:return
	seen=true
	var count: int=0
	for side: float in [-1.0,1.0]:
		var skin: MeshInstance3D=car.body.get_node(NodePath("ReferenceSide"+str(side).replace(".","_")))
		check(Detail.mesh_key(skin.mesh)==("1877bdbfd00065bba77150cfbe4b6077e8d85de526d3305964f39a60a7f794dc" if side<0 else "dc5f58a62cf3f5db658e0bdabd433b68d4504720d21f1f77a98311c30993c569"),"exact protected backing "+str(side))
		var tree: TriangleMesh=skin.mesh.generate_triangle_mesh()
		for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
			if not (str(part.name).begins_with("ReferenceDoorSeam"+str(side).replace(".","_")) or str(part.name).begins_with("RefHandleOutline"+str(side).replace(".","_")) or str(part.name).begins_with("RefHandlePull"+str(side).replace(".","_"))):continue
			count+=1
			check(part.mesh.get_meta("car_keep_master",false),"contour keeps its distance geometry "+str(part.name))
			check(part.mesh.get_meta("volt_contour_backing","")==Detail.mesh_key(skin.mesh),"contour backing identity "+str(part.name))
			var points: PackedVector3Array=part.mesh.get_faces()
			for at: int in range(0,points.size(),3):
				var samples: Array=[points[at],points[at+1],points[at+2],(points[at]+points[at+1]+points[at+2])/3.0]
				for point: Vector3 in samples:
					var hit: Dictionary=tree.intersect_ray(point+Vector3(side*0.20,0,0),Vector3(-side,0,0))
					check(not hit.is_empty(),"complete backing coverage "+str(part.name))
					if not hit.is_empty():
						var gap: float=side*(point.x-hit.position.x)
						check(gap>=0.00030 and gap<=0.0020,"continuous exposed contour "+str(part.name)+" "+str(gap))
	check(count==14,"all six seams and eight handle strips")
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Source.observer=observe
	var car=Source.new();car.vehicle_id="electric";car.simple_model=true;car.cache_rest_pose=false
	root.add_child(car)
	while not car.model_ready:await process_frame
	check(seen,"final reduced source reviewed")
	var protected_count: int=0;var protected_triangles: int=0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if not part.mesh.get_meta("car_keep_master",false):continue
		protected_count+=1;protected_triangles+=part.mesh.get_faces().size()/3
		for surface: int in range(part.mesh.get_surface_count()):
			check(RenderingServer.mesh_get_surface(part.mesh.get_rid(),surface).get("lods",[]).is_empty(),"protected geometry has no lower distance surface")
	check(protected_count==2 and protected_triangles==5086,"both protected batches retain all 5086 backing/contour triangles")
	car.free();print("STEP10_VOLT ",checks," checks, ",failures," failures");quit(1 if failures else 0)

extends SceneTree
## Check actual fascia openings and preservation of saved paint choices.
const OUTPUT: String="res://../docs/evidence/volt-new-references-2026-10-29/body-checks.json"
var checks: int=0
var failures: int=0
var metrics: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func first_surface(car: CarVisual,origin: Vector3) -> String:
	var nearest: float=INF
	var label: String=""
	for node: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var transform: Transform3D=car.body.global_transform.affine_inverse()*node.global_transform
		var faces: PackedVector3Array=node.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			var hit: Variant=Geometry3D.ray_intersects_triangle(origin,Vector3.BACK,transform*faces[i],transform*faces[i+1],transform*faces[i+2])
			if hit==null: continue
			var distance: float=origin.distance_to(hit)
			if distance<nearest: nearest=distance;label=str(node.name)
	return label
func run() -> void:
	var factory: Dictionary=VehicleLivery.defaults("electric")
	check(factory.colors.body=="b8bbb9" and factory.colors.accent=="272f33","silver factory finish and charcoal accent")
	var former: Dictionary=factory.duplicate(true)
	former.colors.body="638d86"
	former.colors.accent="263c43"
	check(VehicleLivery.normalize(former,"electric")==former,"previous saved green stays unchanged")
	var custom: Dictionary=former.duplicate(true)
	custom.colors.body="992244"
	custom.colors.accent="142536"
	check(VehicleLivery.normalize(custom,"electric")==custom,"valid custom paint stays unchanged")
	var old_source:=GDScript.new()
	old_source.source_code=FileAccess.get_file_as_string("res://../docs/evidence/volt-new-references-2026-10-29/task-base/game/vehicle/vehicle_livery.gd").replace("\r\n","\n").replace("class_name VehicleLivery\n","")
	check(old_source.reload()==OK,"load exact pre-task paint defaults")
	var old: RefCounted=old_source.new()
	for id: String in VehicleCatalog.ALL_IDS:
		if id!="electric": check(VehicleLivery.defaults(id)==old.call("defaults",id),"other vehicle factory finish unchanged "+id)
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var label: String="simple" if simple else "full"
		check(car.body.find_children("DoorRoofCut*","MeshInstance3D",true,false).size()==4 and car.body.find_children("DoorPillarCut*","MeshInstance3D",true,false).size()==6,"four door perimeters still include their windows "+label)
		for side: float in [-1.0,1.0]:
			var glazing: MeshInstance3D=car.body.get_node(("SideGlazing"+str(side)).validate_node_name())
			var pillar: MeshInstance3D=car.body.get_node(("DoorPillarCut"+str(side)+"2").validate_node_name())
			check(glazing.mesh.get_aabb().end.z<=pillar.mesh.get_aabb().end.z+0.002,"fixed rear quarter glass remains removed "+label+str(side))
			var name_value: String="Curtain"+str(side)
			var back: MeshInstance3D=car.body.get_node((name_value+"Back").validate_node_name())
			check(back!=null and car.body.find_children((name_value+"Return").validate_node_name()+"*","MeshInstance3D",true,false).size()==4,"air curtain has an inset back and four returns "+label+str(side))
			var origin: Vector3=back.mesh.get_aabb().get_center()+Vector3.FORWARD*0.30
			var first: String=first_surface(car,origin)
			check(first==str(back.name),"actual air-curtain opening is not covered by paint "+label+str(side))
			metrics[label+str(side)]={"first_visible_surface_through_curtain":first}
		car.free()
	FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")+"\n")
	print("VOLT_REFERENCE_BODY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

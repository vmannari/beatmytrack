extends "res://tests/test_car_model_revert.gd"
const RFL_OUT: String="res://../docs/evidence/rally-front-2026-11-15"
const RFL_WORK: String="res://../build/rally-front-2026-11-15"
const Detail=preload("res://vehicle/car_detail_reduction.gd")
var groups: Dictionary={}
var contexts: int=0
func _initialize() -> void: survey_front.call_deferred()
func scope(part: Node) -> bool:
	return str(part.name).begins_with("FrontLamp") or str(part.name).begins_with("FrontGrille")
func inspect(group: Dictionary) -> void:
	var others: Array=[];var has_front: bool=false
	for entry: Dictionary in group.entries:
		if scope(entry.part): has_front=true
		else: others.append(entry.code)
	others.sort()
	if has_front:
		var code: String=var_to_bytes(others).hex_encode().sha256_text()
		var recipe: Dictionary=Detail.recipe(group.vehicle,group.code)
		var parts: Dictionary={};var costs: Dictionary={}
		for entry: Dictionary in group.entries:
			parts[entry.code]={"name":str(entry.part.name),"source":entry.source,"front":scope(entry.part)}
		Detail.apply_group(group)
		for entry: Dictionary in group.entries:
			if scope(entry.part):costs[str(entry.part.name)]=entry.part.mesh.get_faces().size()/3 if entry.part.visible else 0
		var row: Dictionary={"context":group.code,"others":others,"parts":parts,"recipe":recipe,"front_costs":costs}
		if groups.has(code): assert(groups[code].recipe==recipe,"A retained frame must have one exact recipe")
		groups[code]=row;contexts+=1
	else: Detail.apply_group(group)
func survey_front() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RFL_WORK))
	var measured: Array=[];var masters: Dictionary={}
	Base.enabled=true;Kits.enabled=true;Cache.enabled=true;preload("res://ui/garage_car_cache.gd").enabled=false
	for id: String in ["compact","kart","forklift","electric","hovercraft","super_rally"]:
		for mode: String in (["stock","fitted","full"] if id=="compact" else ["stock","full"]):
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.editable_kits=mode=="fitted";car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			root.add_child(car)
			while not car.model_ready:await process_frame
			masters[id+"_"+mode]=signature(car)
			measured.append({"vehicle":id,"mode":mode,"inventory":inventory(car,false)})
			if id=="compact":
				var holder:=Node3D.new();holder.name="RallyBefore";holder.transform=car.transform;car.get_parent().add_child(holder)
				for child: Node in car.get_children():
					if child is Node3D:
						var duplicate: Node=child.duplicate();holder.add_child(duplicate)
				for part: Node in holder.find_children("*","",true,false):part.owner=holder
				var packed:=PackedScene.new();assert(packed.pack(holder)==OK)
				assert(ResourceSaver.save(packed,RFL_WORK.path_join("compact-"+mode+"-before.scn"),ResourceSaver.FLAG_COMPRESS)==OK);holder.free()
			car.free();await process_frame
	Base.enabled=false;Kits.enabled=false;Cache.enabled=false;Detail.offline=inspect
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="compact";car.simple_model=true;car.editable_kits=editable;car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready:await process_frame
		if editable:
			for category: String in VehicleCustomisation.CATEGORIES:
				for option: Array in VehicleCustomisation.options(category,"compact").slice(1):
					var choice: Dictionary=car.customisation.duplicate();choice[category]=option[0];car.change_kit_parts(choice)
					choice=car.customisation.duplicate();choice[category]="stock";car.change_kit_parts(choice)
		car.free();await process_frame
	FileAccess.open(RFL_OUT.path_join("before.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":measured,"contexts":contexts,"frames":groups.size()},"  "))
	FileAccess.open(RFL_OUT.path_join("frame-registry.json"),FileAccess.WRITE).store_string(JSON.stringify(groups,"  "))
	FileAccess.open("res://tests/fixtures/rally_front_baseline.json",FileAccess.WRITE).store_string(JSON.stringify({"provenance":"Pinned 4.7.2 task-start prepared masters before Rally front authoring; exact GPU/articulation/shadow signatures.","signatures":masters},"  "))
	print("RALLY_FRONT_BASELINE ",measured.size()," masters; ",groups.size()," exact retained-body frames");quit()

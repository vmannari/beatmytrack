extends SceneTree
const Source=preload("res://tests/support/car_step10_source.gd")
const D=preload("res://vehicle/car_detail_reduction.gd")
var found: Dictionary={};var mode: String=""
func _initialize() -> void: run.call_deferred()
func inspect(car: CarVisual,holders: Variant) -> void:
	var parts: Array=car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders:parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		var label: String=str(part.name)
		var keep: bool=(car.vehicle_id=="compact" and (label.begins_with("FrontLamp") or label.begins_with("FrontGrille"))) or (car.vehicle_id=="kart" and (label.begins_with("Helmet") or label=="TomkartDriver" or "SteeringAssembly" in str(car.get_path_to(part)))) or (car.vehicle_id=="electric" and (label.begins_with("ReferenceSide") or label.begins_with("ReferenceRoof") or label=="ReferencePanoramicRoof"))
		if keep:
			var key: String=car.vehicle_id+"_"+mode
			if not found.has(key):found[key]=[]
			found[key].append(car.vehicle_id+"_"+D.mesh_key(part.mesh))
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Source.observer=inspect
	for id: String in ["compact","kart","electric"]:
		for current: String in ["stock","fitted"]:
			mode=current
			var car=Source.new();car.vehicle_id=id;car.simple_model=true;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			root.add_child(car)
			while not car.model_ready:await process_frame
			car.free();await process_frame
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/car_step10_landmarks.json"))
	var checks: int=0;var failures: int=0
	for key: String in expected:
		checks+=1;found[key].sort()
		if found[key]!=expected[key]:failures+=1;printerr("STEP10_LANDMARK_FAIL ",key)
	print("STEP10_LANDMARKS ",checks," checks, ",failures," failures");quit(1 if failures else 0)

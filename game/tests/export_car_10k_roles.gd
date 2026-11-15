extends SceneTree
var WORK: String=OS.get_environment("BMT_CAR_BUDGET_WORK") if OS.has_environment("BMT_CAR_BUDGET_WORK") else "res://../build/car-10k-models-2026-11-14"
const Budget=preload("res://vehicle/car_budget_reduction.gd")
var protected_keys: Dictionary={}
func _initialize() -> void: run.call_deferred()
func collect(car: CarVisual,parts: Array) -> void:
	for part: MeshInstance3D in parts:
		if part.mesh==null: continue
		if "SteeringAssembly" in str(car.get_path_to(part)): protected_keys[Budget.code(part.mesh,car.vehicle_id)]="steering assembly"
func run() -> void:
	for path: String in ["modular_car_base","modular_car_kits","prepared_car_cache"]: load("res://vehicle/"+path+".gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false;Budget.offline=collect
	var car:=CarVisual.new();car.vehicle_id="kart";car.editable_kits=true;car.cache_rest_pose=false;root.add_child(car)
	while not car.model_ready: await process_frame
	car.free()
	FileAccess.open(WORK.path_join("protected-roles.json"),FileAccess.WRITE).store_string(JSON.stringify(protected_keys))
	print("TEN_K_PROTECTED ",protected_keys.size()," steering meshes");quit()

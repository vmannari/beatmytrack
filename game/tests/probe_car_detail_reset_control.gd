extends "res://tests/measure_car_simplification.gd"
const OUT_DETAIL: String="res://../docs/evidence/car-detail-reduction-2026-11-14"
func _initialize() -> void: control.call_deferred()
func control() -> void:
	Base.enabled=false;Kits.enabled=false;Cache.enabled=false
	preload("res://vehicle/car_detail_reduction.gd").enabled=false
	var legacy: bool="--legacy-racing" in OS.get_cmdline_user_args()
	if legacy: CarVisual._builder_scripts["racing_car_models"]=load("res://../build/car-detail-reduction-2026-11-14/original_racing_car_models.gd")
	var car:=CarVisual.new()
	car.vehicle_id="hovercraft";car.editable_kits=true;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults("hovercraft")
	root.add_child(car)
	while not car.model_ready: await process_frame
	var before: Dictionary=inventory(car,false)
	var observations: Array=[]
	for category: String in VehicleCustomisation.CATEGORIES:
		for option: Array in VehicleCustomisation.options(category,car.vehicle_id).slice(1):
			var selection: Dictionary=car.customisation.duplicate()
			selection[category]=option[0];car.change_kit_parts(selection)
		var selection: Dictionary=car.customisation.duplicate();selection[category]="stock"
		car.change_kit_parts(selection)
		observations.append({"category":category,"triangles":inventory(car,false).triangles})
	var after: Dictionary=inventory(car,false)
	print("HOVER_RESET_CONTROL legacy=",legacy," before=",before.triangles," after=",after.triangles)
	FileAccess.open(OUT_DETAIL.path_join("hover-reset-legacy.json" if legacy else "hover-reset-control.json"),FileAccess.WRITE).store_string(JSON.stringify({"legacy_racing":legacy,"detail_enabled":false,"before":before,"after":after,"categories":observations},"\t"))
	car.free();quit()

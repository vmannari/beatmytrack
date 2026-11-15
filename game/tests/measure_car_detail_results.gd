extends "res://tests/measure_car_simplification.gd"
## CLV04: real prepared hits, current source parity and retained full geometry.
const DETAIL_OUT: String="res://../docs/evidence/car-detail-reduction-2026-11-14"
var detail_rows: Array=[]
var trace_logger: Logger
func _initialize() -> void: measure_details.call_deferred()
func measure_details() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	var without_detail: bool="--without-detail" in OS.get_cmdline_user_args()
	preload("res://vehicle/car_detail_reduction.gd").enabled=not without_detail
	if "--trace-errors" in OS.get_cmdline_user_args():
		trace_logger=load("res://../build/car-detail-reduction-2026-11-14/trace_logger.gd").new()
		OS.add_logger(trace_logger)
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=false
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DETAIL_OUT.path_join("before.json")))
	for id: String in VehicleCatalog.IDS:
		for mode: String in ["stock","fitted","full"]:
			var car:=CarVisual.new()
			car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id)
			car.editable_kits=mode=="fitted"
			car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			var base_hits: int=Base.hits;var kit_hits: int=Kits.hits
			root.add_child(car)
			while not car.model_ready: await process_frame
			if prepared:
				check(Base.hits==base_hits+1,"actual prepared base "+id+mode)
				if mode=="fitted": check(Kits.hits==kit_hits+4,"actual four fitted module hits "+id)
			var current: Dictionary=inventory(car,false)
			var before: Dictionary={}
			for row: Dictionary in prior.rows:
				if row.vehicle==id and row.mode==mode: before=row.inventory
			if mode=="full": check(current.triangles==int(before.triangles),"full reference triangle count retained "+id)
			else:
				check(current.triangles<=int(before.triangles),"accepted simple geometry reduction "+id+mode)
				check(current.surfaces<=int(before.surfaces),"no extra visible surfaces "+id+mode)
			detail_rows.append({"vehicle":id,"mode":mode,"inventory":current,"before_triangles":before.triangles,"base_hits":Base.hits-base_hits,"kit_hits":Kits.hits-kit_hits})
			print("DETAIL_RESULT ",id," ",mode," ",before.triangles," -> ",current.triangles," bytes=",current.buffer_bytes," surfaces=",current.surfaces)
			car.free();await process_frame
	var texture: Texture2D=load("res://assets/vehicles/compact_plate_v1/ink.res")
	print("DETAIL_PLATE_IMAGE payload=",texture.get_image().get_data().size()," format=",texture.get_image().get_format()," mipmaps=",texture.get_image().get_mipmap_count())
	FileAccess.open(DETAIL_OUT.path_join("control-results.json" if without_detail else "prepared-results.json" if prepared else "source-results.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":detail_rows,"plate_image_payload_bytes":texture.get_image().get_data().size()},"\t"))
	if trace_logger!=null: OS.remove_logger(trace_logger)
	print("DETAIL_RESULTS ",checks," checks, ",failures," failures; prepared=",prepared)
	quit(1 if failures else 0)

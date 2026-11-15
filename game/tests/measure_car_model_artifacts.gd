extends "res://tests/measure_car_simplification.gd"
## CMA04: count quality-repair costs and retain exact full geometry.
const DETAIL_OUT: String="res://../docs/evidence/car-model-artifacts-2026-11-14"
var detail_rows: Array=[]
const WORK: String="res://../build/car-model-artifacts-2026-11-14"
func apply_candidates(car: CarVisual,parts: Array) -> void:
	var budget=preload("res://vehicle/car_budget_reduction.gd")
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		if budget.is_protected(part) or (part.mesh is ArrayMesh and part.mesh.get_blend_shape_count()>0): continue
		var path: String=WORK.path_join("staged-final-five").path_join(budget.code(part.mesh,car.vehicle_id)+".res")
		if ResourceLoader.exists(path): budget.swap(part,load(path))


var trace_logger: Logger
func master_signature(car: Node3D) -> Array:
	var result: Array=[]
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null: continue
		var streams: Array=[]
		for surface: int in range(part.mesh.get_surface_count()):
			var packet: Dictionary=RenderingServer.mesh_get_surface(part.mesh.get_rid(),surface)
			for field: String in ["format","vertex_count","index_count","vertex_data","attribute_data","skin_data","index_data","blend_shapes"]: streams.append(packet.get(field))
		result.append(var_to_bytes([car.global_transform.affine_inverse()*part.global_transform,part.cast_shadow,streams]).hex_encode().sha256_text())
	result.sort();return result

func _initialize() -> void: measure_details.call_deferred()
func measure_details() -> void:
	var prepared: bool="--prepared" in OS.get_cmdline_user_args()
	var without_detail: bool="--without-detail" in OS.get_cmdline_user_args()
	if "--candidates" in OS.get_cmdline_user_args(): preload("res://vehicle/car_budget_reduction.gd").offline=apply_candidates
	preload("res://vehicle/car_detail_reduction.gd").enabled=not without_detail
	if "--trace-errors" in OS.get_cmdline_user_args():
		trace_logger=load("res://../build/car-model-artifacts-2026-11-14/trace_logger.gd").new()
		OS.add_logger(trace_logger)
	Base.enabled=prepared;Kits.enabled=prepared;Cache.enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=false
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DETAIL_OUT.path_join("before.json")))
	for id: String in VehicleCatalog.IDS:
		if id=="super_rally": continue
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
			if mode=="full":
				check(current.triangles==int(before.triangles),"full reference triangle count retained "+id)
				if prepared: check(current.buffer_bytes==int(before.buffer_bytes),"full reference mesh buffers retained "+id)
				if prepared:
					var reference: Node3D=(load(WORK.path_join(id+"-full-before.scn")) as PackedScene).instantiate()
					root.add_child(reference)
					check(master_signature(car)==master_signature(reference),"every full master GPU stream and transform remains exact "+id)
					reference.free()
			else:
				if mode=="stock": check(current.triangles>=9000 and current.triangles<=11000,"approximately 10000 stock triangles "+id)
			detail_rows.append({"vehicle":id,"mode":mode,"inventory":current,"before_triangles":before.triangles,"before_surfaces":before.surfaces,"base_hits":Base.hits-base_hits,"kit_hits":Kits.hits-kit_hits})
			print("DETAIL_RESULT ",id," ",mode," ",before.triangles," -> ",current.triangles," bytes=",current.buffer_bytes," surfaces=",current.surfaces)
			car.free();await process_frame
	var texture: Texture2D=load("res://assets/vehicles/compact_plate_v1/ink.res")
	print("DETAIL_PLATE_IMAGE payload=",texture.get_image().get_data().size()," format=",texture.get_image().get_format()," mipmaps=",texture.get_image().get_mipmap_count())
	FileAccess.open(DETAIL_OUT.path_join("control-results.json" if without_detail else "prepared-results.json" if prepared else "source-results.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":detail_rows,"plate_image_payload_bytes":texture.get_image().get_data().size()},"\t"))
	if trace_logger!=null: OS.remove_logger(trace_logger)
	print("DETAIL_RESULTS ",checks," checks, ",failures," failures; prepared=",prepared)
	quit(1 if failures else 0)

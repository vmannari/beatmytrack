extends "res://tests/capture_modular_car_ab.gd"
## Native three-way controls: procedural, prepared, procedural again.
var simple: bool=false
var editable: bool=false
var checks: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("PREPARED_VISUAL_FAIL ",label)
func difference(a: Image,b: Image) -> Dictionary:
	var result: Dictionary=super.difference(a,b)
	var aa: PackedByteArray=a.get_data()
	var bb: PackedByteArray=b.get_data()
	var over: int=0
	for pixel: int in range(aa.size()/4):
		var peak: int=0
		for channel: int in range(3): peak=maxi(peak,absi(int(aa[pixel*4+channel])-int(bb[pixel*4+channel])))
		if peak>8: over+=1
	result.pixels_over_8_fraction=float(over)/(aa.size()/4)
	return result
func visual_gate(metrics: Dictionary,label: String) -> void:
	# Retain the established GPO03/GPO04 gates from
	# test_garage_render_optimization.gd. Prepared Garage assets deliberately
	# retain 0.5-pixel LODs; those are not pixel-identical to full-detail draws.
	check(metrics.mean_rgb_delta<0.25,"retained native image energy gate "+label)
	check(metrics.pixels_over_8_fraction<0.005,"retained native visible-pixel gate "+label)
func make_car(vehicle: String,parts: Dictionary,prepared: bool,decorated: bool=false) -> CarVisual:
	Cache.enabled=prepared;Base.enabled=prepared;Kits.enabled=prepared
	preload("res://ui/garage_car_cache.gd").enabled=false
	Cache.entries.clear()
	var car:=CarVisual.new()
	car.vehicle_id=vehicle;car.simple_model=simple;car.editable_kits=editable
	car.customisation=parts.duplicate(true)
	car.livery=VehicleLivery.defaults(vehicle)
	if decorated:
		car.livery.colors.body="277ab1";car.livery.colors.accent="f0d58b"
		car.livery.pattern=str(LiveryCatalog.patterns[0].id)
		car.livery.stickers.hood.id=str(LiveryCatalog.stickers[0].id)
		if LiveryCatalog.has_roof(vehicle): car.livery.stickers.roof.id=str(LiveryCatalog.stickers[0].id)
	stage.add_child(car)
	return car
func compare_case(vehicle: String,fitted: bool,selections: Dictionary,decorated: bool=false) -> void:
	await super.compare_case(vehicle,fitted,selections,decorated)
	var row: Dictionary=rows[-1]
	row.simple=simple;row.editable=editable
	visual_gate(row.control_difference,"procedural repeat "+row.case)
	visual_gate(row.difference,"prepared "+row.case)
func showroom(vehicle: String,prepared: bool,label: String) -> Image:
	Base.enabled=false;Cache.enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=prepared
	var view:=CarShowroom.new()
	view.vehicle_id=vehicle;view.garage_mode=true
	view.livery=VehicleLivery.defaults(vehicle)
	view.livery.colors.body="277ab1"
	view.size=Vector2(1280,720)
	root.add_child(view)
	while not view.showroom_ready: await process_frame
	for _i: int in range(8):
		view._process(0.0)
		view._submit_render()
		await RenderingServer.frame_post_draw
		await process_frame
	check(view.reflections.views.size()==2,"full reflection pair "+label)
	var image: Image=view.showroom_viewport.get_texture().get_image()
	check(image.save_png(output.path_join(label+".png"))==OK,"capture "+label)
	view.free()
	await process_frame
	return image
func compare_garage(vehicle: String) -> void:
	var before: Image=await showroom(vehicle,false,vehicle+"-garage-procedural")
	var old_hits: int=preload("res://ui/garage_car_cache.gd").hits
	var after: Image=await showroom(vehicle,true,vehicle+"-garage-prepared")
	check(preload("res://ui/garage_car_cache.gd").hits==old_hits+1,"Garage actually uses prepared resource "+vehicle)
	var control: Image=await showroom(vehicle,false,vehicle+"-garage-control")
	var row: Dictionary={"case":vehicle+"-garage","difference":difference(before,after),"control_difference":difference(before,control)}
	rows.append(row)
	visual_gate(row.control_difference,"Garage procedural repeat "+vehicle)
	visual_gate(row.difference,"Garage prepared "+vehicle)
func header(prepared: bool,label: String) -> Image:
	Base.enabled=false;Cache.enabled=false
	preload("res://ui/header_simple_cache.gd").enabled=prepared
	var paint: Dictionary=VehicleLivery.defaults("compact")
	paint.colors.body="277ab1"
	var view: Control=load("res://ui/profile_car.gd").make_preview("compact",paint,VehicleCustomisation.defaults())
	view.header_template=true;view.size=Vector2(176,112)
	root.add_child(view)
	while not view.presentation_ready: await process_frame
	load("res://ui/profile_car.gd").apply_presentation(view)
	for _i: int in range(6):
		view.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	var image: Image=view.viewport.get_texture().get_image()
	check(image.save_png(output.path_join(label+".png"))==OK,"capture "+label)
	view.free()
	await process_frame
	return image
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	Engine.time_scale=0.0
	root.size=Vector2i(1280,720)
	var destination: String=OS.get_environment("BMT_PREPARED_EVIDENCE")
	check(not destination.is_empty(),"explicit evidence directory")
	output=destination
	DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(640,360);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	var camera:=Camera3D.new();stage.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.0
	camera.position=Vector3(5.4,3.8,-7.1);camera.look_at(Vector3(0,0.65,0));camera.current=true
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-58,-35,0);light.shadow_enabled=true;stage.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("647158")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("bac8ce");environment.environment.ambient_light_energy=0.35
	stage.add_child(environment)
	var floor:=MeshInstance3D.new();var floor_mesh:=PlaneMesh.new();floor_mesh.size=Vector2(24,24);floor.mesh=floor_mesh;floor.position.y=-0.02
	var material:=StandardMaterial3D.new();material.albedo_color=Color("73796c");material.roughness=1.0;floor.material_override=material;stage.add_child(floor)
	var base_output: String=output
	for vehicle: String in VehicleCatalog.IDS:
		var selections: Dictionary={}
		for category: String in VehicleCustomisation.CATEGORIES: selections[category]=VehicleCustomisation.options(category,vehicle)[1][0]
		for quality: bool in [false,true]:
			for edit: bool in [false,true]:
				simple=quality;editable=edit
				output=base_output.path_join(vehicle+"-"+("simple" if simple else "full")+("-editable" if editable else "-fixed"))
				DirAccess.make_dir_recursive_absolute(output)
				await compare_case(vehicle,false,selections)
		simple=false;editable=true
		output=base_output.path_join(vehicle+"-fitted");DirAccess.make_dir_recursive_absolute(output)
		await compare_case(vehicle,true,selections,true)
	output=base_output
	viewport.free()
	for vehicle: String in VehicleCatalog.IDS: await compare_garage(vehicle)
	var before: Image=await header(false,"header-procedural")
	var old_hits: int=preload("res://ui/header_simple_cache.gd").hits
	var after: Image=await header(true,"header-prepared")
	check(preload("res://ui/header_simple_cache.gd").hits==old_hits+1,"header uses prepared template")
	var control: Image=await header(false,"header-control")
	var row: Dictionary={"case":"compact-header","difference":difference(before,after),"control_difference":difference(before,control)}
	rows.append(row)
	visual_gate(row.control_difference,"header procedural repeat")
	visual_gate(row.difference,"header prepared")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"rows":rows},"  "))
	print("PREPARED_PIPELINE_VISUALS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

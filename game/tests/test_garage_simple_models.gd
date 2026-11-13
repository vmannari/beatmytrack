extends SceneTree
## GSM01-GSM04 / SMO02: actual App retention, all-five Garage models and custom controls.
var checks: int=0
var failures: int=0
var rows: Array=[]
var output: String="res://../docs/evidence/simple-models-only-2026-11-08/garage-headless"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("GARAGE_SIMPLE_FAIL ",label)
func frames(count: int=4) -> void:
	for _frame: int in range(count):await process_frame
func wait_garage(app: Node) -> GaragePage:
	var page: GaragePage=app._retained_garage
	var deadline: int=Time.get_ticks_msec()+90000
	while (not page.showroom.showroom_ready or (page.progressive_entry and page.showroom.preparing)) and Time.get_ticks_msec()<deadline:await process_frame
	check(page.showroom.showroom_ready,"actual Garage studio becomes ready")
	page.showroom.finish_car_transition()
	await frames(4)
	return page
func capture(view: CarShowroom,label: String) -> int:
	view.finish_car_transition();view.finish_kit_transition();view.finish_paint_transition()
	view.invalidate_render()
	if DisplayServer.get_name()=="headless":return 0
	for _frame: int in range(5):
		view.invalidate_render();view.reflections.request_draw()
		await RenderingServer.frame_post_draw
	var image: Image=view.showroom_viewport.get_texture().get_image()
	check(image.save_png(output.path_join(label+".png"))==OK,"native Garage capture "+label)
	return view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
func triangles(car: CarVisual) -> int:
	var count: int=0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or part.mesh==null:continue
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array=part.mesh.surface_get_arrays(surface)
			count+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	return count
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,720)
	var app: Node=load("res://core/app.tscn").instantiate()
	var folder: String="user://garage-simple"
	DirAccess.make_dir_recursive_absolute(folder)
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.records.settings={"music_enabled":false,"reduced_car_models":false,"selected_car":"compact","vehicle_liveries":{},"vehicle_customisation":{}}
	for id: String in VehicleCatalog.IDS:
		var paint: Dictionary=VehicleLivery.defaults(id)
		paint.colors.body="277ab1";paint.colors.accent="f0d58b"
		paint.pattern=LiveryCatalog.patterns[0].id
		paint.stickers.hood.id=LiveryCatalog.stickers[0].id
		app.records.settings.vehicle_liveries[id]=paint
		app.records.settings.vehicle_customisation[id]=VehicleCustomisation.defaults()
	check(app.records.save_records()==OK,"private valid Garage fixture saves")
	app.library=TrackLibrary.new(folder.path_join("tracks"));app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete:await process_frame
	var first_spec: Dictionary=app._garage_preloader._spec()
	app.records.settings.reduced_car_models=true
	var second_spec: Dictionary=app._garage_preloader._spec()
	check(first_spec==second_spec and second_spec.simple,"preloaded studio always pins reduced geometry")
	app._garage_preloader._sync_pictures()
	for id: String in app._garage_preloader.picture_service.warm_views:check(app._garage_preloader.picture_service.warm_views[id].simple_model,"warm carousel observes the changed quality "+id)
	app.records.settings.reduced_car_models=false
	app._garage_preloader._sync_pictures()
	for id: String in app._garage_preloader.picture_service.warm_views:check(app._garage_preloader.picture_service.warm_views[id].simple_model,"retired false preference leaves warm carousel reduced "+id)
	var old_loader: Node=load("res://../docs/evidence/garage-simple-models-2026-11-07/before/game/ui/garage_preloader.gd").new()
	var new_loader: Node=load("res://ui/garage_preloader.gd").new()
	for loader: Node in [old_loader,new_loader]:
		loader.app=app;root.add_child(loader);loader.set_process(false);loader.foreground=false;loader._process(0.0)
	check(old_loader._resources.is_empty() and new_loader._resources.is_empty() and not old_loader._allowed(false) and not new_loader._allowed(false),"archived and current preloaders both retain the foreground resource fence")
	old_loader.queue_free();new_loader.queue_free()
	VehicleCatalog.selected="compact"
	app._show_screen("garage")
	var page: GaragePage=await wait_garage(app)
	var retained_id: int=page.get_instance_id()
	check(page.showroom.car.simple_model,"reduced Garage is the production default with false preference")
	var camera_state: Array=[page.showroom.yaw,page.showroom.zoom,page.showroom.elevation]
	app._show_screen("settings");await frames(5)
	var settings: SettingsPage=app.root_ui.find_child("SettingsPage",true,false)
	settings._show_section("graphics")
	check(settings.find_child("SimpleCarModels",true,false)==null,"Graphics has no model selector")
	check(settings._apply(),"ordinary Settings Apply remains available")
	app._show_screen("garage")
	page=await wait_garage(app)
	check(page.get_instance_id()==retained_id and page.showroom.car.simple_model,"retained Garage adopts reduced quality on return")
	check([page.showroom.yaw,page.showroom.zoom,page.showroom.elevation]==camera_state,"quality switch preserves camera framing")
	for id: String in page.thumbnails:check(page.thumbnails[id].simple_model,"carousel selects the same quality "+id)
	var view: CarShowroom=page.showroom
	for id: String in VehicleCatalog.IDS:
		for fitted: bool in [false,true]:
			var parts: Dictionary=VehicleCustomisation.defaults()
			if fitted:
				for category: String in VehicleCustomisation.CATEGORIES:parts[category]=VehicleCustomisation.options(category,id)[-1][0]
			app.records.settings.vehicle_customisation[id]=parts
			page.preview_car(VehicleCatalog.IDS.find(id));view.finish_car_transition()
			page.refresh_cosmetics();view.finish_car_transition()
			check(view.car.simple_model and view.car.vehicle_id==id,"reduced quality survives car replacement "+id)
			var wear: Dictionary=view.weathering.snapshot();wear.dirt=0.22;wear.snow=0.12
			view.weathering.restore(wear)
			var counts: Array=[]
			for reduced: bool in [false,true]:
				var paint: Dictionary=view.livery.duplicate(true)
				var saved_wear: Dictionary=view.weathering.snapshot()
				var camera_before: Array=[view.yaw,view.zoom,view.elevation]
				view.apply_model_quality(reduced);view.finish_car_transition()
				check(view.car.simple_model==reduced and view.car.editable_kits,"quality uses editable native Garage car "+id)
				check(view.car.customisation==parts,"quality preserves fitted parts "+id+str(fitted)+str(reduced))
				check(view.car.livery==VehicleLivery.normalize(paint,id),"quality preserves saved livery "+id+str(fitted)+str(reduced))
				if view.car.customisation!=parts:print("GARAGE_PARTS_DIAGNOSTIC expected=",JSON.stringify(parts)," actual=",JSON.stringify(view.car.customisation)," showroom=",JSON.stringify(view.customisation))
				if view.car.livery!=paint:print("GARAGE_PAINT_DIAGNOSTIC expected=",JSON.stringify(paint)," actual=",JSON.stringify(view.car.livery))
				check(view.weathering.snapshot()==saved_wear,"quality retains exact dirt/snow/wash state "+id)
				check([view.yaw,view.zoom,view.elevation]==camera_before,"quality retains orbit and zoom "+id)
				check(view.reflections.enabled and view.reflections.views.size()==2,"both planar reflections retained "+id)
				var stored: int=triangles(view.car);counts.append(stored)
				for close: bool in [false,true]:
					view.zoom=0.52 if close else 1.0;view._orbit()
					var label: String=id+("-fitted" if fitted else "-stock")+("-reduced" if reduced else "-standard")+("-close" if close else "-normal")
					var primitives: int=await capture(view,label)
					rows.append({"case":label,"stored_car_triangles":stored,"main_view_primitives":primitives})
				view.zoom=1.0;view._orbit()
			check(counts[1]<counts[0]*0.8,"Garage reduced car has substantially fewer master triangles "+id)
			var identity: int=view.car.get_instance_id()
			view.apply_customisation(VehicleCustomisation.defaults(),true);view.finish_kit_transition()
			check(view.car.get_instance_id()==identity and view.car.simple_model,"editable kit replacement retains reduced car instance "+id)
			var recolour: Dictionary=view.livery.duplicate(true);recolour.colors.body="a1473b"
			view.apply_livery(recolour,true);view.finish_paint_transition()
			check(view.car.paint_materials.body.albedo_color==Color("a1473b"),"paint applies to reduced model "+id)
			view.apply_livery(VehicleLivery.for_car(app.records.settings,id))
			view.set_wash_mode(true);check(view.wash_mode and is_instance_valid(view.wash_effect),"wash tool opens on reduced model "+id);view.set_wash_mode(false)
	app.records.settings.reduced_car_models=false
	page.refresh_cosmetics();view.finish_car_transition()
	check(view.car.simple_model,"retained Garage ignores retired false preference")
	for id: String in page.thumbnails:check(page.thumbnails[id].simple_model,"carousel stays reduced with retired false preference "+id)
	app.queue_free();await frames(16)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))
	print("GARAGE_SIMPLE_MODELS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

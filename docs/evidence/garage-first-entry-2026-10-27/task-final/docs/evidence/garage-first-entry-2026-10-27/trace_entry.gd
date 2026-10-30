extends SceneTree
var output: String
var app: Node
var samples: Array[Dictionary]=[]
var last_frame: int=0
var draw_start: int=0
var draw_ms: float=0
var phase: String="startup"
var metrics: Dictionary={}
var _warm_seen: Dictionary={}
var _warm_count: int=-1

func _initialize() -> void:
	if "--early-shared" in OS.get_cmdline_user_args(): load("res://../docs/evidence/garage-first-entry-2026-10-27/early_shared.gd").install()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if "--task-start" in OS.get_cmdline_user_args():
		for path: String in ["ui/garage_preloaded_studio.gd","ui/garage_preloader.gd","ui/garage_preview_cache.gd","ui/garage_page.gd"]:
			var script: Script=load("res://"+path)
			script.source_code=FileAccess.get_file_as_string("res://../docs/evidence/garage-first-entry-2026-10-27/before/game/"+path)
			assert(script.reload(true)==OK)
	process_frame.connect(sample)
	RenderingServer.frame_pre_draw.connect(func() -> void: draw_start=Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: draw_ms=(Time.get_ticks_usec()-draw_start)/1000.0)
	run.call_deferred()

func sample() -> void:
	var now: int=Time.get_ticks_usec()
	var row: Dictionary={"time_ms":now/1000.0,"frame_ms":(now-last_frame)/1000.0 if last_frame else 0,"draw_ms":draw_ms,"phase":phase}
	last_frame=now
	if is_instance_valid(app):
		var loader: Node=app.get("_garage_preloader")
		if is_instance_valid(loader) and is_instance_valid(loader.studio):
			row.warm_draws=loader.studio.warm_draws
			row.constructed=loader.studio.showroom_ready
			if _warm_count!=loader.studio.warm_draws:
				_warm_count=loader.studio.warm_draws
				var fresh: Array=[]
				for entry: Dictionary in loader.studio._held:
					var node: Object=entry.node.get_ref()
					if not is_instance_valid(node) or not node.visible or _warm_seen.has(node.get_instance_id()): continue
					_warm_seen[node.get_instance_id()]=true
					var material: Material=node.get_active_material(0) if node is MeshInstance3D else node.material_override
					fresh.append({"node":str(node.get_path()),"material":material.get_class() if material!=null else "none","shader":material.shader.resource_path if material is ShaderMaterial and material.shader!=null else ""})
				row.fresh=fresh
		var page: GaragePage=app._retained_garage
		if is_instance_valid(page) and is_instance_valid(page.showroom):
			row.main_size=str(page.showroom.showroom_viewport.size)
			row.preview_renders=page._preview_service.renders
			row.preview_active=not page._preview_service.active.is_empty()
			row.transition=app.menu_page_motion!=null
	samples.append(row)

func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://core/app.tscn").instantiate()
	var folder: String="user://entry-"+TrackLibrary.unique_id()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	var began: int=Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._publishing_slots_foreground=true
	metrics.startup_ms=(Time.get_ticks_usec()-began)/1000.0
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false;music.menu_player.stop();music.menu_player.stream=null
	var paint: Dictionary=VehicleLivery.defaults("compact")
	paint.colors.body="c72d34";paint.pattern=LiveryCatalog.patterns[0].id
	paint.stickers.hood.id=LiveryCatalog.stickers[0].id
	if "--stock" in OS.get_cmdline_user_args(): paint=VehicleLivery.defaults("compact")
	app.records.settings.vehicle_liveries={"compact":paint}
	var wear: Dictionary=VehicleWeathering.new().snapshot()
	wear.dirt=0.2;wear.slow_dirt=0.1
	if "--stock" in OS.get_cmdline_user_args(): wear=VehicleWeathering.new().snapshot()
	assert(app.records.save_vehicle_conditions({"compact":wear})==OK)
	VehicleCatalog.selected="compact"
	app._garage_appearance_changed()
	app._show_screen("tracks")
	var loader: Node=app._garage_preloader
	loader.foreground=true
	phase="preload"
	var deadline: int=Time.get_ticks_msec()+120000
	if "--prepared" in OS.get_cmdline_user_args():
		while (loader.studio==null or not loader.studio.prepared) and Time.get_ticks_msec()<deadline: await process_frame
	else:
		while app.menu_page_motion!=null: await process_frame
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--entry-delay="):
				var until: int=Time.get_ticks_msec()+int(argument.trim_prefix("--entry-delay="))
				while Time.get_ticks_msec()<until: await process_frame
	metrics.preload_ready=loader.studio!=null and loader.studio.prepared
	metrics.preload_warm_draws=loader.studio.warm_draws if loader.studio!=null else 0
	phase="entry"
	began=Time.get_ticks_usec()
	app._show_screen("garage")
	metrics.entry_callback_ms=(Time.get_ticks_usec()-began)/1000.0
	var page: GaragePage=app._retained_garage
	if "--shared-finishes" in OS.get_cmdline_user_args():
		load("res://../docs/evidence/garage-first-entry-2026-10-27/prototype_finish.gd").apply(page.showroom)
		page._preview_service.can_render=func() -> bool: return false
	for argument: String in OS.get_cmdline_user_args():
		if argument in ["--car-only","--room-only"]:
			for node: GeometryInstance3D in page.showroom.camera.get_parent().find_children("*","GeometryInstance3D",true,false):
				var car_part: bool=page.showroom.car.is_ancestor_of(node)
				if car_part!=(argument=="--car-only"): node.hide()
			page._preview_service.can_render=func() -> bool: return false
	if "--no-preview" in OS.get_cmdline_user_args(): page._preview_service.can_render=func() -> bool: return false
	while app.menu_page_motion!=null: await process_frame
	metrics.transition_ms=(Time.get_ticks_usec()-began)/1000.0
	phase="live"
	var until: int=Time.get_ticks_msec()+4000
	while Time.get_ticks_msec()<until: await process_frame
	phase="orbit"
	var yaw: float=page.showroom.yaw
	var motion:=InputEventMouseMotion.new()
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.relative=Vector2(40,0)
	page.showroom.gui_input.emit(motion)
	metrics.orbit_changed=page.showroom.yaw!=yaw
	for _i: int in range(12): await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("live.png"))
	metrics.preview_renders=page._preview_service.renders
	metrics.saved_paint=page.showroom.car.livery==paint
	metrics.reflections=page.showroom.reflections.views.size()
	metrics.samples=samples
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	metrics.erase("samples")
	print("ENTRY_TRACE ",JSON.stringify(metrics))
	app.queue_free()
	for _i: int in range(24): await process_frame
	quit()

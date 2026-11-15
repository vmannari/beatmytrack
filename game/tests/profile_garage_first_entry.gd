extends SceneTree
## Actual first Garage entry, including the full live room and both reflections.
var output: String="res://../build/garage-first-entry-2026-11-14/manual"
var app: Node
var events: Array[Dictionary] = []
var started: int

func _initialize() -> void:
	if "--before" in OS.get_cmdline_user_args():
		for file: String in ["graphics_preparation.gd","garage_first_draw.gd","garage_opening_showroom.gd","garage_preloader.gd"]:
			var folder: String="rendering" if file=="graphics_preparation.gd" else "ui"
			var script: Script=load("res://"+folder+"/"+file)
			script.source_code=FileAccess.get_file_as_string("res://../docs/evidence/garage-first-entry-2026-11-14/before/"+file+".txt")
			assert(script.reload(true)==OK)
	if "--cpu" in OS.get_cmdline_user_args():
		var first: Script=load("res://ui/garage_first_draw.gd")
		var source: String=first.source_code
		source=source.replace("func hold(world: Node) -> void:","func hold(world: Node) -> void:\n\tvar cpu: int=Time.get_ticks_usec()")
		source=source.replace("\nfunc release()", "\n\tprint(\"HOLD_CPU \",(Time.get_ticks_usec()-cpu)/1000.0,\" nodes=\",pending.size())\n\nfunc release()")
		source=source.replace("\t\tvar camera: Camera3D = get_parent()", "\t\tvar cpu: int=Time.get_ticks_usec()\n\t\tvar camera: Camera3D = get_parent()")
		source=source.replace("\t\tvar began: int = Time.get_ticks_usec()", "\t\tprint(\"WARM_CPU \",(Time.get_ticks_usec()-cpu)/1000.0,\" remaining=\",pending.size(),\" groups=\",groups.size())\n\t\tvar began: int = Time.get_ticks_usec()")
		first.source_code=source
		assert(first.reload(true)==OK)
	run.call_deferred()

func mark(label: String) -> void:
	var row: Dictionary = {"stage":label,"ms":(Time.get_ticks_usec()-started)/1000.0}
	events.append(row)
	print("GARAGE_ENTRY_STAGE ",JSON.stringify(row))

func run() -> void:
	var id: String="compact"
	var fitted: bool=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--vehicle="): id=arg.trim_prefix("--vehicle=")
		if arg=="--fitted": fitted=true
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	OS.set_environment("BMT_API_URL","")
	root.size=Vector2i(1280,720)
	app=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new("user://probe/records.json")
	var parts: Dictionary=VehicleCustomisation.defaults()
	if fitted:
		for category: String in VehicleCustomisation.CATEGORIES: parts[category]=VehicleCustomisation.options(category,id)[1][0]
	app.library=TrackLibrary.new("user://probe/tracks")
	app.cloud_root_override="user://probe/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	# App owns loading its records. Seed the private fixture after that load.
	app.records.settings.selected_car=id
	app.records.settings.vehicle_customisation={}
	app.records.settings.vehicle_customisation[id]=parts
	VehicleCatalog.selected=id
	app._garage_appearance_changed()
	app._publishing_slots_foreground=true
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false
	music.menu_player.stop()
	music.menu_player.stream=null
	app._show_screen("tracks")
	for _i: int in range(2): await process_frame
	started=Time.get_ticks_usec()
	app._show_screen("garage")
	mark("navigation_returned")
	var page: GaragePage=app._retained_garage
	var studio: CarShowroom=page.showroom
	var previous: String=""
	var maximum: float=0
	var frames: int=0
	var deadline: int=Time.get_ticks_msec()+120000
	while studio.get("preparing")==true and Time.get_ticks_msec()<deadline:
		var stage: String="waiting"
		if studio.car!=null:
			stage="building_car" if not studio.car.model_ready else "building_room" if not studio.showroom_ready else "warming" if studio.get("_first")!=null else "settling"
		if stage!=previous: mark(stage);previous=stage
		var tick: int=Time.get_ticks_usec()
		await process_frame
		maximum=maxf(maximum,(Time.get_ticks_usec()-tick)/1000.0)
		frames+=1
	mark("live_ready")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("live.png"))
	var report: Dictionary={"events":events,"max_frame_ms":maximum,"frames":frames,"garage_cache_hits":preload("res://ui/garage_car_cache.gd").hits,"ready":studio.showroom_ready and studio.get("preparing")!=true}
	report.vehicle=id
	report.actual_vehicle=studio.car.vehicle_id
	report.fitted=fitted
	report.selection_matches=studio.car.vehicle_id==id and studio.car.customisation==parts
	report.kit_hits=preload("res://vehicle/modular_car_kits.gd").hits
	report.base_hits=preload("res://vehicle/modular_car_base.gd").hits
	var base: Script=load("res://vehicle/modular_car_base.gd")
	var holder: Node=load(base.path_for(studio.car)).instantiate()
	var data: Dictionary=holder.get_meta("modular_car_base",{})
	report.base_key_matches=data.get("key",[])==base.key_for(studio.car)
	report.base_source_differences=[]
	var validation: Script=load("res://vehicle/prepared_asset_sources.gd")
	var saved: Dictionary=validation.runtime_projection(data.get("sources",{}))
	var current: Dictionary=validation.runtime_hashes(studio.car.model_id)
	for path: String in current:
		if saved.get(path)!=current[path]: report.base_source_differences.append(path)
	holder.free()
	app._show_screen("settings")
	started=Time.get_ticks_usec()
	app._show_screen("garage")
	report.reentry_ms=(Time.get_ticks_usec()-started)/1000.0
	report.same_studio=page.showroom==studio
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GARAGE_FIRST_ENTRY_PROFILE ",JSON.stringify(report))
	app.queue_free()
	for _i: int in range(20): await process_frame
	quit(0 if report.ready and report.same_studio and report.selection_matches else 1)

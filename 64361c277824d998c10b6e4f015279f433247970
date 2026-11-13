extends SceneTree
var view: Node
var app: Node
var destination: String
var variant: String="original"
var scope: String="standalone"
var frames: Array[Dictionary]=[]
var last_tick: int=0
var pre_tick: int=0
var phase: String="startup"
var checks: int=0
var failures: int=0
var lab: String="res://../build/cold-render-investigation-2026-10-27"

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL ",label)
func stamp() -> int: return int(Time.get_unix_time_from_system()*1000000.0)
func on_frame() -> void:
	var now: int=Time.get_ticks_usec()
	if last_tick>0 and frames.size()<3000: frames.append({"utc_us":stamp(),"phase":phase,"frame_us":now-last_tick})
	last_tick=now
func on_pre() -> void: pre_tick=Time.get_ticks_usec()
func on_post() -> void:
	if not frames.is_empty(): frames[-1].draw_us=Time.get_ticks_usec()-pre_tick
func pipeline_counts() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)]

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): destination=argument.trim_prefix("--output=")
		if argument.begins_with("--variant="): variant=argument.trim_prefix("--variant=")
		if argument.begins_with("--scope="): scope=argument.trim_prefix("--scope=")
	var config:=ConfigFile.new();config.set_value("backend","url","");assert(config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")
	root.size=Vector2i(1280,720)
	Engine.max_fps=60
	if variant in ["parallel_hint","trace_link"]:
		check(GDExtensionManager.load_extension(lab.path_join("parallel_probe.gdextension"))==GDExtensionManager.LOAD_STATUS_OK,"diagnostic parallel compiler extension loads")
	# Only this owned process's GDScript resources are reloaded. Source files,
	# owner processes and their resources are never changed.
	for path: String in ["ui/showroom_studio.gd","ui/garage_environment.gd","ui/garage_reflections.gd","ui/car_showroom.gd","ui/garage_preloaded_studio.gd","ui/garage_preloader.gd","core/app.gd"]:
		var script: GDScript=load("res://"+path)
		script.source_code=FileAccess.get_file_as_string(lab.path_join("frozen").path_join(path))
		check(script.reload(true)==OK,"frozen script reload "+path)
	process_frame.connect(on_frame)
	RenderingServer.frame_pre_draw.connect(on_pre)
	RenderingServer.frame_post_draw.connect(on_post)
	var start: int=Time.get_ticks_usec()
	if scope=="app":
		app=load("res://core/app.tscn").instantiate()
		var folder: String="user://cold-render-fixture"
		app.records=LocalRecords.new(folder.path_join("records.json"));app.library=TrackLibrary.new(folder.path_join("tracks"));app.cloud_root_override=folder.path_join("cloud")
		root.add_child(app)
		while not app.startup_complete: await process_frame
		app._publishing_slots_foreground=true
		app._garage_preloader.foreground=true
		while app._garage_preloader.studio==null: await process_frame
		view=app._garage_preloader.studio
		view._diag_case=variant
	else:
		view=load("res://ui/garage_preloaded_studio.gd").new()
		view._diag_case=variant
		view.vehicle_id="compact";view.garage_mode=true;view.framing_scale=0.84
		view.size=Vector2(1168,360)
		view.permitted=func() -> bool: return true
		root.add_child(view)
	phase="construction"
	var deadline: int=Time.get_ticks_msec()+120000
	while not view._diag_ready and Time.get_ticks_msec()<deadline: await process_frame
	check(view._diag_ready,"original studio completes CPU construction")
	var ready_us: int=Time.get_ticks_usec()-start
	var initial: Dictionary={"held":view._held.size(),"pending":view._pending.size(),"key_set":{},"pipeline":pipeline_counts()}
	for entry: Dictionary in view._pending: initial["key_set"][entry.key]=true
	initial["unique_keys"]=initial["key_set"].size();initial.erase("key_set")
	if variant.begins_with("representatives"):
		var seen: Dictionary={};var remaining: Array[Dictionary]=[]
		for entry: Dictionary in view._pending:
			if seen.has(entry.key): continue
			seen[entry.key]=true;remaining.append(entry)
		view._pending=remaining
	if variant=="sky_incremental":
		for environment: WorldEnvironment in view.camera.get_parent().find_children("*","WorldEnvironment",true,false):
			if environment.environment.sky!=null: environment.environment.sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	phase="warming"
	if variant=="prime_empty": await view._diag_interval("empty",-1)
	if scope!="app": view.warm()
	while not view.prepared and Time.get_ticks_msec()<deadline:
		if variant=="trace_link" and FileAccess.file_exists(lab.path_join("shader-source/captured.frag")): break
		await process_frame
	if variant=="trace_link":
		view.permitted=func() -> bool: return false
		check(FileAccess.file_exists(lab.path_join("shader-source/captured.frag")),"native generated spatial shader source captured")
		view.queue_free();view=null
		for index: int in range(32): await process_frame
		print("SOURCE_CAPTURE_RESULT ",checks," checks, ",failures," failures")
		quit(1 if failures else 0)
		return
	check(view.prepared,"original finishes, reflection and carousel phases complete")
	var prepared_us: int=Time.get_ticks_usec()-start
	check(view.carousel_texture!=null,"original carousel capture is ready before transfer")
	phase="adoption"
	if app!=null:
		app._show_screen("garage")
		check(app._retained_garage.showroom==view,"actual App adopts the exact prepared world")
	else: view.adopt()
	check(view._held.is_empty() and view._pending.is_empty(),"handoff releases held preparation state")
	check(view._thumbnail_state.is_empty() and not view.read_only,"handoff restores original live mode")
	check(view.reflections.views.size()==2 and view.showroom_viewport.msaa_3d==Viewport.MSAA_4X,"two original reflections and live MSAA remain")
	for index: int in range(12): await process_frame
	var yaw: float=view.yaw
	var drag:=InputEventMouseMotion.new();drag.button_mask=MOUSE_BUTTON_MASK_LEFT;drag.relative=Vector2(12,0)
	view.gui_input.emit(drag)
	check(view.yaw!=yaw,"adopted original studio orbit works")
	for index: int in range(6): await process_frame
	var target: String=ProjectSettings.globalize_path(destination)
	DirAccess.make_dir_recursive_absolute(target)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(target.path_join("final.png"))
	view.showroom_viewport.get_texture().get_image().save_png(target.path_join("studio.png"))
	var result: Dictionary={"scope":scope,"variant":variant,"checks":checks,"failures":failures,"ready_us":ready_us,"prepared_us":prepared_us,"initial":initial,"draws":view._diag_rows,"frames":frames,"final_pipeline":pipeline_counts(),"dimensions":view.showroom_viewport.size}
	FileAccess.open(target.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("COLD_RENDER_RESULT ",JSON.stringify({"variant":variant,"scope":scope,"checks":checks,"failures":failures,"ready_ms":ready_us/1000.0,"prepared_ms":prepared_us/1000.0,"warm_draws":view.warm_draws}))
	if app!=null: app.queue_free()
	else: view.queue_free()
	view=null;app=null
	for index: int in range(24): await process_frame
	quit(1 if failures else 0)

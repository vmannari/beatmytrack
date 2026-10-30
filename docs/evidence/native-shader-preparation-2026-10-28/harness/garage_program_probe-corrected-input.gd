extends SceneTree
var app: Node
var mode: String
var output: String
var lab: String="res://../build/native-shader-preparation-2026-10-28"
var phase: String="startup"
var frames: Array[Dictionary]=[]
var responses: Array[Dictionary]=[]
var last: int=0
var pre_draw: int=0
var epoch: int=0
var monotonic_epoch: int=0
var checks: int=0
var failures: int=0
var pulse: Button
func _initialize() -> void: run.call_deferred()
func utc() -> int: return epoch+Time.get_ticks_usec()-monotonic_epoch
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func tick() -> void:
	var now: int=Time.get_ticks_usec()
	if last>0 and frames.size()<20000: frames.append({"utc_us":utc(),"phase":phase,"frame_us":now-last})
	last=now
func before_draw() -> void: pre_draw=Time.get_ticks_usec()
func after_draw() -> void:
	if not frames.is_empty(): frames[-1].draw_us=Time.get_ticks_usec()-pre_draw
func set_phase(value: String,inputs: bool=false) -> void:
	phase=value
	var state: Dictionary={"phase":phase,"enabled":inputs,"pid":OS.get_process_id(),"hwnd":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)}
	FileAccess.open(output.path_join("pulse-state.json"),FileAccess.WRITE).store_string(JSON.stringify(state))
func clicked() -> void:
	responses.append({"utc_us":utc(),"phase":phase})
	pulse.text="Probe "+str(responses.size())
func run() -> void:
	mode=OS.get_environment("BMT_PREP_MODE")
	output=OS.get_environment("BMT_PREP_OUTPUT")
	epoch=int(Time.get_unix_time_from_system()*1000000.0);monotonic_epoch=Time.get_ticks_usec()
	var config:=ConfigFile.new();config.set_value("backend","url","");assert(config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")
	root.size=Vector2i(1280,720);Engine.max_fps=60
	check(GDExtensionManager.load_extension(lab.path_join("program_probe.gdextension"))==GDExtensionManager.LOAD_STATUS_OK,"owned diagnostic extension loads")
	process_frame.connect(tick);RenderingServer.frame_pre_draw.connect(before_draw);RenderingServer.frame_post_draw.connect(after_draw)
	app=load("res://core/app.tscn").instantiate()
	var folder: String="user://program-preparation-fixture"
	app.records=LocalRecords.new(folder.path_join("records.json"));app.library=TrackLibrary.new(folder.path_join("tracks"));app.cloud_root_override=folder.path_join("cloud")
	app.records.settings.music_enabled=false
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var loader: Node=app._garage_preloader
	loader.foreground=false
	VehicleCatalog.selected="compact"
	app._show_screen("tracks")
	while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await process_frame
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false;music.menu_player.stop();music.menu_player.stream=null
	pulse=Button.new();pulse.position=Vector2(1030,8);pulse.size=Vector2(220,48);pulse.text="Probe 0123456789";pulse.pressed.connect(clicked);root.add_child(pulse)
	for index: int in range(8): await process_frame
	set_phase("menu",true)
	for index: int in range(30): await process_frame
	if mode=="import":
		set_phase("worker",true)
		var worker: String=ProjectSettings.globalize_path(lab.path_join("shader_worker.exe"))
		var pid: int=OS.create_process(worker,[OS.get_environment("BMT_PREP_JOBS"),OS.get_environment("BMT_PREP_BINARIES")],false)
		check(pid>0,"start the owned separate compiler process")
		FileAccess.open(output.path_join("worker-pid.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":pid,"parent":OS.get_process_id()}))
		var deadline: int=Time.get_ticks_msec()+120000
		while OS.is_process_running(pid) and Time.get_ticks_msec()<deadline: await process_frame
		if OS.is_process_running(pid): OS.kill(pid);check(false,"compiler completes before timeout")
		var result_path: String=OS.get_environment("BMT_PREP_BINARIES").path_join("worker-result.json")
		var result: Variant=JSON.parse_string(FileAccess.get_file_as_string(result_path))
		check(result is Dictionary and result.get("success",false),"compiler produces the complete captured program inventory")
	set_phase("warming",false)
	loader.foreground=true
	var deadline: int=Time.get_ticks_msec()+120000
	while (loader.studio==null or not loader.studio.prepared) and Time.get_ticks_msec()<deadline: await process_frame
	check(loader.studio!=null and loader.studio.prepared,"actual App's original Garage completes native preparation")
	if loader.studio!=null and loader.studio.prepared:
		var view: Node=loader.studio
		set_phase("entry",false)
		app._show_screen("garage")
		check(app._retained_garage.showroom==view,"App adopts the exact original prepared world")
		for index: int in range(20): await process_frame
		check(view.reflections.views.size()==2 and view.showroom_viewport.msaa_3d==Viewport.MSAA_4X,"original reflections and four-sample live rendering remain")
		await RenderingServer.frame_post_draw
		view.showroom_viewport.get_texture().get_image().save_png(output.path_join("studio.png"))
		root.get_texture().get_image().save_png(output.path_join("app.png"))
		var yaw: float=view.yaw
		var drag:=InputEventMouseMotion.new();drag.button_mask=MOUSE_BUTTON_MASK_LEFT;drag.relative=Vector2(12,0)
		view.gui_input.emit(drag)
		check(view.yaw!=yaw,"real live Garage orbit remains connected")
	set_phase("teardown",false)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"mode":mode,"checks":checks,"failures":failures,"frames":frames,"responses":responses,"static_memory_bytes":OS.get_static_memory_usage()},"  "))
	app.queue_free();app=null;pulse.queue_free();pulse=null
	for index: int in range(32): await process_frame
	print("GARAGE_PROGRAM_PROBE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

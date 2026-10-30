extends SceneTree
## Actual App races: every car/theme, then cancellation inside particle staging.
const EFFECTS = preload("res://vehicle/effect_render_preparation.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var mode: String = ""
var interrupted: bool = false
var observed: bool = false
var cases: Array[Dictionary] = []
var frozen: bool = true
var largest_first_group: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)

func observe() -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.game) or not is_instance_valid(app.race_loading): return
	var game: Node=app.game
	var world: Node=game.get_node_or_null("World")
	if world==null: return
	var proxies: Array=world.find_children("Covered*","GPUParticles3D",true,false)
	if proxies.is_empty(): return
	if not observed: largest_first_group=maxi(largest_first_group,proxies.size())
	observed=true
	frozen=frozen and game.sim.state.tick==0 and game.track_session.elapsed_ticks==0 and game.countdown_ticks==360 and game.trails.cursor==0 and game.trails.instances.visible_instance_count==0 and game.trails.instances.instance_count==16384
	if interrupted or mode=="complete": return
	interrupted=true
	match mode:
		"navigation": app._show_screen("settings")
		"car": VehicleCatalog.selected="kart"
		"selection": app.selected_track=NativeTrack.new()
		"scope": app.online.client.configure("http://127.0.0.1:1")
		"pressure": app.notification(NOTIFICATION_OS_MEMORY_WARNING)
		"teardown": app.queue_free()

func first_emission(game: Node) -> void:
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for _frame: int in range(3): await process_frame
	var state: Dictionary=RewindHistory.properties(game.sim.state)
	var originals: Array[Dictionary]=[]
	var before: float=Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
	var began: int=Time.get_ticks_usec()
	for source: GPUParticles3D in game.sand_dust.get_children():
		originals.append({"source":source,"pose":source.transform,"ratio":source.amount_ratio,"speed":source.speed_scale,"emitting":source.emitting})
		source.global_position=game.camera.global_position-game.camera.global_basis.z*10.0
		source.amount_ratio=1.0;source.speed_scale=1.0;source.emitting=true
	for _frame: int in range(3): await process_frame;await RenderingServer.frame_post_draw
	var compilations: float=Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)-before
	if RenderingServer.get_current_rendering_method()!="gl_compatibility": check(compilations==0,"first real emission in the actual lit App world needs no new draw pipeline")
	check(RewindHistory.properties(game.sim.state)==state,"first-emission observation leaves canonical state unchanged")
	cases[-1].first_emission={"three_draws_ms":(Time.get_ticks_usec()-began)/1000.0,"new_draw_pipelines":compilations}
	for original: Dictionary in originals:
		original.source.restart(true);original.source.emitting=original.emitting
		original.source.transform=original.pose;original.source.amount_ratio=original.ratio;original.source.speed_scale=original.speed

func race(vehicle: String, theme: String, interruption: String="complete") -> void:
	VehicleCatalog.selected=vehicle
	app.online.client.configure("")
	app._show_screen("tracks")
	var track: NativeTrack=NativeTrack.read("res://resources/tracks/ellipse.json")
	track.metadata.theme=theme
	track.metadata.cloud_version="owned-staged-effects"
	app.selected_track=track
	mode=interruption;interrupted=false;observed=false;frozen=true;largest_first_group=0
	var revealed: Dictionary={}
	var began: int=Time.get_ticks_usec()
	app._start_race(track,false,true)
	if is_instance_valid(app.race_loading):
		app.race_loading.tree_exiting.connect(func() -> void:
			if is_instance_valid(app) and is_instance_valid(app.game):
				revealed.tick=app.game.sim.state.tick;revealed.countdown=app.game.countdown_ticks)
	var deadline: int=Time.get_ticks_msec()+120000
	while is_instance_valid(app) and app.cloud_starting and Time.get_ticks_msec()<deadline: await process_frame
	if interruption=="teardown":
		for _frame: int in range(8): await process_frame
		check(interrupted and not is_instance_valid(app),"App teardown retires active particle preparation")
		return
	check(observed,"actual loading reached the staged particle draw")
	check(frozen,"all staged draws preserve canonical tick, elapsed ticks, countdown and full empty trail ring")
	check(largest_first_group==1,"actual App adds only one particle proxy before its first covered draw")
	if interruption in ["complete","pressure"]:
		check(is_instance_valid(app.game) and not app.cloud_starting,"actual car/theme preparation completes")
		if is_instance_valid(app.game):
			app.game.set_physics_process(false)
			check(revealed.get("tick",-1)==0 and revealed.get("countdown",-1)==360,"actual reveal retains tick zero and complete countdown")
			check(app.game.effects_prepared and app.game.effect_preparation_counts.particles==app.game.sand_dust.get_child_count(),"every actual source emitter is prepared before reveal")
			check(app.game.get_node("World").find_children("Covered*","",true,false).is_empty(),"actual race contains no temporary preparation nodes")
			var source_emission: bool=false
			for source: GPUParticles3D in app.game.sand_dust.get_children(): source_emission=source_emission or source.emitting
			check(not source_emission,"preparing proxies starts no live emission")
			cases.append({"vehicle":vehicle,"theme":theme,"mode":interruption,"wall_ms":(Time.get_ticks_usec()-began)/1000.0,"counts":app.game.effect_preparation_counts.duplicate(true),"cache_bytes":EFFECTS.cache_bytes(app)})
			if interruption=="pressure": check(EFFECTS.cache_bytes(app)==0,"App pressure evicts idle entries and forbids retaining in-flight nodes")
			if "--first-emission" in OS.get_cmdline_user_args(): await first_emission(app.game)
			app._leave_race()
	else:
		for _frame: int in range(8): await process_frame
		check(interrupted and app.game==null and not app.cloud_starting and not is_instance_valid(app.race_loading),"staged cancellation cannot attach or activate abandoned graphics")
	for _frame: int in range(4): await process_frame

func run() -> void:
	if DisplayServer.get_name()=="headless": print("Native graphical test required");quit(1);return
	root.size=Vector2i(960,540)
	var folder: String="user://effect-loading-"+TrackLibrary.unique_id()
	app=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled=false
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	process_frame.connect(observe)
	for vehicle: String in VehicleCatalog.IDS: await race(vehicle,"pine")
	for theme: String in TrackTheme.IDS:
		if theme!="pine": await race("compact",theme)
	for interruption: String in ["navigation","car","selection","scope","pressure","teardown"]:
		await race("compact","pine",interruption)
	process_frame.disconnect(observe)
	for _frame: int in range(24): await process_frame
	var output: String="res://../build/runtime-loading-fixes-2026-10-27/app-effects-"+RenderingServer.get_current_rendering_method()+".json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"  "))
	print("RUNTIME_EFFECT_LOADING ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

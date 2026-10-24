extends SceneTree
const WORLDS = preload("res://track/prepared_world_cache.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var done: bool = false
var frames: int = 0
var interrupted: bool = false
var kind: String = ""
var original_car: String
var original_url: String
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func start(track: NativeTrack) -> void:
	await app._start_race(track,false,true)
	done = true
func observe() -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.game) or app.game.preparation_complete: return
	frames += 1
	var game: Node = app.game
	check(game.process_mode == Node.PROCESS_MODE_DISABLED and game.sim.state.tick == 0 and game.countdown_ticks == 360,"installation cannot advance simulation/countdown")
	check(is_instance_valid(app.race_loading) and not app.root_ui.visible,"loading cover owns incomplete world")
	game._physics_process(VehicleSimulation.STEP); game._process(0.0)
	var key := InputEventKey.new(); key.pressed = true; key.physical_keycode = KEY_C
	game._unhandled_key_input(key); game._unhandled_input(key)
	game.toggle_pause(); app._results(); app._complete_draft_test()
	check(game.sim.state.tick == 0 and game.online_frames.is_empty(),"manual callbacks also respect readiness barrier")
	if interrupted or kind.is_empty(): return
	interrupted = true
	match kind:
		"background": game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		"foreground_return": game._notification(Node.NOTIFICATION_APPLICATION_PAUSED); game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		"navigation": app._show_screen("garage")
		"car": VehicleCatalog.selected = "kart"
		"selection": app.selected_track = NativeTrack.new()
		"scope": app.online.client.configure("https://cancelled-install.invalid")
		"deadline": app._race_loading_timed_out(app.race_loading.get_instance_id())
		"teardown": app.queue_free()
func fixture(theme: String, suffix: String) -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_default(); doc.theme = theme
	for index: int in range(48): doc.objects.append({"kind":"cone","position":[-32+(index%12)*5,20+(index/12)*5],"rotation":0})
	var track: NativeTrack = TrackCompiler.compile(doc)
	track.content_hash += suffix
	track.metadata.cloud_version = "cooperative-fixture-"+suffix
	return track
func race(track: NativeTrack) -> void:
	app._show_screen("tracks"); app.selected_track = track
	done = false; interrupted = false; frames = 0
	start(track)
	var deadline: int = Time.get_ticks_msec()+60000
	while not done and is_instance_valid(app) and Time.get_ticks_msec()<deadline: await process_frame
	check(done or kind == "teardown","race coroutine settles before deadline")
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var folder: String = "user://cooperative_install_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder); app.records = LocalRecords.new(folder.path_join("records.json")); app.cloud_root_override = folder.path_join("cloud")
	NativeTrackVisual.ROAD_DISK_CACHE.directory = folder.path_join("roads")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	original_car = VehicleCatalog.selected; original_url = app.online.client.base_url()
	process_frame.connect(observe)
	for theme: String in TrackTheme.IDS:
		kind = ""
		var track: NativeTrack = fixture(theme,theme)
		WORLDS.entries.clear()
		await race(track)
		check(frames > 0,theme+" cold installation yields to the UI")
		check(is_instance_valid(app.game) and app.game.preparation_complete and app.game.track_ground.world_built,theme+" exposes complete world and controls")
		check(not is_instance_valid(app.race_loading) and app.game.countdown_ticks == 360,theme+" releases cover with full countdown")
		check(app.game.track_session.target_laps == 5 and app.game.sim.state.tick == 0,theme+" preserves five-lap start state")
		var signature: Array = visual_signature(app.game.track_ground)
		var cold_frames: int = frames
		app._leave_race(); await process_frame
		await race(track)
		var restored_signature: Array = visual_signature(app.game.track_ground)
		if restored_signature != signature: print("COOPERATIVE_SIGNATURE_DIFF ",theme," ",first_difference(signature,restored_signature,"world")," cache_entries=",WORLDS.entries.size())
		check(restored_signature == signature,theme+" cached cooperative world preserves exact resources, placement and groups")
		print("COOPERATIVE_INSTALL_THEME ",theme," cold_frames=",cold_frames," cached_frames=",frames)
		app._leave_race(); await process_frame
	for mode: String in ["background","foreground_return"]:
		kind = mode; WORLDS.entries.clear()
		await race(fixture("pine",mode))
		check(interrupted and app.game.preparation_complete,"focus event is retained during installation: "+mode)
		check(app.game.paused == (mode == "background"),"unfinished background load pauses at activation, early return stays ready: "+mode)
		check(app.game.sim.state.tick == 0 and app.game.countdown_ticks == 360,"focus transition preserves full countdown and start state")
		app._leave_race(); await process_frame
	for mode: String in ["navigation","car","selection","scope","deadline","teardown"]:
		kind = mode
		WORLDS.entries.clear()
		await race(fixture("pine",mode))
		for frame: int in range(4): await process_frame
		check(interrupted,mode+" interrupts inside actual visual installation")
		if mode == "teardown":
			check(not is_instance_valid(app),"teardown releases partially prepared race and owner")
			break
		check(app.game == null and not is_instance_valid(app.race_loading) and not app.cloud_starting,mode+" discards incomplete race without stale activation")
		check(app.root_ui.visible,mode+" restores usable menu")
		check(WORLDS.entries.is_empty(),mode+" cannot publish incomplete world cache")
		VehicleCatalog.selected = original_car; app.online.client.configure(original_url)
	WORLDS.entries.clear()
	process_frame.disconnect(observe)
	print("COOPERATIVE_RACE_INSTALL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func visual_signature(node: Node) -> Array:
	var result: Array = [node.get_class(),node.get_groups()]
	if node is Node3D: result.append(node.transform)
	if node is GeometryInstance3D: result.append([node.layers,node.cast_shadow,material_signature(node.material_override)])
	if node is MeshInstance3D: result.append(node.mesh)
	if node is MultiMeshInstance3D: result.append([node.multimesh.mesh,node.multimesh.instance_count,node.multimesh.buffer])
	for child: Node in node.get_children(): result.append(visual_signature(child))
	return result
func material_signature(material: Material) -> Variant:
	if not material is ShaderMaterial: return material
	# Winter snow wind intentionally owns a new material per race. Verify its
	# executable shader and every uniform, rather than requiring shared identity.
	var result: Array = [material.shader.code,material.render_priority]
	for uniform: Dictionary in material.shader.get_shader_uniform_list(): result.append([uniform.name,material.get_shader_parameter(uniform.name)])
	return result
func first_difference(a: Variant,b: Variant,path: String) -> String:
	if a is Array and b is Array:
		if a.size()!=b.size(): return path+" size "+str(a.size())+"/"+str(b.size())
		for index: int in range(a.size()):
			if a[index]!=b[index]: return first_difference(a[index],b[index],path+"/"+str(index))
	return path+" "+str(a)+" -> "+str(b)

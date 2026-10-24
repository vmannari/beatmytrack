extends SceneTree
const OUT: String = "res://../docs/evidence/speed-bumps-2026-10-12"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func document(theme: String = "pine") -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = theme
	doc["automatic_scenery"] = false
	var road: Dictionary = RoadPieces.create("straight",Vector2(-45,0),0,10)
	road.length = 90.0
	doc.pieces = [road]
	doc.objects = [{"kind":"speed_bump","position":[0,0],"rotation":0,"scale":1.0}]
	return doc

func crossing(track: NativeTrack, config: HandlingConfig, mode: String, heading: float = PI*0.5, scale_value: float = 1.0) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.reset(Vector2(-25,0),heading)
	var drive := DriveFrame.new(); drive.throttle = 255
	var brake := DriveFrame.new(); brake.brake = 255
	sim.state.velocity = sim.state.forward()*18.0
	# Real pedal history at a distance, then equal-speed/position crossing to
	# isolate suspension timing from entry speed. No forced pitch state.
	for i: int in range(42): sim.step(brake if mode == "timed" or mode == "braking" else drive,track)
	sim.state.position = -sim.state.forward()*(config.wheelbase*0.5+1.05*scale_value)
	sim.state.velocity = sim.state.forward()*18.0
	var rewind_state: Dictionary = RewindHistory.properties(sim.state)
	var initial: Array = sim.state.snapshot()
	var lost: float = 0.0
	var rise: float = 0.0
	var frames: Array = []
	for i: int in range(90):
		var frame: DriveFrame = brake if mode == "braking" else drive
		frames.append(frame.packed())
		var previous: Vector2 = sim.state.position
		var old_velocity: Vector2 = sim.state.velocity
		# Compare the same tick with bump effects removed, retaining ordinary forces.
		var baseline := VehicleSimulation.new(config)
		RewindHistory.restore(baseline.state,RewindHistory.properties(sim.state))
		var objects: Array = track.speed_bump_objects
		track.speed_bump_objects = []
		baseline.step(frame,track)
		track.speed_bump_objects = objects
		sim.step(frame,track)
		lost += maxf(0.0,baseline.state.velocity.length()-sim.state.velocity.length())
		var front: Vector2 = sim.state.position+sim.state.forward()*config.wheelbase*0.5
		if SpeedBumps.height(front,objects)>0.01: rise = maxf(rise,sim.state.bump_transfer.y)
		check(sim.state.velocity.is_finite() and sim.state.bump_transfer.is_finite(),"finite crossing state")
		check(sim.state.jump_height == 0.0 and sim.state.collision_count == 0,"bump is traversable without ballistic jump or wall collision")
		check(sim.state.velocity.length() <= baseline.state.velocity.length()+0.00001,"bump never adds forward energy")
		if i == 0: check(sim.state.position.distance_to(previous) <= old_velocity.length()*VehicleSimulation.STEP+0.02,"no teleport through bump")
	var replay := VehicleSimulation.new(config)
	RewindHistory.restore(replay.state,rewind_state)
	check(replay.state.snapshot() == initial,"rewind captures sprung pitch and rate")
	for packed: Array in JSON.parse_string(JSON.stringify(frames)):
		var frame := DriveFrame.new(); frame.steer = int(packed[0]); frame.throttle = int(packed[1]); frame.brake = int(packed[2]); frame.handbrake = int(packed[3]) if packed.size()>3 else 0
		replay.step(frame,track)
	check(replay.state.snapshot() == sim.state.snapshot(),"exact JSON replay and rewind continuation through bump")
	return {"loss":lost,"speed":sim.state.velocity.length(),"rise":rise}

func run() -> void:
	root.size = Vector2i(1280,720)
	var capture: bool = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for theme: String in TrackDocument.THEMES:
		var entries: Array = CreatorCatalog.filtered("Props","speed bump",[],theme)
		check((entries.size()==1) == (theme in ["pine","storm","night_city"]),theme+" palette eligibility")
	var doc: Dictionary = document()
	check(TrackDocument.validate(doc).is_empty(),"speed bump document validates: "+str(TrackDocument.validate(doc)))
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null and track.cell_at(Vector2.ZERO) == 0,"bump preserves underlying drivable road")
	var roundtrip: NativeTrack = TrackCompiler.compile(JSON.parse_string(JSON.stringify(doc)))
	check(track.cells == roundtrip.cells and track.content_hash == roundtrip.content_hash,"saved object compiles identically")
	check(SpeedBumps.height(Vector2.ZERO,track.speed_bump_objects) == SpeedBumps.HEIGHT,"canonical 18cm crown")
	check(is_zero_approx(SpeedBumps.height(Vector2(1.0,0),track.speed_bump_objects)),"crown joins road at zero height")
	check(SpeedBumps.height(Vector2(0,4.1),track.speed_bump_objects) == 0.0,"outside footprint unaffected")
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		var flat: Dictionary = crossing(track,config,"flat")
		var timed: Dictionary = crossing(track,config,"timed")
		var braking: Dictionary = crossing(track,config,"braking")
		print("BUMP_CROSSING ",id," flat=",flat," timed=",timed," braking=",braking)
		check(timed.loss < flat.loss*0.80 and timed.loss < braking.loss*0.80,id+" rising nose reduces bump loss versus held power/brake at equal entry speed")
		check(timed.rise > 0.08,id+" brake-release-throttle actually raises nose on leading axle crossing")
		check(timed.speed > flat.speed,id+" timed technique retains higher exit speed")
	# Rotated/reverse/scaled crossings and a partial-width line stay deterministic.
	for turn: float in [0.0,90.0,37.0]:
		for scale_value: float in [0.5,1.0,3.0]:
			var object: Dictionary = doc.objects[0]; object.rotation = turn; object.scale = scale_value
			var rotated: NativeTrack = TrackCompiler.compile(doc)
			# Infinite clean road for oblique diagnostic crossings.
			rotated.cells.fill(0); rotated.kerbs = RoadKerbs.new()
			crossing(rotated,VehicleCatalog.config("compact"),"timed",PI*0.5-deg_to_rad(turn),scale_value)
			crossing(rotated,VehicleCatalog.config("compact"),"timed",PI*1.5-deg_to_rad(turn),scale_value)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var straight: Dictionary = approach(track,config,-100.0)
	var timed_approach: Dictionary = approach(track,config,-3.0)
	print("BUMP_APPROACH flat=",straight," timed=",timed_approach)
	check(timed_approach.ticks < straight.ticks and timed_approach.exit > straight.exit,"actual brake-throttle approach is quicker with higher exit speed")
	var elevated := VehicleState.new(); elevated.position = Vector2.ZERO; elevated.velocity = Vector2(18,0); elevated.heading = PI*0.5
	for mode: String in ["bridge","flight","roll"]:
		elevated.track_elevated = mode == "bridge"; elevated.jump_height = 1.0 if mode == "flight" else 0.0; elevated.roll_ticks = 10 if mode == "roll" else 0
		var speed: Vector2 = elevated.velocity
		SpeedBumps.advance(elevated,Vector2(-0.1,0),elevated.heading,speed,config,track.speed_bump_objects,VehicleSimulation.STEP)
		check(elevated.velocity == speed,mode+" excludes ground bump impact")
	var plain_doc: Dictionary = TrackDocument.create_default()
	print("BUMP_COMPILER_GOLDEN ",TrackCompiler.compile(plain_doc).content_hash)
	await editor_roundtrip(capture)
	if capture: await captures()
	print("SPEED_BUMP_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func captures() -> void:
	for theme: String in ["pine","storm","night_city"]:
		var doc: Dictionary = document(theme)
		var game: Node = load("res://core/game.tscn").instantiate()
		game.set("initial_track",TrackCompiler.compile(doc))
		game.set("handling",VehicleCatalog.config("compact"))
		game.set("attempt_practice",true)
		game.set("production_mode",true)
		game.set("editor_test",true)
		root.add_child(game)
		await process_frame
		game.set_physics_process(false)
		game.set("countdown_ticks",0)
		var sim: VehicleSimulation = game.get("sim")
		sim.reset(Vector2(-12,0),PI*0.5); sim.state.velocity = Vector2(18,0)
		var brake := DriveFrame.new(); brake.brake = 255
		var drive := DriveFrame.new(); drive.throttle = 255
		for i: int in range(42): sim.step(brake,game.native_track)
		sim.state.position = Vector2(-config_wheelbase()*0.5-1.05,0); sim.state.velocity = Vector2(18,0)
		var loaded_pitch: float = sim.state.bump_transfer.x
		for i: int in range(8): sim.step(drive,game.native_track)
		game.set("frame",drive)
		game.set("previous_position",sim.state.position); game.set("previous_heading",sim.state.heading)
		game.camera.follow(sim.state.position,Vector2.ZERO,sim.state.heading,0.0,true)
		var before: Array = sim.state.snapshot()
		for i: int in range(5):
			game.call("_process",0.016)
			await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(theme+"-driving.png")))==OK,theme+" actual driving capture")
		check(sim.state.snapshot() == before,"presentation cannot change canonical bump response")
		check(game.car.body.rotation.x > loaded_pitch and sim.state.bump_transfer.y > 0.0 and is_equal_approx(game.car.body.rotation.x,sim.state.bump_transfer.x),"actual rendered nose is rising from brake compression using canonical pitch")
		# The headlamp illuminates the approaching crown before the front axle.
		if theme == "night_city":
			sim.reset(Vector2(-8,0),PI*0.5)
			game.set("previous_position",sim.state.position); game.set("previous_heading",sim.state.heading)
			game.camera.follow(sim.state.position,Vector2.ZERO,sim.state.heading,0.0,true)
			for i: int in range(4):
				game.call("_process",0.016)
				await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join("night-approach.png")))==OK,"night headlamp approach capture")
		game.queue_free(); await process_frame

func config_wheelbase() -> float:
	return VehicleCatalog.config("compact").wheelbase

func approach(track: NativeTrack, config: HandlingConfig, release: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.reset(Vector2(-14,0),PI*0.5); sim.state.velocity = Vector2(18,0)
	var ticks: int = 0
	var braked: bool = false
	while sim.state.position.x < 8.0 and ticks < 600:
		var frame := DriveFrame.new(); frame.throttle = 255
		var front: float = sim.state.position.x+config.wheelbase*0.5
		if release > -100.0 and front > -7.0 and front < release:
			frame.brake = 255; frame.throttle = 0; braked = true
		sim.step(frame,track)
		ticks += 1
	return {"ticks":ticks,"exit":sim.state.velocity.length(),"braked":braked}

func editor_roundtrip(capture: bool) -> void:
	var folder: String = "user://speed_bump_test_"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.gd").new()
	app.set("library",TrackLibrary.new(folder))
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app); await process_frame
	var doc: Dictionary = document(); doc.objects = []
	app.set("document",doc); app.call("_show_screen","create")
	await process_frame; await process_frame
	app.call("_editor_category","objects")
	var browser: ObjectBrowser = app.get("object_browser")
	var canvas: EditorCanvas = app.get("canvas")
	browser.category = "Props"; browser.choose("speed_bump")
	canvas._place(canvas.to_screen(Vector2.ZERO))
	check(app.document.objects.size() == 1 and app.document.objects[0].kind == "speed_bump","actual editor palette places bump")
	app.call("_scale_object",0.25)
	app.call("_rotate_object")
	var placed: Dictionary = app.document.objects[0].duplicate(true)
	check(is_equal_approx(float(placed.span),9.0) and not placed.has("scale"),"bump resize changes transverse width only")
	app.call("_undo")
	check(app.document.objects[0].rotation != placed.rotation,"rotate operation undoes")
	app.call("_redo")
	check(app.document.objects[0] == placed,"redo restores exact bump")
	var library: TrackLibrary = app.get("library")
	check(library.save_document(app.document)==OK,"actual local bump save")
	var restored: Dictionary = library.load_document(app.document.id)
	check(restored.objects[0] == placed,"position, rotation and scale survive file reload")
	if capture:
		var deadline: int = Time.get_ticks_msec()+20000
		var expected_hash: String = TrackCompiler.compile(app.document).content_hash
		while (app.editor_preview_thread != null or app.canvas.native_preview == null or app.canvas.native_preview.content_hash != expected_hash or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
		check(app.canvas.native_preview != null and app.canvas.native_preview.content_hash == expected_hash and not app.editor_world._building,"actual edited bump 3D preview is ready")
		browser.refresh()
		for i: int in range(6): await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join("object-palette.png")))==OK,"actual editor palette and placed object capture")
	app.queue_free(); await process_frame
	var files: DirAccess = DirAccess.open(folder)
	for file: String in files.get_files(): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)

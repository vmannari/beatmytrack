extends SceneTree

var checks: int = 0
var failures: int = 0

class KerbYard extends PlaygroundData:
	var kerbs := RoadKerbs.new()
	func _init() -> void:
		islands = []
		kerbs.extent = Vector2(50,50)
		kerbs.grid = Vector2i(200,200)
		kerbs.blocked.resize(40000)
		kerbs._strip(Vector2(-20,0),Vector2(20,0),Vector2(-20,0.75),Vector2(20,0.75),40.0,80.0,120.0)
	func kerb_heights(state: VehicleState, config: HandlingConfig) -> Vector4:
		if state.track_elevated or state.jump_height > 0.0: return Vector4.ZERO
		var axle: Vector2 = state.forward()*config.wheelbase*0.5
		var side: Vector2 = state.right()*(0.83*HandlingConfig.BODY_SCALE)
		return Vector4(kerbs.height_at(state.position+axle-side),kerbs.height_at(state.position+axle+side),kerbs.height_at(state.position-axle-side),kerbs.height_at(state.position-axle+side))

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	var config: HandlingConfig = load("res://resources/original_slide.tres")
	if config == null: config = load("res://resources/balanced.tres")
	var yard := KerbYard.new()
	check(is_equal_approx(yard.kerbs.height_at(Vector2(0,0.6)),RoadKerbs.HEIGHT),"crown is 10 cm")
	check(yard.kerbs.height_at(Vector2(0,0.08)) > 0.0 and yard.kerbs.height_at(Vector2(0,0.08)) < 0.085,"road-side bevel has interpolated height")
	check(yard.kerbs.height_at(Vector2(0,-0.01)) == 0.0 and yard.kerbs.height_at(Vector2(0,0.76)) == 0.0,"no contact beyond visible strip")
	for direction: float in [1.0,-1.0]:
		var sim := VehicleSimulation.new(config)
		sim.reset(Vector2(0,-4 if direction > 0 else 4))
		sim.state.velocity = Vector2(0,20*direction)
		var flat := VehicleSimulation.new(config)
		flat.reset(sim.state.position)
		flat.state.velocity = sim.state.velocity
		var peak: float = 0.0
		var pitch: float = 0.0
		for tick: int in range(100):
			sim.step(DriveFrame.new(),yard)
			flat.step(DriveFrame.new())
			peak = maxf(peak,sim.state.kerb_offset.x)
			pitch = maxf(pitch,absf(sim.state.kerb_offset.y))
		check(peak > 0.015 and peak <= 0.14,"forward/reverse crossing produces a small bounded body bump")
		check(pitch > 0.003 and pitch < 0.08,"axle crossings give bounded pitch")
		check(sim.state.velocity.length() < flat.state.velocity.length() and sim.state.velocity.length() > flat.state.velocity.length()-0.25,"crossing loses a little speed, never gains power")
		check(sim.state.jump_height == 0.0 and sim.state.collision_count == 0,"kerb is traversable without collision or airborne mode")
		print("KERB_CROSS direction=",direction," peak_m=",peak," pitch_rad=",pitch," speed_loss_mps=",flat.state.velocity.length()-sim.state.velocity.length())
		for tick: int in range(120): sim.step(DriveFrame.new())
		check(sim.state.kerb_offset.length() < 0.0001,"body settles after leaving kerb")
	var one_side := VehicleSimulation.new(config)
	one_side.reset(Vector2(-10,0.4+0.83*HandlingConfig.BODY_SCALE),PI*0.5)
	one_side.state.velocity = Vector2(12,0)
	for tick: int in range(60): one_side.step(DriveFrame.new(),yard)
	check(one_side.state.kerb_offset.z > 0.01 and absf(one_side.state.kerb_offset.y) < 0.001,"only right tyres on kerb produces the correct roll without false pitch")
	var stationary := VehicleSimulation.new(config)
	stationary.reset(Vector2(0,0.4))
	for tick: int in range(240): stationary.step(DriveFrame.new(),yard)
	check(stationary.state.velocity == Vector2.ZERO,"standing still on kerb never creates travel")
	var elevated := VehicleState.new()
	elevated.position = Vector2(0,0.4)
	elevated.track_elevated = true
	check(yard.kerb_heights(elevated,config) == Vector4.ZERO,"bridge deck ignores ground kerb")
	elevated.track_elevated = false
	elevated.jump_height = 1.0
	check(yard.kerb_heights(elevated,config) == Vector4.ZERO,"airborne car ignores ground kerb")
	var expected: Array = []
	for batch: int in [1,2,4,8]:
		var replay := VehicleSimulation.new(config)
		replay.reset(Vector2(0,-4))
		replay.state.velocity = Vector2(0,32)
		for block: int in range(240/batch):
			for tick: int in range(batch):
				var data: Array = JSON.parse_string(JSON.stringify([0,0,0]))
				var frame := DriveFrame.new()
				frame.steer = int(data[0]); frame.throttle = int(data[1]); frame.brake = int(data[2])
				replay.step(frame,yard)
		if batch == 1: expected = replay.state.snapshot()
		check(replay.state.snapshot() == expected,"complete kerb snapshot replays at batch %s" % batch)
	var fast := VehicleSimulation.new(config)
	fast.reset(Vector2(0,-1.3)); fast.state.velocity = Vector2(0,46)
	for tick: int in range(12): fast.step(DriveFrame.new(),yard)
	check(fast.state.kerb_offset.x > 0.001,"top-speed swept tyres detect the narrow kerb")
	var recorder := HandlingRecorder.new()
	recorder.start(one_side,yard)
	check(recorder.header.schema_version == 7 and recorder.header.initial_state.size() == 19,"schema 7 records the six spring scalars at snapshot index 18")
	check(recorder.header.physics_version == VehicleSimulation.PHYSICS_VERSION,"kerb replay manifest pins new physics")
	_geometry()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-kerbs="): await _capture(argument.trim_prefix("--capture-kerbs="))
	print("KERB_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _geometry() -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.pieces = [RoadPieces.create("curve",Vector2.ZERO,0,12)]
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(not track.kerbs.triangles.is_empty(),"creator curve compiles raised contact geometry headlessly")
	var visible: int = 0
	var agreement: bool = true
	for t: Dictionary in track.kerbs.triangles:
		var center: Vector2 = (t.points[0]+t.points[1]+t.points[2])/3.0
		var expected: float = (t.heights[0]+t.heights[1]+t.heights[2])/3.0
		if expected > 0.001:
			visible += 1
			agreement = agreement and absf(track.kerbs.height_at(center)-expected) < 0.0001
	check(visible > 0 and agreement,"contact interpolation agrees with rendered triangles across full tapered curve")
	var rebuilt: NativeTrack = TrackCompiler.compile(doc)
	check(track.kerbs.triangles == rebuilt.kerbs.triangles,"canonical kerb triangles rebuild identically")
	var sample: Dictionary = track.kerbs.triangles[track.kerbs.triangles.size()/2]
	var p: Vector2 = (sample.points[0]+sample.points[1]+sample.points[2])/3.0
	doc.paint = [{"surface":0,"width":8.0,"shape":"square","points":[[p.x,p.y]]}]
	check(TrackCompiler.compile(doc).kerbs.height_at(p) == 0.0,"painted junction removes kerb contact with its visible mask")
	doc.paint = []
	doc.surface = "dirt"
	check(TrackCompiler.compile(doc).kerbs.triangles.is_empty(),"dirt pieces never acquire asphalt kerbs")
	var native: NativeTrack = NativeTrack.read("res://resources/tracks/slicks_freeway_test.json")
	check(not native.kerbs.triangles.is_empty(),"native circuits also compile raised kerbs")
	doc.surface = "asphalt"
	doc.base_track = "slicks_freeway_test"
	var remix: NativeTrack = TrackCompiler.compile(doc)
	var native_preserved: bool = false
	for t: Dictionary in remix.kerbs.triangles:
		if t.uv[0].y < 0.0: native_preserved = true
	check(native_preserved,"native remix retains raised source kerbs outside new road pieces")


func _capture(directory: String) -> void:
	root.size = Vector2i(1280,720)
	var doc: Dictionary = TrackDocument.create_blank()
	doc.pieces = [RoadPieces.create("curve",Vector2.ZERO,0,12)]
	var track: NativeTrack = TrackCompiler.compile(doc)
	var segments: Array[Dictionary] = RoadKerbs.creator_segments(doc)
	var segment: Dictionary = segments[segments.size()/2]
	var edge: Vector2 = (Vector2(segment.a)+Vector2(segment.b))*0.5
	var outward: Vector2 = ((Vector2(segment.outer_a)+Vector2(segment.outer_b))*0.5-edge).normalized()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	var hud: CanvasLayer = game.get("hud")
	hud.visible = false
	var countdown: Label = game.get("countdown_label")
	if countdown != null: countdown.hide()
	var sim: VehicleSimulation = game.get("sim")
	sim.reset(edge-outward*3.0,atan2(outward.x,outward.y))
	sim.state.velocity = outward*7.0
	var view := Camera3D.new()
	game.add_child(view)
	view.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.size = 9.0
	var aim: Vector3 = VisualGeometry.world(edge)+Vector3.UP*0.30
	view.position = aim+Vector3(6,4,-6)
	view.look_at(aim)
	view.current = true
	var peak: float = -1.0
	for frame: int in range(90):
		for tick: int in range(2): sim.step(DriveFrame.new(),track)
		game.set("previous_position",sim.state.position)
		game.call("_process",1.0/60.0)
		await RenderingServer.frame_post_draw
		var filename: String = ""
		if frame == 0: filename = "before.png"
		if frame == 89: filename = "after.png"
		if sim.state.kerb_offset.x > peak:
			peak = sim.state.kerb_offset.x
			if peak > 0.01: filename = "crossing.png"
		if filename != "": check(root.get_texture().get_image().save_png(directory.path_join(filename)) == OK,"actual kerb capture saved "+filename)
	print("KERB_CAPTURE peak_m=",peak)
	check(peak > 0.01,"actual creator kerb raises the rendered car")
	game.queue_free()
	await process_frame

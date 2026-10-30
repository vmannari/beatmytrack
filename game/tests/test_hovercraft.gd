extends "res://backend/runner.gd"
## Roster, deterministic air-cushion handling, persistence and native presentation.
const EVIDENCE: String = "res://../docs/evidence/hovercraft-2026-10-28/"
const RETAINED: Array[String] = ["compact","pickup","kart","forklift","electric"]
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}
var graphical: bool = false
var output: String = EVIDENCE

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func traces() -> Dictionary:
	var result: Dictionary = {}
	for id: String in RETAINED:
		var config: HandlingConfig = VehicleCatalog.config(id)
		var sim := VehicleSimulation.new(config)
		var states: Array[String] = []
		for tick: int in range(2400):
			sim.step(DriveFrame.sample(sin(tick*0.017)*0.7,1.0 if tick%600<400 else 0.0,0.8 if tick%600>460 else 0.0,0.5 if tick%700>650 else 0.0))
			if tick%120 == 0: states.append(var_to_bytes(sim.state.snapshot()).hex_encode().sha256_text())
		result[id] = {"config_hash":JSON.stringify(config.snapshot(),"",true).sha256_text(),"states":states}
	return result

func _run() -> void:
	var evidence_root: String = EVIDENCE
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): evidence_root = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	if "--baseline" in OS.get_cmdline_user_args():
		var file := FileAccess.open(EVIDENCE+"retained-before.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(traces(),"\t"))
		file.close()
		print("HOVERCRAFT_BASELINE: five config hashes and 100 exact state checkpoints")
		quit()
		return
	check(traces() == JSON.parse_string(FileAccess.get_file_as_string(EVIDENCE+"retained-before.json")),"five retained config hashes and 100 state checkpoints stay exact")
	OS.set_environment("BMT_API_URL","")
	graphical = DisplayServer.get_name() != "headless"
	output = evidence_root.path_join(RenderingServer.get_current_rendering_method() if graphical else "headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	check(VehicleCatalog.IDS == ["compact","pickup","kart","forklift","electric","hovercraft"],"new six-vehicle lineup removes Sports Car and Formula")
	check(VehicleCatalog.NAMES.size() == VehicleCatalog.IDS.size() and VehicleCatalog.CLASSES.size() == VehicleCatalog.IDS.size() and VehicleCatalog.DESCRIPTIONS.size() == VehicleCatalog.IDS.size(),"catalogue fields align")
	check(VehicleCatalog.valid_id("formula") == "compact" and VehicleCatalog.valid_id("classic") == "compact","retired selections fall back safely")
	check(VehicleCatalog.config("missing").vehicle_id == "compact","unknown configs use Compact")
	var config: HandlingConfig = VehicleCatalog.config("hovercraft")
	check(config.air_cushion and not config.handbrake_enabled and config.snapshot().air_cushion,"versioned air-cushion capability is in replay identity")
	check(manifest().vehicles.has("hovercraft") and not manifest().vehicles.has("formula") and not manifest().vehicles.has("classic"),"worker advertises the playable roster")
	check(TrackLifecycle._contract(TrackDocument.create_default(),"hovercraft").config_hash == manifest().vehicles.hovercraft.config_hash,"publication and verifier agree on hovercraft identity")
	_handling(config)
	_persistence()
	await _model(config)
	if graphical and "--integration" in OS.get_cmdline_user_args(): await _app(config)
	var report := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("HOVERCRAFT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _handling(config: HandlingConfig) -> void:
	var sim := VehicleSimulation.new(config)
	for tick: int in range(2400): sim.step(DriveFrame.sample(0,1,0))
	check(sim.state.velocity.length() > 35.0 and sim.state.velocity.length() <= config.maximum_speed,"hovercraft approaches its bounded 130 km/h top speed")
	metrics.top_kph = sim.state.velocity.length()*3.6
	var turn := VehicleSimulation.new(config)
	turn.state.velocity = Vector2(0,20)
	for tick: int in range(90): turn.step(DriveFrame.sample(0.6,0.5,0))
	check(turn.state.heading > 0.2 and absf(turn.state.slip_angle()) > 0.15,"rudder turns hull while world momentum produces a sustained slide")
	metrics.slide_degrees = rad_to_deg(absf(turn.state.slip_angle()))
	var brake := VehicleSimulation.new(config)
	brake.state.velocity = Vector2(10,25)
	var stop_ticks: int = 0
	for tick: int in range(900):
		brake.step(DriveFrame.sample(0,0,1))
		stop_ticks += 1
		if brake.state.velocity.length() < 0.15: break
	check(brake.state.velocity.length() < 0.15 and brake.state.velocity.y >= 0.0,"brake settles forward and sideways travel before reverse")
	metrics.stop_seconds = stop_ticks/120.0
	var reverse := VehicleSimulation.new(config)
	for tick: int in range(30): reverse.step(DriveFrame.sample(0,0,1))
	check(reverse.state.velocity == Vector2.ZERO,"short brake tap at rest cannot select reverse")
	for tick: int in range(360): reverse.step(DriveFrame.sample(0,0,1))
	check(reverse.state.velocity.y < -4.0 and reverse.state.velocity.length() <= config.reverse_speed,"held brake reverses with a separate speed cap")
	var coast := VehicleSimulation.new(config)
	coast.state.velocity = Vector2(8,25)
	var dissipative: bool = true
	for tick: int in range(2000):
		var speed: float = coast.state.velocity.length()
		coast.step(DriveFrame.sample(sin(tick*0.02),0,0))
		dissipative = dissipative and coast.state.velocity.length() <= speed+0.00001
	check(dissipative,"unpowered steering never manufactures speed")
	var dry := VehicleSimulation.new(config)
	var oily := VehicleSimulation.new(config)
	oily.state.tire_oil = 1.0
	oily.state.tire_water = 1.0
	oily.state.tire_dirt = 1.0
	for tick: int in range(240):
		var frame := DriveFrame.sample(0.4,0.8,0)
		dry.step(frame)
		oily.step(frame)
	check(dry.state.velocity == oily.state.velocity and dry.state.heading == oily.state.heading,"air cushion ignores tire dirt, oil and water grip penalties")
	var yard := PlaygroundData.new()
	var collision := VehicleSimulation.new(config)
	collision.state.position = Vector2(0,55)
	collision.state.velocity = Vector2(0,30)
	for tick: int in range(60): collision.step(DriveFrame.sample(0,1,0),yard)
	check(collision.state.collision_count > 0 and collision.state.position.y <= yard.half_extent.y-config.collision_radius,"hovering retains solid boundary collisions")
	var original := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	var saved: Dictionary = {}
	var frames: Array[Array] = []
	for tick: int in range(3600):
		var frame := DriveFrame.sample(sin(tick*0.015)*0.75,1.0 if tick%600<400 else 0.0,1.0 if tick%600>450 else 0.0,1.0)
		frames.append(frame.packed())
		original.step(frame,yard)
		if tick == 1799: saved = RewindHistory.pack_state(original.state)
	for packed: Array in JSON.parse_string(JSON.stringify(frames)): replay.step(unpack(packed),yard)
	check(replay.state.snapshot() == original.state.snapshot(),"serialized 3600-input replay with collisions is exact")
	RewindHistory.restore(replay.state,saved)
	for tick: int in range(1800,3600): replay.step(unpack(frames[tick]),yard)
	check(replay.state.snapshot() == original.state.snapshot(),"rewind continuation stays exact")
	check(replay.state.handbrake_pressure == 0.0,"hovercraft has no wheel handbrake")

func unpack(packed: Array) -> DriveFrame:
	return DriveFrame.sample(float(packed[0])/127.0,float(packed[1])/255.0,float(packed[2])/255.0,float(packed[3])/255.0 if packed.size() > 3 else 0.0)

func _persistence() -> void:
	var records := LocalRecords.new("user://hovercraft-tests/records.json")
	DirAccess.make_dir_recursive_absolute("user://hovercraft-tests")
	records.settings.selected_car = "formula"
	var liveries: Dictionary = {}
	for id: String in VehicleCatalog.ALL_IDS: liveries[id] = VehicleLivery.defaults(id)
	records.settings.vehicle_liveries = liveries
	var achievements: Dictionary = AchievementProgress.empty()
	achievements.metrics = {"car_mask":(1 << 4),"cars_classic":7,"cars_formula":9}
	records.settings.achievements = achievements
	check(records.save_records() == OK,"legacy roster save remains writable")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	check(reopened.settings.get("selected_car") == "formula" and reopened.settings.get("vehicle_liveries",{}).size() == 8,"retired selection and all eight livery identities survive reload")
	for id: String in VehicleCatalog.ALL_IDS:
		check(VehicleLivery.for_car(reopened.settings,id) == liveries[id],"normalized saved livery remains exact: "+id)
	check(reopened.settings.get("achievements",{}) == achievements,"legacy achievements survive roster change")
	check(VehicleCatalog.ALL_IDS.find("kart") == 4 and VehicleCatalog.ALL_IDS.find("hovercraft") == 7,"achievement bit positions remain stable")
	AchievementProgress.customise(reopened,"hovercraft")
	check(int(reopened.settings.achievements.metrics.customised_mask) == 128 and int(reopened.settings.achievements.metrics.customised) == 1,"new vehicle has its own counted achievement bit")
	reopened.settings.selected_car = "hovercraft"
	check(reopened.save_records() == OK,"hovercraft selection saves atomically")
	var final_save := LocalRecords.new(records.path)
	final_save.load_records()
	check(final_save.settings.selected_car == "hovercraft","hovercraft selection survives reload")

func _model(config: HandlingConfig) -> void:
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "hovercraft"
		car.simple_model = simple
		root.add_child(car)
		while not car.model_ready: await process_frame
		check(car.rolling_wheels.is_empty() and car.front_wheels.is_empty(),"hovercraft has no road wheels: "+str(simple))
		check(car.body.get_node_or_null("FanRotor") != null and car.body.get_node_or_null("RudderLeft") != null,"fan and rudders survive batching: "+str(simple))
		var state := VehicleState.new()
		state.tick = 120
		state.steering = 0.5
		car.present(Vector2.ZERO,0,state,DriveFrame.sample(0.5,1,0))
		var fan: Node3D = car.body.get_node("FanRotor")
		var left: Node3D = fan.get_node_or_null("FanRotorLeft")
		var right: Node3D = fan.get_node_or_null("FanRotorRight")
		var spinning: bool = not is_zero_approx(fan.rotation.z) if left == null or right == null else not is_zero_approx(left.rotation.z) and is_equal_approx(left.rotation.z,-right.rotation.z)
		check(spinning and car.body.get_node("RudderLeft").rotation.y < 0,"presentation animates fan and steering vanes")
		var decorated: Dictionary = VehicleLivery.defaults("hovercraft")
		decorated.pattern = LiveryCatalog.patterns[0].id
		car.apply_livery(decorated)
		check(not car.graphics.bindings.is_empty(),"livery binds to hovercraft surfaces")
		var weathering := VehicleWeathering.new()
		weathering.configure(car,"pine",config)
		check(not weathering.materials.is_empty(),"hovercraft supports garage weathering")
		car.set_night_headlights(true)
		check(car.road_headlight != null,"hovercraft supports night races")
		var audio := VehicleAudio.new()
		root.add_child(audio)
		audio.configure("hovercraft",config,car)
		for tick: int in range(120): audio.model.advance(state,DriveFrame.sample(0,1,0),VehicleSimulation.STEP)
		check(audio.engine_load[0].stream != null and audio.model.shifts == 0 and audio.model.rpm > 5000,"fan audio responds to power without gear shifts")
		audio.present(state,DriveFrame.sample(0,1,0),null,0.1,false)
		check(float(audio.levels.tire) == 0.0 and float(audio.levels.road) == 0.0,"hovercraft emits no tire squeal or rolling noise")
		audio.free()
		car.free()
		await process_frame

func settle() -> void:
	for tick: int in range(8): await process_frame
	if graphical: await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"saved "+label)

func _app(config: HandlingConfig) -> void:
	root.size = Vector2i(1280,720)
	var directory: String = "user://hovercraft-app-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.records.settings.selected_car = "classic"
	app.records.save_records()
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(VehicleCatalog.selected == "compact","actual startup safely replaces a retired active selection")
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	check(page.cards.get_child_count() == 6 and page.find_child("GarageCar_hovercraft",true,false) != null,"Garage lists the new six-car lineup")
	check(page.find_child("GarageCar_classic",true,false) == null and page.find_child("GarageCar_formula",true,false) == null,"retired cars are absent from Garage")
	await capture("garage-lineup")
	page.preview_car(VehicleCatalog.IDS.find("hovercraft"))
	page._confirm_car()
	await create_timer(0.8).timeout
	await settle()
	check(VehicleCatalog.selected == "hovercraft" and page.showroom.car.vehicle_id == "hovercraft","Garage commits actual hovercraft selection")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		await capture("garage-"+str(dimensions.x))
	root.size = Vector2i(1280,720)
	app._show_screen("tracks")
	app.selected_track.metadata.cloud_version = "isolated-hovercraft-fixture"
	await app._start_race(app.selected_track,false,true)
	await settle()
	check(app.game != null and app.game.handling.snapshot() == config.snapshot() and app.game.car.vehicle_id == "hovercraft","ordinary race installs the selected hovercraft tune and model")
	if app.game != null:
		app.game.set_physics_process(false)
		app.game.countdown_label.hide()
		check(not app.game.trails.visible and not app.game.sand_dust.visible,"race disables wheel marks and wheel particles")
		await capture("gameplay")
	app.queue_free()
	await process_frame

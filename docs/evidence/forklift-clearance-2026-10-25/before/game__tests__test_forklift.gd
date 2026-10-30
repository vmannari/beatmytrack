extends "res://backend/runner.gd"
## Rear-axle kinematics, articulation, retained saves and real Garage/race integration.
var checks: int = 0
var failures: int = 0
var evidence: String = "res://../docs/evidence/forklift-2026-10-25"
var graphical: bool = false
var metrics: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func settle() -> void:
	for index: int in range(8): await process_frame
	if graphical: await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if not graphical: return
	await settle()
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png")) == OK,"saved "+label)

func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	graphical = DisplayServer.get_name() != "headless"
	evidence = ProjectSettings.globalize_path(evidence).path_join(RenderingServer.get_current_rendering_method() if graphical else "headless")
	DirAccess.make_dir_recursive_absolute(evidence)
	var config: HandlingConfig = VehicleCatalog.config("forklift")
	check(VehicleCatalog.valid_id("forklift") == "forklift","selectable cars include Forklift")
	check(config.vehicle_id == "forklift" and config.rear_steering and config.version == "forklift-1","dedicated versioned rear-steer handling")
	check(config.snapshot().get("rear_steering",false),"rear steering participates in comparable rules")
	var info: Dictionary = manifest()
	for id: String in VehicleCatalog.IDS:
		check(info.vehicles[id].config_hash == JSON.stringify(VehicleCatalog.config(id).snapshot(),"",true).sha256_text(),id+" native server and client handling hashes agree")
	check(TrackLifecycle._contract(TrackDocument.create_default(),"forklift").config_hash == info.vehicles.forklift.config_hash,"Forklift publication and race contracts agree")
	for id: String in ["compact","pickup","classic","formula","kart"]:
		check(not VehicleCatalog.config(id).snapshot().has("rear_steering"),id+" retains its established config snapshot")
	_check_turns(config)
	_check_replay(config)
	_check_existing_traces()
	await _check_model(config)
	if graphical: await _check_studio()
	await _check_app(config)
	var report := FileAccess.open(evidence.path_join("metrics.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("FORKLIFT_METRICS ",JSON.stringify(metrics))
	print("FORKLIFT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _check_turns(config: HandlingConfig) -> void:
	for speed: float in [5.0,-3.0]:
		for steer: float in [-0.6,0.6]:
			var sim := VehicleSimulation.new(config)
			sim.state.velocity = Vector2(0,speed)
			for tick: int in range(90): sim.step(DriveFrame.sample(steer,0,0))
			check(signf(sim.state.heading) == signf(speed*steer),"familiar nose turn in forward/reverse: %s/%s" % [speed,steer])
			var lateral: float = sim.state.velocity.dot(sim.state.right())
			var front: float = lateral+sim.state.yaw_rate*config.wheelbase*0.5
			var rear: float = lateral-sim.state.yaw_rate*config.wheelbase*0.5
			check(absf(front) < absf(rear)*0.5,"fixed front axle leads while tail swings: %s/%s" % [speed,steer])
			metrics["turn_%s_%s" % [speed,steer]] = {"heading":sim.state.heading,"front_side_speed":front,"rear_side_speed":rear}
	var stopped := VehicleSimulation.new(config)
	for tick: int in range(240): stopped.step(DriveFrame.sample(1,0,0))
	check(stopped.state.position == Vector2.ZERO and stopped.state.heading == 0.0,"steering alone cannot move a parked Forklift")
	var driven := VehicleSimulation.new(config)
	for tick: int in range(1200): driven.step(DriveFrame.sample(0,1,0))
	check(driven.state.velocity.length() > config.maximum_speed*0.95 and driven.state.velocity.length() <= config.maximum_speed,"low top speed is attainable and bounded")
	metrics.maximum_speed_kph = driven.state.velocity.length()*3.6
	for tick: int in range(600):
		driven.step(DriveFrame.sample(0,0,1))
		if driven.state.velocity.length() < 0.15: break
	check(driven.state.velocity.length() < 0.15,"heavy Forklift brakes to a stop")
	var forces: Vector3 = RallyHandbrake.forces(config,6.0,0.0,0.0,0.5,1.0,0.0,0.0,VehicleSimulation.STEP)
	check(forces.x < 0.0 and forces.z > 0.0,"rear axle supplies outward force and requested yaw during handbrake recovery")

func _check_replay(config: HandlingConfig) -> void:
	var original := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	var frames: Array[Array] = []
	for tick: int in range(2400):
		var frame: DriveFrame = DriveFrame.sample(sin(tick*0.017)*0.8,1.0 if tick%600<400 else 0.0,1.0 if tick%600>=430 else 0.0,0.7 if tick%480>400 else 0.0)
		frames.append(frame.packed())
		original.step(frame)
	var decoded: Array = JSON.parse_string(JSON.stringify(frames))
	for batch: int in range(0,2400,4):
		for tick: int in range(batch,batch+4):
			var frame := DriveFrame.new()
			frame.steer = int(decoded[tick][0]); frame.throttle = int(decoded[tick][1]); frame.brake = int(decoded[tick][2]); frame.handbrake = int(decoded[tick][3]) if decoded[tick].size() > 3 else 0
			replay.step(frame)
	check(original.state.snapshot() == replay.state.snapshot(),"serialized rear-steer replay is exact at 120/30 Hz presentation batches")

func _check_existing_traces() -> void:
	# Load the actual task-start source only into this isolated test process.
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/forklift-2026-10-25/before/game__vehicle__vehicle_simulation.gd").replace("class_name VehicleSimulation", "")
	check(script.reload() == OK,"task-start simulation compiles for exact comparisons")
	for id: String in ["compact","pickup","classic","formula","kart"]:
		var config: HandlingConfig = VehicleCatalog.config(id)
		var old: RefCounted = script.new(config)
		var current := VehicleSimulation.new(config)
		var exact: bool = true
		for tick: int in range(1800):
			var frame: DriveFrame = DriveFrame.sample(sin(tick*0.021),0.8 if tick%500<300 else 0.0,0.8 if tick%500>=350 else 0.0,0.9 if tick%480>370 else 0.0)
			old.step(frame); current.step(frame)
			exact = exact and old.state.snapshot() == current.state.snapshot()
		check(exact,id+" canonical state matches task-start at every tick including rear brake")

func _check_model(config: HandlingConfig) -> void:
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "forklift"; car.simple_model = simple
		car.livery = VehicleLivery.defaults("forklift")
		root.add_child(car)
		var compact_finish: StandardMaterial3D = CompactFinish.paint(Color.WHITE)
		check(is_equal_approx(car.paint_materials.body.roughness,compact_finish.roughness) and car.paint_materials.body.clearcoat_enabled,"Forklift uses the Compact paint finish")
		var triangles: int = 0
		for part: Node in car.find_children("*","MeshInstance3D",true,false): triangles += (part as MeshInstance3D).mesh.get_faces().size()/3
		metrics["triangles_racing" if simple else "triangles_detailed"] = triangles
		metrics["meshes_racing" if simple else "meshes_detailed"] = car.find_children("*","MeshInstance3D",true,false).size()
		var reference := CarVisual.new()
		reference.vehicle_id = "forklift"; reference.simple_model = simple; reference.batch_parts = false
		root.add_child(reference)
		var reference_triangles: int = 0
		for part: Node in reference.find_children("*","MeshInstance3D",true,false): reference_triangles += (part as MeshInstance3D).mesh.get_faces().size()/3
		check(triangles == reference_triangles,"production batching preserves every detailed/racing Forklift triangle")
		reference.queue_free()
		check(car.front_wheels.is_empty() and car.rear_wheels.size() == 2 and car.rolling_wheels.size() == 4,"only rear wheels articulate in detailed/racing mesh")
		for pivot: Node3D in car.rear_wheels:
			check(pivot.position.z > 0.0 and is_equal_approx(pivot.position.z*2.0*HandlingConfig.BODY_SCALE,config.wheelbase),"rear steering pivot matches canonical axle")
		check(is_equal_approx(absf(car.rear_wheels[0].position.x-car.rear_wheels[1].position.x)*HandlingConfig.BODY_SCALE,config.track_width),"visible wheel track matches handling")
		for input: float in [-1.0,0.0,1.0]:
			var state := VehicleState.new()
			state.steering = input
			var before: Array = state.snapshot()
			car.present(Vector2.ZERO,0.0,state,DriveFrame.new())
			for pivot: Node3D in car.rear_wheels: check(is_equal_approx(pivot.rotation.y,input*config.steering_angle),"rear wheel turns opposite nose steering")
			for rotor: Node3D in car.rolling_wheels:
				var pivot: Node3D = rotor.get_parent()
				if pivot.position.z < 0.0: check(pivot.rotation.y == 0.0,"front wheel stays fixed")
			check(before == state.snapshot(),"articulation cannot change canonical state")
		var livery: Dictionary = car.livery.duplicate(true)
		livery.colors.body = "aa3322"; livery.pattern = str(LiveryCatalog.patterns[0].id)
		car.apply_livery(livery)
		check(car.graphics.bindings.size() > 0,"native paint/pattern bindings support Forklift")
		var wear := VehicleWeathering.new()
		wear.configure(car,"pine",config)
		check(not wear.bindings.is_empty(),"Forklift supports washing/weathering")
		var radii_match: bool = true
		for binding: Dictionary in wear.bindings:
			if binding.wheel:
				var expected: float = 0.43 if binding.wash_transform.origin.z < 0.0 else 0.30
				radii_match = radii_match and is_equal_approx(float(binding.finish.get_shader_parameter("wheel_radius")),expected)
		check(radii_match,"weathering uses the actual large front/small rear tire radii")
		car.set_night_headlights(true)
		check(car.road_headlight != null,"work lights support night races")
		var audio := VehicleAudio.new()
		root.add_child(audio)
		audio.configure("forklift",config,car)
		check(audio.engine_load[0].stream != null and audio.model.vehicle_id == "forklift","cleared heavy engine bank loads without losing identity")
		for tick: int in range(120):
			var state := VehicleState.new()
			state.velocity = Vector2(0,config.maximum_speed)
			audio.model.advance(state,DriveFrame.sample(0,1,0),VehicleSimulation.STEP)
		check(audio.model.gear == 1 and audio.model.shifts == 0,"single-speed Forklift drivetrain")
		audio.queue_free(); car.queue_free()
		await process_frame

func _check_studio() -> void:
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	car.vehicle_id = "forklift"
	world.add_child(car)
	ShowroomStudio.build(world,car)
	var camera := Camera3D.new()
	camera.fov = 35.0
	world.add_child(camera)
	camera.position = Vector3(-5,3.8,-6)
	camera.look_at(Vector3(0,1.0,-0.2))
	camera.current = true
	await capture("model-front")
	check(_model_fits(car,camera,Vector2(root.size)),"complete mast/forks fit the studio photo")
	if "--bake-art" in OS.get_cmdline_user_args():
		check(root.get_texture().get_image().save_png("res://assets/menu/forklift_illustration_v1.png") == OK,"native Forklift catalogue artwork baked")
	camera.position = Vector3(-4,3.2,5)
	camera.look_at(Vector3(0,1.0,0))
	for steer: float in [-1.0,0.0,1.0]:
		var state := VehicleState.new()
		state.steering = steer
		car.present(Vector2.ZERO,0,state,DriveFrame.new())
		await capture("rear-steering-"+str(int(steer)))
	world.queue_free()
	await process_frame

func _model_fits(car: CarVisual, camera: Camera3D, dimensions: Vector2) -> bool:
	var viewport := Rect2(Vector2.ONE*4.0,dimensions-Vector2.ONE*8.0)
	for node: Node in car.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		# A batched mast/fork mesh has empty AABB corners well outside its silhouette.
		for vertex: Vector3 in mesh.mesh.get_faces():
			var point: Vector2 = camera.unproject_position(mesh.global_transform*vertex)
			if not viewport.has_point(point):
				print("FORKLIFT_BOUNDS outside=",mesh.get_path()," point=",point," viewport=",dimensions)
				return false
	return true

func _check_app(config: HandlingConfig) -> void:
	root.size = Vector2i(1280,720)
	var directory: String = ProjectSettings.globalize_path("res://../build/forklift/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	await settle()
	var page: Control = app.root_ui.find_child("GaragePage",true,false)
	check(page.cards.get_child_count() == VehicleCatalog.IDS.size() and page.find_child("GarageCar_forklift",true,false) != null,"Garage includes the native Forklift card")
	var thumbnail: CarShowroom = page.thumbnails.forklift
	check(_model_fits(thumbnail.car,thumbnail.camera,Vector2(thumbnail.showroom_viewport.size)),"tall Forklift fits its Garage catalogue thumbnail")
	page.preview_car(VehicleCatalog.IDS.find("forklift"))
	page._confirm_car()
	await create_timer(0.8).timeout
	await settle()
	check(VehicleCatalog.selected == "forklift" and app.records.settings.selected_car == "forklift","Garage commits Forklift selection")
	check(page.showroom.car.vehicle_id == "forklift","Garage displays actual Forklift model")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		await settle()
		check(_model_fits(page.showroom.car,page.showroom.camera,Vector2(page.showroom.showroom_viewport.size)),"whole Forklift fits Garage at "+str(dimensions))
		await capture("garage-"+str(dimensions.x))
	var reopened := LocalRecords.new(app.records.path)
	reopened.load_records()
	check(reopened.settings.selected_car == "forklift","Forklift selection survives reload")
	root.size = Vector2i(1280,720)
	app._show_screen("tracks")
	app.selected_track.metadata.cloud_version = "isolated-forklift-race-fixture"
	await app._start_race(app.selected_track,false,true)
	await settle()
	check(app.game != null and app.game.handling.rear_steering and app.game.car.vehicle_id == "forklift","ordinary race loads rear-steered Forklift")
	if app.game != null:
		app.game.set_physics_process(false)
		app.game.countdown_label.hide()
		check(app.game.trails.wheelbase == config.wheelbase,"race trails use Forklift wheelbase")
		await capture("gameplay")
	app.queue_free()
	await process_frame

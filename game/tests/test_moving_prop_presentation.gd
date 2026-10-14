extends SceneTree
## Real Ajorata collisions through the normal game presenter, without profiling.
const WORLDS = preload("res://track/prepared_world_cache.gd")
var checks: int = 0
var failures: int = 0
var capture_directory: String = ""

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("This MultiMesh regression requires TestScript -Graphical.")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-moving-props="):
			capture_directory = ProjectSettings.globalize_path(argument.trim_prefix("--capture-moving-props="))
	if not capture_directory.is_empty(): DirAccess.make_dir_recursive_absolute(capture_directory)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	WORLDS.entries.clear()
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ajorata.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	check(track != null and track.tyre_origins.size() == 24,"actual Ajorata fixture has 24 movable tyre stacks")
	if track == null:
		quit(1)
		return
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var tyre_hit: VehicleSimulation = collision_run(track,config,true)
	var prop_hit: VehicleSimulation = collision_run(track,config,false)
	check(tyre_hit != null,"canonical car collision displaces an Ajorata tyre")
	check(prop_hit != null,"canonical car collision displaces an Ajorata cone")
	if tyre_hit == null or prop_hit == null:
		quit(1)
		return
	for pass_index: int in range(2):
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.production_mode = true
		game.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(game)
		# _ready queues layout/audio callbacks. Keep the scene alive through a
		# rendered frame even when optional capture() returns immediately.
		await RenderingServer.frame_post_draw
		game.paused = true
		game.countdown_ticks = 0
		game.race_cues.reset()
		var visual: NativeTrackVisual = game.track_ground
		check(visual.light_instances.size() == 2,"Ajorata binds both movable cones")
		check(not game.profile_enabled,"normal game defaults to profiling disabled")
		check(not WORLDS.entries.is_empty(),"first race prepares scenery for the repeat")
		var initial_state: VehicleState = game.sim.state
		game.sim.step(DriveFrame.new(),track)
		for profiling: bool in [false,true]:
			game.profile_enabled = profiling
			game.previous_position = tyre_hit.state.position
			game.previous_heading = tyre_hit.state.heading
			game.camera.speed_zoom_enabled = false
			game.camera.follow(tyre_hit.state.position,Vector2.ZERO,tyre_hit.state.heading,0.0,true)
			if pass_index == 0 and not profiling:
				initial_state.position = tyre_hit.state.position
				initial_state.heading = tyre_hit.state.heading
				game._process(0.0)
				await capture("tyres-before-present")
			game.sim.state = tyre_hit.state
			var before: Array = tyre_hit.state.snapshot()
			game._process(0.0)
			check(tyres_match(visual,tyre_hit.state,track),"hit tyres render canonical positions/spins; profiling="+str(profiling)+" pass="+str(pass_index))
			check(tyre_hit.state.snapshot() == before,"tyre presentation leaves canonical state exact")
			if pass_index == 0 and not profiling: await capture("tyres-after-present")
			game.sim.state = prop_hit.state
			before = prop_hit.state.snapshot()
			game._process(0.0)
			check(props_match(visual,prop_hit.state),"hit cones render canonical positions/tilts; profiling="+str(profiling)+" pass="+str(pass_index))
			check(prop_hit.state.snapshot() == before,"cone presentation leaves canonical state exact")
		# Returning to an earlier state is also how rewind restores props.
		game.profile_enabled = false
		game.sim.state = initial_state
		game._process(0.0)
		check(tyres_match(visual,initial_state,track),"earlier snapshot restores authored tyre transforms")
		check(props_match(visual,initial_state),"earlier snapshot restores authored cone transforms")
		# Finish coasting presents its own simulation rather than the frozen race.
		game.finish_sim = tyre_hit
		game._process(0.0)
		check(tyres_match(visual,tyre_hit.state,track),"finish coast presents its selected tyre state without profiling")
		game.finish_sim = prop_hit
		game._process(0.0)
		check(props_match(visual,prop_hit.state),"finish coast presents its selected cone state without profiling")
		game.finish_sim = null
		game.restart()
		game._process(0.0)
		check(tyres_match(visual,game.sim.state,track),"restart returns every tyre to its authored position")
		await RenderingServer.frame_post_draw
		root.remove_child(game)
		game.free()
		await process_frame
	# The handling playground has no native track/tyre presenter.
	var playground: Node = load("res://core/game.tscn").instantiate()
	playground.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(playground)
	await RenderingServer.frame_post_draw
	for profiling: bool in [false,true]:
		playground.profile_enabled = profiling
		playground._process(0.0)
		check(playground.native_track == null,"handling playground remains safe; profiling="+str(profiling))
	root.remove_child(playground)
	playground.free()
	WORLDS.entries.clear()
	print("MOVING_PROP_PRESENTATION checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func collision_run(track: NativeTrack, config: HandlingConfig, tyres: bool) -> VehicleSimulation:
	var targets: PackedVector2Array = track.tyre_origins if tyres else PackedVector2Array()
	if not tyres:
		for object: Dictionary in track.metadata.creator_document.objects:
			if object.kind in CreatorCatalog.SOFT: targets.append(Vector2(object.position[0],object.position[1]))
	for target: Vector2 in targets:
		for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			var sim := VehicleSimulation.new(config)
			sim.reset(target-direction*3.0,atan2(direction.x,direction.y))
			sim.state.velocity = direction*20.0
			for tick: int in range(90): sim.step(DriveFrame.new(),track)
			var moved: float = 0.0
			var rows: Array = sim.state.loose_tyres if tyres else sim.state.light_props
			for index: int in range(rows.size()):
				moved = maxf(moved,Vector2(rows[index][0],rows[index][1]).distance_to(targets[index]))
			if moved > 0.1:
				print("AJORATA_IMPACT ","tyres" if tyres else "cones"," displacement_m=",moved," target=",target," direction=",direction)
				return sim
	return null

func tyres_match(visual: NativeTrackVisual, state: VehicleState, track: NativeTrack) -> bool:
	# The dummy renderer does not retain MultiMesh transforms; run this test graphically.
	for index: int in range(track.tyre_origins.size()):
		var point: Vector2 = track.tyre_origins[index]
		var spin: float = 0.0
		if index < state.loose_tyres.size():
			point = Vector2(state.loose_tyres[index][0],state.loose_tyres[index][1])
			spin = state.loose_tyres[index][4]
		var expected := Transform3D(Basis(Vector3.UP,spin),VisualGeometry.world(point)+Vector3.UP*0.014)
		if not visual.tyre_instances.multimesh.get_instance_transform(index).is_equal_approx(expected): return false
	return true

func props_match(visual: NativeTrackVisual, state: VehicleState) -> bool:
	for index: int in range(state.light_props.size()):
		var row: Array = state.light_props[index]
		var prop: Node3D = visual.light_instances[index]
		if not Vector2(prop.position.x,-prop.position.z).is_equal_approx(Vector2(row[0],row[1])): return false
		if not is_equal_approx(prop.rotation.z,float(row[4])*0.9): return false
	return true

func capture(name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_directory.path_join(name+".png"))

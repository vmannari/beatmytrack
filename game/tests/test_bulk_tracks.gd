extends SceneTree

var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check_ylikulku_crossing()
	var catalog := TrackCatalog.new(TrackLibrary.new())
	var config := HandlingConfig.new()
	check(BuiltinTracks.ids().size() == 194, "all 194 distinct supplied names are in the native catalog")
	var rows: Array[Dictionary] = []
	for entry: Dictionary in BuiltinTracks.entries():
		catalog.add_builtin(entry.id)
		var track := NativeTrack.read(entry.path)
		check(track != null and track.identity == entry.id and track.route.size() >= 3, entry.id + " loads native geometry and route")
		check(not str(entry.creator).strip_edges().is_empty(), entry.id + " has searchable author metadata")
		var sim := VehicleSimulation.new(config)
		sim.reset(track.spawn, track.spawn_heading)
		sim.state.route_index = track.nearest_route(track.spawn)
		var elevated: bool = track.collision_elevated_at(track.spawn, sim.state.route_index, config.collision_radius)
		var clear: bool = track.collision_normal(track.spawn, config.collision_radius, elevated) == Vector2.ZERO
		check(clear, entry.id + " spawn has car clearance")
		var driver := RouteDriver.new()
		for tick: int in range(120): sim.step(driver.sample(sim.state, track, config),track)
		check(is_finite(sim.state.position.x) and is_finite(sim.state.position.y) and is_finite(sim.state.velocity.length()), entry.id + " runs through real simulation")
		rows.append({"id":entry.id,"spawn_clear":clear,"one_second_distance":sim.state.position.distance_to(track.spawn),"contacts":sim.state.collision_count})
	check(catalog.query({"creator":"jArMo"},[]).size() > 5, "real author search is case insensitive across the imported corpus")
	var fictional: Array[Dictionary] = catalog.query({"creator":"nora apex"},[])
	check(not fictional.is_empty(), "fictional author search finds missing-author fixtures")
	check(fictional.all(func(entry: Dictionary) -> bool: return entry.creator_kind == "fictional"), "artificial author attribution remains explicitly tagged")
	check(catalog.query({"creator":"nobody-with-this-name"},[]).is_empty(), "unknown author query returns no matches")
	var output := FileAccess.open("res://../build/bulk-runtime.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(rows,"\t"))
	print("BULK_TRACK_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check_ylikulku_crossing() -> void:
	var track := NativeTrack.read("res://resources/tracks/slicks_ylikulku_test.json")
	var config := HandlingConfig.new()
	check(absf(track.bridge_axis.dot(Vector2.UP)) > 0.99, "YLIKULKU bridge follows its north-south rails")
	# Source-derived passages: north/south goes above, east/west below.
	for passage: Array in [[Vector2(144,87),Vector2(144,31),true], [Vector2(144,31),Vector2(144,87),true], [Vector2(113,60),Vector2(186,60),false], [Vector2(186,60),Vector2(113,60),false]]:
		var start: Vector2 = Vector2(passage[0].x-160,100-passage[0].y)*track.cell_size
		var end: Vector2 = Vector2(passage[1].x-160,100-passage[1].y)*track.cell_size
		var state := VehicleState.new()
		state.position = start
		state.route_index = track.nearest_route(start)
		var bridge := BridgePresentation.new(track)
		var max_height: float = 0.0
		var blocked: bool = false
		for i: int in range(1,201):
			var before: Vector2 = state.position
			var target: Vector2 = start.lerp(end,float(i)/200.0)
			state.velocity = (end-start).normalized()*8.0
			state.position = target
			track.resolve(state,before,config)
			blocked = blocked or state.position.distance_to(target)>0.001
			max_height = maxf(max_height,bridge.height_at(state.position,state.route_index))
		check(not blocked and state.collision_count==0, "YLIKULKU entire passage clears rails on correct layer: upper="+str(passage[2]))
		check(max_height>3.0 if passage[2] else max_height<0.001, "YLIKULKU passage presentation matches collision layer: upper="+str(passage[2]))
	var rail := Vector2(129-160,100-60)*track.cell_size
	check(track.collision_normal(rail,config.collision_radius,true)!=Vector2.ZERO, "YLIKULKU upper side rail remains collidable")
	check(track.collision_normal(rail,config.collision_radius,false)==Vector2.ZERO, "YLIKULKU side rail does not obstruct underpass")
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn,track.spawn_heading)
	sim.state.route_index = track.nearest_route(track.spawn)
	var driver := RouteDriver.new()
	var session := TrackSession.new(120,3)
	for tick: int in range(21600):
		var before: Vector2 = sim.state.position
		sim.step(driver.sample(sim.state,track,config),track)
		session.advance(track,before,sim.state.position,sim.state.route_index)
		if session.finished: break
	print("YLIKULKU_LAPS: ",session.completed_laps," contacts=",sim.state.collision_count," times=",session.lap_times)
	check(session.finished,"YLIKULKU AI completes three ordered laps through both crossing layers")

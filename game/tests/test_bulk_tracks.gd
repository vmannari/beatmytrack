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

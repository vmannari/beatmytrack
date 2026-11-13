extends SceneTree
## KFS03: ordered track completion and exact replay/rewind on the production tune.

var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func initial_vehicle(config: HandlingConfig, track: NativeTrack) -> VehicleSimulation:
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn, track.spawn_heading)
	var distance: float = (sim.state.position - track.finish_center).dot(track.finish_forward)
	sim.state.position -= track.finish_forward * maxf(0.0, distance + 3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	sim.state.track_elevated = track.elevated_at(sim.state.position, sim.state.route_index)
	if CreatorBridges.at_any(track.creator_bridges, sim.state.position):
		sim.state.track_elevated = CreatorBridges.initial_layer(track.creator_bridges, sim.state.position, sim.state.heading)
	return sim

func _initialize() -> void:
	for source: String in ["res://tests/fixtures/over_and_under.json", "res://resources/storm_tracks/storm_freight.json", "res://resources/storm_tracks/storm_quarry.json"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track != null, "track compiles: " + source)
		if track == null: continue
		var config: HandlingConfig = VehicleCatalog.config("kart")
		var sim := initial_vehicle(config, track)
		var session := TrackSession.new(120, 5)
		var driver := RouteDriver.new()
		var frames: Array[DriveFrame] = []
		var saved: Dictionary = {}
		for tick: int in range(72000):
			var frame: DriveFrame = driver.sample(sim.state, track, config)
			frames.append(frame)
			var before: Vector2 = sim.state.position
			var layer: int = int(sim.state.track_elevated)
			sim.step(frame, track)
			session.advance(track, before, sim.state.position, sim.state.route_index, sim.state.track_elevated, layer)
			if tick == 1199: saved = RewindHistory.properties(sim.state, true)
			if session.finished: break
		check(session.finished and session.completed_laps == 5, "five ordered laps: " + source)
		check(sim.state.collision_count == 0, "zero contacts: " + source)
		var replay := initial_vehicle(config, track)
		for frame: DriveFrame in frames: replay.step(frame, track)
		check(replay.state.snapshot() == sim.state.snapshot(), "exact full replay: " + source)
		if not saved.is_empty():
			RewindHistory.restore(replay.state, saved)
			for index: int in range(1200, frames.size()): replay.step(frames[index], track)
			check(replay.state.snapshot() == sim.state.snapshot(), "exact resumed replay: " + source)
		print("KART_FAST_TRACK ", source, " laps=", session.completed_laps, " ticks=", frames.size(), " contacts=", sim.state.collision_count)
	print("KART_FAST_TRACKS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

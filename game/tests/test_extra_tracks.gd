extends SceneTree
## Additional owner-authorized Slicks circuits: full driven laps and JSON replay.

var failures: int = 0
var checks: int = 0


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + description)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var driver := RouteDriver.new()
	var config: HandlingConfig = load("res://resources/balanced.tres")
	print("EXTRA_TRACK_VERSIONS handling=", config.version, " physics=", VehicleSimulation.PHYSICS_VERSION)
	for name: String in ["arto4", "hiekka", "ovaali3"]:
		var path: String = "res://tests/fixtures/legacy_tracks/slicks_" + name + "_test.json"
		var track := NativeTrack.read(path)
		check(track != null and track.route.size() > 20, name + " loads native route")
		if track == null:
			continue
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(metadata.get("theme", "") in ["pine", "desert", "coast"], name + " carries supported base theme")
		check(not String(metadata.get("title", "")).is_empty(), name + " has a menu title")
		check(track.bridge_height == 0.0, name + " simple circuit needs no crossing inference")
		check(track.collision_normal(track.spawn, config.collision_radius, false) == Vector2.ZERO, name + " spawn has collision clearance")
		var sim := VehicleSimulation.new(config)
		sim.reset(track.spawn, track.spawn_heading)
		sim.state.route_index = track.nearest_route(track.spawn)
		var session := TrackSession.new(120, 3)
		var frames: Array[Array] = []
		for tick: int in range(120 * 240):
			var previous: Vector2 = sim.state.position
			var input: DriveFrame = driver.sample(sim.state, track, config)
			frames.append(input.packed())
			sim.step(input, track)
			session.advance(track, previous, sim.state.position,sim.state.route_index,sim.state.track_elevated)
			if session.finished:
				break
		print("EXTRA_TRACK_RESULT ", name, " laps=", session.completed_laps, " next_cp=", session.next_checkpoint, " times=", session.lap_times, " collisions=", sim.state.collision_count, " ticks=", sim.state.tick)
		check(session.finished and session.completed_laps == 3, name + " AI completes three ordered laps")
		check(sim.state.collision_count == 0, name + " conservative AI avoids all blocking contacts")
		var replay := VehicleSimulation.new(config)
		replay.reset(track.spawn, track.spawn_heading)
		replay.state.route_index = track.nearest_route(track.spawn)
		var replay_session := TrackSession.new(120, 3)
		var packed_frames: Array = JSON.parse_string(JSON.stringify(frames))
		for batch_start: int in range(0, packed_frames.size(), 8):
			for i: int in range(batch_start, mini(batch_start + 8, packed_frames.size())):
				var frame := DriveFrame.new()
				frame.steer = int(packed_frames[i][0])
				frame.throttle = int(packed_frames[i][1])
				frame.brake = int(packed_frames[i][2])
				var previous: Vector2 = replay.state.position
				replay.step(frame, track)
				replay_session.advance(track, previous, replay.state.position,replay.state.route_index,replay.state.track_elevated)
		check(replay.state.snapshot() == sim.state.snapshot() and replay_session.lap_times == session.lap_times, name + " full JSON replay exactly matches in batches of eight")
		var final_ticks: int = session.elapsed_ticks
		session.advance(track, track.spawn, track.spawn + Vector2.ONE, 0)
		check(session.completed_laps == 3 and session.elapsed_ticks == final_ticks, name + " finish freezes exactly at three laps")
	print("EXTRA_TRACK_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

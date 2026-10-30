extends SceneTree
## Confidence, real ghost distance lookup, reserved payoff and musical event routing.
var checks: int = 0
var failures: int = 0


func _initialize() -> void: call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)


func run() -> void:
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var state := VehicleState.new()
	var distance: float = track.route_length * 0.3
	state.position = track._race_route_point(distance)
	var direction: Vector2 = (track._race_route_point(distance + 3) - track._race_route_point(distance - 3)).normalized()
	state.heading = atan2(direction.x, direction.y)
	state.velocity = direction * 2.0
	var session := TrackSession.new()
	var previous: Vector2 = track._race_route_point(distance - 0.1)
	var slow: float = DrivingScoreProgress.driving_quality(state, track, config, session, previous)
	state.velocity = direction * 35.0
	var fast: float = DrivingScoreProgress.driving_quality(state, track, config, session, previous)
	check(slow > 0.95 and absf(slow - fast) < 0.000001, "same clean line has identical musical quality at 2 and 35m/s")
	var snapshot: Array = state.snapshot()
	DrivingScoreProgress.driving_quality(state, track, config, session, previous)
	check(state.snapshot() == snapshot, "confidence reads but never changes state")
	var flow := DrivingScoreProgress.new()
	for i: int in range(60 * 120): flow.advance(1.0 / 120, 1.0)
	check(flow.confidence > 0.99 and flow.requested_layer() == 4, "clock and clean motion alone do not unlock the soaring layer")
	for i: int in range(3): flow.sector_completed(true)
	check(flow.exceptional() and flow.requested_layer() == 5, "confirmed clean sectors unlock the reserved payoff")
	var confidence_before: float = flow.confidence
	flow.advance(0.05, 1.0, 0.6)
	check(flow.confidence > confidence_before - 0.025 and flow.requested_layer() >= 4 and flow.wobble > 0, "small contact wobbles without losing the band")
	flow.advance(0.05, 1.0, 12.0)
	check(flow.confidence < 0.5 and flow.requested_layer() <= 2 and not flow.exceptional(), "major crash substantially lowers confidence and payoff")
	for i: int in range(45 * 120):
		flow.advance(1.0 / 120, 1.0)
		if i > 0 and i % 600 == 0: flow.sector_completed(true)
	check(flow.exceptional(), "a real rebuild can recover after a major setback")
	flow.pace_delta = 0.08
	flow.sector_completed(true, true)
	check(flow.fast_corners == 1, "clean corner ahead of recorded pace contributes a fast-corner streak")
	flow.sector_completed(false)
	check(flow.clean_sectors == 0 and flow.fast_corners == 0, "dirty sector breaks the confidence evidence streak")
	var poses: Array = []
	var start: float = track.route_progress(track.finish_center)
	for index: int in range(101):
		var point: Vector2 = track._race_route_point(start + track.route_length * index / 100.0)
		poses.append([index * 12, point.x, point.y, 0.0, 0.0, 0.0, 0.0])
	var reference := ScorePaceReference.new()
	reference.configure(track, {"ticks": 1200, "poses": poses})
	check(reference.distances.size() == 101, "recorded ghost builds a bounded presentation lookup")
	var half: float = reference.distances[-1] * 0.5
	check(absf(reference.delta_seconds(half, 4.92) - 0.08) < 0.05, "eight-hundredths ahead is read from actual pose timing")
	check(is_nan(reference.delta_seconds(reference.distances[-1] + 10, 12.0)), "ghost comparison never extrapolates missing future data")
	var backtrack_poses: Array = []
	var steps: Array[float] = [0.0, 0.3, 0.2, 0.3, 0.5]
	for index: int in range(steps.size()):
		var point: Vector2 = track._race_route_point(start + track.route_length * steps[index])
		backtrack_poses.append([index * 120, point.x, point.y, 0.0, 0.0, 0.0, 0.0])
	var reversing := ScorePaceReference.new()
	reversing.configure(track,{"ticks":480,"poses":backtrack_poses})
	check(absf(reversing.distances[-1] - track.route_length * 0.5) < 1.0, "ghost backtracking/recovery never fabricates extra distance")
	var empty := ScorePaceReference.new()
	empty.configure(track, {})
	check(is_nan(empty.delta_seconds(10, 3)), "a new user track has neutral missing ghost data")
	var near_pb := DrivingScoreProgress.new()
	state.tick = 0
	state.position = track._race_route_point(start + track.route_length * 0.81)
	near_pb.reset(state)
	near_pb.confidence = 1.0
	near_pb.clean_seconds = 20.0
	near_pb.clean_sectors = 4
	near_pb.earned_seconds = 56.0
	session.completed_laps = 1
	session.route_distance = track.route_length * 0.82
	state.position = track._race_route_point(start + session.route_distance)
	state.heading = atan2((state.position - near_pb.last_position).x, (state.position - near_pb.last_position).y)
	state.velocity = state.forward() * 12.0
	state.tick = 1
	near_pb.observe(state, track, config, session)
	check(not near_pb.breath_pending, "missing real PB reference cannot trigger an exceptional-PB breath")
	near_pb.pace_delta = 0.08
	state.tick = 2
	state.position += state.forward() * 0.01
	near_pb.observe(state, track, config, session)
	check(near_pb.breath_pending, "clean late-lap motion ahead of recorded PB requests the breath")
	near_pb.breath_pending = false
	state.tick = 3
	state.position += state.forward() * 0.01
	near_pb.observe(state, track, config, session)
	check(not near_pb.breath_pending, "one lap never repeats its exceptional-PB breath")
	var world: GameSoundtrack = root.get_node("AudioWorld")
	world.app_suspended = false
	var owner := Node.new()
	root.add_child(owner)
	world.begin_race(owner, "pine", state)
	for biome: String in TrackTheme.IDS:
		world.begin_race(owner, biome, state)
		check(world.family == biome and world.synced == null and world.race_player.stream == null and not world.race_player.playing, "each biome has no background score: " + biome)
	world.progress.confidence = 1.0
	world.progress.earned_seconds = 56.0
	world.progress.clean_sectors = 4
	world.progress.clean_seconds = 20.0
	world.last_bar = 5
	world.breath_queued = true
	world.advance_arrangement(0.01, world.BAR_SECONDS * 5.0 + 0.10)
	check(world.breath_count == 0, "exceptional PB breath waits for a musical boundary")
	world.advance_arrangement(0.01, world.BAR_SECONDS * 6.0)
	check(world.breath_count == 1 and world.event_kind == "" and not world.event_player.playing, "diagnostic musical boundary cannot play a race breath cue")
	world._process(0.4)
	check(world.race_player.volume_db <= -79.0, "two-beat breath exposes car audio through a muted score")
	world._process(0.9)
	check(world.breath_elapsed < 0 and world.race_player.volume_db <= -79.0 and not world.race_player.playing, "race score stays absent after the diagnostic breath")
	world.results_feedback(0.08, true)
	check(world.event_kind == "personal_best" and world.results_improvement == 0.08, "real 0.08s improvement routes the resolving PB sting")
	world.results_feedback(0.08, false)
	check(world.event_kind == "finish", "practice/ineligible feedback never claims a PB")
	world.results_feedback(-0.2, true)
	check(world.event_kind == "finish", "slower race routes the normal motif finish")
	world.leave_race(owner)
	world.event_player.stop()
	world.menu_player.stop()
	root.remove_child(owner)
	owner.queue_free()
	await process_frame
	print("SCORE_FLOW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

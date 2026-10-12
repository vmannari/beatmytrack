class_name DrivingScoreProgress
extends RefCounted
## A read-only musical observer. Never part of simulation, scoring or replay state.
const ENTRIES: Array[float] = [0.0, 12.0, 24.0, 40.0, 56.0]
const FULL_SECONDS: float = 56.0
var earned_seconds: float = 0.0
var quality: float = 0.0
var recovery_seconds: float = 0.0
var last_tick: int = 0
var last_collisions: int = 0
var last_position := Vector2.ZERO
var furthest_tick: int = 0
var pending_impact: float = 0.0
var initialized: bool = false


func reset(state: VehicleState = null) -> void:
	earned_seconds = 0.0
	quality = 0.0
	recovery_seconds = 0.0
	initialized = state != null
	last_tick = state.tick if state != null else 0
	last_collisions = state.collision_count if state != null else 0
	last_position = state.position if state != null else Vector2.ZERO
	furthest_tick = last_tick
	pending_impact = 0.0


func notify_impact(strength: float) -> void:
	if is_finite(strength): pending_impact = maxf(pending_impact, strength)


func advance(seconds: float, driving_quality: float, impact: float = 0.0) -> void:
	if not is_finite(seconds) or seconds <= 0.0: return
	quality = clampf(driving_quality, 0.0, 1.0) if is_finite(driving_quality) else 0.0
	# A scrape leaves the motif intact. A harder hit sheds at most eight earned seconds.
	if impact > 1.5:
		var severity: float = smoothstep(1.5, 12.0, impact)
		earned_seconds = maxf(0.0, earned_seconds - 8.0 * severity)
		recovery_seconds = maxf(recovery_seconds, 1.0 + severity * 2.0)
	var recovering: float = minf(seconds, recovery_seconds)
	recovery_seconds = maxf(0.0, recovery_seconds - seconds)
	var gain_seconds: float = (seconds - recovering) + recovering * 0.35
	# Healthy motion earns progress. Sustained stopping/off-road/backtracking eases it away.
	earned_seconds = clampf(earned_seconds + gain_seconds * quality - seconds * 0.22 * (1.0 - quality), 0.0, FULL_SECONDS)


func observe(state: VehicleState, track: NativeTrack, config: HandlingConfig, session: TrackSession) -> void:
	if not initialized:
		reset(state)
		return
	if state.tick < last_tick:
		# Rewind preserves the musical clock but cannot earn the scrubbed interval a second time.
		last_tick = state.tick
		last_collisions = state.collision_count
		last_position = state.position
		pending_impact = 0.0
		return
	if state.tick == last_tick: return
	if state.tick <= furthest_tick:
		last_tick = state.tick
		last_collisions = state.collision_count
		last_position = state.position
		pending_impact = 0.0
		return
	var seconds: float = minf(0.25, float(state.tick - last_tick) / VehicleSimulation.TICK_RATE)
	var impact: float = pending_impact
	# Collision observer vectors last one tick; a count change still notices a between-frame hit.
	if state.collision_count > last_collisions and impact == 0.0: impact = maxf(state.collision_impulse.length(), 5.0)
	advance(seconds, driving_quality(state, track, config, session, last_position), impact)
	pending_impact = 0.0
	last_tick = state.tick
	last_collisions = state.collision_count
	last_position = state.position
	furthest_tick = maxi(furthest_tick, state.tick)


static func driving_quality(state: VehicleState, track: NativeTrack, config: HandlingConfig, session: TrackSession, previous: Vector2) -> float:
	var speed: float = state.velocity.length()
	if speed < 1.2 or state.roll_ticks > 0: return 0.0
	if session != null and session.missed_checkpoint >= 0: return 0.0
	var direction: Vector2 = state.forward()
	var bend: float = 0.0
	if track != null and track.route.size() >= 3:
		var cell: int = track.cell_at(state.position, state.track_elevated)
		var dirt_road: bool = str(track.metadata.get("creator_document", {}).get("surface", "")) == "dirt"
		if cell not in [0, 5] and not (cell == 2 and dirt_road): return 0.0
		var index: int = track.nearest_route(state.position, state.route_index)
		var progress: float = track.route_progress(state.position, index)
		var before: Vector2 = track._race_route_point(progress - 3.0)
		var after: Vector2 = track._race_route_point(progress + 3.0)
		direction = (after - before).normalized()
		var upcoming: Vector2 = track._race_route_point(progress + 12.0) - after
		if not upcoming.is_zero_approx(): bend = absf(direction.angle_to(upcoming.normalized()))
		# A rotating stationary car and reverse travel do not build the score.
		if state.position.distance_squared_to(previous) < 0.000001: return 0.0
	var alignment: float = smoothstep(0.05, 0.55, state.velocity.normalized().dot(direction))
	var expected: float = lerpf(config.maximum_speed * 0.28, maxf(2.5, config.maximum_speed * 0.09), smoothstep(0.12, 1.2, bend))
	var pace: float = smoothstep(1.2, maxf(2.5, expected), speed)
	# Ordinary braking, kerbs and controlled drifts retain full musical credit.
	var control: float = 1.0 - 0.5 * smoothstep(deg_to_rad(38.0), deg_to_rad(75.0), absf(state.slip_angle()))
	return clampf(pace * alignment * control, 0.0, 1.0)


func requested_layer() -> int:
	for i: int in range(ENTRIES.size() - 1, -1, -1):
		if earned_seconds + 0.00001 >= ENTRIES[i]: return i
	return 0

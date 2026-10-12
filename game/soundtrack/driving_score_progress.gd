class_name DrivingScoreProgress
extends RefCounted
## Read-only confidence/momentum. No audio, rewards or writes to canonical state.
const ENTRIES: Array[float] = [0.0, 6.0, 16.0, 30.0, 44.0, 56.0]
const FULL_SECONDS: float = 56.0
var earned_seconds: float = 0.0
var confidence: float = 0.25
var quality: float = 0.0
var recovery_seconds: float = 0.0
var clean_seconds: float = 0.0
var clean_sectors: int = 0
var fast_corners: int = 0
var pace_delta: float = NAN
var rival_delta: float = NAN
var wobble: float = 0.0
var last_tick: int = 0
var last_collisions: int = 0
var last_position := Vector2.ZERO
var furthest_tick: int = 0
var pending_impact: float = 0.0
var initialized: bool = false
var last_sector: int = 0
var sector_clean: bool = true
var sector_gate_seen: bool = false
var sector_corner_seen: bool = false
var last_gate: int = 0
var last_breath_lap: int = -1
var breath_pending: bool = false


func reset(state: VehicleState = null) -> void:
	earned_seconds = 0.0
	confidence = 0.25
	quality = 0.0
	recovery_seconds = 0.0
	clean_seconds = 0.0
	clean_sectors = 0
	fast_corners = 0
	pace_delta = NAN
	rival_delta = NAN
	wobble = 0.0
	initialized = state != null
	last_tick = state.tick if state != null else 0
	last_collisions = state.collision_count if state != null else 0
	last_position = state.position if state != null else Vector2.ZERO
	furthest_tick = last_tick
	pending_impact = 0.0
	last_sector = 0
	sector_clean = true
	sector_gate_seen = false
	sector_corner_seen = false
	last_gate = 0
	last_breath_lap = -1
	breath_pending = false


func notify_impact(strength: float) -> void:
	if is_finite(strength): pending_impact = maxf(pending_impact, strength)


func advance(seconds: float, driving_quality: float, impact: float = 0.0) -> void:
	if not is_finite(seconds) or seconds <= 0.0: return
	quality = clampf(driving_quality, 0.0, 1.0) if is_finite(driving_quality) else 0.0
	if impact > 0.15:
		wobble = maxf(wobble, clampf(impact / 12.0, 0.08, 1.0))
		confidence = maxf(0.0, confidence - minf(0.025, impact * 0.009))
	if impact > 4.0:
		var severity: float = smoothstep(4.0, 14.0, impact)
		confidence = maxf(0.0, confidence - 0.18 - severity * 0.52)
		earned_seconds = maxf(0.0, earned_seconds - 5.0 - 15.0 * severity)
		recovery_seconds = maxf(recovery_seconds, 1.5 + severity * 2.0)
		clean_seconds = 0.0
		clean_sectors = 0
		sector_clean = false
	var target: float = quality
	# Ghost data is optional. Behind pace never negates clean driving.
	if is_finite(pace_delta) and pace_delta > 0: target = minf(1.0, target + 0.035)
	if is_finite(rival_delta) and rival_delta > 0: target = minf(1.0, target + 0.025)
	if fast_corners > 0: target = minf(1.0, target + minf(0.035, fast_corners * 0.01))
	confidence = move_toward(confidence, target, seconds * (0.028 if target >= confidence else 0.10))
	var recovering: float = minf(seconds, recovery_seconds)
	recovery_seconds = maxf(0.0, recovery_seconds - seconds)
	var gained: float = seconds - recovering * 0.65
	earned_seconds = clampf(earned_seconds + gained * quality - seconds * 0.22 * (1.0 - quality), 0.0, FULL_SECONDS)
	if quality >= 0.85 and impact <= 4.0: clean_seconds += seconds
	elif quality < 0.55: clean_seconds = maxf(0.0, clean_seconds - seconds * 2.0)
	if quality < 0.65: sector_clean = false
	wobble = move_toward(wobble, 0.0, seconds * 0.7)


func sector_completed(clean: bool, corner: bool = false) -> void:
	if clean:
		clean_sectors += 1
		confidence = minf(1.0, confidence + 0.045)
		if corner and ((is_finite(pace_delta) and pace_delta >= 0) or (is_finite(rival_delta) and rival_delta >= 0)): fast_corners += 1
	else:
		clean_sectors = 0
		fast_corners = 0
		confidence = maxf(0.0, confidence - 0.09)
	sector_clean = true
	sector_gate_seen = false
	sector_corner_seen = false


func observe(state: VehicleState, track: NativeTrack, config: HandlingConfig, session: TrackSession) -> void:
	if not initialized: reset(state); return
	if state.tick < last_tick or state.tick <= furthest_tick:
		last_tick = state.tick
		last_collisions = state.collision_count
		last_position = state.position
		pending_impact = 0.0
		if track != null and session != null: last_sector = int(float(session.completed_laps) * 4.0 + session.route_distance / track.route_length * 4.0)
		return
	var seconds: float = minf(0.25, float(state.tick - last_tick) / VehicleSimulation.TICK_RATE)
	var impact: float = pending_impact
	if state.collision_count > last_collisions and impact == 0.0: impact = maxf(state.collision_impulse.length(), 5.0)
	advance(seconds, driving_quality(state, track, config, session, last_position), impact)
	if track != null and session != null and track.route_length > 0:
		if absf(state.yaw_rate) > 0.25 and quality >= 0.85: sector_corner_seen = true
		var gate: int = session.completed_laps * (session.checkpoint_count() + 1) + session.next_checkpoint
		if gate > last_gate: sector_gate_seen = true
		last_gate = gate
		var sector: int = session.completed_laps * 4 + int(clampf(session.route_distance / track.route_length, 0.0, 0.9999) * 4.0)
		# No pre-start wrap or geometric shortcut can masquerade as clean sectors.
		if sector > last_sector and sector_gate_seen:
			sector_completed(sector_clean and quality >= 0.7, sector_corner_seen)
			last_sector = sector
		var fraction: float = session.route_distance / track.route_length
		if session.completed_laps >= 1 and fraction >= 0.80 and fraction < 0.95 and earned_seconds >= 44.0 and exceptional() and is_finite(pace_delta) and pace_delta > 0.015 and last_breath_lap != session.completed_laps:
			breath_pending = true
			last_breath_lap = session.completed_laps
	pending_impact = 0.0
	last_tick = state.tick
	last_collisions = state.collision_count
	last_position = state.position
	furthest_tick = maxi(furthest_tick, state.tick)


static func driving_quality(state: VehicleState, track: NativeTrack, config: HandlingConfig, session: TrackSession, previous: Vector2) -> float:
	# Velocity is used for direction/standstill only, never relative to maximum speed.
	if state.velocity.length() < 0.5 or state.roll_ticks > 0 or state.position.distance_squared_to(previous) < 0.000001: return 0.0
	if session != null and session.missed_checkpoint >= 0: return 0.0
	var direction: Vector2 = state.forward()
	var line: float = 1.0
	if track != null and track.route.size() >= 3:
		var cell: int = track.cell_at(state.position, state.track_elevated)
		var dirt: bool = str(track.metadata.get("creator_document", {}).get("surface", "")) == "dirt"
		if cell not in [0, 5] and not (cell == 2 and dirt): return 0.0
		var index: int = track.nearest_route(state.position, state.route_index)
		var distance: float = track.route_progress(state.position, index)
		var before: Vector2 = track._race_route_point(distance - 3.0)
		var after: Vector2 = track._race_route_point(distance + 3.0)
		direction = (after - before).normalized()
		var center: Vector2 = track._race_route_point(distance)
		var half: float = maxf(3.0, float(track.metadata.get("representative_width_m", 9.0)) * 0.5)
		if track.route_widths.size() == track.route.size(): half = maxf(2.0, track.route_widths[index] * 0.5)
		var lateral: float = absf((state.position - center).dot(direction.orthogonal())) / half
		# Legitimate inside/apex lines are not punished for leaving the centreline.
		line = 1.0 - 0.28 * smoothstep(0.85, 1.5, lateral)
	var alignment: float = smoothstep(0.05, 0.55, state.velocity.normalized().dot(direction))
	var control: float = 1.0 - 0.4 * smoothstep(deg_to_rad(42.0), deg_to_rad(80.0), absf(state.slip_angle()))
	return clampf(line * alignment * control, 0.0, 1.0)


func exceptional() -> bool:
	return confidence >= 0.9 and clean_seconds >= 10.0 and clean_sectors >= 3 and recovery_seconds <= 0.0


func requested_layer() -> int:
	var floors: Array[float] = [0.0, 0.30, 0.45, 0.60, 0.72, 0.90]
	for index: int in range(ENTRIES.size() - 1, -1, -1):
		if index == 5 and not exceptional(): continue
		if earned_seconds + 0.00001 >= ENTRIES[index] and confidence >= floors[index]: return index
	return 0

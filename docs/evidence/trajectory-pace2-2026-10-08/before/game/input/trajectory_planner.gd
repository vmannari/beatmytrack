class_name TrajectoryPlanner
extends RefCounted
const MAX_PILOT_CONTACTS: int = 4
const CONTACT_COST_TICKS: float = 36.0
## Offline qualification prevents a minimum-curvature heuristic selecting a
## slower/impossible line. Pilot laps are diagnostics, never scores or uploads.
static func prepare(track: NativeTrack, config: HandlingConfig) -> RacingTrajectory:
	var winner: RacingTrajectory
	var score: float = INF
	var candidates: Array = []
	for method: String in ["minimum_curvature","smoothing","center","minimum_time"]:
		var trajectory := RacingTrajectory.new()
		trajectory.build(track,config,method)
		var result: Dictionary = _pilot(track,config,trajectory)
		candidates.append({"strategy":method,"finished":result.finished,"ticks":result.ticks,"contacts":result.contacts,"missed_gate":result.missed_gate,"standing_ticks":result.standing_ticks,"flying_ticks":result.flying_ticks,"estimated_race_ticks":result.estimated_race_ticks,"diagnostic_laps":2})
		# Standing-only qualification missed hot entries across the lap seam.
		# Reject repeated impacts; isolated glances have an explicit planner cost.
		# This cost never changes the actual recorded/verified race time.
		var qualified: bool = result.finished and result.contacts <= MAX_PILOT_CONTACTS
		var candidate_score: float = result.estimated_race_ticks+result.contacts*CONTACT_COST_TICKS if qualified else INF
		if winner == null or candidate_score < score:
			winner = trajectory; score = candidate_score; winner.pilot_ticks = roundi(result.estimated_race_ticks/5.0) if qualified else 0
	winner.pilot_candidates = candidates
	# Canonicalize the derived data through the exact persisted representation.
	# JSON rounds float64 spacing/corridors: cold and warm control must see the
	# same numbers, otherwise a later quantization boundary can differ by a bit.
	var normalized := RacingTrajectory.new()
	var loaded: bool = normalized.restore(JSON.parse_string(JSON.stringify(winner.serialize())),track,config)
	assert(loaded,"Planner must emit a valid reusable trajectory")
	return normalized

static func _pilot(track: NativeTrack, config: HandlingConfig, trajectory: RacingTrajectory) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.reset(track.spawn,track.spawn_heading)
	var distance: float = (sim.state.position-track.finish_center).dot(track.finish_forward)
	sim.state.position -= track.finish_forward*maxf(0.0,distance+3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	sim.state.track_elevated = track.elevated_at(sim.state.position,sim.state.route_index)
	if CreatorBridges.at_any(track.creator_bridges,sim.state.position): sim.state.track_elevated = CreatorBridges.initial_layer(track.creator_bridges,sim.state.position,sim.state.heading)
	var session := TrackSession.new(VehicleSimulation.TICK_RATE,2)
	var mpc := TrajectoryMPC.new()
	var held := DriveFrame.new()
	var gate: int = -1
	var progressed: int = 0
	for tick: int in range(30000):
		if tick%TrajectoryMPC.UPDATE_TICKS == 0:
			var s: float = trajectory.project(sim.state.position,track.route_progress(sim.state.position,sim.state.route_index))
			held = mpc.control(sim.state,trajectory,s,config,0.9225,0.5)
		var before: Vector2 = sim.state.position
		var layer: int = int(sim.state.track_elevated)
		sim.step(held,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,layer)
		if session.next_checkpoint != gate: gate = session.next_checkpoint; progressed = tick
		if session.finished or session.missed_checkpoint >= 0 or tick-progressed > 1800: break
	var standing: int = roundi(session.lap_times[0]*VehicleSimulation.TICK_RATE) if not session.lap_times.is_empty() else 0
	var flying: int = roundi(session.lap_times[1]*VehicleSimulation.TICK_RATE) if session.lap_times.size() > 1 else 0
	return {"finished":session.finished,"ticks":session.elapsed_ticks,"contacts":sim.state.collision_count,"missed_gate":session.missed_checkpoint,"standing_ticks":standing,"flying_ticks":flying,"estimated_race_ticks":standing+4*flying}

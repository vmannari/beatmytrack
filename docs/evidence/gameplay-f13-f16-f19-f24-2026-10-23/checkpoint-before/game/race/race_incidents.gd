extends RefCounted
## Bounded cosmetic-bonus observations, separate from timing/physics authority.
static func build(session: TrackSession, telemetry: LapTelemetry, state: VehicleState) -> Dictionary:
	if not session.finished or session.completed_laps != RaceRules.LAPS or telemetry.completed.size() != RaceRules.LAPS: return {}
	var collisions: int = state.collision_count
	var off_track: bool = false
	for lap: Dictionary in telemetry.completed:
		if not lap.get("valid",false) or lap.get("samples",[]).is_empty(): return {}
		for event: Dictionary in lap.get("events",[]):
			if event.get("kind") == "collision": collisions = maxi(collisions,1)
			else: off_track = true
	return {"schema":"bmt-race-incidents-v1","ticks":session.elapsed_ticks,"collision_count":collisions,"off_track":off_track}

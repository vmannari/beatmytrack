class_name TrajectoryMusicAnalyzer
extends RefCounted
## Presentation-only constant-yaw projection. It does not simulate tyre forces.
var off_track_risk: float = 0.0
var overspeed_risk: float = 0.0
var slip_risk: float = 0.0
var driving_risk: float = 0.0
func analyze(state: VehicleState, track: NativeTrack, map: TrackMusicAnalyzer, seconds: float) -> float:
	off_track_risk = 0.0; overspeed_risk = 0.0
	if map.states.is_empty(): return 0.0
	var position: Vector2 = state.position
	var velocity: Vector2 = state.velocity
	var hint: int = state.route_index
	for step: int in range(6):
		velocity = velocity.rotated(-clampf(state.yaw_rate,-2.0,2.0)*seconds/6.0)
		position += velocity*seconds/6.0
		hint = track.nearest_route(position,hint)
		var d: float = track.route_progress(position,hint)
		var index: int = map.index_at(d)
		var error: float = position.distance_to(track._race_route_point(d))
		off_track_risk = maxf(off_track_risk,smoothstep(map.widths[index]*0.35,map.widths[index]*0.8,error))
		overspeed_risk = maxf(overspeed_risk,smoothstep(1.05,1.7,velocity.length()/map.expected_speed[index]))
	slip_risk = smoothstep(0.12,0.65,absf(state.slip_angle()))
	driving_risk = clampf(0.5*off_track_risk+0.3*overspeed_risk+0.2*slip_risk,0.0,1.0)
	return driving_risk

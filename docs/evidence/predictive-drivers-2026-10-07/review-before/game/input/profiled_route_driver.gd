class_name ProfiledRouteDriver
extends RefCounted
const VERSION: String = "profiled-route-3"
## Offline development controller. It only emits ordinary quantized inputs.
## The conservative regression RouteDriver and canonical simulation are unchanged.
var rng := RandomNumberGenerator.new()
var skill: float
var consistency: float
var aggression: float
var pace_scale: float
var tick: int = 0
var noise: float = 0.0
var steering_noise: float = 0.0
var mistake_until: int = 0
var recovery: bool = false
var mistakes: int = 0
var detour_until: int = 0
var reverse_until: int = 0
var detour_side: float = 1.0
var gate_seen: int = -1
var gate_tick: int = 0
var obstacle_detours: bool = false

func _init(traits: Dictionary, theme: String, content: String, attempt: int, scale: float = 1.0) -> void:
	rng.seed = (str(traits.seed)+"/"+content+"/"+str(attempt)).sha256_text().left(15).hex_to_int()
	consistency = clampf(float(traits.consistency),0.0,1.0)
	aggression = clampf(float(traits.aggression),0.0,1.0)
	var learning: float = float(traits.learning)*0.035*(1.0-exp(-float(attempt)/2.5))
	skill = clampf(float(traits.skill)+float(traits.strengths.get(theme,0.0))+learning,0.0,1.0)
	pace_scale = clampf(scale,0.6,2.0)
	# Session form is correlated across a whole attempt, rather than frame jitter.
	pace_scale *= 1.0+rng.randf_range(-0.018,0.018)*(1.0-consistency)

func sample(state: VehicleState, track: NativeTrack, config: HandlingConfig, session: TrackSession) -> DriveFrame:
	tick += 1
	var gate: int = session.next_checkpoint+session.completed_laps*10000
	if gate != gate_seen:
		gate_seen = gate
		gate_tick = tick
	if tick % 120 == 1:
		noise = lerpf(noise,rng.randf_range(-0.035,0.035)*(1.0-consistency),0.35)
		steering_noise = lerpf(steering_noise,rng.randf_range(-0.05,0.05)*(1.0-consistency),0.4)
		if rng.randf() < 0.008*(1.0-consistency)*(0.5+aggression) and tick > 600:
			mistake_until = tick+rng.randi_range(35,100)
			mistakes += 1
	var index: int = track.nearest_route(state.position,state.route_index)
	var speed: float = state.velocity.length()
	var lookahead: int = clampi(2+floori(speed/8.0),3,6)
	var target: Vector2 = track.route[(index+lookahead)%track.route.size()]
	# Return behind a missed gate, then cross it in the required direction.
	# This changes only controller targets; no teleport, gate skipping or time edits.
	if session.initialized and session.missed_checkpoint >= 0:
		var center: Vector2 = session.checkpoint_road_center(track)
		var direction: Vector2 = session.checkpoint_direction(track)
		if (state.position-center).dot(direction) > -4.0 and not recovery:
			target = center-direction*8.0
		else:
			recovery = true
			target = center+direction*3.0
	else: recovery = false
	var offset: Vector2 = target-state.position
	var avoidance: Vector2 = _obstacle_normal(state.position+state.velocity*0.35,state,track,config)
	var route_direction: Vector2 = (track.route[(index+lookahead)%track.route.size()]-track.route[index]).normalized()
	var lateral: Vector2 = route_direction.orthogonal()
	var clearance: float = minf(6.0,maxf(1.0,track.route_widths[index]*0.5-config.collision_radius-0.4))
	# A head-on tyre wall needs a real reverse-and-detour manoeuvre. Pushing
	# directly against its normal cannot rotate a stationary car around it.
	if obstacle_detours and avoidance != Vector2.ZERO and tick > detour_until:
		var scores: Array[int] = [0,0]
		for side: int in range(2):
			for distance: float in [2.0,4.0,6.0,8.0]:
				var probe: Vector2 = state.position+route_direction*distance+lateral*clearance*(1.0 if side == 0 else -1.0)
				if _obstacle_normal(probe,state,track,config) != Vector2.ZERO: scores[side] += 1
		detour_side = 1.0 if scores[0] < scores[1] else -1.0
		reverse_until = tick+90 if speed < 0.7 or tick-gate_tick > 240 else tick
		detour_until = tick+600
	if tick < detour_until:
		offset += lateral*clearance*detour_side
	elif avoidance != Vector2.ZERO: offset += avoidance*3.0
	var desired: float = atan2(offset.x,offset.y)
	var error: float = wrapf(desired-state.heading,-PI,PI)
	var steer: float = clampf(error*2.3-state.yaw_rate*0.15+steering_noise,-1.0,1.0)
	var future: Vector2 = track.route[(index+12)%track.route.size()]-target
	var corner: float = absf(wrapf(atan2(future.x,future.y)-desired,-PI,PI))
	# Keep momentum through bends; the old heading-error subtraction braked
	# continually even while following a clean line. Full throttle is ordinary
	# canonical input, with braking retained for sharp corners and gate recovery.
	var speed_goal: float = clampf(23.0-corner*12.0-absf(error)*5.0,5.0,23.0)
	speed_goal *= (0.70+skill*0.40+aggression*0.04+noise)*pace_scale
	if avoidance != Vector2.ZERO: speed_goal = minf(speed_goal,4.0)
	if session.missed_checkpoint >= 0: speed_goal = minf(speed_goal,3.5)
	if tick < mistake_until: speed_goal *= 0.65
	speed_goal = minf(speed_goal,config.maximum_speed*0.8)
	var frame := DriveFrame.new()
	frame.steer = clampi(roundi(steer*127),-127,127)
	frame.throttle = 255 if speed < speed_goal else 0
	frame.brake = 128 if speed > speed_goal+0.6+aggression*0.7 else 0
	if tick < reverse_until:
		frame.steer = 0
		frame.throttle = 0
		frame.brake = 255
	return frame

func _obstacle_normal(point: Vector2, state: VehicleState, track: NativeTrack, config: HandlingConfig) -> Vector2:
	var normal: Vector2 = track.collision_normal(point,config.collision_radius+0.3,state.track_elevated)
	if state.track_elevated or not obstacle_detours: return normal
	var closest: float = config.collision_radius+0.3+LooseTyres.RADIUS
	for tyre: Array in state.loose_tyres:
		var delta: Vector2 = point-Vector2(float(tyre[0]),float(tyre[1]))
		if delta.length() < closest:
			closest = delta.length()
			normal = delta.normalized() if closest > 0.001 else -state.forward()
	return normal

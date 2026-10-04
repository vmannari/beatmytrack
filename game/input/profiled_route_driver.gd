class_name ProfiledRouteDriver
extends RefCounted
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
	if tick % 120 == 1:
		noise = lerpf(noise,rng.randf_range(-0.035,0.035)*(1.0-consistency),0.35)
		steering_noise = lerpf(steering_noise,rng.randf_range(-0.05,0.05)*(1.0-consistency),0.4)
		if rng.randf() < 0.008*(1.0-consistency)*(0.5+aggression) and tick > 600:
			mistake_until = tick+rng.randi_range(35,100)
			mistakes += 1
	var index: int = track.nearest_route(state.position,state.route_index)
	var target: Vector2 = track.route[(index+3)%track.route.size()]
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
	var avoidance: Vector2 = track.collision_normal(state.position+state.velocity*0.35,config.collision_radius+0.3,state.track_elevated)
	if avoidance != Vector2.ZERO: offset += avoidance*3.0
	var desired: float = atan2(offset.x,offset.y)
	var error: float = wrapf(desired-state.heading,-PI,PI)
	var steer: float = clampf(error*2.3-state.yaw_rate*0.15+steering_noise,-1.0,1.0)
	var future: Vector2 = track.route[(index+12)%track.route.size()]-target
	var corner: float = absf(wrapf(atan2(future.x,future.y)-desired,-PI,PI))
	var speed_goal: float = clampf(12.0-corner*10.0-absf(error)*8.0,3.0,12.0)
	speed_goal *= (0.85+skill*0.95+aggression*0.06+noise)*pace_scale
	if avoidance != Vector2.ZERO: speed_goal = minf(speed_goal,4.0)
	if session.missed_checkpoint >= 0: speed_goal = minf(speed_goal,3.5)
	if tick < mistake_until: speed_goal *= 0.65
	speed_goal = minf(speed_goal,config.maximum_speed*0.8)
	var speed: float = state.velocity.length()
	var frame := DriveFrame.new()
	frame.steer = clampi(roundi(steer*127),-127,127)
	frame.throttle = 166 if speed < speed_goal else 0
	frame.brake = 128 if speed > speed_goal+0.6+aggression*0.7 else 0
	return frame

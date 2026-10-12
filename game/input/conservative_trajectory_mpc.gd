class_name ConservativeTrajectoryMPC
extends RefCounted
## Bounded LTV Frenet MPC. Five states: lateral/heading/yaw/lateral-velocity/
## speed error. Steering and acceleration controls; canonical physics is external.
const VERSION: String = "frenet-ltv-mpc-2"
const HORIZON: int = 16
const DT: float = 0.1
const UPDATE_TICKS: int = 12 # 10 Hz against canonical 120 Hz.
const ITERATIONS: int = 14
var steering := PackedFloat64Array()
var acceleration := PackedFloat64Array()
var references: Array[Dictionary] = []
var predicted: Array[PackedFloat64Array] = []
var initial := PackedFloat64Array()
var config: HandlingConfig
var yaw_decay: float
var side_decay: float
var smoothness: float = 0.6
var previous_steering: float = 0.0
var previous_acceleration: float = 0.0
var updates: int = 0
var last_cost: float = 0.0
var guidance_steering: float = 0.0
var guidance_acceleration: float = 0.0

func control(state: VehicleState, trajectory: RacingTrajectory, progress: float, handling: HandlingConfig, pace: float, skill: float, disturbance: float = 0.0) -> DriveFrame:
	config = handling
	yaw_decay = exp(-config.mass/config.rotational_inertia*7.0*DT)
	side_decay = exp(-config.lateral_response*DT)
	smoothness = lerpf(1.8,0.35,skill)
	var reference: Dictionary = trajectory.at(progress)
	var speed: float = state.velocity.length()
	var aim: Dictionary = trajectory.at(progress+4.0+speed*0.25)
	var offset: Vector2 = aim.point-state.position
	var angle: float = config.steering_angle*(1.0-config.high_speed_steering_reduction*clampf(speed/24.0,0.0,1.0))
	var pursuit: float = 2.0*offset.dot(state.right())/maxf(offset.length_squared(),1.0)
	guidance_steering = clampf(atan(config.wheelbase*pursuit)/angle-state.yaw_rate*0.025,-1.0,1.0)
	var braking_preview: Dictionary = trajectory.at(progress+speed*lerpf(0.20,0.02,skill))
	var speed_goal: float = minf(reference.speed,braking_preview.speed)*pace
	guidance_acceleration = clampf((speed_goal-speed)*lerpf(2.1,3.5,skill),-config.braking_force/config.mass,RacingTrajectory.drive_acceleration(config,speed,reference.grip,reference.drag))
	var normal := Vector2(cos(reference.heading),-sin(reference.heading))
	initial = PackedFloat64Array([(state.position-reference.point).dot(normal),wrapf(state.heading-reference.heading,-PI,PI),state.yaw_rate,state.velocity.dot(state.right()),state.velocity.length()-maxf(2.0,state.velocity.length())])
	references.clear()
	var s: float = progress
	var travel_speed: float = maxf(2.0,state.velocity.length())
	for i: int in range(HORIZON):
		var ref: Dictionary = trajectory.at(s)
		ref.speed *= pace
		var margin: float = lerpf(0.45,0.10,skill)
		ref.lower = minf(0.0,float(ref.lower)+margin)
		ref.upper = maxf(0.0,float(ref.upper)-margin)
		ref.nominal = travel_speed
		var next_speed: float = move_toward(travel_speed,ref.speed,8.0*DT)
		var next: Dictionary = trajectory.at(s+travel_speed*DT)
		ref.turn = wrapf(next.heading-ref.heading,-PI,PI)
		ref.dv = next_speed-travel_speed
		var steer_angle: float = config.steering_angle*(1.0-config.high_speed_steering_reduction*clampf(travel_speed/24.0,0.0,1.0))
		var ratio: float = config.front_grip/config.rear_grip
		ref.yaw_bound = minf(config.maximum_yaw_rate,config.lateral_grip*ref.grip/maxf(travel_speed,2.0))*0.92
		var nominal_yaw: float = clampf(travel_speed*ref.curvature,-ref.yaw_bound*0.95,ref.yaw_bound*0.95)
		var raw_nominal: float = nominal_yaw
		if config.progressive_handling:
			var yaw_capacity: float = maxf(0.1,config.lateral_grip*config.front_grip*ref.grip/maxf(travel_speed,1.0))
			nominal_yaw = clampf(nominal_yaw,-yaw_capacity*0.90,yaw_capacity*0.90)
			raw_nominal = nominal_yaw/pow(1.0-pow(absf(nominal_yaw)/yaw_capacity,6),1.0/6.0)
		# Linearize at a physically feasible steer, even when the current car
		# is too fast for a reference bend. Otherwise the saturated affine
		# model can have no admissible input interval at all.
		var feed_angle: float = clampf(atan(raw_nominal*config.wheelbase/maxf(travel_speed,1.0)/ratio),-steer_angle,steer_angle)
		var yaw: float = travel_speed/config.wheelbase*tan(feed_angle)*ratio
		var derivative: float = maxf(2.0,travel_speed)/config.wheelbase*steer_angle*ratio/pow(cos(feed_angle),2)
		if config.progressive_handling:
			var demand: float = absf(yaw)/maxf(0.1,config.lateral_grip*config.front_grip*ref.grip/maxf(travel_speed,1.0))
			var saturation: float = pow(1.0+pow(demand,6),-1.0/6.0)
			yaw *= saturation
			derivative *= pow(saturation,7)
		ref.gain = derivative
		ref.bias = yaw-derivative*feed_angle/steer_angle
		ref.drive = RacingTrajectory.drive_acceleration(config,travel_speed,ref.grip,ref.drag)
		ref.brake = minf(config.braking_force/config.mass,config.longitudinal_grip*ref.grip)*0.85
		ref.side = travel_speed*(1.0-side_decay)/config.lateral_response
		ref.yaw = travel_speed*ref.curvature
		ref.heading_goal = atan(ref.yaw/config.lateral_response)
		ref.side_goal = -travel_speed*ref.yaw/config.lateral_response
		# Invert the complete affine model. Dropping its bias clipped usable
		# steering on tight bends and made feasible reference lines run wide.
		ref.steer_lower = maxf(-1.0,(-ref.yaw_bound-ref.bias)/ref.gain)
		ref.steer_upper = minf(1.0,(ref.yaw_bound-ref.bias)/ref.gain)
		references.append(ref)
		s += travel_speed*DT
		travel_speed = next_speed
	if steering.size() != HORIZON:
		steering.resize(HORIZON); acceleration.resize(HORIZON)
		for i: int in range(HORIZON):
			steering[i] = clampf((references[i].yaw-references[i].bias)/references[i].gain,references[i].steer_lower,references[i].steer_upper)
			acceleration[i] = clampf(references[i].dv/DT+2.0*(references[i].speed-state.velocity.length()),-references[i].brake,references[i].drive)
	else:
		for i: int in range(HORIZON-1): steering[i] = steering[i+1]; acceleration[i] = acceleration[i+1]
	var cost: float = _rollout(steering,acceleration,true)
	for iteration: int in range(ITERATIONS):
		var gradients: Array[PackedFloat64Array] = _gradient()
		var accepted: bool = false
		var step: float = 0.03/(1.0+state.velocity.length_squared()/400.0)
		for search: int in range(5):
			var trial_steer: PackedFloat64Array = steering.duplicate()
			var trial_accel: PackedFloat64Array = acceleration.duplicate()
			var last: float = previous_steering
			for i: int in range(HORIZON):
				var low: float = maxf(references[i].steer_lower,last-config.steering_rate*DT)
				var high: float = minf(references[i].steer_upper,last+config.steering_rate*DT)
				var alow: float = -references[i].brake
				var ahigh: float = references[i].drive
				if i == 0:
					# Keep the linearization local during sharp corners/recovery.
					low = maxf(low,guidance_steering-0.12); high = minf(high,guidance_steering+0.12)
					alow = maxf(alow,guidance_acceleration-1.5); ahigh = minf(ahigh,guidance_acceleration+1.5)
				if low > high: low = clampf(guidance_steering,references[i].steer_lower,references[i].steer_upper); high = low
				if alow > ahigh: alow = clampf(guidance_acceleration,-references[i].brake,references[i].drive); ahigh = alow
				trial_steer[i] = clampf(trial_steer[i]-step*gradients[0][i],low,high)
				trial_accel[i] = clampf(trial_accel[i]-step*gradients[1][i]*12.0,alow,ahigh)
				last = trial_steer[i]
			var candidate: float = _rollout(trial_steer,trial_accel,false)
			if is_finite(candidate) and candidate < cost:
				steering = trial_steer; acceleration = trial_accel; cost = _rollout(steering,acceleration,true); accepted = true; break
			step *= 0.35
		if not accepted: break
	last_cost = cost
	updates += 1
	previous_steering = clampf(clampf(steering[0],guidance_steering-0.12,guidance_steering+0.12),references[0].steer_lower,references[0].steer_upper)
	previous_acceleration = clampf(clampf(acceleration[0],guidance_acceleration-1.5,guidance_acceleration+1.5),-references[0].brake,references[0].drive)
	var frame := DriveFrame.new()
	frame.steer = clampi(roundi((previous_steering+disturbance)*127.0),-127,127)
	var force: float = config.engine_force/config.mass*(1.0-0.45*clampf(state.velocity.length()/config.maximum_speed,0.0,1.0))
	var drag: float = (config.drag*state.velocity.length_squared()+config.rolling_resistance)/config.mass+reference.drag
	var pedal: float = previous_acceleration+drag
	if pedal >= 0.0: frame.throttle = clampi(roundi(pedal/maxf(0.1,force)*255.0),0,255)
	else: frame.brake = clampi(roundi(-pedal/(config.braking_force/config.mass)*255.0),0,255)
	return frame

func _rollout(u: PackedFloat64Array, a: PackedFloat64Array, save: bool) -> float:
	var z: PackedFloat64Array = initial.duplicate()
	var total: float = 0.0
	var last_u: float = previous_steering
	var last_a: float = previous_acceleration
	if save: predicted.clear()
	for i: int in range(HORIZON):
		var ref: Dictionary = references[i]
		var r: float = yaw_decay*z[2]+(1.0-yaw_decay)*(ref.gain*u[i]+ref.bias)
		var h: float = z[1]+DT*r-ref.turn-DT*ref.curvature*z[4]
		var b: float = side_decay*z[3]-ref.side*r
		var y: float = z[0]+DT*(ref.nominal*h+b)
		var v: float = z[4]+DT*a[i]-ref.dv
		z = PackedFloat64Array([y,h,r,b,v])
		var weight: float = 3.0 if i == HORIZON-1 else 1.0
		var outside: float = y-clampf(y,ref.lower,ref.upper)
		var speed_error: float = v+ref.nominal+ref.dv-ref.speed
		total += weight*(y*y+8.0*pow(h-ref.heading_goal,2)+0.12*speed_error*speed_error+0.10*pow(r-ref.yaw,2)+0.025*pow(b-ref.side_goal,2)+30.0*outside*outside-0.025*speed_error)
		total += smoothness*pow(u[i]-last_u,2)+0.008*pow(a[i]-last_a,2)
		last_u = u[i]; last_a = a[i]
		if save: predicted.append(z)
	return total

func _gradient() -> Array[PackedFloat64Array]:
	var gu := PackedFloat64Array(); gu.resize(HORIZON)
	var ga := PackedFloat64Array(); ga.resize(HORIZON)
	var ly: float = 0.0; var lh: float = 0.0; var lr: float = 0.0; var lb: float = 0.0; var lv: float = 0.0
	for i: int in range(HORIZON-1,-1,-1):
		var ref: Dictionary = references[i]
		var z: PackedFloat64Array = predicted[i]
		var weight: float = 3.0 if i == HORIZON-1 else 1.0
		ly += weight*(2.0*z[0]+60.0*(z[0]-clampf(z[0],ref.lower,ref.upper)))
		lh += weight*16.0*(z[1]-ref.heading_goal)
		lr += weight*0.2*(z[2]-ref.yaw)
		lb += weight*0.05*(z[3]-ref.side_goal)
		lv += weight*(0.24*(z[4]+ref.nominal+ref.dv-ref.speed)-0.025)
		lh += DT*ref.nominal*ly
		lb += DT*ly
		lr += DT*lh-ref.side*lb
		gu[i] += (1.0-yaw_decay)*ref.gain*lr
		ga[i] += DT*lv
		var du: float = 2.0*smoothness*(steering[i]-(previous_steering if i == 0 else steering[i-1]))
		var da: float = 0.016*(acceleration[i]-(previous_acceleration if i == 0 else acceleration[i-1]))
		gu[i] += du; ga[i] += da
		if i > 0: gu[i-1] -= du; ga[i-1] -= da
		lv -= DT*ref.curvature*lh
		lr *= yaw_decay
		lb *= side_decay
	return [gu,ga]

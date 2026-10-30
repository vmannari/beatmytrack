class_name TrajectoryMPC
extends RefCounted
## Bounded LTV Frenet MPC. Five states: lateral/heading/yaw/lateral-velocity/
## speed error. Steering and acceleration controls; canonical physics is external.
const VERSION: String = "frenet-ltv-mpc-3"
const HORIZON: int = 16
const DT: float = 0.1
const UPDATE_TICKS: int = 12 # 10 Hz against canonical 120 Hz.
const ITERATIONS: int = 14
const PROGRESS_REWARD: float = 0.025
var steering := PackedFloat64Array()
var acceleration := PackedFloat64Array()
var references: Array[Dictionary] = []
var predicted: Array[PackedFloat64Array] = []
var initial := PackedFloat64Array()
var config: HandlingConfig
var yaw_decay: float
var side_decay: float
var smoothness: float = 0.6
var tracking_weight: float = 1.0
var grip_utilization: float = 1.0
var previous_steering: float = 0.0
var previous_acceleration: float = 0.0
var updates: int = 0
var last_cost: float = 0.0
var guidance_steering: float = 0.0
var guidance_acceleration: float = 0.0
var steering_trust: float = 0.12
var recovering: bool = false
var conservative: ConservativeTrajectoryMPC

func control(state: VehicleState, trajectory: RacingTrajectory, progress: float, handling: HandlingConfig, pace: float, skill: float, disturbance: float = 0.0, track: NativeTrack = null) -> DriveFrame:
	if handling.vehicle_id != "compact" or trajectory.safe_reference:
		if conservative == null: conservative = ConservativeTrajectoryMPC.new()
		var frame: DriveFrame = conservative.control(state,trajectory,progress,handling,pace,skill,disturbance)
		updates = conservative.updates
		return frame
	config = handling
	yaw_decay = exp(-config.mass/config.rotational_inertia*7.0*DT)
	side_decay = exp(-config.lateral_response*DT)
	smoothness = lerpf(1.8,1.3,minf(skill*2.0,1.0))
	tracking_weight = 0.75+skill*0.5
	grip_utilization = clampf(0.85+skill*0.30,0.85,1.0)
	var reference: Dictionary = trajectory.at(progress)
	var speed: float = state.velocity.length()
	var lookahead: float = 4.0+speed*0.25
	var aim: Dictionary = trajectory.at(progress+lookahead)
	var apex_bias: float = maxf(0.0,skill-0.5)*0.8
	var aim_bias: float = clampf(signf(aim.curvature)*apex_bias,float(aim.lower),float(aim.upper))
	aim.point += Vector2(cos(aim.heading),-sin(aim.heading))*aim_bias
	var offset: Vector2 = aim.point-state.position
	var forward_velocity: float = state.velocity.dot(state.forward())
	var angle: float = config.steering_angle*(1.0-config.high_speed_steering_reduction*clampf(absf(forward_velocity)/24.0,0.0,1.0))
	var travel_direction: Vector2 = state.velocity.normalized() if speed > 2.0 else state.forward()
	var travel_right := Vector2(travel_direction.y,-travel_direction.x)
	var pursuit: float = 2.0*offset.dot(travel_right)/maxf(offset.length_squared(),1.0)
	guidance_steering = clampf(atan(config.wheelbase*pursuit*config.rear_grip/config.front_grip*speed/maxf(absf(forward_velocity),maxf(1.0,speed*0.5)))/angle-(state.yaw_rate-speed*reference.curvature)*0.025,-1.0,1.0)
	var braking_preview: Dictionary = trajectory.at(progress+speed*maxf(0.12,lerpf(0.20,0.02,skill)))
	var speed_goal: float = minf(_speed_limit(reference.curvature,float(reference.grip)*state.grip),minf(reference.speed,braking_preview.speed)*pace)
	var slope: float = (float(trajectory.at(progress+2.0).speed)-float(trajectory.at(progress-2.0).speed))*pace/4.0
	var feed_acceleration: float = speed*slope
	guidance_acceleration = clampf(feed_acceleration+(speed_goal-speed)*lerpf(2.1,2.8,minf(skill*2.0,1.0)),-config.braking_force/config.mass,RacingTrajectory.drive_acceleration(config,speed,reference.grip,reference.drag,reference.curvature))
	var normal := Vector2(cos(reference.heading),-sin(reference.heading))
	initial = PackedFloat64Array([(state.position-reference.point).dot(normal),wrapf(state.heading-reference.heading,-PI,PI),state.yaw_rate,state.velocity.dot(state.right()),state.velocity.length()-maxf(2.0,state.velocity.length())])
	var heading_goal: float = atan(speed*float(reference.curvature)/config.lateral_response)
	if config.vehicle_id in ["compact","kart"]:
		if absf(initial[0]) > 0.8 or absf(initial[1]-heading_goal) > 0.1: recovering = true
		elif absf(initial[0]) < 0.35 and absf(initial[1]-heading_goal) < 0.05: recovering = false
	steering_trust = (0.50 if config.vehicle_id == "kart" else 0.28) if recovering else 0.12
	references.clear()
	var s: float = progress
	var travel_speed: float = maxf(2.0,state.velocity.length())
	var nominal_side: float = state.velocity.dot(state.right())
	var loose_contact: bool = track != null and track.tire_pickup(state) > 0.0
	var tire_grip: float = 1.0-maxf(VehicleSimulation.dirt_grip_loss(state.tire_dirt,config.dirty_tire_grip_loss,loose_contact),maxf(state.tire_oil*0.65,state.tire_water*0.18))
	for i: int in range(HORIZON):
		var ref: Dictionary = trajectory.at(s)
		ref.speed = minf(_speed_limit(ref.curvature,float(ref.grip)*state.grip),float(ref.speed)*pace)
		var margin: float = lerpf(0.45,0.10,skill)
		ref.lower = minf(0.0,float(ref.lower)+margin)
		ref.upper = maxf(0.0,float(ref.upper)-margin)
		ref.lateral_goal = clampf(signf(ref.curvature)*apex_bias,ref.lower,ref.upper)
		ref.nominal = travel_speed
		var change: float = RacingTrajectory.drive_acceleration(config,travel_speed,ref.grip,ref.drag,ref.curvature) if ref.speed > travel_speed else RacingTrajectory.braking_acceleration(config,travel_speed,ref.grip,ref.curvature)
		var next_speed: float = move_toward(travel_speed,ref.speed,change*DT)
		var next: Dictionary = trajectory.at(s+travel_speed*DT)
		ref.turn = wrapf(next.heading-ref.heading,-PI,PI)
		ref.dv = next_speed-travel_speed
		var nominal_forward: float = sqrt(maxf(1.0,travel_speed*travel_speed-nominal_side*nominal_side))
		var steer_angle: float = config.steering_angle*(1.0-config.high_speed_steering_reduction*clampf(nominal_forward/24.0,0.0,1.0))
		var ratio: float = config.front_grip/config.rear_grip
		var allowed_yaw: float = maxf(config.maximum_yaw_rate,3.2) if config.vehicle_id == "compact" and track != null and absf(ref.curvature) >= 0.075 else config.maximum_yaw_rate
		ref.yaw_bound = (minf(allowed_yaw,config.lateral_grip*ref.grip/maxf(travel_speed,2.0)) if config.progressive_handling else allowed_yaw)*0.98
		var nominal_yaw: float = clampf(travel_speed*ref.curvature,-ref.yaw_bound*0.95,ref.yaw_bound*0.95)
		var raw_nominal: float = nominal_yaw
		if config.progressive_handling:
			var yaw_capacity: float = maxf(0.1,config.lateral_grip*config.front_grip*ref.grip/maxf(travel_speed,1.0))
			nominal_yaw = clampf(nominal_yaw,-yaw_capacity*0.90,yaw_capacity*0.90)
			raw_nominal = nominal_yaw/pow(1.0-pow(absf(nominal_yaw)/yaw_capacity,6),1.0/6.0)
		# Linearize at a physically feasible steer, even when the current car
		# is too fast for a reference bend. Otherwise the saturated affine
		# model can have no admissible input interval at all.
		var feed_angle: float = clampf(atan(raw_nominal*config.wheelbase/maxf(nominal_forward,1.0)/ratio),-steer_angle,steer_angle)
		var yaw: float = nominal_forward/config.wheelbase*tan(feed_angle)*ratio
		var derivative: float = maxf(2.0,nominal_forward)/config.wheelbase*steer_angle*ratio/pow(cos(feed_angle),2)
		if config.progressive_handling:
			var demand: float = absf(yaw)/maxf(0.1,config.lateral_grip*config.front_grip*ref.grip/maxf(travel_speed,1.0))
			var saturation: float = pow(1.0+pow(demand,6),-1.0/6.0)
			yaw *= saturation
			derivative *= pow(saturation,7)
		ref.gain = derivative
		ref.bias = yaw-derivative*feed_angle/steer_angle
		ref.drive = RacingTrajectory.drive_acceleration(config,travel_speed,ref.grip,ref.drag)
		var turn_loss: float = (1.0-config.corner_energy_retention)*travel_speed*pow(travel_speed*float(ref.curvature),2)/config.lateral_response
		var resistance_loss: float = (config.drag*travel_speed*travel_speed+config.rolling_resistance)/config.mass+float(ref.drag)
		ref.brake = RacingTrajectory.braking_acceleration(config,travel_speed,ref.grip,ref.curvature)+turn_loss+resistance_loss
		var response: float = config.lateral_response*tire_grip
		var capacity: float = config.lateral_grip*ref.grip*state.grip
		var saturated: bool = absf(nominal_side)*response > capacity
		ref.side_decay = 1.0 if saturated else exp(-response*DT)
		ref.side_bias = -signf(nominal_side)*capacity*DT if saturated else 0.0
		ref.side = nominal_forward*DT if saturated else nominal_forward*(1.0-ref.side_decay)/maxf(response,0.1)
		ref.side_speed = -nominal_yaw*DT*travel_speed/nominal_forward
		ref.yaw = nominal_yaw
		nominal_side = clampf(ref.side_decay*nominal_side+ref.side_bias-ref.side*nominal_yaw,-next_speed*0.9,next_speed*0.9)
		ref.heading_goal = asin(clampf(-nominal_side/maxf(next_speed,2.0),-0.9,0.9))
		ref.side_goal = nominal_side
		ref.lateral_heading = next_speed
		ref.lateral_side = 1.0/cos(ref.heading_goal)
		ref.lateral_speed = tan(ref.heading_goal)
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
					low = maxf(low,guidance_steering-steering_trust); high = minf(high,guidance_steering+steering_trust)
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
	previous_steering = clampf(clampf(steering[0],guidance_steering-steering_trust,guidance_steering+steering_trust),references[0].steer_lower,references[0].steer_upper)
	previous_acceleration = clampf(clampf(acceleration[0],guidance_acceleration-1.5,guidance_acceleration+1.5),-references[0].brake,references[0].drive)
	var frame := DriveFrame.new()
	frame.steer = clampi(roundi((previous_steering+disturbance)*127.0),-127,127)
	var forward_speed: float = state.velocity.dot(state.forward())
	var falloff: float = 1.0-0.45*clampf(forward_speed/config.maximum_speed,0.0,1.0)
	if config.slide_power_recovery > 0.0 and forward_speed > 0.0:
		falloff += (1.0-falloff)*config.slide_power_recovery*smoothstep(0.06,0.30,absf(state.slip_angle()))
	var force: float = config.engine_force/config.mass*falloff
	var drag: float = (config.drag*state.velocity.length_squared()+config.rolling_resistance)/config.mass+reference.drag
	var lateral: float = state.velocity.dot(state.right())-state.velocity.dot(state.forward())*state.yaw_rate*VehicleSimulation.STEP
	var lateral_force: float = minf(absf(lateral)*config.lateral_response,config.lateral_grip*reference.grip*state.grip)
	var remaining: float = move_toward(lateral,0.0,lateral_force*VehicleSimulation.STEP)
	var alignment: float = clampf(absf(state.velocity.dot(state.forward()))/maxf(absf(lateral),0.01),0.0,1.0)
	var scrub: float = maxf(0.0,lateral*lateral-remaining*remaining)*(1.0-config.corner_energy_retention*alignment)/maxf(2.0*speed*VehicleSimulation.STEP,0.1)
	var pedal: float = previous_acceleration+drag+scrub
	if pedal >= 0.0: frame.throttle = clampi(roundi(pedal/maxf(0.1,force)*255.0),0,255)
	else: frame.brake = clampi(roundi(-pedal/(config.braking_force/config.mass)*255.0),0,255)
	return TrajectoryHandbrake.refine(state,track,trajectory,progress,config,frame,pace) if track != null else frame

func _speed_limit(k: float, grip: float = 1.0) -> float:
	# Skill can spend the planner's margins, never request a steady turn beyond
	# the actual yaw/steering capacity and then rely on a late correction.
	var yaw_capacity: float = maxf(config.maximum_yaw_rate,3.2) if config.vehicle_id == "compact" and absf(k) >= 0.075 else config.maximum_yaw_rate
	var corner_bound: float = minf(sqrt(config.lateral_grip*grip/maxf(absf(k),0.0001)),minf(yaw_capacity/maxf(absf(k),0.0001),RacingTrajectory.steering_speed(config,absf(k),1.0)))
	return maxf(1.0,minf(config.maximum_speed,corner_bound*grip_utilization))

func _rollout(u: PackedFloat64Array, a: PackedFloat64Array, save: bool) -> float:
	var z: PackedFloat64Array = initial.duplicate()
	var total: float = 0.0
	var last_u: float = previous_steering
	var last_a: float = previous_acceleration
	if save: predicted.clear()
	for i: int in range(HORIZON):
		var ref: Dictionary = references[i]
		var target_yaw: float = ref.gain*u[i]+ref.bias
		var r: float = yaw_decay*z[2]+(1.0-yaw_decay)*target_yaw
		var h: float = z[1]+DT*r-ref.turn-DT*ref.curvature*z[4]
		var b: float = ref.side_decay*z[3]+ref.side_bias-ref.side*r+ref.side_speed*z[4]
		var v: float = z[4]+DT*a[i]-ref.dv
		var y: float = z[0]+DT*(ref.lateral_heading*(h-ref.heading_goal)+ref.lateral_side*(b-ref.side_goal)+ref.lateral_speed*v)
		z = PackedFloat64Array([y,h,r,b,v])
		var weight: float = 3.0 if i == HORIZON-1 else 1.0
		var outside: float = y-clampf(y,ref.lower,ref.upper)
		var speed_error: float = v+ref.nominal+ref.dv-ref.speed
		total += weight*(tracking_weight*pow(y-ref.lateral_goal,2)+8.0*pow(h-ref.heading_goal,2)+0.12*speed_error*speed_error+0.10*pow(r-ref.yaw,2)+0.025*pow(b-ref.side_goal,2)+30.0*outside*outside-PROGRESS_REWARD*speed_error)
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
		ly += weight*(2.0*tracking_weight*(z[0]-ref.lateral_goal)+60.0*(z[0]-clampf(z[0],ref.lower,ref.upper)))
		lh += weight*16.0*(z[1]-ref.heading_goal)
		lr += weight*0.2*(z[2]-ref.yaw)
		lb += weight*0.05*(z[3]-ref.side_goal)
		lv += weight*(0.24*(z[4]+ref.nominal+ref.dv-ref.speed)-PROGRESS_REWARD)
		lh += DT*ref.lateral_heading*ly
		lb += DT*ref.lateral_side*ly
		lv += DT*ref.lateral_speed*ly
		lr += DT*lh-ref.side*lb
		gu[i] += (1.0-yaw_decay)*ref.gain*lr
		ga[i] += DT*lv
		var du: float = 2.0*smoothness*(steering[i]-(previous_steering if i == 0 else steering[i-1]))
		var da: float = 0.016*(acceleration[i]-(previous_acceleration if i == 0 else acceleration[i-1]))
		gu[i] += du; ga[i] += da
		if i > 0: gu[i-1] -= du; ga[i-1] -= da
		lv += ref.side_speed*lb-DT*ref.curvature*lh
		lr *= yaw_decay
		lb *= ref.side_decay
	return [gu,ga]

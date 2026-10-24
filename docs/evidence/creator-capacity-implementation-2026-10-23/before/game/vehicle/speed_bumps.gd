class_name SpeedBumps
extends RefCounted
## Fixed-step sprung pitch and dissipative tyre crossings; never grants energy.
const HEIGHT: float = 0.18

static func height(point: Vector2, objects: Array) -> float:
	var result: float = 0.0
	for object: Dictionary in objects:
		var local: Vector2 = (point-Vector2(object.position[0],object.position[1])).rotated(-deg_to_rad(float(object.rotation)))
		var half: Vector2 = CreatorObjects.size_of(object)*0.5
		if absf(local.x) >= half.x or absf(local.y) > half.y: continue
		result = maxf(result,HEIGHT*float(object.get("scale",1.0))*pow(cos(local.x/half.x*PI*0.5),2.0))
	return result

static func contacts(point: Vector2, heading: float, config: HandlingConfig, objects: Array) -> Vector4:
	var forward := Vector2(sin(heading),cos(heading))*config.wheelbase*0.5
	var right := Vector2(cos(heading),-sin(heading))*config.track_width*0.5
	return Vector4(height(point+forward-right,objects),height(point+forward+right,objects),
		height(point-forward-right,objects),height(point-forward+right,objects))

static func advance(state: VehicleState, previous: Vector2, previous_heading: float, previous_velocity: Vector2, config: HandlingConfig, objects: Array, seconds: float) -> void:
	if objects.is_empty():
		state.bump_transfer = Vector2.ZERO
		return
	var acceleration: float = (state.velocity-previous_velocity).dot(state.forward())/seconds
	var target: float = clampf(acceleration*0.006,-0.085,0.065)
	# Braking compresses the front spring; release/throttle lets it rebound. A
	# held accelerator settles at a pitch and cannot supply the rising-nose benefit.
	state.bump_transfer.y += ((target-state.bump_transfer.x)*110.0-state.bump_transfer.y*10.0)*seconds
	state.bump_transfer.x = clampf(state.bump_transfer.x+state.bump_transfer.y*seconds,-0.12,0.12)
	state.bump_transfer.y = clampf(state.bump_transfer.y,-1.0,1.0)
	if state.track_elevated or state.jump_height > 0.0 or state.roll_ticks > 0: return
	var last: Vector4 = contacts(previous,previous_heading,config,objects)
	var travel: float = previous.distance_to(state.position)+absf(angle_difference(previous_heading,state.heading))*config.wheelbase*0.5
	var samples: int = maxi(1,ceili(travel/0.08))
	var rise := Vector4.ZERO
	for i: int in range(1,samples+1):
		var t: float = float(i)/samples
		var next: Vector4 = contacts(previous.lerp(state.position,t),lerp_angle(previous_heading,state.heading,t),config,objects)
		for wheel: int in range(4): rise[wheel] += maxf(0.0,next[wheel]-last[wheel])
		last = next
	var speed: float = state.velocity.length()
	var forward_speed: float = state.velocity.dot(state.forward())
	var rising: float = state.bump_transfer.y*signf(forward_speed)
	var relief: float = lerpf(1.0,0.18,smoothstep(0.08,0.36,rising))
	var leading: float = (rise.x+rise.y)*0.5 if forward_speed >= 0.0 else (rise.z+rise.w)*0.5
	var trailing: float = (rise.z+rise.w)*0.5 if forward_speed >= 0.0 else (rise.x+rise.y)*0.5
	var loss: float = speed*(leading*3.0*relief+trailing*0.70)*smoothstep(5.0,18.0,speed)
	if speed > 0.0: state.velocity *= maxf(0.0,speed-loss)/speed

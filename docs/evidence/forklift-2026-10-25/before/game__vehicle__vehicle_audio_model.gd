class_name VehicleAudioModel
extends RefCounted
## Virtual drivetrain for sound only. Never feeds RPM/gears back into handling.
var vehicle_id: String = "compact"
var maximum_speed: float = 46.0
var idle_rpm: float = 1000.0
var redline_rpm: float = 7200.0
var rpm: float = 1000.0
var load_amount: float = 0.0
var gear: int = 1
var shift_remaining: float = 0.0
var shift_cooldown: float = 0.0
var shifts: int = 0
var reverse: bool = false
var anchors := Vector3(1200.0, 3000.0, 6000.0)
const GEAR_TOPS: Array[float] = [0.30, 0.50, 0.71, 0.90, 1.13]

func configure(id: String, speed: float) -> void:
	vehicle_id = VehicleCatalog.valid_id(id)
	maximum_speed = maxf(10.0,speed)
	match vehicle_id:
		"pickup":
			idle_rpm = 800.0; redline_rpm = 5200.0; anchors = Vector3(950,2400,4400)
		"classic":
			idle_rpm = 1050.0; redline_rpm = 7600.0; anchors = Vector3(1250,3200,6500)
		"formula":
			idle_rpm = 1800.0; redline_rpm = 13000.0; anchors = Vector3(2100,5800,11000)
		"kart":
			idle_rpm = 1600.0; redline_rpm = 10800.0; anchors = Vector3(1800,4700,9300)
		_:
			idle_rpm = 1000.0; redline_rpm = 7200.0; anchors = Vector3(1200,3000,6000)
	reset()

func reset() -> void:
	rpm = idle_rpm
	load_amount = 0.0
	gear = 1
	shift_remaining = 0.0
	shift_cooldown = 0.0
	shifts = 0
	reverse = false

func advance(state: VehicleState, frame: DriveFrame, delta: float) -> bool:
	var dt: float = maxf(0.0,delta)
	var speed: float = state.velocity.length()
	var signed_speed: float = state.velocity.dot(state.forward())
	reverse = signed_speed < -0.6
	var pedal: float = float(frame.brake if reverse else frame.throttle)/255.0
	load_amount = lerpf(load_amount,pedal,1.0-exp(-dt*(14.0 if pedal>load_amount else 7.0)))
	shift_cooldown = maxf(0.0,shift_cooldown-dt)
	shift_remaining = maxf(0.0,shift_remaining-dt)
	var changed: bool = false
	if reverse:
		gear = -1
	elif gear < 1:
		gear = 1
	elif vehicle_id != "kart" and shift_cooldown == 0.0:
		if gear < GEAR_TOPS.size() and speed > maximum_speed*GEAR_TOPS[gear-1]*0.92:
			gear += 1
			changed = true
		elif gear > 1 and speed < maximum_speed*GEAR_TOPS[gear-2]*0.63:
			gear -= 1
			changed = true
	if changed:
		shift_remaining = 0.12
		shift_cooldown = 0.32
		shifts += 1
	var top: float = maximum_speed*GEAR_TOPS[maxi(0,gear-1)] if vehicle_id != "kart" else maximum_speed*1.04
	if reverse: top = 9.0
	var wheel_rpm: float = idle_rpm + clampf(speed/top,0.0,1.0)*(redline_rpm-idle_rpm)
	var neutral_rpm: float = idle_rpm+load_amount*(redline_rpm-idle_rpm)*0.56
	var desired: float = lerpf(neutral_rpm,wheel_rpm,smoothstep(0.8,4.0,speed))
	if state.jump_height>0.0 or state.handbrake_pressure>0.4:
		desired += load_amount*(redline_rpm-idle_rpm)*0.12
	rpm = lerpf(rpm,clampf(desired,idle_rpm,redline_rpm),1.0-exp(-dt*(22.0 if changed else 11.0)))
	return changed

func weights() -> Vector3:
	# Equal-power fades in log RPM keep power stable between neighboring recordings.
	if rpm<=anchors.x: return Vector3(1,0,0)
	if rpm>=anchors.z: return Vector3(0,0,1)
	var lower: float = anchors.x if rpm<anchors.y else anchors.y
	var upper: float = anchors.y if rpm<anchors.y else anchors.z
	var blend: float = clampf(log(rpm/lower)/log(upper/lower),0.0,1.0)
	return Vector3(cos(blend*PI*.5),sin(blend*PI*.5),0) if rpm<anchors.y else Vector3(0,cos(blend*PI*.5),sin(blend*PI*.5))

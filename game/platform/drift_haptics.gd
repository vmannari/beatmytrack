extends RefCounted
## Observes sliding during live driving; never changes canonical vehicle state.

const SteeringHaptics = preload("res://platform/steering_haptics.gd")
const START_SLIP: float = deg_to_rad(10.0)
const END_SLIP: float = deg_to_rad(7.0)
const MIN_SPEED: float = 4.0
const SETTLE_SECONDS: float = 0.06
const PULSE_INTERVAL: float = 0.10
const PULSE_MS: int = 20

var feedback: Callable = SteeringHaptics.press
var sliding: bool = false
var slide_seconds: float = 0.0
var cooldown: float = 0.0

func reset() -> void:
	sliding = false
	slide_seconds = 0.0
	cooldown = 0.0

func present(delta: float, state: VehicleState, enabled: bool, active: bool) -> void:
	if not enabled or not active or state == null:
		reset()
		return
	if not is_finite(delta) or delta <= 0.0: return
	# A delayed frame can request one fresh pulse, never a backlog of vibrations.
	var step: float = minf(delta, PULSE_INTERVAL)
	cooldown = maxf(0.0, cooldown-step)
	var speed: float = state.velocity.length()
	var slip: float = absf(state.slip_angle())
	if state.jump_height > 0.001 or state.bridge_airborne or state.roll_ticks > 0 or speed < MIN_SPEED or slip < (END_SLIP if sliding else START_SLIP):
		sliding = false
		slide_seconds = 0.0
		return
	sliding = true
	slide_seconds = minf(SETTLE_SECONDS, slide_seconds+step)
	if slide_seconds < SETTLE_SECONDS or cooldown > 0.000001: return
	var severity: float = smoothstep(END_SLIP, deg_to_rad(35.0), slip)
	var strength: float = lerpf(0.09, 0.225, severity)*lerpf(0.65, 1.0, smoothstep(MIN_SPEED, 16.0, speed))
	feedback.call(strength, PULSE_MS)
	cooldown = PULSE_INTERVAL

class_name RewindReturn
extends RefCounted
## Presentation pacing only. Every accepted simulation step remains exactly 1/120 s.
const RESUME_TICKS: int = 36 # 0.30 seconds at the fixed callback rate.
const RESUME_SPEED: float = 0.35
const CANCEL_SECONDS: float = 0.06
var remaining: int = 0
var credit: float = 0.0
var speed: float = 1.0
var cancel_remaining: float = 0.0

func reset() -> void:
	remaining = 0
	credit = 0.0
	speed = 1.0
	cancel_remaining = 0.0

func resume() -> void:
	reset()
	remaining = RESUME_TICKS
	speed = RESUME_SPEED

func cancel() -> void:
	# Cancel cannot change input opportunity or scored tick cadence.
	reset()
	cancel_remaining = CANCEL_SECONDS

func step_due() -> bool:
	if remaining <= 0:
		credit = 0.0
		speed = 1.0
		return true
	var progress: float = 1.0-float(remaining)/RESUME_TICKS
	speed = lerpf(RESUME_SPEED,1.0,smoothstep(0.0,1.0,progress))
	credit += speed
	remaining -= 1
	if credit < 1.0: return false
	credit -= 1.0
	return true

func interpolation(fraction: float) -> float:
	return clampf(credit+speed*fraction,0.0,1.0) if speed < 1.0 else fraction

func visual_delta(delta: float) -> float:
	# A tiny camera easing on Cancel; car, clock and input remain real time.
	if cancel_remaining <= 0.0: return delta
	var weight: float = 1.0-cancel_remaining/CANCEL_SECONDS
	cancel_remaining = maxf(0.0,cancel_remaining-delta)
	return delta*lerpf(0.25,1.0,smoothstep(0.0,1.0,weight))

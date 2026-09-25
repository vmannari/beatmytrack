extends RefCounted
## Presentation-only handheld feedback; never called from the simulation step.

const DURATION_MS: int = 12
const AMPLITUDE: float = 0.2

static func press(strength: float = AMPLITUDE) -> void:
	if strength > 0.0 and (OS.has_feature("android") or OS.has_feature("ios")):
		Input.vibrate_handheld(DURATION_MS, clampf(strength, 0.0, 1.0))

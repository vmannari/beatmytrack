extends RefCounted
## Presentation-only handheld feedback; never called from the simulation step.

const DURATION_MS: int = 12
const AMPLITUDE: float = 0.2

static func press() -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(DURATION_MS, AMPLITUDE)

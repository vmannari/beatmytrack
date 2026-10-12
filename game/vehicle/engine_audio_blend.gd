class_name EngineAudioBlend
extends RefCounted
## Coherent recorded sustains require constant-amplitude, not unrelated-power fades.

static func rpm_gains(weights: Vector3) -> Vector3:
	return weights/maxf(weights.x+weights.y+weights.z,0.000001)

static func load_gains(load_amount: float) -> Vector2:
	var loaded: float = sqrt(clampf(load_amount,0.0,1.0))
	var coasting: float = sqrt(1.0-clampf(load_amount,0.0,1.0))
	return Vector2(loaded,coasting*0.84)/maxf(loaded+coasting,0.000001)

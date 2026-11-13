class_name CompactKitVariants
extends RefCounted
## Original second collection, fitted to the same compact sheet and wheel frames.
const HOODS: Array[String] = ["extractor","cowl","twin_scoop","reverse","ribs","vented"]
const BODIES: Array[String] = ["heritage","touring","wide","endurance","gravel","urban"]

static func hood_point(kind: String, _u: float, v: float, point: Vector3) -> Vector3:
	var along: float = smoothstep(0.12,0.34,v)*(1-smoothstep(0.81,0.98,v))
	if kind=="vented": point.y += 0.075*(1-smoothstep(0.19,0.43,absf(point.x)))*along
	elif kind=="cowl":
		point.y += 0.080*(1-smoothstep(0.29,0.51,absf(point.x)))*smoothstep(0.16,0.75,v)*(1-smoothstep(0.90,0.99,v))
	elif kind=="ribs":
		for x: float in [-0.38,0.0,0.38]: point.y += 0.022*(1-smoothstep(0.03,0.10,absf(point.x-x)))*along
	return point

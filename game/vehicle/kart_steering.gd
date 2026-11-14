extends RefCounted
## Presentation-only steering. Authored poses share one immutable native mesh.
const SOURCE_CENTER := Vector3(0,0.54,-0.31)
const CENTER := Vector3(0,0.54,-0.265)
const REST := Basis(Vector3.RIGHT,1.15)
const LOCK: float = PI/3.0
const STEPS: int = 5
const SHOULDER := Vector3(0.177686388,0.698039100,0.376223732)
const ELBOW := Vector3(0.265192359,0.562773045,0.082504820)
const WRIST := Vector3(0.188398396,0.544779528,-0.227622445)

static func wheel_basis(input: float) -> Basis:
	return REST*Basis(Vector3.UP,-clampf(input,-1,1)*LOCK)

static func present(wheel: Node3D, driver: MeshInstance3D, input: float) -> void:
	input = clampf(input,-1,1)
	if wheel != null: wheel.basis = wheel_basis(input)
	if driver == null or driver.mesh.get_blend_shape_count() != STEPS*2: return
	var amount: float = absf(input)*STEPS
	for direction: int in range(2):
		for step: int in range(1,STEPS+1):
			var weight: float = maxf(0,1-absf(amount-step))
			if (input < 0) != (direction == 0): weight = 0
			driver.set_blend_shape_value(direction*STEPS+step-1,weight)

static func mirrored(point: Vector3, side: float) -> Vector3:
	return point*Vector3(side,1,1)

static func projection(point: Vector3, a: Vector3, b: Vector3) -> float:
	return clampf((point-a).dot(b-a)/(b-a).length_squared(),0,1)

static func elbow_for(shoulder: Vector3, wrist: Vector3, pole: Vector3) -> Vector3:
	var upper: float = SHOULDER.distance_to(ELBOW)
	var lower: float = ELBOW.distance_to(WRIST)
	var distance: float = shoulder.distance_to(wrist)
	var axis: Vector3 = (wrist-shoulder)/distance
	var along: float = (upper*upper-lower*lower+distance*distance)/(2*distance)
	var perpendicular: Vector3 = (pole-shoulder)-axis*(pole-shoulder).dot(axis)
	return shoulder+axis*along+perpendicular.normalized()*sqrt(maxf(0,upper*upper-along*along))


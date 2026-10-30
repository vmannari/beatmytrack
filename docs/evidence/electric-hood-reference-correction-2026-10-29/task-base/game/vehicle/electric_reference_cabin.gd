extends RefCounted
## The fastback greenhouse is an independent, continuous curved shell.
## Model coordinates are metres, with the nose towards negative Z.
const Surface = preload("res://vehicle/electric_reference_mesh.gd")
const Body = preload("res://vehicle/electric_reference_body.gd")

static func cubic(a: float, b: float, c: float, d: float, t: float) -> float:
	var s: float = 1.0 - t
	return s*s*s*a + 3.0*s*s*t*b + 3.0*s*t*t*c + t*t*t*d

static func roof_z(t: float) -> float:
	return cubic(-0.90, -0.45, 0.40, 1.72, t)

static func roof_height(t: float) -> float:
	return cubic(1.00, 1.50, 1.50, 0.96, t)

static func roof_width(t: float) -> float:
	# The glass and roof pull inward from the full-width cowl and rear deck.
	return cubic(0.82, 0.64, 0.64, 0.80, t)

static func top_point(u: float, t: float) -> Vector3:
	var across: float = 2.0*u-1.0
	var crown: float = 0.030*across*across
	return Vector3(across*roof_width(t), roof_height(t)-crown, roof_z(t))

static func belt_height(t: float) -> float:
	return Body.shoulder(roof_z(t))

static func side_point(side: float, t: float, v: float) -> Vector3:
	var upper: Vector3 = top_point(1.0 if side>0.0 else 0.0, t)
	var lower := Vector3(side*Body.top_width(upper.z), belt_height(t), upper.z)
	var p: Vector3 = lower.lerp(upper, v)
	# Mild outward bow catches a soft reflection without breaking the frame joins.
	p.x += side*0.012*sin(PI*v)*sin(PI*t)
	return p

static func glass_start(_v: float) -> float:
	# The side glass reaches the windshield foot. Its tapered tip is formed by
	# the roof descending to the belt, not by a wide opaque triangular pillar.
	return 0.040

static func glass_end(_v: float) -> float:
	return 0.970

static func build(car: CarVisual, paint: Material, trim: Material, glass: Material) -> void:
	# The windshield, roof and backlight share one curvature; silver outer rails
	# are separate strips following exactly the same surface.
	Surface.patch(car.body, "ReferenceCanopyGlass", 48, 72, func(u: float, v: float) -> Vector3:
		return top_point(lerpf(0.035, 0.965, u), v), glass, Vector3.UP, car.simple_model)
	for edge: int in range(2):
		Surface.patch(car.body, "ReferenceRoofRail"+str(edge), 5, 72, func(u: float, v: float) -> Vector3:
			return top_point(lerpf(0.0, 0.035, u) if edge==0 else lerpf(0.965, 1.0, u), v), paint, Vector3.UP, car.simple_model)
	for side: float in [-1.0, 1.0]:
		var hint := Vector3(side, 0.2, 0.0)
		var suffix: String = str(side)
		# A single side surface keeps the glass, bright rim and pillar paint fitted.
		Surface.patch(car.body, "ReferenceWindowBottom"+suffix, 60, 4, func(u: float, v: float) -> Vector3:
			return side_point(side, u, lerpf(0.0, 0.075, v)), paint, hint, car.simple_model)
		Surface.patch(car.body, "ReferenceWindowTop"+suffix, 60, 4, func(u: float, v: float) -> Vector3:
			return side_point(side, u, lerpf(0.925, 1.0, v)), paint, hint, car.simple_model)
		Surface.patch(car.body, "ReferenceFrontPillar"+suffix, 22, 30, func(u: float, v: float) -> Vector3:
			return side_point(side, lerpf(0.0, glass_start(v), u), lerpf(0.075, 0.925, v)), paint, hint, car.simple_model)
		Surface.patch(car.body, "ReferenceRearPillar"+suffix, 22, 30, func(u: float, v: float) -> Vector3:
			return side_point(side, lerpf(glass_end(v), 1.0, u), lerpf(0.075, 0.925, v)), paint, hint, car.simple_model)
		Surface.patch(car.body, "ReferenceSideGlass"+suffix, 72, 28, func(u: float, v: float) -> Vector3:
			return side_point(side, lerpf(glass_start(v), glass_end(v), u), lerpf(0.075, 0.925, v)), glass, hint, car.simple_model)
		# Central divider and the slim taper separating the rear quarter glass.
		for divider: int in range(2):
			Surface.patch(car.body, "ReferenceWindowDivider"+suffix+str(divider), 3, 24, func(u: float, v: float) -> Vector3:
				var center: float = 0.470 if divider==0 else lerpf(0.800, 0.755, v)
				return side_point(side, center + lerpf(-0.008, 0.008, u), lerpf(0.075, 0.925, v)) + Vector3(side*0.0015, 0.0, 0.0), trim, hint, car.simple_model)
		# A fine black gasket defines the lower glazing line over the silver waist.
		Surface.patch(car.body, "ReferenceWindowGasket"+suffix, 56, 2, func(u: float, v: float) -> Vector3:
			return side_point(side, lerpf(glass_start(0.0), glass_end(0.0), u), lerpf(0.067, 0.081, v)) + Vector3(side*0.001, 0.0, 0.0), trim, hint, car.simple_model)

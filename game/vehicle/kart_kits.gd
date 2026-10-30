extends RefCounted
## Original cosmetic fittings in kart model metres. Tyres, axles and engine stay fixed.
const G = preload("res://vehicle/kart_geometry.gd")

const Shapes = preload("res://vehicle/kart_kit_shapes.gd")
const NOSES: Dictionary = {
	"sprint":[Vector4(-1.42,0.46,0.235,0.035),Vector4(-1.40,0.66,0.245,0.045),Vector4(-1.35,0.73,0.25,0.050),Vector4(-1.29,0.73,0.25,0.050),Vector4(-1.23,0.68,0.245,0.045),Vector4(-1.20,0.46,0.235,0.035)],
	"enduro":[Vector4(-1.42,0.61,0.27,0.075),Vector4(-1.40,0.70,0.29,0.100),Vector4(-1.35,0.73,0.30,0.120),Vector4(-1.29,0.73,0.30,0.120),Vector4(-1.23,0.67,0.30,0.095),Vector4(-1.20,0.53,0.295,0.080)],
	"wedge":[Vector4(-1.43,0.40,0.215,0.025),Vector4(-1.40,0.58,0.235,0.040),Vector4(-1.35,0.69,0.270,0.065),Vector4(-1.29,0.73,0.310,0.095),Vector4(-1.23,0.69,0.320,0.105),Vector4(-1.20,0.51,0.310,0.080)],
	"arrow":[Vector4(-1.47,0.12,0.24,0.024),Vector4(-1.43,0.35,0.25,0.040),Vector4(-1.37,0.68,0.28,0.065),Vector4(-1.29,0.72,0.29,0.080),Vector4(-1.23,0.60,0.27,0.065),Vector4(-1.20,0.36,0.25,0.035)],
	"split":[Vector4(-1.43,0.51,0.265,0.065),Vector4(-1.40,0.69,0.28,0.090),Vector4(-1.35,0.73,0.30,0.105),Vector4(-1.29,0.73,0.30,0.105),Vector4(-1.23,0.65,0.29,0.090),Vector4(-1.20,0.44,0.27,0.060)],
	"shield":[Vector4(-1.42,0.66,0.26,0.060),Vector4(-1.40,0.72,0.28,0.085),Vector4(-1.35,0.73,0.29,0.090),Vector4(-1.29,0.69,0.29,0.090),Vector4(-1.23,0.57,0.28,0.070),Vector4(-1.20,0.40,0.26,0.045)],
	"retro":[Vector4(-1.44,0.43,0.25,0.055),Vector4(-1.41,0.64,0.25,0.075),Vector4(-1.35,0.73,0.25,0.080),Vector4(-1.29,0.71,0.25,0.080),Vector4(-1.23,0.63,0.25,0.070),Vector4(-1.20,0.40,0.25,0.035)]}
const FAIRINGS: Dictionary = {
	"sprint":[Vector4(-1.23,0.11,0.34,0.025),Vector4(-0.87,0.13,0.41,0.030),Vector4(-0.64,0.17,0.46,0.035),Vector4(-0.41,0.14,0.50,0.025),Vector4(-0.35,0.115,0.49,0.020)],
	"enduro":[Vector4(-1.23,0.14,0.37,0.035),Vector4(-0.87,0.18,0.44,0.045),Vector4(-0.64,0.22,0.54,0.060),Vector4(-0.41,0.19,0.58,0.050),Vector4(-0.35,0.15,0.56,0.030)],
	"wedge":[Vector4(-1.23,0.08,0.35,0.020),Vector4(-0.87,0.13,0.42,0.035),Vector4(-0.64,0.18,0.50,0.055),Vector4(-0.41,0.19,0.57,0.045),Vector4(-0.35,0.16,0.56,0.025)],
	"arrow":[Vector4(-1.23,0.075,0.36,0.030),Vector4(-0.87,0.12,0.44,0.060),Vector4(-0.64,0.175,0.515,0.075),Vector4(-0.41,0.14,0.55,0.050),Vector4(-0.35,0.10,0.53,0.025)],
	"split":[Vector4(-1.23,0.13,0.36,0.030),Vector4(-0.87,0.18,0.44,0.045),Vector4(-0.64,0.22,0.53,0.065),Vector4(-0.41,0.19,0.57,0.050),Vector4(-0.35,0.14,0.55,0.030)],
	"shield":[Vector4(-1.23,0.15,0.37,0.035),Vector4(-0.87,0.19,0.43,0.040),Vector4(-0.64,0.21,0.50,0.045),Vector4(-0.41,0.19,0.55,0.035),Vector4(-0.35,0.15,0.54,0.020)],
	"retro":[Vector4(-1.23,0.11,0.35,0.030),Vector4(-0.87,0.14,0.43,0.035),Vector4(-0.64,0.175,0.50,0.045),Vector4(-0.41,0.145,0.54,0.035),Vector4(-0.35,0.115,0.53,0.025)]}
const PODS: Dictionary = {
	"sprint":[Vector4(-0.60,0.07,0.265,0.035),Vector4(-0.48,0.15,0.265,0.055),Vector4(-0.12,0.16,0.27,0.060),Vector4(0.34,0.14,0.26,0.055),Vector4(0.49,0.08,0.25,0.035)],
	"enduro":[Vector4(-0.60,0.10,0.29,0.065),Vector4(-0.48,0.17,0.30,0.125),Vector4(-0.12,0.175,0.30,0.120),Vector4(0.34,0.155,0.27,0.075),Vector4(0.49,0.11,0.25,0.045)],
	"wedge":[Vector4(-0.60,0.10,0.30,0.065),Vector4(-0.48,0.175,0.30,0.110),Vector4(-0.12,0.155,0.285,0.090),Vector4(0.34,0.115,0.26,0.050),Vector4(0.49,0.06,0.25,0.025)],
	"blade":[Vector4(-0.60,0.07,0.26,0.030),Vector4(-0.48,0.18,0.255,0.045),Vector4(-0.12,0.19,0.255,0.050),Vector4(0.34,0.15,0.255,0.045),Vector4(0.49,0.055,0.245,0.022)],
	"channel":[Vector4(-0.60,0.10,0.285,0.055),Vector4(-0.48,0.175,0.295,0.100),Vector4(-0.12,0.18,0.295,0.105),Vector4(0.34,0.155,0.27,0.080),Vector4(0.49,0.095,0.25,0.045)],
	"rounded":[Vector4(-0.60,0.06,0.28,0.040),Vector4(-0.48,0.15,0.28,0.095),Vector4(-0.12,0.17,0.285,0.110),Vector4(0.34,0.145,0.27,0.085),Vector4(0.49,0.06,0.25,0.040)],
	"box":[Vector4(-0.60,0.115,0.295,0.065),Vector4(-0.48,0.17,0.295,0.110),Vector4(-0.12,0.17,0.295,0.110),Vector4(0.34,0.16,0.27,0.075),Vector4(0.49,0.12,0.25,0.045)]}

static func suffix(kind: String) -> String:
	return "" if kind=="stock" else "_"+kind+"_v2"

static func _profile(catalog: Dictionary, kind: String, original: Array[Vector4]) -> Array[Vector4]:
	if kind=="stock": return original
	var result: Array[Vector4] = []
	result.assign(catalog[kind])
	return result

static func nose_profile(kind: String, original: Array[Vector4]) -> Array[Vector4]:
	return _profile(NOSES,kind,original)

static func fairing_profile(kind: String, original: Array[Vector4]) -> Array[Vector4]:
	return _profile(FAIRINGS,kind,original)

static func pod_profile(kind: String, original: Array[Vector4]) -> Array[Vector4]:
	return _profile(PODS,kind,original)

static func panel(parent: Node3D, label: String, profile: Array[Vector4], material: Material, simple: bool, kind: String, pod: bool = false) -> MeshInstance3D:
	if kind=="stock": return preload("res://vehicle/kart_bodywork.gd").formed(parent,label,profile,material,simple)
	var contour: Array[Vector2] = [Vector2(0.70,1),Vector2(0.94,0.72),Vector2(1,-0.28),Vector2(0.80,-0.86),Vector2(-0.80,-0.86),Vector2(-1,-0.28),Vector2(-0.94,0.72),Vector2(-0.70,1)]
	var rounding: float = 0.08
	if kind in ["retro","rounded"]:
		contour.clear()
		for step: int in range(24):
			var angle: float = TAU*step/24
			contour.append(Vector2(cos(angle),sin(angle)))
	elif kind in ["split","channel"]:
		contour = [Vector2(0.35,1),Vector2(0.86,1),Vector2(1,0.60),Vector2(1,-0.45),Vector2(0.75,-0.85),Vector2(-0.75,-0.85),Vector2(-1,-0.45),Vector2(-1,0.60),Vector2(-0.86,1),Vector2(-0.35,1),Vector2(-0.22,0.12),Vector2(0.22,0.12)]
		rounding = 0.06
	elif kind in ["shield","box"]:
		contour = [Vector2(0.92,1),Vector2(1,0.85),Vector2(1,-0.70),Vector2(0.92,-0.85),Vector2(-0.92,-0.85),Vector2(-1,-0.70),Vector2(-1,0.85),Vector2(-0.92,1)]
		rounding = 0.04
	elif kind=="arrow" or (kind=="blade" and pod):
		contour = [Vector2(0,1.30),Vector2(0.90,0.25),Vector2(1,-0.45),Vector2(0.60,-0.85),Vector2(-0.60,-0.85),Vector2(-1,-0.45),Vector2(-0.90,0.25)]
		rounding = 0.06
	return Shapes.formed(parent,label,profile,contour,material,simple,rounding)

static func bumper(car: CarVisual, parent: Node3D, trim: Material, metal: Material) -> void:
	var s: bool = car.simple_model
	var kind: String = str(car.customisation.aero)
	for side: float in [-1.0,1.0]:
		Shapes.tube(parent,"KitBumperStay_"+kind,[Vector3(side*0.30,0.17,1.04),Vector3(side*0.35,0.18,1.17),Vector3(side*0.35,0.22,1.29)],0.022,metal,s,16)
	if kind=="loop":
		Shapes.tube(parent,"WraparoundRearBumper",[Vector3(-0.73,0.23,1.22),Vector3(-0.69,0.23,1.26),Vector3(-0.49,0.23,1.29),Vector3(0.49,0.23,1.29),Vector3(0.69,0.23,1.26),Vector3(0.73,0.23,1.22)],0.048,trim,s,40)
		for side: float in [-1.0,1.0]: G.ellipsoid(parent,"WraparoundBumperCap",Vector3(side*0.73,0.23,1.22),Vector3.ONE*0.048,trim,s)
	elif kind=="blade":
		G.rounded(parent,"WideRearBumper",Vector3(0,0.22,1.285),Vector3(1.44,0.17,0.10),0.035,trim,s)
		G.rounded(parent,"RearBumperPaintInset",Vector3(0,0.23,1.337),Vector3(0.52,0.06,0.012),0.005,car.paint_materials.accent,s)
	elif kind=="twin":
		for y: float in [0.16,0.29]: G.rounded(parent,"TwinRearBumperRail",Vector3(0,y,1.285),Vector3(1.42,0.075,0.10),0.025,trim,s)
		for x: float in [-0.66,-0.35,0.35,0.66]: G.rounded(parent,"TwinRearBumperBridge",Vector3(x,0.225,1.285),Vector3(0.055,0.16,0.085),0.015,trim,s)
	elif kind=="oval":
		var ring: Array[Vector3] = []
		for step: int in range(65):
			var a: float = TAU*step/64
			ring.append(Vector3(sin(a)*0.70,0.235+cos(a)*0.105,1.30))
		Shapes.tube(parent,"OvalRearBumper",ring,0.029,trim,s,64)
		G.rounded(parent,"OvalBumperBadge",Vector3(0,0.235,1.30),Vector3(0.28,0.17,0.065),0.025,car.paint_materials.accent,s)
	elif kind=="cage":
		Shapes.tube(parent,"CrossBraceBumperFrame",[Vector3(0,0.13,1.30),Vector3(-0.60,0.13,1.30),Vector3(-0.68,0.15,1.30),Vector3(-0.70,0.225,1.30),Vector3(-0.68,0.30,1.30),Vector3(-0.60,0.32,1.30),Vector3(0.60,0.32,1.30),Vector3(0.68,0.30,1.30),Vector3(0.70,0.225,1.30),Vector3(0.68,0.15,1.30),Vector3(0.60,0.13,1.30),Vector3(0,0.13,1.30)],0.026,trim,s,48)
		for side: float in [-1.0,1.0]: Shapes.tube(parent,"RearBumperDiagonal",[Vector3(side*0.65,0.15,1.30),Vector3(0,0.225,1.30),Vector3(-side*0.65,0.30,1.30)],0.016,metal,s,16)
		G.rounded(parent,"CrossBraceBumperBadge",Vector3(0,0.225,1.329),Vector3(0.15,0.105,0.025),0.015,car.paint_materials.body,s)
	elif kind=="panel":
		for y: float in [0.145,0.315]: G.rounded(parent,"SlottedBumperRail",Vector3(0,y,1.285),Vector3(1.46,0.065,0.105),0.020,trim,s)
		for x: float in [-0.69,-0.55,0.55,0.69]: G.rounded(parent,"SlottedBumperPost",Vector3(x,0.23,1.285),Vector3(0.070,0.19,0.105),0.018,trim,s)
		G.rounded(parent,"SlottedBumperCenter",Vector3(0,0.23,1.285),Vector3(0.66,0.20,0.105),0.025,trim,s)
		G.rounded(parent,"SlottedBumperPaint",Vector3(0,0.23,1.339),Vector3(0.47,0.105,0.015),0.006,car.paint_materials.body,s)
	elif kind=="chevron":
		Shapes.tube(parent,"ChevronRearBumper",[Vector3(-0.71,0.29,1.285),Vector3(-0.62,0.27,1.30),Vector3(0,0.15,1.30),Vector3(0.62,0.27,1.30),Vector3(0.71,0.29,1.285)],0.048,trim,s,40)
		for side: float in [-1.0,1.0]: G.ellipsoid(parent,"ChevronBumperCap",Vector3(side*0.71,0.29,1.285),Vector3.ONE*0.048,trim,s)
		G.rounded(parent,"ChevronBumperCenter",Vector3(0,0.175,1.34),Vector3(0.18,0.11,0.035),0.018,car.paint_materials.accent,s)

static func rim(car: CarVisual, parent: Node3D, side: float, metal: Material, bright: Material, trim: Material) -> void:
	var s: bool = car.simple_model
	var kind: String = str(car.customisation.rims)
	var magnesium := CompactFinish.alloy(Color({"three":"91836b","six":"66767e","disc":"807b68","turbine":"b0b5b1","mesh":"9f855c","dish":"a0a8aa","star":"566369"}.get(kind,"807b68")))
	magnesium.roughness = 0.43
	G.lathe(parent,"KitMagnesiumBarrel_v2_"+kind,[Vector2(-0.138,0.115),Vector2(-0.138,0.135),Vector2(-0.120,0.145),Vector2(-0.101,0.127),Vector2(0.101,0.127),Vector2(0.120,0.145),Vector2(0.138,0.135),Vector2(0.138,0.115),Vector2(0.103,0.111),Vector2(-0.103,0.111),Vector2(-0.138,0.115)],magnesium,s)
	if kind=="disc":
		Shapes.lathe(parent,"RecessedDiscWheel",[Vector2(side*0.099,0),Vector2(side*0.099,0.123),Vector2(side*0.117,0.123),Vector2(side*0.117,0),Vector2(side*0.099,0)],magnesium,s)
	elif kind=="dish":
		Shapes.lathe(parent,"DeepBowlWheel",[Vector2(side*0.032,0.025),Vector2(side*0.032,0.045),Vector2(side*0.042,0.068),Vector2(side*0.065,0.093),Vector2(side*0.105,0.115),Vector2(side*0.127,0.123),Vector2(side*0.132,0.129),Vector2(side*0.128,0.133),Vector2(side*0.119,0.126),Vector2(side*0.088,0.114),Vector2(side*0.050,0.091),Vector2(side*0.027,0.066),Vector2(side*0.020,0.045),Vector2(side*0.020,0.025),Vector2(side*0.032,0.025)],magnesium,s)
	elif kind=="mesh":
		for spoke: int in range(10):
			var angle: float = TAU*spoke/10
			for sweep: float in [-0.28,0.28]:
				Shapes.tube(parent,"CrossMeshWheel",[Vector3(side*0.092,sin(angle)*0.034,cos(angle)*0.034),Vector3(side*0.112,sin(angle+sweep*0.6)*0.085,cos(angle+sweep*0.6)*0.085),Vector3(side*0.125,sin(angle+sweep)*0.128,cos(angle+sweep)*0.128)],0.0045,magnesium,s,8)
	else:
		var count: int = {"three":3,"six":6,"turbine":9,"star":5}.get(kind,3)
		for spoke: int in range(count):
			var angle: float = TAU*spoke/count
			var polygon: Array[Vector2] = [Vector2(0.028,-0.016),Vector2(0.080,-0.025),Vector2(0.130,-0.020),Vector2(0.130,0.020),Vector2(0.080,0.025),Vector2(0.028,0.016)]
			if kind=="six":
				for split: float in [-1.0,1.0]:
					var fork: Array[Vector2] = [Vector2(0.028,split*0.003-0.005),Vector2(0.075,split*0.010-0.006),Vector2(0.131,split*0.025-0.005),Vector2(0.131,split*0.025+0.005),Vector2(0.075,split*0.010+0.006),Vector2(0.028,split*0.003+0.005)]
					Shapes.spoke(parent,"SplitForgedWheel",fork,angle,side,magnesium)
				continue
			if kind=="turbine": polygon = [Vector2(0.030,-0.006),Vector2(0.075,-0.018),Vector2(0.125,-0.031),Vector2(0.132,-0.012),Vector2(0.085,0.008),Vector2(0.030,0.010)]
			if kind=="star": polygon = [Vector2(0.027,-0.021),Vector2(0.068,-0.024),Vector2(0.131,-0.011),Vector2(0.131,0.011),Vector2(0.068,0.024),Vector2(0.027,0.021)]
			Shapes.spoke(parent,"ForgedWheel_"+kind,polygon,angle,side,magnesium)
	var cap := VisualGeometry.cylinder(parent,0.042,0.20,Vector3.ZERO,metal,true)
	cap.rotation.z = PI*0.5
	for bolt: int in range(3):
		var a: float = TAU*bolt/3
		G.ellipsoid(parent,"KitWheelNut",Vector3(side*0.124,sin(a)*0.052,cos(a)*0.052),Vector3(0.009,0.008,0.008),bright,s)
	Shapes.tube(parent,"KitValveStem",[Vector3(side*0.13,0.095,-0.066),Vector3(side*0.15,0.10,-0.069)],0.004,trim,s,4)

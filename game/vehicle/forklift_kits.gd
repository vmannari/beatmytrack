extends RefCounted
## Removable cosmetic fittings, in forklift model coordinates.
const Surface = preload("res://vehicle/hovercraft_sport_surface.gd")

static func build(car: CarVisual, category: String) -> void:
	var kind: String = str(car.customisation[category])
	if category == "rims":
		for index: int in range(car.rolling_wheels.size()):
			var rotor: Node3D = car.rolling_wheels[index]
			var frame: Node3D = car.new_kit_frame(category,rotor)
			if kind == "stock": continue
			var pivot: Node3D = rotor.get_parent()
			var side: float = signf(pivot.position.x)
			var radius: float = car.wheel_radii[index]/HandlingConfig.BODY_SCALE
			var face: float = (0.32 if pivot.position.z < 0.0 else 0.25)*0.48+0.056
			var metal: Material = CompactFinish.alloy(Color("a9b5b4"))
			if kind == "fork_ring":
				var ring := Node3D.new()
				frame.add_child(ring)
				ring.position.x = side*face
				ring.rotation.z = PI*0.5
				VisualGeometry.ring(ring,Vector3.ZERO,radius*0.56,0.018,metal)
			else:
				var disc := VisualGeometry.cylinder(frame,radius*0.51,0.018,Vector3(side*face,0,0),metal,true)
				disc.rotation.z = PI*0.5
				if kind == "fork_spoke":
					var dark: Material = CompactFinish.rubber(Color("263034"))
					for spoke: int in range(6):
						var angle: float = spoke*TAU/6.0
						var mark := VisualGeometry.box(frame,Vector3(0.02,0.035,radius*0.31),Vector3(side*(face+0.012),sin(angle)*radius*0.29,cos(angle)*radius*0.29),dark)
						mark.rotation.x = -angle
		return
	var frame: Node3D = car.new_kit_frame(category,car.body)
	if kind == "stock": return
	var paint: Material = car.paint_materials.body
	var metal: Material = CompactFinish.alloy(Color("9ba7a5"))
	var dark: Material = CompactFinish.rubber(Color("263034"))
	var simple: bool = car.simple_model
	match category:
		"hood":
			if kind == "fork_vent":
				Surface.rounded_box(frame,"VentCover",Vector3(0.90,0.045,0.54),Vector3(0,1.55,1.06),0.025,paint,simple)
				for i: int in range(6): Surface.rounded_box(frame,"Vent",Vector3(0.65,0.009,0.025),Vector3(0,1.577,0.87+i*0.075),0.005,dark,simple)
			elif kind == "fork_rib":
				for x: float in [-0.3,0.0,0.3]: Surface.rounded_box(frame,"EngineRib",Vector3(0.075,0.045,0.65),Vector3(x,1.55,1.04),0.02,metal,simple)
			else:
				for side: float in [-1.0,1.0]: Surface.rounded_box(frame,"Intake",Vector3(0.27,0.075,0.49),Vector3(side*0.27,1.56,1.04),0.035,paint,simple)
		"aero":
			Surface.rounded_box(frame,"RearGuard",Vector3(1.60,0.10,0.10),Vector3(0,0.67,1.70),0.04,metal,simple)
			if kind == "fork_twin": Surface.rounded_box(frame,"RearGuardUpper",Vector3(1.55,0.08,0.09),Vector3(0,0.84,1.68),0.03,metal,simple)
			if kind == "fork_wrap":
				for side: float in [-1.0,1.0]: Surface.rounded_box(frame,"GuardReturn",Vector3(0.09,0.10,0.42),Vector3(side*0.76,0.67,1.52),0.035,metal,simple)
		"body":
			for side: float in [-1.0,1.0]:
				var height: float = 0.20 if kind == "fork_plate" else 0.07
				Surface.rounded_box(frame,"SideGuard",Vector3(0.07,height,0.65),Vector3(side*0.86,0.78,0.05),0.025,paint if kind == "fork_plate" else metal,simple)
				if kind == "fork_twin": Surface.rounded_box(frame,"LowerRail",Vector3(0.06,0.06,0.65),Vector3(side*0.86,0.65,0.05),0.025,metal,simple)

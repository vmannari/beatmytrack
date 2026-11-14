class_name VehicleModels
extends RefCounted
## Original authored geometry, same matte toon/ink kit as the compact.
## Coordinates in unscaled model metres: nose -Z, tail +Z.

static func build(car: CarVisual, id: String) -> void:
	car.body = Node3D.new()
	car.add_child(car.body)
	car.brake_material = VisualGeometry.material(Color("802d2b"))
	var paint: StandardMaterial3D = VisualGeometry.material(Color({"pickup":"944638","classic":"739181","formula":"c8ad58","kart":"b96d43","forklift":"d5a62d"}.get(id,"c8c1ab")))
	VisualGeometry.ink(paint)
	var cream: StandardMaterial3D = VisualGeometry.material(Color("d9d0b7"))
	VisualGeometry.ink(cream)
	var accent: StandardMaterial3D = VisualGeometry.material(Color("d9d0b7"))
	VisualGeometry.ink(accent)
	car.paint_materials = {"body":paint, "accent":accent}
	var trim: StandardMaterial3D = VisualGeometry.material(Color("182126"))
	var glass: StandardMaterial3D = VisualGeometry.material(Color("304957"))
	match id:
		"hovercraft":
			load("res://vehicle/hovercraft_model.gd").build(car)
			return
		"electric":
			load("res://vehicle/electric_car_model.gd").build(car)
			return
		"pickup": _pickup(car,paint,cream,trim,glass,accent)
		"classic": _classic(car,paint,cream,trim,glass,accent)
		"formula": _formula(car,paint,cream,trim,glass,accent)
		"kart":
			load("res://vehicle/kart_model.gd").build(car)
			return
		"forklift": load("res://vehicle/forklift_model.gd").build(car)
	var config: HandlingConfig = VehicleCatalog.config(id)
	var half_axle: float = config.wheelbase / (2.0 * HandlingConfig.BODY_SCALE)
	var half_track: float = config.track_width / (2.0 * HandlingConfig.BODY_SCALE)
	var radius: float = 0.44 if id == "pickup" else 0.22 if id == "kart" else 0.34
	for side: float in [-1.0,1.0]:
		for axle: float in [-half_axle,half_axle]:
			if id == "forklift":
				var wheel_radius: float = 0.43 if axle < 0.0 else 0.30
				load("res://vehicle/forklift_model.gd").wheel(car,Vector3(side*half_track,wheel_radius,axle),wheel_radius,0.32 if axle < 0.0 else 0.25)
			else:
				_wheel(car,Vector3(side*half_track,radius,axle),radius,0.36 if id == "formula" else 0.27,trim)

	if id == "forklift":
		for category: String in VehicleCustomisation.CATEGORIES:
			load("res://vehicle/forklift_kits.gd").build(car,category)

static func _box(car: CarVisual, dimensions: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	return VisualGeometry.box(car.body,dimensions,center,material)

static func _wheel(car: CarVisual, center: Vector3, radius: float, width: float, trim: Material) -> void:
	var wheel := Node3D.new()
	wheel.position = center
	car.add_child(wheel)
	var tire := VisualGeometry.cylinder(wheel,radius,width,Vector3.ZERO,trim)
	tire.rotation.z = PI*0.5
	var rim: StandardMaterial3D = VisualGeometry.material(Color("778386"))
	var hub := VisualGeometry.cylinder(wheel,radius*0.58,width+0.012,Vector3.ZERO,rim)
	hub.rotation.z = PI*0.5
	var cap := VisualGeometry.cylinder(wheel,radius*0.20,width+0.03,Vector3.ZERO,trim)
	cap.rotation.z = PI*0.5
	for spoke: int in range(8):
		var angle: float = spoke*TAU/8.0
		car._seam(wheel,Vector3(signf(center.x)*(width*0.5+0.009),sin(angle)*radius*0.25,cos(angle)*radius*0.25),Vector3(signf(center.x)*(width*0.5+0.009),sin(angle)*radius*0.53,cos(angle)*radius*0.53),0.025,trim)
	if car.vehicle_id == "forklift":
		if center.z > 0.0: car.rear_wheels.append(wheel)
	elif center.z < 0: car.front_wheels.append(wheel)
	car.register_rolling_wheel(wheel, radius)

static func _cabin(car: CarVisual, width: float, base: float, roof: float, front: float, back: float, roof_front: float, roof_back: float, paint: Material, glass: Material, trim: Material) -> void:
	var top: float = width*0.81
	car._panel([Vector3(-width,base,front),Vector3(width,base,front),Vector3(top,roof,roof_front),Vector3(-top,roof,roof_front)],Vector3(0,0.6,-0.8),paint)
	car._panel([Vector3(-width,base,back),Vector3(width,base,back),Vector3(top,roof,roof_back),Vector3(-top,roof,roof_back)],Vector3(0,0.6,0.8),paint)
	car._panel([Vector3(-top,roof,roof_front),Vector3(top,roof,roof_front),Vector3(top,roof,roof_back),Vector3(-top,roof,roof_back)],Vector3.UP,paint)
	# Insets lie on the same slopes with a small outward offset.
	for rear: bool in [false,true]:
		var z0: float = back if rear else front
		var z1: float = roof_back if rear else roof_front
		var direction: float = 1.0 if rear else -1.0
		car._panel([Vector3(-width*0.88,lerpf(base,roof,0.12),lerpf(z0,z1,0.12)+direction*0.008),Vector3(width*0.88,lerpf(base,roof,0.12),lerpf(z0,z1,0.12)+direction*0.008),Vector3(top*0.90,lerpf(base,roof,0.89),lerpf(z0,z1,0.89)+direction*0.008),Vector3(-top*0.90,lerpf(base,roof,0.89),lerpf(z0,z1,0.89)+direction*0.008)],Vector3(0,0.6,direction*0.8),glass)
	for side: float in [-1.0,1.0]:
		car._panel([Vector3(side*width,base,front),Vector3(side*width,base,back),Vector3(side*top,roof,roof_back),Vector3(side*top,roof,roof_front)],Vector3(side,0.3,0),paint)
		car._panel([Vector3(side*(lerpf(width,top,0.13)+0.009),lerpf(base,roof,0.13),lerpf(front,roof_front,0.13)+0.08),Vector3(side*(lerpf(width,top,0.13)+0.009),lerpf(base,roof,0.13),lerpf(back,roof_back,0.13)-0.08),Vector3(side*(lerpf(width,top,0.88)+0.009),lerpf(base,roof,0.88),lerpf(back,roof_back,0.88)-0.07),Vector3(side*(lerpf(width,top,0.88)+0.009),lerpf(base,roof,0.88),lerpf(front,roof_front,0.88)+0.07)],Vector3(side,0.3,0),glass)
		_box(car,Vector3(0.17,0.12,0.23),Vector3(side*(width+0.10),base+0.08,front+0.22),trim)

static func _pickup(car: CarVisual, paint: Material, cream: Material, trim: Material, glass: Material, accent: Material) -> void:
	car._shell(car.body,[Vector3(0.97,0.46,2.66),Vector3(1.01,0.83,2.63)],paint)
	# Open cargo bed: floor, separate side rails and tailgate, no solid top lid.
	_box(car,Vector3(1.68,0.08,2.13),Vector3(0,0.87,1.47),trim)
	for side: float in [-1.0,1.0]:
		_box(car,Vector3(0.18,0.49,2.21),Vector3(side*0.92,1.06,1.43),paint)
		_box(car,Vector3(0.20,0.10,2.22),Vector3(side*0.92,1.32,1.43),accent)
		_box(car,Vector3(0.07,0.22,0.14),Vector3(side*0.91,1.05,2.58),car.brake_material)
		_box(car,Vector3(0.035,0.05,0.20),Vector3(side*1.02,1.13,-0.02),trim)
		car._seam(car.body,Vector3(side*1.015,0.80,0.29),Vector3(side*1.015,1.30,0.29),0.017,trim)
	for rib: int in range(7):
		_box(car,Vector3(0.025,0.025,1.98),Vector3(-0.68+rib*0.226,0.923,1.45),paint)
	_box(car,Vector3(1.98,0.46,0.14),Vector3(0,1.08,2.55),paint)
	_box(car,Vector3(1.97,0.12,0.16),Vector3(0,1.33,2.55),accent)
	_box(car,Vector3(1.98,0.42,2.88),Vector3(0,1.04,-1.14),paint)
	_box(car,Vector3(1.92,0.12,1.4),Vector3(0,1.30,-1.86),accent)
	_cabin(car,0.94,1.30,1.95,-1.12,0.35,-0.70,0.23,accent,glass,trim)
	_box(car,Vector3(1.85,0.37,0.06),Vector3(0,1.10,-2.61),trim)
	for side: float in [-1.0,1.0]:
		_box(car,Vector3(0.43,0.23,0.08),Vector3(side*0.66,1.12,-2.66),cream)
		_box(car,Vector3(0.38,0.10,0.09),Vector3(side*0.66,0.93,-2.66),VisualGeometry.material(Color("b98132")))
	for line: int in range(4):
		_box(car,Vector3(0.69,0.024,0.08),Vector3(0,0.99+line*0.072,-2.66),cream)
	for end: float in [-1.0,1.0]:
		_box(car,Vector3(2.08,0.16,0.15),Vector3(0,0.69,end*2.67),trim)

static func _classic(car: CarVisual, paint: Material, cream: Material, trim: Material, glass: Material, accent: Material) -> void:
	car._shell(car.body,[Vector3(0.83,0.32,2.03),Vector3(0.91,0.57,2.08),Vector3(0.83,0.81,1.92)],paint)
	_cabin(car,0.75,0.82,1.34,-0.76,1.60,-0.23,0.52,paint,glass,trim)
	# Rounded wings, front lamps and the rear engine grille define the silhouette.
	for side: float in [-1.0,1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side*0.69,0,-1.15)
		car.body.add_child(wing)
		car._shell(wing,[Vector3(0.23,0.48,0.81),Vector3(0.23,0.77,0.73),Vector3(0.16,0.89,0.55)],paint)
		var lamp := VisualGeometry.cylinder(car.body,0.17,0.07,Vector3(side*0.68,0.73,-1.90),cream)
		lamp.rotation.x = PI*0.38
		_box(car,Vector3(0.40,0.12,0.05),Vector3(side*0.61,0.65,2.07),car.brake_material)
		car._seam(car.body,Vector3(side*0.903,0.53,0.40),Vector3(side*0.85,0.80,0.40),0.018,trim)
		_box(car,Vector3(0.035,0.045,0.18),Vector3(side*0.865,0.78,0.18),trim)
	_box(car,Vector3(0.18,0.02,1.08),Vector3(0,0.826,-1.34),accent)
	_box(car,Vector3(0.18,0.02,0.74),Vector3(0,1.352,0.14),accent)
	for vent: int in range(7):
		_box(car,Vector3(0.83,0.026,0.033),Vector3(0,0.837,1.63+vent*0.036),trim)
	for end: float in [-1.0,1.0]:
		_box(car,Vector3(1.68,0.13,0.085),Vector3(0,0.47,end*2.09),trim)

static func _formula(car: CarVisual, paint: Material, cream: Material, trim: Material, glass: Material, accent: Material) -> void:
	# Open-wheel single seater with tapered nose, cockpit, suspension and wings.
	car._shell(car.body,[Vector3(0.42,0.19,2.13),Vector3(0.39,0.40,2.03),Vector3(0.28,0.52,1.82)],paint)
	_box(car,Vector3(0.48,0.026,0.66),Vector3(0,0.541,-0.05),trim)
	_box(car,Vector3(0.32,0.23,0.16),Vector3(0,0.62,0.24),trim)
	var helmet := VisualGeometry.cylinder(car.body,0.145,0.21,Vector3(0,0.68,0.04),cream)
	_box(car,Vector3(0.25,0.065,0.05),Vector3(0,0.73,-0.08),glass)
	# Low rollover hoop behind the driver, without closing the cockpit.
	for side: float in [-1.0,1.0]:
		car._seam(car.body,Vector3(side*0.23,0.45,0.40),Vector3(side*0.17,0.86,0.49),0.045,trim)
	car._seam(car.body,Vector3(-0.17,0.86,0.49),Vector3(0.17,0.86,0.49),0.045,trim)
	for side: float in [-1.0,1.0]:
		_box(car,Vector3(0.40,0.27,1.15),Vector3(side*0.55,0.33,0.57),paint)
		_box(car,Vector3(0.30,0.19,0.045),Vector3(side*0.55,0.34,-0.03),trim)
		for axle: float in [-1.45,1.45]:
			for offset: float in [-0.25,0.25]:
				car._seam(car.body,Vector3(side*0.32,0.30,axle+offset),Vector3(side*0.94,0.34,axle),0.042,trim)
		_box(car,Vector3(0.04,0.25,0.44),Vector3(side*0.90,0.30,-2.06),paint)
		_box(car,Vector3(0.045,0.32,0.55),Vector3(side*0.75,0.74,1.99),paint)
	_box(car,Vector3(1.83,0.065,0.45),Vector3(0,0.25,-2.06),accent)
	_box(car,Vector3(1.52,0.075,0.55),Vector3(0,0.81,1.99),accent)
	_box(car,Vector3(0.11,0.36,0.15),Vector3(0,0.58,1.99),trim)
	_box(car,Vector3(0.13,0.018,1.29),Vector3(0,0.535,-1.13),accent)
	for vent: int in range(5):
		_box(car,Vector3(0.39,0.02,0.025),Vector3(0,0.536,0.81+vent*0.12),trim)
	_box(car,Vector3(0.13,0.08,0.045),Vector3(0,0.34,2.15),car.brake_material)

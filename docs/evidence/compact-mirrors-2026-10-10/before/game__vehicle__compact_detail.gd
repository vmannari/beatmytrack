class_name CompactDetail
extends RefCounted
## Original fictional hatch details, authored from the owner's visual direction.
## Shared opaque materials batch on the sprung body and four rolling pivots.

static func tire(parent: Node3D, material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rounded shoulders, broad tread, recessed sidewall. Axis is local X.
	var profile: Array[Vector2] = [Vector2(-0.14,0.23),Vector2(-0.14,0.32),Vector2(-0.105,0.363),Vector2(-0.075,0.37),Vector2(0.075,0.37),Vector2(0.105,0.363),Vector2(0.14,0.32),Vector2(0.14,0.23)]
	for row: int in range(profile.size()-1):
		for segment: int in range(64):
			var a: float = TAU*segment/64.0
			var b: float = TAU*(segment+1)/64.0
			var p: Vector2 = profile[row]
			var q: Vector2 = profile[row+1]
			var points: Array[Vector3] = [Vector3(p.x,sin(a)*p.y,cos(a)*p.y),Vector3(q.x,sin(a)*q.y,cos(a)*q.y),Vector3(q.x,sin(b)*q.y,cos(b)*q.y),Vector3(p.x,sin(b)*p.y,cos(b)*p.y)]
			var tangent: Vector2 = (q-p).normalized()
			for index: int in [0,2,1,0,3,2]:
				var angle: float = a if index in [0,1] else b
				tool.set_normal(Vector3(-tangent.y,tangent.x*sin(angle),tangent.x*cos(angle)))
				tool.set_uv(Vector2(angle/TAU,float(row+(1 if index in [1,2] else 0))/(profile.size()-1)))
				tool.add_vertex(points[index])
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var tire_finish := ShaderMaterial.new()
	tire_finish.shader = preload("res://vehicle/compact_tire.gdshader")
	mesh.material_override = tire_finish
	parent.add_child(mesh)

static func build(car: CarVisual, blue: Material, cream: Material, trim: Material, alloy: Material) -> void:
	var rubber := VisualGeometry.material(Color("303234"))
	var bright := CompactFinish.alloy(Color("b5b8ae"))
	var amber := VisualGeometry.material(Color("d58b32"))
	var lens := VisualGeometry.material(Color("e7e4d2"))
	var shade := VisualGeometry.material(Color("384e55"))
	_front(car, blue, cream, trim, alloy)
	# The arch rolls out from the actual body skin to a narrow dark opening lip.
	for side: float in [-1.0,1.0]:
		for axle: float in [-1.28,1.28]:
			CompactCoachwork.build_arch(car,side,axle,blue,trim)
		# Seams follow the actual curved steel instead of disappearing inside it.
		for door_end: float in [-0.71,0.47]:
			for segment: int in range(28):
				var y0: float = lerpf(1.01,0.59,segment/28.0)
				var y1: float = lerpf(1.01,0.59,(segment+1)/28.0)
				car._seam(car.body,Vector3(side*(CompactCoachwork.body_width(y0,door_end)+0.003),y0,door_end),Vector3(side*(CompactCoachwork.body_width(y1,door_end)+0.003),y1,door_end),0.006,trim)
		for segment: int in range(36):
			var z0: float=lerpf(-0.68,0.44,segment/36.0)
			var z1: float=lerpf(-0.68,0.44,(segment+1)/36.0)
			car._seam(car.body,Vector3(side*(CompactCoachwork.body_width(0.56,z0)+0.003),0.56,z0),Vector3(side*(CompactCoachwork.body_width(0.56,z1)+0.003),0.56,z1),0.006,trim)
		for front: bool in [true,false]:
			var z_center: float=-0.68 if front else 0.44
			for segment: int in range(8):
				var a: float=(PI if front else PI*1.5)+segment/8.0*PI*0.5
				var b: float=(PI if front else PI*1.5)+(segment+1)/8.0*PI*0.5
				var y0: float=0.59+sin(a)*0.03
				var y1: float=0.59+sin(b)*0.03
				var z0: float=z_center+cos(a)*0.03
				var z1: float=z_center+cos(b)*0.03
				car._seam(car.body,Vector3(side*(CompactCoachwork.body_width(y0,z0)+0.003),y0,z0),Vector3(side*(CompactCoachwork.body_width(y1,z1)+0.003),y1,z1),0.006,trim)
		VisualGeometry.box(car.body,Vector3(0.018,0.046,0.17),Vector3(side*0.883,0.835,0.30),trim)
		VisualGeometry.box(car.body,Vector3(0.023,0.021,0.13),Vector3(side*0.894,0.846,0.30),bright)
		VisualGeometry.box(car.body,Vector3(0.020,0.032,0.066),Vector3(side*0.881,0.82,-0.83),amber)
		CompactCoachwork.build_mirror(car,side,trim,bright)
		# Slim drip rails, black windscreen gasket, separate wiper blades.
		car._seam(car.body,Vector3(side*0.63,1.483,-0.34),Vector3(side*0.63,1.483,1.12),0.010,cream)
		car._seam(car.body,Vector3(side*0.67,1.083,-0.934),Vector3(side*0.16,1.12,-0.886),0.023,trim)
		# Stacked rear lenses in a dark housing, and restrained hatch hardware.
		_rear_patch(car,side,0.635,0.795,0.68,1.02,0.022,trim)
		_rear_patch(car,side,0.653,0.777,0.91,1.002,0.029,amber)
		_rear_patch(car,side,0.653,0.777,0.77,0.895,0.030,car.brake_material)
		_rear_patch(car,side,0.653,0.777,0.695,0.750,0.029,lens)
	for vent: int in range(18):
		VisualGeometry.box(car.body,Vector3(0.014,0.012,0.082),Vector3(-0.51+vent*0.06,1.047,-1.04),trim)
	_wrap_bumper(car,trim,true)
	VisualGeometry.box(car.body,Vector3(0.29,0.045,0.035),Vector3(0,0.91,CompactCoachwork.rear_skin(0,0.91)+0.016),trim)
	# Twin round lamps per side share the gently curved, recessed dark fascia.
	for side: float in [-1.0,1.0]:
		for offset: float in [0.405,0.651]:
			var x: float = side*offset
			for layer: int in range(4):
				var radii: Array[float] = [0.122,0.107,0.094,0.064]
				var materials: Array[Material] = [trim,bright,shade,lens]
				var light := VisualGeometry.cylinder(car.body,radii[layer],0.018,Vector3(x,0.798,_nose_z(x)-layer*0.009),materials[layer])
				light.rotation = Vector3(PI*0.5,-atan(0.40625*x),0)
			var glint := VisualGeometry.cylinder(car.body,0.028,0.009,Vector3(x-0.022,0.841,_nose_z(x)-0.038),lens)
			glint.rotation.x = PI*0.5
		VisualGeometry.box(car.body,Vector3(0.19,0.065,0.028),Vector3(side*0.61,0.535,_nose_z(side*0.61)-0.15),amber)
	# Recessed dark centres, alloy rim lips and explicit lug centres on every wheel.
	for rotor: Node3D in car.rolling_wheels:
		var side: float = signf((rotor.get_parent() as Node3D).position.x)
		var lip := Node3D.new()
		rotor.add_child(lip)
		lip.position.x = side*0.143
		lip.rotation.z = -side*PI*0.5
		VisualGeometry.ring(lip,Vector3.ZERO,0.235,0.023,bright)
		_rim_bowl(rotor,side,alloy)
		var cap := VisualGeometry.cylinder(rotor,0.062,0.18,Vector3.ZERO,trim)
		cap.rotation.z = PI*0.5
		for lug: int in range(4):
			var a: float = lug*TAU/4.0
			var bolt := VisualGeometry.cylinder(rotor,0.014,0.195,Vector3(0,sin(a)*0.047,cos(a)*0.047),bright)
			bolt.rotation.z = PI*0.5


static func _front(car: CarVisual, blue: Material, cream: Material, trim: Material, alloy: Material) -> void:
	# Curved nose with a separate moulded rubber bumper wrapping both corners.
	_nose_band(car,0.81,0.605,0.971,0.0,-1.89,blue)
	_nose_band(car,0.795,0.660,0.932,-0.009,-1.91,trim)
	for row: int in range(5):
		_nose_band(car,0.280,0.691+row*0.046,0.702+row*0.046,-0.017,-2.00,alloy)
	_wrap_bumper(car,trim)
	CompactCoachwork.build_hood(car,blue,cream)


static func _rear_skin(x: float, y: float) -> float:
	return CompactCoachwork.rear_skin(x,y)


static func _rear_patch(car: CarVisual, side: float, inner: float, outer: float, bottom: float, top: float, relief: float, material: Material) -> void:
	# Small solid tiles follow both the waist bend and corner chamfer, with
	# their backs embedded in the body instead of floating rectangular boxes.
	for row: int in range(16):
		var y0: float = lerpf(bottom,top,row/16.0)
		var y1: float = lerpf(bottom,top,(row+1)/16.0)
		var inner0: float = inner/0.88*CompactCoachwork.width_at_height(y0)
		var outer0: float = outer/0.88*CompactCoachwork.width_at_height(y0)
		var inner1: float = inner/0.88*CompactCoachwork.width_at_height(y1)
		var outer1: float = outer/0.88*CompactCoachwork.width_at_height(y1)
		var a := Vector3(side*inner0,y0,_rear_skin(inner0,y0)+relief)
		var b := Vector3(side*outer0,y0,_rear_skin(outer0,y0)+relief)
		var c := Vector3(side*outer1,y1,_rear_skin(outer1,y1)+relief)
		var d := Vector3(side*inner1,y1,_rear_skin(inner1,y1)+relief)
		car._panel([a,b,c,d],Vector3(side*0.6,0.6,1).normalized(),material)
		var inset := Vector3(0,0,-relief-0.015)
		car._panel([a,d,d+inset,a+inset],Vector3(-side,0,0),material)
		car._panel([b,c,c+inset,b+inset],Vector3(side,0,0),material)
		if row == 0: car._panel([a,b,b+inset,a+inset],Vector3.DOWN,material)
		if row == 15: car._panel([d,c,c+inset,d+inset],Vector3.UP,material)


static func _nose_z(x: float) -> float:
	return -2.119+0.130*pow(x/0.8,2.0)


static func _wrap_bumper(car: CarVisual, rubber: Material, rear: bool = false) -> void:
	CompactCoachwork.build_bumper(car,rear,rubber)


static func _nose_band(car: CarVisual, half_width: float, bottom: float, top: float, offset: float, back: float, material: Material) -> void:
	for segment: int in range(16):
		var x0: float = lerpf(-half_width,half_width,segment/16.0)
		var x1: float = lerpf(-half_width,half_width,(segment+1)/16.0)
		var z0: float = _nose_z(x0)+offset
		var z1: float = _nose_z(x1)+offset
		car._panel([Vector3(x0,bottom,z0),Vector3(x1,bottom,z1),Vector3(x1,top,z1),Vector3(x0,top,z0)],Vector3((z1-z0)/(x1-x0),0,-1),material)
		car._panel([Vector3(x0,top,z0),Vector3(x1,top,z1),Vector3(x1,top,back),Vector3(x0,top,back)],Vector3.UP,material)
		car._panel([Vector3(x0,bottom,z0),Vector3(x1,bottom,z1),Vector3(x1,bottom,back),Vector3(x0,bottom,back)],Vector3.DOWN,material)
	for side: float in [-1.0,1.0]:
		var x: float = side*half_width
		var z: float = _nose_z(x)+offset
		car._panel([Vector3(x,bottom,z),Vector3(x,top,z),Vector3(x,top,back),Vector3(x,bottom,back)],Vector3(side,0,0),material)


static func _rim_bowl(rotor: Node3D, side: float, metal: Material) -> void:
	# Sloping inner barrel from the bright lip to a recessed spoke bed.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in range(32):
		var a: float = TAU*segment/32.0
		var b: float = TAU*(segment+1)/32.0
		var points: Array[Vector3] = [Vector3(side*0.146,sin(a)*0.232,cos(a)*0.232),Vector3(side*0.146,sin(b)*0.232,cos(b)*0.232),Vector3(side*0.074,sin(b)*0.195,cos(b)*0.195),Vector3(side*0.074,sin(a)*0.195,cos(a)*0.195)]
		var normal := Vector3(side*0.46,-sin((a+b)*0.5)*0.89,-cos((a+b)*0.5)*0.89)
		var indices: Array[int] = [0,1,2,0,2,3]
		if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0: indices = [0,2,1,0,3,2]
		for index: int in indices:
			tool.set_normal(normal.normalized())
			tool.add_vertex(points[index])
	var part := MeshInstance3D.new()
	part.mesh = tool.commit()
	part.material_override = metal
	rotor.add_child(part)

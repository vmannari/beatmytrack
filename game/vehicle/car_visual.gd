class_name CarVisual
extends Node3D
## Base 4.25 x 1.8 m compact scaled by HandlingConfig.BODY_SCALE; +Z rear, -Z nose. Presentation only.

var front_wheels: Array[Node3D] = []
var brake_lights: Array[MeshInstance3D] = []
var body: Node3D
var brake_material: StandardMaterial3D


func _ready() -> void:
	scale = Vector3.ONE * HandlingConfig.BODY_SCALE
	var paint := VisualGeometry.material(Color("c8c1ab"))
	VisualGeometry.ink(paint)
	var blue := VisualGeometry.material(Color("244d69"))
	VisualGeometry.ink(blue)
	var trim := VisualGeometry.material(Color("171e21"))
	var glass := VisualGeometry.material(Color("293b43"))
	var rim := VisualGeometry.material(Color("657177"))
	var lamps := VisualGeometry.material(Color("e4dfc5"))
	brake_material = VisualGeometry.material(Color("802d2b"))
	body = Node3D.new()
	add_child(body)
	_shell(body, [Vector3(0.82,0.32,2.00),Vector3(0.90,0.40,2.125),Vector3(0.88,0.52,2.08)], trim)
	_shell(body, [Vector3(0.86, 0.5, 2.03), Vector3(0.88, 0.86, 1.98), Vector3(0.76, 1.02, 1.8)], blue)
	_shell(body, [Vector3(0.875, 0.85, 1.98), Vector3(0.76, 1.02, 1.8)], paint)
	# Three-door hatch: the cabin reaches the tail, with no sedan boot deck.
	_hatchback(paint, glass, trim)
	for side: float in [-1.0, 1.0]:
		_seam(body,Vector3(side*0.55,1.025,-1.73),Vector3(side*0.58,1.025,-1.05),0.012,trim)
		# One long front door, then a fixed rear quarter window.
		_seam(body,Vector3(side*0.88,0.87,0.47),Vector3(side*0.88,0.58,0.47),0.012,trim)
		VisualGeometry.box(body,Vector3(0.025,0.055,0.20),Vector3(side*0.88,0.85,0.32),trim)
		_seam(body,Vector3(side*0.89,0.64,-0.90),Vector3(side*0.89,0.64,0.78),0.024,trim)
		# Painted sill stripe and swept rear-quarter cream motif from the menu.
		_panel([Vector3(side*0.884,0.83,0.78),Vector3(side*0.884,0.83,1.35),Vector3(side*0.884,0.59,1.05),Vector3(side*0.884,0.59,0.90)],Vector3(side,0,0),paint)
	VisualGeometry.box(body,Vector3(1.26,0.19,0.04),Vector3(0,0.79,-2.035),trim)
	for slat: int in range(3):
		VisualGeometry.box(body,Vector3(0.72,0.013,0.025),Vector3(0,0.73+slat*0.055,-2.065),rim)
	for side: float in [-1.0, 1.0]:
		for offset: float in [0.43,0.65]:
			var lamp := VisualGeometry.cylinder(body,0.10,0.04,Vector3(side*offset,0.80,-2.055),lamps)
			lamp.rotation.x = PI*0.5
		VisualGeometry.box(body,Vector3(0.14,0.13,0.045),Vector3(side*0.77,0.77,-2.02),VisualGeometry.material(Color("b77929")))
		brake_lights.append(VisualGeometry.box(body, Vector3(0.16, 0.27, 0.07), Vector3(side * 0.73, 0.84, 2.01), brake_material))
		VisualGeometry.box(body, Vector3(0.18, 0.12, 0.28), Vector3(side * 0.93, 1.03, -0.48), trim)
		for axle: float in [-1.28, 1.28]:
			for segment: int in range(12):
				var a0: float = PI*segment/12.0
				var a1: float = PI*(segment+1)/12.0
				_panel([Vector3(side*0.893,0.37+sin(a0)*0.39,axle+cos(a0)*0.39),Vector3(side*0.893,0.37+sin(a1)*0.39,axle+cos(a1)*0.39),Vector3(side*0.895,0.37+sin(a1)*0.46,axle+cos(a1)*0.46),Vector3(side*0.895,0.37+sin(a0)*0.46,axle+cos(a0)*0.46)],Vector3(side,0,0),blue)
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.83, 0.37, axle)
			add_child(pivot)
			var tire := VisualGeometry.cylinder(pivot, 0.36, 0.24, Vector3.ZERO, trim)
			tire.rotation.z = PI * 0.5
			var hub := VisualGeometry.cylinder(pivot, 0.2, 0.25, Vector3.ZERO, rim)
			hub.rotation.z = PI * 0.5
			for spoke: int in range(8):
				var a: float = spoke*TAU/8.0
				_seam(pivot,Vector3(side*0.132,sin(a)*0.08,cos(a)*0.08),Vector3(side*0.132,sin(a)*0.185,cos(a)*0.185),0.024,lamps)
			if axle < 0:
				front_wheels.append(pivot)
	VisualGeometry.box(body, Vector3(1.0, 0.14, 0.08), Vector3(0, 0.49, -2.13), trim)
	VisualGeometry.box(body, Vector3(0.4, 0.13, 0.045), Vector3(0, 0.64, 2.15), lamps)


func present(point: Vector2, angle: float, state: VehicleState, frame: DriveFrame) -> void:
	position = VisualGeometry.world(point)
	rotation.y = -angle
	for wheel: Node3D in front_wheels:
		wheel.rotation.y = -state.steering * 0.4
	body.rotation.z = clampf(state.yaw_rate * state.velocity.length() * 0.0015, -0.055, 0.055)
	brake_material.albedo_color = Color("f17158") if frame.brake > 0 else Color("802d2b")


func _shell(parent: Node3D, sections: Array[Vector3], surface: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for section: Vector3 in sections:
		var w: float = section.x
		var y: float = section.y
		var length: float = section.z
		rings.append(PackedVector3Array([Vector3(-w + 0.16, y, -length), Vector3(w - 0.16, y, -length),
			Vector3(w, y, -length + 0.22), Vector3(w, y, length - 0.22), Vector3(w - 0.16, y, length),
			Vector3(-w + 0.16, y, length), Vector3(-w, y, length - 0.22), Vector3(-w, y, -length + 0.22)]))
	for row: int in range(rings.size() - 1):
		for i: int in range(8):
			var j: int = (i + 1) % 8
			for vertex: Vector3 in [rings[row][i], rings[row + 1][j], rings[row + 1][i], rings[row][i], rings[row][j], rings[row + 1][j]]:
				tool.add_vertex(vertex)
	var top: PackedVector3Array = rings.back()
	for i: int in range(1, 7):
		for vertex: Vector3 in [top[0], top[i], top[i + 1]]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = surface
	parent.add_child(instance)


func _seam(parent: Node3D, start: Vector3, end: Vector3, width: float, surface: Material) -> void:
	var stroke := VisualGeometry.box(parent,Vector3(width,width,start.distance_to(end)),(start+end)*0.5,surface)
	var up: Vector3 = Vector3.RIGHT if absf((end-start).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	stroke.basis = Basis.looking_at(end-start,up)


func _hatchback(paint: Material, glass: Material, trim: Material) -> void:
	# Broad roof, long side glazing and a sloping rear hatch; +Z is the tail.
	var lf := Vector3(-0.76,1.01,-1.00)
	var rf := Vector3(0.76,1.01,-1.00)
	var lr := Vector3(-0.76,1.01,1.91)
	var rr := Vector3(0.76,1.01,1.91)
	var tlf := Vector3(-0.63,1.48,-0.40)
	var trf := Vector3(0.63,1.48,-0.40)
	var tlr := Vector3(-0.63,1.48,1.18)
	var trr := Vector3(0.63,1.48,1.18)
	_panel([lf,rf,trf,tlf],Vector3(0,0.79,-0.61),paint)
	_panel([lr,rr,trr,tlr],Vector3(0,0.84,0.54),paint)
	_panel([tlf,trf,trr,tlr],Vector3.UP,paint)
	_panel([Vector3(-0.68,1.065,-0.95),Vector3(0.68,1.065,-0.95),Vector3(0.57,1.445,-0.46),Vector3(-0.57,1.445,-0.46)],Vector3(0,0.79,-0.61),glass)
	_panel([Vector3(-0.67,1.075,1.83),Vector3(0.67,1.075,1.83),Vector3(0.57,1.435,1.27),Vector3(-0.57,1.435,1.27)],Vector3(0,0.84,0.54),glass)
	for side: float in [-1.0,1.0]:
		_panel([Vector3(side*0.76,1.01,-1.0),Vector3(side*0.76,1.01,1.91),Vector3(side*0.63,1.48,1.18),Vector3(side*0.63,1.48,-0.4)],Vector3(side,0.277,0),paint)
		# Window corners lie on the sloped cabin side, just outside its paint.
		_panel([Vector3(side*0.748,1.07,-0.85),Vector3(side*0.748,1.07,0.42),Vector3(side*0.651,1.425,0.42),Vector3(side*0.651,1.425,-0.35)],Vector3(side,0.277,0),glass)
		_panel([Vector3(side*0.748,1.07,0.52),Vector3(side*0.748,1.07,1.68),Vector3(side*0.651,1.425,1.14),Vector3(side*0.651,1.425,0.52)],Vector3(side,0.277,0),glass)
		_panel([Vector3(side*0.749,1.07,0.42),Vector3(side*0.749,1.07,0.52),Vector3(side*0.652,1.425,0.52),Vector3(side*0.652,1.425,0.42)],Vector3(side,0.277,0),trim)
		_seam(body,Vector3(side*0.750,1.065,-0.88),Vector3(side*0.750,1.065,1.70),0.018,trim)
		_seam(body,Vector3(side*0.70,1.02,-0.92),Vector3(side*0.12,1.04,-0.93),0.022,trim)
	var reflection := VisualGeometry.material(Color("4d6673"))
	_panel([Vector3(-0.52,1.074,-0.944),Vector3(-0.34,1.074,-0.944),Vector3(0.10,1.44,-0.471),Vector3(-0.13,1.44,-0.471)],Vector3(0,0.79,-0.61),reflection)
	# Hatch seam and rear wiper make the short tail readable from overhead.
	_seam(body,Vector3(-0.68,1.05,1.87),Vector3(0.68,1.05,1.87),0.018,trim)
	_seam(body,Vector3(0,1.10,1.80),Vector3(0.36,1.17,1.69),0.020,trim)


func _panel(points: Array[Vector3], normal: Vector3, surface: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: Array[int] = [0,1,2,0,2,3]
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0:
		indices = [0,2,1,0,3,2]
	for index: int in indices:
		tool.set_normal(normal.normalized())
		tool.add_vertex(points[index])
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = surface
	body.add_child(node)

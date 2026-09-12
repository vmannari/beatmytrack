class_name CarVisual
extends Node3D
## Base 4.25 x 1.8 m compact scaled by HandlingConfig.BODY_SCALE; +Z rear, -Z nose. Presentation only.

var front_wheels: Array[Node3D] = []
var brake_lights: Array[MeshInstance3D] = []
var body: Node3D
var brake_material: StandardMaterial3D


func _ready() -> void:
	scale = Vector3.ONE * HandlingConfig.BODY_SCALE
	var paint := VisualGeometry.material(Color("adb8b4"))
	var trim := VisualGeometry.material(Color("171e21"))
	var glass := VisualGeometry.material(Color("293b43"))
	var rim := VisualGeometry.material(Color("657177"))
	var lamps := VisualGeometry.material(Color("e4dfc5"))
	brake_material = VisualGeometry.material(Color("802d2b"))
	body = Node3D.new()
	add_child(body)
	VisualGeometry.box(body, Vector3(1.8, 0.24, 4.25), Vector3(0, 0.42, 0), trim)
	_shell(body, [Vector3(0.86, 0.5, 2.03), Vector3(0.88, 0.86, 1.98), Vector3(0.76, 1.02, 1.8)], paint)
	# Glass cabin slopes toward a separate matte roof, preserving readable nose.
	var cabin := Node3D.new()
	cabin.position.z = 0.18
	body.add_child(cabin)
	_shell(cabin, [Vector3(0.76, 0.98, 1.18), Vector3(0.62, 1.48, 0.74)], glass)
	VisualGeometry.box(cabin, Vector3(1.28, 0.075, 1.5), Vector3(0, 1.5, 0), paint)
	for side: float in [-1.0, 1.0]:
		VisualGeometry.box(body, Vector3(0.48, 0.12, 0.07), Vector3(side * 0.55, 0.78, -2.0), lamps)
		brake_lights.append(VisualGeometry.box(body, Vector3(0.52, 0.12, 0.07), Vector3(side * 0.52, 0.8, 2.01), brake_material))
		VisualGeometry.box(body, Vector3(0.18, 0.12, 0.28), Vector3(side * 0.93, 1.03, -0.48), trim)
		# Narrow dark B-pillars, sill, front and rear wheel arches.
		VisualGeometry.box(cabin, Vector3(0.035, 0.4, 0.1), Vector3(side * 0.7, 1.2, 0.14), trim)
		for axle: float in [-1.28, 1.28]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.83, 0.37, axle)
			add_child(pivot)
			var tire := VisualGeometry.cylinder(pivot, 0.36, 0.24, Vector3.ZERO, trim)
			tire.rotation.z = PI * 0.5
			var hub := VisualGeometry.cylinder(pivot, 0.2, 0.25, Vector3.ZERO, rim)
			hub.rotation.z = PI * 0.5
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

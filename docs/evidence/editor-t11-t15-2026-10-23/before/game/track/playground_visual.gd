class_name PlaygroundVisual
extends Node3D


func build(data: PlaygroundData) -> void:
	var asphalt := VisualGeometry.material(Color("545c5a"))
	var earth := VisualGeometry.material(Color("56634a"))
	var concrete := VisualGeometry.material(Color("a09f91"))
	var white := VisualGeometry.material(Color("bab8a3"))
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	var faded := VisualGeometry.material(Color("68716b"))
	var orange := VisualGeometry.material(Color("ac593c"))
	var dark := VisualGeometry.material(Color("232c2c"))
	VisualGeometry.box(self, Vector3(1000, 0.15, 1000), Vector3(0, -0.2, 0), earth)
	VisualGeometry.box(self, Vector3(data.half_extent.x * 2, 0.1, data.half_extent.y * 2), Vector3(0, -0.05, 0), asphalt)
	# Low contrast surface seams communicate movement without noisy scenery.
	for x: int in range(-40, 48, 10):
		VisualGeometry.box(self, Vector3(0.045, 0.01, 120), Vector3(x, 0.008, 0), faded)
	for y: int in range(-50, 60, 10):
		VisualGeometry.box(self, Vector3(96, 0.01, 0.045), Vector3(0, 0.009, y), faded)
	for side: float in [-1.0, 1.0]:
		VisualGeometry.box(self, Vector3(0.6, 0.65, data.half_extent.y * 2 + 0.6), Vector3(side * (data.half_extent.x + 0.3), 0.3, 0), concrete)
		VisualGeometry.box(self, Vector3(data.half_extent.x * 2, 0.65, 0.6), Vector3(0, 0.3, side * (data.half_extent.y + 0.3)), concrete)
		VisualGeometry.box(self, Vector3(0.15, 0.015, 116), Vector3(side * 46, 0.02, 0), white)
	for island: Vector3 in data.islands:
		var center := Vector3(island.x, 0, -island.y)
		VisualGeometry.cylinder(self, island.z, 0.45, center + Vector3(0, 0.2, 0), concrete)
		VisualGeometry.cylinder(self, island.z - 0.3, 0.46, center + Vector3(0, 0.2, 0), earth)
		VisualGeometry.ring(self, center + Vector3(0, 0.025, 0), 12.0, 0.14, white)
		VisualGeometry.ring(self, center + Vector3(0, 0.026, 0), 16.0, 0.1, white)
	# Central braking lane and painted distance markers, not a race/checkpoint system.
	for side: float in [-1.0, 1.0]:
		VisualGeometry.box(self, Vector3(0.13, 0.015, 68), Vector3(side * 5.0, 0.02, 8), white)
	for i: int in range(6):
		var y: float = -30.0 + i * 10.0
		VisualGeometry.box(self, Vector3(10, 0.015, 0.2), Vector3(0, 0.02, -y), white)
		_label(str(i * 10), Vector3(7.0, 0.035, -y), 1.1)
	_label("BRAKE", Vector3(0, 0.04, -24), 1.4)
	_label("SLALOM", Vector3(23, 0.04, 41), 1.3)
	_label("SKID CIRCLE", Vector3(-23, 0.04, 12), 1.1)
	for i: int in range(6):
		var center := Vector3(23.0 + (-2.5 if i % 2 == 0 else 2.5), 0, 34.0 - i * 6.0)
		VisualGeometry.box(self, Vector3(0.7, 0.08, 0.7), center + Vector3(0, 0.04, 0), dark)
		var cone := VisualGeometry.cylinder(self, 0.3, 0.65, center + Vector3(0, 0.37, 0), orange)
		(cone.mesh as CylinderMesh).top_radius = 0.08
	# Decorative cones are deliberately non-colliding; concrete islands/walls collide.


func _label(text: String, point: Vector3, scale_factor: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.02 * scale_factor
	label.modulate = Color("b7b59e")
	label.outline_size = 0
	label.no_depth_test = false
	label.rotation.x = -PI * 0.5
	label.position = point
	add_child(label)

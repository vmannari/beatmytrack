extends RefCounted
## The production Garage rig and finishes over a transparent podium cutout.
static func build(world: Node3D, car: CarVisual) -> WorldEnvironment:
	var environment: WorldEnvironment = GarageEnvironment.build_lighting(world,false,true)
	environment.name = "PodiumReflectionEnvironment"
	# Other chassis still use the original nonreflective toon paint. Give their
	# podium-only paint copies the Compact's existing Garage automotive finish.
	if car.vehicle_id != "compact": _garage_paint(car)
	ShowroomStudio._studio_glass(car,{})
	ShowroomStudio._contact(world,Vector3(0,0.004,0),Vector2(2.4,4.7)*HandlingConfig.BODY_SCALE,0.40)
	for wheel: Vector3 in car.wheel_rest_positions:
		var position: Vector3 = car.transform*(wheel*HandlingConfig.BODY_SCALE)
		ShowroomStudio._contact(world,Vector3(position.x,0.007,position.z),Vector2(0.60,0.8),0.65)
	return environment

static func _garage_paint(car: CarVisual) -> void:
	var paints: Array = car.paint_materials.values()
	if car.accent_roof != null: paints.append(car.accent_roof)
	for variant: Dictionary in car.paint_variants: paints.append(variant.material)
	var copies: Dictionary = {}
	for node: Node in car.find_children("*","MeshInstance3D",true,false):
		for index: int in range(node.mesh.get_surface_count()):
			var source: Material = node.get_active_material(index)
			var pigment: StandardMaterial3D = source as StandardMaterial3D
			if source is ShaderMaterial and source.has_meta("livery_source"): pigment = source.get_meta("livery_source")
			if pigment not in paints: continue
			if not copies.has(source):
				var paint: StandardMaterial3D = CompactFinish.paint(pigment.albedo_color)
				if source is ShaderMaterial:
					var graphic: ShaderMaterial = source.duplicate()
					graphic.shader = LiveryGraphics.FINISH
					LiveryGraphics.paint_finish(graphic,paint)
					copies[source] = graphic
				else: copies[source] = paint
			if node.material_override != null: node.material_override = copies[source]
			else: node.set_surface_override_material(index,copies[source])

static func prepare(view: WeakRef) -> void:
	# Give shared Garage radiance its bounded first draws before freezing the image.
	for _frame: int in range(3):
		await RenderingServer.frame_post_draw
		var preview: Control = view.get_ref()
		if preview == null or not preview.is_visible_in_tree(): return
		preview._refresh()

extends "res://ui/garage_preview_renderer.gd"
## Dedicated carousel capture: the exact car in one photographic viewport, without the workshop.
func _ready() -> void:
	set_process(false)
	read_only = true
	garage_mode = true
	elevation = atan(0.16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	showroom_viewport = SubViewport.new()
	showroom_viewport.own_world_3d = true
	showroom_viewport.size = Vector2i(2048,512)
	# Keep the existing capture resolution/AA while measuring the scene change.
	showroom_viewport.msaa_3d = Viewport.MSAA_4X
	showroom_viewport.mesh_lod_threshold = 0.5
	showroom_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var holder := Node.new()
	holder.name = "ThumbnailWorld"
	add_child(holder)
	holder.add_child(showroom_viewport)
	var image := TextureRect.new()
	image.name = "ModelRender"
	image.texture = showroom_viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(image)
	MenuStyle.fill(image)
	var world := Node3D.new()
	world.name = "ThumbnailStudio"
	showroom_viewport.add_child(world)
	car = CarVisual.new()
	car.vehicle_id = vehicle_id
	car.garage_template = true
	car.editable_kits = VehicleCustomisation.supported(vehicle_id)
	car.livery = livery
	car.customisation = customisation
	car.cooperative_build = cooperative_build
	world.add_child(car)
	while not car.model_ready:
		await get_tree().process_frame
		if not is_inside_tree() or is_queued_for_deletion(): return
	turntable = Node3D.new()
	turntable.name = "ThumbnailStage"
	world.add_child(turntable)
	car.reparent(turntable)
	car.position.y = GarageEnvironment.DECK_HEIGHT
	var environment: WorldEnvironment = GarageEnvironment.build_lighting(world,true)
	environment.environment.ambient_light_energy = 0.54
	world.get_node("GarageKey").light_energy = 1.08
	ShowroomStudio._studio_glass(car,{})
	var floor := MeshInstance3D.new()
	floor.name = "ThumbnailFloor"
	# A few curved strips remove the horizon seam without constructing a room.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2] = [Vector2(-40,0),Vector2(8,0)]
	var normals: Array[Vector3] = [Vector3.UP,Vector3.UP]
	for step: int in range(1,13):
		var angle: float = step*PI/24.0
		profile.append(Vector2(8+4*sin(angle),4*(1-cos(angle))))
		normals.append(Vector3(0,cos(angle),-sin(angle)))
	profile.append(Vector2(12,20))
	normals.append(Vector3(0,0,-1))
	for index: int in range(profile.size()-1):
		var a: Vector2 = profile[index]
		var b: Vector2 = profile[index+1]
		var points: Array[Vector3] = [Vector3(-40,a.y,a.x),Vector3(-40,b.y,b.x),Vector3(40,b.y,b.x),Vector3(40,a.y,a.x)]
		for vertex: int in [0,2,1,0,3,2]:
			tool.set_normal(normals[index if vertex in [0,3] else index+1])
			tool.add_vertex(points[vertex])
	floor.mesh = tool.commit()
	var floor_finish := ShaderMaterial.new()
	floor_finish.shader = preload("res://ui/studio_floor.gdshader")
	floor.material_override = floor_finish
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(floor)
	var deck := MeshInstance3D.new()
	deck.name = "ThumbnailDeck"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = GarageEnvironment.DECK_RADIUS
	cylinder.bottom_radius = GarageEnvironment.DECK_RADIUS
	cylinder.height = 0.20
	cylinder.radial_segments = 64
	deck.mesh = cylinder
	deck.position.y = 0.115
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color("293d49")
	finish.roughness = 0.8
	finish.metallic = 0.05
	deck.material_override = finish
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(deck)
	_shadow(turntable,Vector3(0,0.220,0),Vector2(2.3,4.4)*HandlingConfig.BODY_SCALE,0.34)
	for wheel: Vector3 in car.wheel_rest_positions:
		_shadow(turntable,Vector3(wheel.x*HandlingConfig.BODY_SCALE,0.222,wheel.z*HandlingConfig.BODY_SCALE),Vector2(0.62,0.85),0.52)
	weathering.configure(car,"pine",VehicleCatalog.config(vehicle_id))
	weathering.restore(condition)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 38.0
	camera.current = true
	_orbit()
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	resized.connect(refresh_thumbnail)
	visibility_changed.connect(refresh_thumbnail)
	refresh_thumbnail()
	showroom_ready = true

func _shadow(parent: Node3D, at: Vector3, dimensions: Vector2, opacity: float) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "ThumbnailContactShadow"
	var plane := PlaneMesh.new()
	plane.size = dimensions
	shadow.mesh = plane
	shadow.position = at
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://ui/garage_thumbnail_shadow.gdshader")
	finish.set_shader_parameter("opacity",opacity)
	shadow.material_override = finish
	parent.add_child(shadow)

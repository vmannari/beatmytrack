extends Control
## One temporary native preview; visible Garage meshes are shared, never rebuilt.
var source_car: WeakRef
var vehicle_id: String = "compact"
var livery: Dictionary = {}
var customisation: Dictionary = {}
var category: String = ""
var caption: String = ""
var viewport: SubViewport
var camera: Camera3D
var model: Node3D
var presentation_ready: bool = false
var reused_meshes: bool = false
var points := PackedVector3Array()
var yaw: float = -0.72
var pointer: int = -2
var previous := Vector2.ZERO
var render_requests: int = 0
var _released: bool = false
var callout: Control

class PartCallout extends Control:
	var preview: Control
	func _draw() -> void: preview.draw_callout(self)

func _ready() -> void:
	if category == "aero": yaw = -2.42
	elif category == "rims": yaw = -1.0
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.name = "PurchasePreviewViewport"
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var source: CarVisual = source_car.get_ref() as CarVisual if source_car != null else null
	if is_instance_valid(source) and source.model_ready:
		model = Node3D.new()
		model.name = "PurchaseCarSnapshot"
		world.add_child(model)
		model.scale = source.scale
		var inverse: Transform3D = source.global_transform.affine_inverse()
		for original: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			if original.mesh == null or not original.is_visible_in_tree(): continue
			var copy := MeshInstance3D.new()
			copy.name = original.name
			copy.mesh = original.mesh
			copy.material_override = original.material_override
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface: int in original.mesh.get_surface_count():
				copy.set_surface_override_material(surface,original.get_surface_override_material(surface))
			model.add_child(copy)
			copy.transform = inverse*original.global_transform
		reused_meshes = true
	else:
		var car := CarVisual.new()
		car.vehicle_id = vehicle_id
		car.livery = livery.duplicate(true)
		car.customisation = customisation.duplicate(true)
		car.cooperative_build = true
		car.cache_rest_pose = false
		model = car
		world.add_child(car)
		while not car.model_ready:
			await get_tree().process_frame
			if _released or not is_inside_tree() or is_queued_for_deletion(): return
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.TRANSPARENT
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c0cbe1")
	environment.environment.ambient_light_energy = 0.7
	if ShowroomStudio.cached_sky != null:
		environment.environment.sky = ShowroomStudio.cached_sky
		environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.add_child(environment)
	for data: Array in [[Vector3(-38,-40,0),Color("ffe0bc"),1.0],[Vector3(-22,135,0),Color("b4d2f0"),0.55]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = data[0]
		light.light_color = data[1]
		light.light_energy = data[2]
		world.add_child(light)
	ShowroomStudio._contact(world,Vector3(0,0.003,0),Vector2(2.4,4.7)*HandlingConfig.BODY_SCALE,0.62)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	world.add_child(camera)
	var render := TextureRect.new()
	render.name = "PurchaseCarRender"
	render.texture = viewport.get_texture()
	render.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	render.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var composite := ShaderMaterial.new()
	composite.shader = preload("res://ui/rivalry_car_composite.gdshader")
	composite.set_shader_parameter("linear_resolve",RenderingServer.get_current_rendering_method() != "gl_compatibility")
	render.material = composite
	add_child(render)
	MenuStyle.fill(render)
	callout = PartCallout.new()
	callout.preview = self
	callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(callout)
	MenuStyle.fill(callout)
	_collect_points()
	presentation_ready = true
	resized.connect(refresh)
	visibility_changed.connect(_visibility_changed)
	gui_input.connect(_drag)
	refresh()
	# Complete the initial native material draws without leaving an idle viewport running.
	if DisplayServer.get_name() != "headless":
		for frame: int in range(3):
			await RenderingServer.frame_post_draw
			if _released or not is_inside_tree() or is_queued_for_deletion(): return
			refresh()

func _collect_points() -> void:
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var box: AABB = mesh.get_aabb()
		for x: float in [box.position.x,box.end.x]:
			for y: float in [box.position.y,box.end.y]:
				for z: float in [box.position.z,box.end.z]: points.append(mesh.to_global(Vector3(x,y,z)))

func refresh() -> void:
	if _released or not presentation_ready or not is_inside_tree(): return
	if not is_visible_in_tree():
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var screen: Transform2D = get_viewport().get_stretch_transform()*get_screen_transform()
	var pixels: Vector2 = size*Vector2(screen.x.length(),screen.y.length())
	pixels *= minf(1.0,1200.0/maxf(pixels.x,1.0))
	viewport.size = Vector2i(maxi(1,roundi(pixels.x)),maxi(1,roundi(pixels.y)))
	var center := Vector3.ZERO
	if not points.is_empty():
		var box := AABB(points[0],Vector3.ZERO)
		for point: Vector3 in points: box = box.expand(point)
		center = box.get_center()
	camera.position = center+Vector3(sin(yaw)*8.0,2.8,-cos(yaw)*8.0)
	camera.look_at(center)
	camera.h_offset = 0
	camera.v_offset = 0
	var bounds := Rect2()
	var inverse: Transform3D = camera.global_transform.affine_inverse()
	for index: int in points.size():
		var point: Vector3 = inverse*points[index]
		bounds = Rect2(Vector2(point.x,point.y),Vector2.ZERO) if index == 0 else bounds.expand(Vector2(point.x,point.y))
	var aspect: float = float(viewport.size.x)/maxi(1,viewport.size.y)
	camera.size = maxf(0.1,maxf(bounds.size.y,bounds.size.x/aspect)*1.12)
	camera.h_offset = bounds.get_center().x
	camera.v_offset = bounds.get_center().y
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	render_requests += 1
	if is_instance_valid(callout): callout.queue_redraw()

func _drag(event: InputEvent) -> void:
	if not presentation_ready: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = -1 if event.pressed else -2
		previous = event.position
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and pointer == -2:
			pointer = event.index
			previous = event.position
		elif event.index == pointer: pointer = -2
		accept_event()
	elif (event is InputEventMouseMotion and pointer == -1) or (event is InputEventScreenDrag and event.index == pointer):
		yaw = wrapf(yaw-(event.position.x-previous.x)*0.008,-PI,PI)
		previous = event.position
		refresh()
		accept_event()

func draw_callout(canvas: Control) -> void:
	if not presentation_ready or category.is_empty(): return
	if category == "hood" and cos(yaw)<0.1: return
	if category == "aero" and cos(yaw)>-0.1: return
	var anchor: Vector3 = {"hood":Vector3(0.45,1.0,-1.35),"aero":Vector3(0,1.4,1.84),"rims":Vector3(-0.83,0.4,-1.28),"body":Vector3(-0.9,0.35,-0.3)}.get(category,Vector3.ZERO)*HandlingConfig.BODY_SCALE
	if category == "aero":
		var profile: Dictionary = CompactAero.PROFILES.get(str(customisation.get("aero","stock")),{})
		var center: Vector3 = profile.get("center",CompactCoachwork.roof_point(0,0.94))
		anchor = center*HandlingConfig.BODY_SCALE
	if category in ["rims","body"]: anchor.x = absf(anchor.x)*signf(sin(yaw))
	if camera.is_position_behind(anchor): return
	var at: Vector2 = camera.unproject_position(anchor)*size/Vector2(viewport.size)
	if not Rect2(Vector2(8,8),size-Vector2(16,16)).has_point(at): return
	var font: Font = MenuStyle.DISPLAY
	var text: String = GameText.message(caption).to_upper()
	var font_size: int = 17
	var width: float = minf(size.x-36,font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+24)
	var label_at := Vector2(clampf(at.x+46,12,size.x-width-12),maxf(12,at.y-96))
	var box := Rect2(label_at,Vector2(width,32))
	canvas.draw_style_box(MenuStyle.box(Color("07151feb"),4),box)
	canvas.draw_rect(box,MenuStyle.ACCENT,false,1.5)
	canvas.draw_line(at,Vector2(box.position.x+12,box.end.y),MenuStyle.ACCENT,2,true)
	canvas.draw_circle(at,4,MenuStyle.ACCENT,true,-1,true)
	canvas.draw_string(font,box.position+Vector2(12,23),text,HORIZONTAL_ALIGNMENT_LEFT,width-24,font_size,MenuStyle.ACCENT)

func _visibility_changed() -> void:
	pointer = -2
	refresh()

func release() -> void:
	_released = true
	pointer = -2
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.queue_free()
	presentation_ready = false

func _exit_tree() -> void: release()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: pointer = -2

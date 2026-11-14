extends Control
## Actual equipped cars with static lighting and the production livery mapping.
const FINISH: Shader = preload("res://ui/rivalry_preview_finish.gdshader")
var vehicle_id: String = "compact"
var livery: Dictionary = {}
var customisation: Dictionary = {}
var condition: Dictionary = {}
var fit_to_frame: bool = true
var cooperative_build: bool = true
var cache_rest_pose: bool = true
var render_scale: float = 2.0
var presentation_ready: bool = false
var viewport: SubViewport
var car: CarVisual
var camera: Camera3D
var _render_generation: int = 0
var _bounds: PackedVector3Array = PackedVector3Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	car = _create_car()
	car.vehicle_id = vehicle_id
	car.simple_model = true
	car.livery = VehicleLivery.normalize(livery,vehicle_id)
	car.customisation = customisation.duplicate(true)
	car.cache_rest_pose = cache_rest_pose
	car.cooperative_build = cooperative_build
	car.rotation.y = PI
	viewport.add_child(car)
	while not car.model_ready:
		await get_tree().process_frame
		if not is_inside_tree() or is_queued_for_deletion(): return
	_prepare_materials()
	camera = Camera3D.new()
	camera.position = Vector3(-5,2.5,6)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,0.65,0))
	camera.current = true
	var render := TextureRect.new()
	render.name = "EquippedCarRender"
	render.texture = viewport.get_texture()
	render.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	render.mouse_filter = Control.MOUSE_FILTER_IGNORE
	render.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(render)
	MenuStyle.fill(render)
	resized.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()
	presentation_ready = true

func _create_car() -> CarVisual:
	return CarVisual.new()

func _prepare_materials() -> void:
	var copies: Dictionary = {}
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null: continue
		if part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			part.hide()
			continue
		if part.is_visible_in_tree():
			var bounds: AABB = part.get_aabb()
			var local: Transform3D = inverse*part.global_transform
			for corner: int in range(8): _bounds.append(local*bounds.get_endpoint(corner))
		var sources: Array[Material] = []
		for surface: int in range(part.mesh.get_surface_count()): sources.append(part.get_active_material(surface))
		part.material_override = null
		part.material_overlay = null
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in range(sources.size()):
			var source: Material = sources[surface]
			if not copies.has(source): copies[source] = _material(source)
			part.set_surface_override_material(surface,copies[source])

func _material(source: Material) -> ShaderMaterial:
	# Copy each player's existing uniforms, including body-space decal placement.
	var finish: ShaderMaterial = source.duplicate() if source is ShaderMaterial and source.has_meta("livery_source") else ShaderMaterial.new()
	finish.shader = FINISH
	var pigment: StandardMaterial3D = source.get_meta("livery_source") if source != null and source.has_meta("livery_source") else source as StandardMaterial3D
	if pigment != null:
		finish.set_shader_parameter("paint_color",pigment.albedo_color)
		finish.set_shader_parameter("paint_metallic",pigment.metallic)
		finish.set_shader_parameter("paint_roughness",pigment.roughness)
		finish.set_shader_parameter("use_texture",pigment.albedo_texture != null)
		finish.set_shader_parameter("albedo_texture",pigment.albedo_texture)
		finish.set_shader_parameter("use_vertex_color",pigment.vertex_color_use_as_albedo)
		finish.set_shader_parameter("uv_scale",pigment.uv1_scale)
		finish.set_shader_parameter("uv_offset",pigment.uv1_offset)
	elif source is ShaderMaterial:
		finish.set_shader_parameter("paint_color",Color("152932"))
		finish.set_shader_parameter("paint_metallic",0.3)
		finish.set_shader_parameter("paint_roughness",0.15)
	return finish

func _refresh() -> void:
	if not is_inside_tree() or camera == null: return
	viewport.size = Vector2i(maxi(2,roundi(size.x*render_scale)),maxi(2,roundi(size.y*render_scale)))
	var aspect: float = float(viewport.size.x)/viewport.size.y
	var extent: float = 0.0
	# Parking/reparenting the menu temporarily detaches its 3D children. The
	# immutable car-local bounds avoid querying global transforms in that gap.
	var view: Transform3D = camera.transform.affine_inverse()*car.transform
	for corner: Vector3 in _bounds:
		var point: Vector3 = view*corner
		var depth: float = maxf(0.01,-point.z)
		extent = maxf(extent,maxf(absf(point.y)/depth,absf(point.x)/(depth*aspect)))
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = clampf(rad_to_deg(2*atan(extent*1.08)),1,120)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	_render_generation += 1
	if DisplayServer.get_name() != "headless": _freeze_after_draw(_render_generation)

func _freeze_after_draw(generation: int) -> void:
	await RenderingServer.frame_post_draw
	if is_inside_tree() and not is_queued_for_deletion() and generation==_render_generation:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

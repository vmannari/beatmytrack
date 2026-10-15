class_name CompactKitThumbnail
extends Button
## Native part photographs; at most sixteen textures retained in the cache.
const SIZE := Vector2i(384,112)
const CACHE_LIMIT: int = 16
static var images: Dictionary = {}
static var use_prepared: bool = true
var viewport: SubViewport
var image: TextureRect
var cache_key: String

static func make(category: String, option: Array, chosen: bool, action: Callable) -> CompactKitThumbnail:
	var button := CompactKitThumbnail.new()
	button.name = "KitOption_"+str(option[0])
	button.custom_minimum_size = Vector2(128,102)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = str(option[1])
	button.pressed.connect(action)
	button.set_selected(chosen)
	button.cache_key = category+"/"+str(option[0])+"/kit-preview-5/"+RenderingServer.get_current_rendering_method()
	button.image = TextureRect.new()
	button.image.texture = images.get(button.cache_key)
	if button.image.texture==null and use_prepared:
		var path: String = CompactKits.ASSET_ROOT.path_join("previews/"+RenderingServer.get_current_rendering_method()+"/"+category+"_"+str(option[0])+".png")
		if ResourceLoader.exists(path):
			button.image.texture = load(path) as Texture2D
			if images.size()>=CACHE_LIMIT: images.erase(images.keys()[0])
			images[button.cache_key] = button.image.texture
	button.image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	button.image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	button.image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(button.image)
	button.image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.image.offset_left = 4
	button.image.offset_right = -4
	button.image.offset_top = 4
	button.image.offset_bottom = -30
	var label := MenuStyle.label(str(option[1]),16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -28
	label.offset_bottom = -4
	if button.image.texture == null: button._build_preview(category,str(option[0]))
	return button

func set_selected(chosen: bool) -> void:
	var style: StyleBoxFlat = MenuStyle.card(4)
	style.border_color = MenuStyle.ACCENT if chosen else MenuStyle.BORDER
	style.set_border_width_all(2 if chosen else 1)
	add_theme_stylebox_override("normal",style)
	add_theme_color_override("font_color",MenuStyle.ACCENT if chosen else MenuStyle.TEXT)

func _ready() -> void:
	if viewport != null and DisplayServer.get_name() != "headless": _bake()

func _bake() -> void:
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or not is_instance_valid(viewport): return
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or not is_instance_valid(viewport): return
	var pixels: Image = viewport.get_texture().get_image()
	if pixels == null or pixels.is_empty(): return
	pixels.generate_mipmaps()
	var baked := ImageTexture.create_from_image(pixels)
	if images.size() >= CACHE_LIMIT: images.erase(images.keys()[0])
	images[cache_key] = baked
	image.texture = baked
	viewport.queue_free()
	viewport = null

func _build_preview(category: String, option: String) -> void:
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.gui_disable_input = true
	add_child(viewport)
	image.texture = viewport.get_texture()
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("15232e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c5d1dc")
	environment.environment.ambient_light_energy = 0.55
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50,-35,0)
	key.light_energy = 1.1
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25,145,0)
	fill.light_color = Color("a9c9e7")
	fill.light_energy = 0.4
	world.add_child(fill)
	var car := CarVisual.new()
	car.customisation = VehicleCustomisation.defaults()
	car.customisation[category] = option
	car.livery = VehicleLivery.defaults("compact")
	world.add_child(car)
	ShowroomStudio._studio_glass(car,{})
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var target: Vector3
	var direction: Vector3
	match category:
		"hood":
			target = Vector3(0,1.00,-1.45)*HandlingConfig.BODY_SCALE
			direction = Vector3(2,2.5,-3)
			camera.size = 0.88
		"aero":
			# One common side/rear view compares mounting height and rear overhang.
			target = Vector3(0,1.39,1.84)*HandlingConfig.BODY_SCALE
			direction = Vector3(3,0.95,3)
			camera.size = 1.44
		"rims":
			target = Vector3(0.83,0.37,-1.28)*HandlingConfig.BODY_SCALE
			direction = Vector3(4,0.8,-0.8)
			camera.size = 0.80
		_:
			target = Vector3(0,0.35,0)*HandlingConfig.BODY_SCALE
			direction = Vector3(3,0.9,-4)
			camera.size = 1.3
	camera.position = target+direction
	camera.look_at_from_position(camera.position,target)
	camera.current = true

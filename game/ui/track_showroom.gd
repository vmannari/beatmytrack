class_name TrackShowroom
extends SubViewportContainer
## Scenic menu/editor view of the exact native geometry and shared theme kit.

var track: NativeTrack
var camera: Camera3D
var ready_for_display: bool = false
static var _images: Dictionary = {}
const CACHE_LIMIT: int = 8
var _placeholder: Label

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder = MenuStyle.label("Loading preview…",16,true)
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MenuStyle.fill(_placeholder)
	add_child(_placeholder)
	call_deferred("_prepare")

func _prepare() -> void:
	# Let the parent finish layout before sizing or constructing the preview.
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	if DisplayServer.get_name() == "headless":
		ready_for_display = true
		return
	var key: String = track.content_hash+":"+str(Vector2i(size))
	if _images.has(key):
		_show_image(_images[key])
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size).max(Vector2i.ONE)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = TrackTheme.palette(str(track.metadata.get("theme","pine")))[1]
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bac8ce")
	environment.environment.ambient_light_energy = 0.35
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58,-35,0)
	light.light_color = Color("fff1d8")
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 160
	world.add_child(light)
	var visual := NativeTrackVisual.new()
	world.add_child(visual)
	await visual.build(track,BridgePresentation.new(track),true)
	if not is_inside_tree(): return
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = maxf(track.half_extent.y * 2.1, track.half_extent.x * 1.35)
	camera.far = 400
	camera.position = Vector3(0,150,90)
	camera.look_at(Vector3.ZERO,Vector3.UP)
	camera.current = true
	resized.connect(_fit_preview)
	_fit_preview()
	# The scene is static. Render once after construction/layout, then retain
	# only its small image; no full circuit remains live behind the menu.
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var result := ImageTexture.create_from_image(viewport.get_texture().get_image())
	if _images.size() >= CACHE_LIMIT: _images.erase(_images.keys()[0])
	_images[key] = result
	_show_image(result)
	remove_child(viewport)
	viewport.queue_free()
	camera = null

func _show_image(value: Texture2D) -> void:
	if is_instance_valid(_placeholder):
		remove_child(_placeholder)
		_placeholder.queue_free()
	var picture := TextureRect.new()
	picture.texture = value
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuStyle.fill(picture)
	add_child(picture)
	ready_for_display = true

func _fit_preview() -> void:
	if camera == null: return
	var aspect: float = maxf(0.25,size.x/maxf(1.0,size.y))
	# Menu-only framing: preserve full circuit width in tall selection cards too.
	camera.size = maxf(track.half_extent.y*2.1,track.half_extent.x*2.1/aspect)

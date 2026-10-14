class_name ObjectThumbnail
extends Button
## Small one-shot renders use exactly the placed-object mesh builder.
const CACHE_LIMIT: int = 48
static var _images: Dictionary = {}
var _viewport: SubViewport
var _image: TextureRect
var _cache_key: String

func _ready() -> void:
	if _viewport != null and DisplayServer.get_name() != "headless": _bake_preview()

func _bake_preview() -> void:
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or not is_instance_valid(_viewport): return
	var pixels: Image = _viewport.get_texture().get_image()
	if pixels == null or pixels.is_empty(): return
	var baked: ImageTexture = ImageTexture.create_from_image(pixels)
	if _images.size() >= CACHE_LIMIT: _images.erase(_images.keys()[0])
	_images[_cache_key] = baked
	_image.texture = baked
	_viewport.queue_free()
	_viewport = null

static func make(kind: String, title: String, chosen: bool, action: Callable, biome: String = "pine") -> Button:
	var button := ObjectThumbnail.new()
	button.name = "Asset_"+kind
	button.custom_minimum_size = Vector2(104,82)
	button.tooltip_text = title+" — Tap selected asset for variants and placement"
	button.toggle_mode = true
	button.button_pressed = chosen
	button.pressed.connect(action)
	EditorStyle.card(button,chosen)
	button._cache_key = kind+"/"+TrackTheme.normalized(biome)+"/"+NativeTrackVisual.VERSION
	var cached: Texture2D = _images.get(button._cache_key)
	var viewport: SubViewport
	if cached == null:
		viewport = _render_preview(button,kind,biome)
		button._viewport = viewport
	var image := TextureRect.new()
	image.texture = cached if cached != null else viewport.get_texture()
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.position = Vector2(4,1)
	image.size = Vector2(96,58)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(image)
	button._image = image
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_font_override("font",EditorStyle.FONT)
	label.position = Vector2(0,59)
	label.size = Vector2(104,20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button

static func _render_preview(button: Button, kind: String, biome: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(208,128)
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.gui_disable_input = true
	button.add_child(viewport)
	var kit := NativeTrackVisual.new()
	kit.theme_id = TrackTheme.normalized(biome)
	viewport.add_child(kit)
	var track := NativeTrack.new()
	var object: Dictionary = {"kind":kind,"position":[0,0],"rotation":0}
	track.metadata = {"creator_document":{"objects":[object]}}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	kit._build_placed_objects(track)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c9cf")
	environment.ambient_light_energy = 0.42
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	light.light_color = Color("fff0d3")
	light.light_energy = 1.15
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(7,6,-10)
	viewport.add_child(camera)
	camera.look_at_from_position(camera.position,Vector3.ZERO)
	var bounds: AABB=_mesh_bounds(kit)
	var center: Vector3=bounds.get_center()
	var projected_min := Vector3(INF,INF,INF)
	var projected_max := Vector3(-INF,-INF,-INF)
	for index: int in range(8):
		var point: Vector3=camera.basis.transposed()*(bounds.get_endpoint(index)-center)
		projected_min=projected_min.min(point)
		projected_max=projected_max.max(point)
	var extent: Vector3=projected_max-projected_min
	camera.size=maxf(0.1,maxf(extent.y,extent.x/(208.0/128.0))*1.08)
	camera.look_at_from_position(center+Vector3(7,6,-10),center)
	camera.current = true
	return viewport


static func _mesh_bounds(node: Node, parent: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var transform: Transform3D=parent*node.transform if node is Node3D else parent
	if node is MeshInstance3D: result=transform*node.get_aabb()
	if node is MultiMeshInstance3D and node.multimesh!=null:
		for index: int in range(node.multimesh.instance_count):
			var bounds: AABB=transform*node.multimesh.get_instance_transform(index)*node.multimesh.mesh.get_aabb()
			result=bounds if result.size==Vector3.ZERO else result.merge(bounds)
	for child: Node in node.get_children():
		var bounds: AABB=_mesh_bounds(child,transform)
		if bounds.size!=Vector3.ZERO: result=bounds if result.size==Vector3.ZERO else result.merge(bounds)
	return result

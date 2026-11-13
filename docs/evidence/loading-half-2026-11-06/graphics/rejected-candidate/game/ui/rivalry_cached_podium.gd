extends Control
## The overview is static. Load its native 3D graph only for a missing exact image.
const Pictures = preload("res://ui/rivalry_podium_pictures.gd")
var vehicle_id: String = "compact"
var simple_model: bool = true
var podium_presentation: bool = true
var fit_to_frame: bool = true
var header_template: bool = false
var livery: Dictionary = {}
var customisation: Dictionary = {}
var condition: Dictionary = {}
var _live: Control
var _empty_view: SubViewport
var _image: TextureRect
var _refreshing: bool = false
var presentation_ready: bool:
	get: return _live.presentation_ready if is_instance_valid(_live) else is_instance_valid(_image)
var viewport: SubViewport:
	get: return _live.viewport if is_instance_valid(_live) else _empty_view
var car: Node3D:
	get: return _live.car if is_instance_valid(_live) else null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_view = SubViewport.new()
	_empty_view.transparent_bg = true
	_empty_view.msaa_3d = Viewport.MSAA_4X
	_empty_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_empty_view)
	resized.connect(_refresh)
	get_viewport().size_changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	# Existing containers assign the exact target after the child enters the tree.
	_refreshing = true
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion(): return
	_refreshing = false
	_refresh()

func _dimensions() -> Vector2i:
	var screen: Transform2D = get_viewport().get_stretch_transform()*get_screen_transform()
	var dimensions: Vector2 = size*Vector2(screen.x.length(),screen.y.length())*2.0
	dimensions *= minf(1.0,minf(1536.0/maxf(dimensions.x,1.0),768.0/maxf(dimensions.y,1.0)))
	return Vector2i(maxi(1,roundi(dimensions.x)),maxi(1,roundi(dimensions.y)))

func _refresh() -> void:
	if _refreshing or not is_inside_tree(): return
	if is_instance_valid(_live):
		_live._refresh()
		return
	var dimensions: Vector2i = _dimensions()
	if is_instance_valid(_image) and _empty_view.size == dimensions: return
	_empty_view.size = dimensions
	var texture: ImageTexture = Pictures.read_picture(Pictures.identity(self,dimensions),dimensions)
	if texture == null:
		_build_live()
		return
	if not is_instance_valid(_image):
		_image = TextureRect.new()
		_image.name = "VictoryCarRender"
		_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var material := ShaderMaterial.new()
		material.shader = preload("res://ui/rivalry_car_composite.gdshader")
		material.set_shader_parameter("linear_resolve",RenderingServer.get_current_rendering_method() != "gl_compatibility")
		_image.material = material
		add_child(_image)
		MenuStyle.fill(_image)
	_image.texture = texture

func _build_live() -> void:
	_refreshing = true
	_live = load("res://ui/rivalry_victory_car.gd").new()
	_live.name = "NativePodium"
	for field: String in ["vehicle_id","simple_model","podium_presentation","fit_to_frame","header_template","livery","customisation","condition"]: _live.set(field,get(field))
	_live.reuse_picture = true
	add_child(_live)
	MenuStyle.fill(_live)
	if is_instance_valid(_image):
		_image.queue_free()
		_image = null
	_empty_view.queue_free()
	_empty_view = null
	_refreshing = false

func picture_texture() -> Texture2D:
	return _live.viewport.get_texture() if is_instance_valid(_live) else _image.texture if is_instance_valid(_image) else null

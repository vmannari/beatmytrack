extends Control
## Offline masks of the actual models; no temporary 3D world or per-frame script.
const Art = preload("res://ui/rivalry_loading_visual.gd")
var vehicle_id: String = "compact":
	set(value):
		vehicle_id = VehicleCatalog.valid_id(value)
		if is_instance_valid(_mask):
			_mask.vehicle_id = vehicle_id
			_mask.queue_redraw()
var _mask: Control
var compact: bool = false
var _caption: Label

class Mask extends Control:
	var vehicle_id: String = "compact"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var finish := ShaderMaterial.new()
		finish.shader = preload("res://ui/garage_loading_car.gdshader")
		finish.set_shader_parameter("atlas_columns",float(Art.CAR_IDS.size()))
		material = finish
		resized.connect(queue_redraw)
		set_process(false)
	func _draw() -> void:
		if size.x <= 0 or size.y <= 0: return
		var index: int = maxi(0,Art.CAR_IDS.find(vehicle_id))
		var width: float = minf(size.x*0.86,size.y*1.85)
		var dimensions := Vector2(width,width/1.5)
		draw_texture_rect_region(Art.SILHOUETTES,Rect2((size-dimensions)*0.5,dimensions),Rect2(Vector2(index*Art.TILE.x,0),Art.TILE))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var background := ColorRect.new()
	background.name = "LoadingAtmosphere"
	var atmosphere := ShaderMaterial.new()
	atmosphere.shader = preload("res://ui/garage_loading_car.gdshader")
	atmosphere.set_shader_parameter("backdrop",true)
	atmosphere.set_shader_parameter("compact_preview",compact)
	background.material = atmosphere
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	MenuStyle.fill(background)
	_mask = Mask.new()
	_mask.name = "LoadingCarMask"
	_mask.vehicle_id = vehicle_id
	add_child(_mask)
	MenuStyle.fill(_mask)
	_mask.offset_top = 3 if compact else 60
	_mask.offset_bottom = -58 if compact else -70
	_caption = MenuStyle.label("Loading preview…",14 if compact else 19)
	_caption.name = "LoadingCaption"
	GameText.bind(_caption,"Loading preview…")
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.add_theme_color_override("font_color",Color("a8cdd6"))
	_caption.add_theme_color_override("font_shadow_color",Color(0,0,0,0.45))
	_caption.add_theme_constant_override("shadow_offset_y",1)
	add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_left = 12
	_caption.offset_right = -12
	_caption.offset_top = -63 if compact else -58
	_caption.offset_bottom = -41 if compact else -28
	set_process(false)

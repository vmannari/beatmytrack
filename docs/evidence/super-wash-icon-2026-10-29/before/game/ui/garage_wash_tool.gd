extends Button
## A real button with transparent tool photography, accessible name and focus.
const Studio = preload("res://ui/garage_studio_style.gd")
var photo: TextureRect
var title: Label
var detail: Label
var marker: TextureRect
var _motion: Tween

static func make(tool: String, action: Callable) -> Button:
	var tile := preload("res://ui/garage_wash_tool.gd").new()
	tile.name = "GarageSuperWash" if tool == "super" else "GarageWashHose" if tool == "hose" else "GarageWashMitt"
	tile.tooltip_text = "Super Wash" if tool == "super" else "Hose · Rinse fine dust; wash heavy dirt slowly" if tool == "hose" else "Wash mitt · Scrub stubborn dirt"
	tile.accessibility_name = "Super Wash" if tool == "super" else "Hose" if tool == "hose" else "Wash mitt"
	tile.toggle_mode = tool != "super"
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.set_meta("audio_cue","select")
	tile.pressed.connect(action)
	tile.photo = TextureRect.new()
	tile.photo.name = "ToolPicture"
	tile.photo.texture = preload("res://ui/garage_mode_icons.gd").texture("care") if tool == "super" else load("res://assets/menu/garage/"+tool+"-v1.png")
	if tool == "super": tile.photo.modulate = MenuStyle.ACCENT
	tile.photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tile.photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(tile.photo)
	MenuStyle.fill(tile.photo)
	tile.photo.offset_left = 14
	tile.photo.offset_right = -14
	tile.photo.offset_top = 10
	tile.photo.offset_bottom = -52
	tile.title = MenuStyle.label("Super Wash" if tool == "super" else "Hose" if tool == "hose" else "Wash mitt",22)
	tile.title.add_theme_font_override("font",MenuStyle.DISPLAY)
	tile.add_child(tile.title)
	tile.title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tile.title.offset_left = 12
	tile.title.offset_right = -12
	tile.title.offset_top = -51
	tile.title.offset_bottom = -26
	tile.detail = MenuStyle.label("" if tool == "super" else "RINSE" if tool == "hose" else "DEEP CLEAN",11,true)
	tile.detail.add_theme_constant_override("outline_size",0)
	tile.add_child(tile.detail)
	tile.detail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tile.detail.offset_left = 12
	tile.detail.offset_top = -26
	tile.detail.offset_bottom = -9
	tile.marker = TextureRect.new()
	tile.marker.texture = MenuIcon.texture("check")
	tile.marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.marker.modulate = MenuStyle.ACCENT
	tile.marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(tile.marker)
	tile.marker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tile.marker.offset_left = -25
	tile.marker.offset_right = -9
	tile.marker.offset_top = 9
	tile.marker.offset_bottom = 25
	tile.toggled.connect(tile._selection)
	tile.mouse_entered.connect(tile._hover.bind(true))
	tile.mouse_exited.connect(tile._hover.bind(false))
	tile.resized.connect(tile._resize_photo)
	tile._selection(false)
	return tile

func _selection(selected: bool) -> void:
	Studio.tile(self,selected)
	marker.visible = selected
	title.add_theme_color_override("font_color",MenuStyle.ACCENT if selected else MenuStyle.TEXT)

func sync_selection(selected: bool) -> void:
	set_pressed_no_signal(selected)
	_selection(selected)

func _resize_photo() -> void:
	photo.pivot_offset = photo.size*0.5
	var available: float = maxf(1.0,size.x-title.offset_left+title.offset_right)
	var font: Font = title.get_theme_font("font")
	var font_size: int = 22
	while font_size > 14 and font.get_string_size(GameText.message(title.text),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > available:
		font_size -= 1
	title.add_theme_font_size_override("font_size",font_size)

func _hover(active: bool) -> void:
	if _motion != null: _motion.kill()
	_motion = create_tween()
	_motion.tween_property(photo,"scale",Vector2.ONE*(1.045 if active else 1.0),0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

class_name LiveryTile
extends Button
## A static native-model photograph, readable name and quiet selection frame.
var selected: bool = false
var marker: TextureRect
var _selection_ready: bool = false

static func make(title: String, texture: Texture2D, action: Callable, compact: bool = false) -> LiveryTile:
	var tile := LiveryTile.new()
	tile.custom_minimum_size = Vector2(134,106 if not compact else 100)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.pressed.connect(action)
	tile.tooltip_text = title
	tile.set_meta("audio_cue","select")
	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_theme_constant_override("margin_left",8)
	inset.add_theme_constant_override("margin_right",8)
	inset.add_theme_constant_override("margin_top",6)
	inset.add_theme_constant_override("margin_bottom",6)
	tile.add_child(inset)
	MenuStyle.fill(inset)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation",2)
	inset.add_child(stack)
	var photo := TextureRect.new()
	photo.name = "LiveryModelPreview"
	photo.texture = texture
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stack.add_child(photo)
	var label: Label = MenuStyle.label(title,17)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",MenuStyle.DISPLAY)
	if compact:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 2
		label.custom_minimum_size.y = 30
	stack.add_child(label)
	tile.marker = TextureRect.new()
	tile.marker.texture = MenuIcon.texture("check")
	tile.marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.marker.modulate = MenuStyle.ACCENT
	tile.marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(tile.marker)
	tile.marker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tile.marker.offset_left = -24
	tile.marker.offset_right = -8
	tile.marker.offset_top = 8
	tile.marker.offset_bottom = 24
	tile.set_selected(false)
	return tile

func set_selected(value: bool) -> void:
	if _selection_ready and selected==value: return
	_selection_ready = true
	selected = value
	marker.visible = value
	for state: String in ["normal","hover","pressed","focus"]:
		var style := MenuStyle.box(Color("182d39") if value or state == "hover" else Color("0b1823"),4)
		style.set_corner_radius_all(10)
		style.border_color = MenuStyle.ACCENT if value or state == "focus" else Color("496474") if state == "hover" else Color("29404e")
		style.set_border_width_all(2 if value or state == "focus" else 1)
		add_theme_stylebox_override(state,style)

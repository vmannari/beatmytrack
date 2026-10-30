extends RefCounted
## Shared biome presentation using the existing authored menu glyphs.
static func icon(theme_id: String) -> String:
	return {"pine":"leaf","desert":"cactus","winter":"snowflake","night_city":"night","storm":"storm"}.get(theme_id,"leaf")

static func color(theme_id: String) -> Color:
	return Color({"pine":"7fe098","desert":"f2bf76","winter":"9cdeff","night_city":"c6b3ff","storm":"a5bbff"}.get(theme_id,"7fe098"))

static func view(theme_id: String, font_size: int = 16) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := MenuStyle.box(Color("0b202be8"),4)
	style.content_margin_left = 7
	style.content_margin_right = 7
	badge.add_theme_stylebox_override("panel",style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",6)
	badge.add_child(row)
	var glyph := TextureRect.new()
	glyph.texture = MenuIcon.texture(icon(theme_id))
	glyph.modulate = color(theme_id)
	glyph.custom_minimum_size = Vector2(font_size,font_size)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var label := MenuStyle.label(TrackTheme.title(theme_id).to_upper(),font_size)
	label.add_theme_color_override("font_color",color(theme_id))
	row.add_child(label)
	return badge

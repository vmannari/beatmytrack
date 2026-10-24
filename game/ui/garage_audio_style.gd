extends RefCounted
## Original vector hardware shared by the listening controls; no raster downloads.
static var textures: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if textures.has(kind): return textures[kind]
	var art: String
	match kind:
		"knob", "knob_hover", "knob_disabled":
			var rim: String = "dfbc72" if kind == "knob_hover" else "91a0a4"
			art = "<defs><linearGradient id='rim' x2='.8' y2='1'><stop stop-color='#d0d7d6'/><stop offset='.48' stop-color='#59666b'/><stop offset='1' stop-color='#19252c'/></linearGradient><linearGradient id='face' x2='1' y2='1'><stop stop-color='#8c9799'/><stop offset='.42' stop-color='#36434a'/><stop offset='.7' stop-color='#1c2930'/><stop offset='1' stop-color='#647175'/></linearGradient></defs><circle cx='20' cy='22' r='16' fill='#030a0e' fill-opacity='.7'/><circle cx='20' cy='20' r='16' fill='url(#rim)' stroke='#%s'/><circle cx='20' cy='20' r='13' fill='url(#face)' stroke='#142028'/><path d='M12 10L16 15' stroke='#eee6cd' stroke-width='2.2' stroke-linecap='round'/><path d='M10 25A12 12 0 0 1 25 9' fill='none' stroke='#b7c3c4' stroke-opacity='.25'/>" % rim
		"play": art = "<path d='M14 10L30 20L14 30Z' fill='#edf1ee'/>"
		"pause", "stop": art = "<rect x='13' y='11' width='5' height='18' rx='1' fill='#edf1ee'/><rect x='23' y='11' width='5' height='18' rx='1' fill='#edf1ee'/>"
		"skip_previous": art = "<path d='M27 11L15 20L27 29Z' fill='#edf1ee'/><rect x='10' y='11' width='3' height='18' rx='1' fill='#edf1ee'/>"
		"skip_next": art = "<path d='M13 11L25 20L13 29Z' fill='#edf1ee'/><rect x='27' y='11' width='3' height='18' rx='1' fill='#edf1ee'/>"
		"previous": art = "<path d='M24 12L16 20L24 28' fill='none' stroke='#d5dfe0' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'/>"
		"next": art = "<path d='M16 12L24 20L16 28' fill='none' stroke='#d5dfe0' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'/>"
		"speaker": art = "<path d='M6 16H12L21 9V31L12 24H6Z' fill='#bac7ca'/><path d='M26 14Q32 20 26 26M30 9Q40 20 30 31' fill='none' stroke='#bac7ca' stroke-width='2' stroke-linecap='round'/>"
		_: art = "<path d='M20 16V23' stroke='#576d78' stroke-width='1.4'/>"
	var bitmap := Image.new()
	bitmap.load_svg_from_string("<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>"+art+"</svg>")
	bitmap.generate_mipmaps()
	var result := ImageTexture.create_from_image(bitmap)
	textures[kind] = result
	return result

static func button(node: Button, round_control: bool = false, quiet: bool = false) -> void:
	node.custom_minimum_size = Vector2(60,60) if round_control else Vector2(52,52)
	node.expand_icon = true
	node.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_constant_override("icon_max_width",32)
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var box := MenuStyle.box(Color("24343c") if state == "hover" else Color.TRANSPARENT if quiet else Color("14232b"),8)
		box.set_corner_radius_all(30 if round_control else 8)
		box.border_color = Color("c1ad7e") if round_control and state == "hover" else Color("82979f") if round_control else Color("293d47")
		box.set_border_width_all(1 if round_control else 0)
		if round_control and state == "normal":
			box.shadow_color = Color(0,0,0,0.4)
			box.shadow_size = 3
			box.shadow_offset = Vector2(0,2)
		if state == "pressed": box.bg_color = Color("293b43")
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = MenuStyle.ACCENT
			box.set_border_width_all(2)
			box.set_expand_margin_all(-3)
		node.add_theme_stylebox_override(state,box)
	for state: String in ["icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color"]:
		node.add_theme_color_override(state,Color("e0e8e8"))
	node.add_theme_color_override("icon_disabled_color",Color("43545e"))

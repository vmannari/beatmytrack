extends Button
## Focusable native competition diagrams; no illustration textures.
var format_id: String = "duel"
var caption: String = "Head to head"
var description: PackedStringArray = ["One rival. Your time to beat."]
var audience: String = "You + one rival"
var tries: String = "Unlimited tries"
var chosen: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2(180,260)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	text = caption
	for state: String in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_disabled_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	add_theme_font_size_override("font_size",1)
	set_meta("audio_cue","select")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	refresh()

func refresh() -> void:
	tooltip_text = caption+". "+" ".join(description)+" "+audience+". "+tries
	var style := MenuStyle.box(Color("172c36") if chosen else Color("10232f"),0)
	style.set_corner_radius_all(0)
	style.border_color = MenuStyle.ACCENT if chosen else Color("3b5462")
	style.set_border_width_all(2 if chosen else 1)
	add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("1c3540")
	hover.border_color = MenuStyle.ACCENT if chosen else Color("9bb4be")
	add_theme_stylebox_override("hover",hover)
	add_theme_stylebox_override("pressed",hover)
	var inactive := style.duplicate() as StyleBoxFlat
	inactive.bg_color = Color("13232d")
	add_theme_stylebox_override("disabled",inactive)
	button_pressed = chosen
	queue_redraw()

func artwork_rect() -> Rect2:
	return Rect2(1,1,size.x-2,maxf(92,size.y-2))

func _draw() -> void:
	var inset: float = 19 if size.x >= 250 else 15
	var tint := Color(1,1,1,0.45 if disabled else 1.0)
	var art: Rect2 = artwork_rect()
	draw_rect(art,Color("10202b"))
	ChallengeGraphic.draw_design(self,Rect2(10,40,size.x-20,maxf(48,size.y-122)),format_id,MenuStyle.ACCENT,tint)
	var index: int = ["duel","group","three"].find(format_id)+1
	draw_string(MenuStyle.DISPLAY,Vector2(inset,25),"0"+str(index),HORIZONTAL_ALIGNMENT_LEFT,-1,15,MenuStyle.ACCENT*tint if chosen else Color("c3d0d5")*tint)
	var strip := Rect2(8,size.y-72,size.x-16,64)
	draw_rect(strip,MenuStyle.ACCENT if chosen else Color("091720f2"))
	var label_color: Color = MenuStyle.INK if chosen else MenuStyle.TEXT
	var title_width: float = MenuStyle.DISPLAY.get_string_size(caption.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,28).x
	draw_string(MenuStyle.DISPLAY,Vector2(maxf(20,(size.x-title_width)*0.5),size.y-31),caption.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,size.x-40,28,label_color*tint)
	if chosen:
		var marker := Vector2(size.x-21,21)
		draw_circle(marker,10,MenuStyle.ACCENT,true,-1,true)
		draw_texture_rect(MenuIcon.texture("check",true),Rect2(marker-Vector2(6,6),Vector2(12,12)),false,MenuStyle.INK)

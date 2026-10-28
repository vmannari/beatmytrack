extends Button
## Approved English artwork; other locales use the official G and Google Sans.
const ART: Texture2D = preload("res://assets/auth/google_sign_in_light.png")
const GOOGLE_G: Texture2D = preload("res://assets/auth/google_g.svg")
var _font: Font
var prominent: bool = false

func _ready() -> void:
	_font = GameFonts.face(GameFonts.GOOGLE,500)
	custom_minimum_size = Vector2(280, 60)
	tooltip_text = tr("Continue with Google" if prominent else "Sign in with Google")
	accessibility_name = tooltip_text
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	pressed.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		tooltip_text = tr("Continue with Google" if prominent else "Sign in with Google")
		accessibility_name = tooltip_text
		queue_redraw()

func _draw() -> void:
	if (prominent or not TranslationServer.get_locale().begins_with("en")) and _font != null:
		_draw_localized()
		return
	var factor: float = minf(size.x / ART.get_width(), size.y / ART.get_height())
	var extent: Vector2 = ART.get_size() * factor
	var box := Rect2((size - extent) * 0.5, extent)
	draw_texture_rect(ART, box, false)
	# State overlays preserve the unmodified logo, lettering and aspect ratio.
	if is_hovered() and not disabled: draw_rect(box, Color(0.24, 0.27, 0.30, 0.08))
	if is_pressed() and not disabled: draw_rect(box, Color(0.24, 0.27, 0.30, 0.10))

func _draw_localized() -> void:
	var caption: String = tr("Continue with Google" if prominent else "Sign in with Google")
	var font_size: int = 24 if prominent else 20
	while font_size > 14 and _font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+80 > size.x:
		font_size -= 1
	var text_width: float = _font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var width: float = size.x if prominent else minf(size.x,maxf(280,text_width+80))
	var height: float = minf(size.y,68 if prominent else 60)
	var box := Rect2((size-Vector2(width,height))*0.5,Vector2(width,height))
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color("747775")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8 if prominent else 4)
	draw_style_box(style,box)
	var group_width: float = 26+14+text_width
	var left: float = box.position.x+(width-group_width)*0.5
	draw_texture_rect(GOOGLE_G,Rect2(left,box.position.y+(height-26)*0.5,26,26),false)
	var baseline: float = box.position.y+(height-_font.get_height(font_size))*0.5+_font.get_ascent(font_size)
	draw_string(_font,Vector2(left+40,baseline),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("1f1f1f"))
	if is_hovered() and not disabled: draw_rect(box,Color(0.24,0.27,0.30,0.08))
	if is_pressed() and not disabled: draw_rect(box,Color(0.24,0.27,0.30,0.10))

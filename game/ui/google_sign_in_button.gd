extends Button
## Google's pre-approved artwork, uniformly scaled with original typography/logo.
const ART: Texture2D = preload("res://assets/auth/google_sign_in_light.png")

func _ready() -> void:
	custom_minimum_size = Vector2(280, 60)
	tooltip_text = "Sign in with Google"
	accessibility_name = "Sign in with Google"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	pressed.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _draw() -> void:
	var factor: float = minf(size.x / ART.get_width(), size.y / ART.get_height())
	var extent: Vector2 = ART.get_size() * factor
	var box := Rect2((size - extent) * 0.5, extent)
	draw_texture_rect(ART, box, false)
	# State overlays preserve the unmodified logo, lettering and aspect ratio.
	if is_hovered() and not disabled: draw_rect(box, Color(0.24, 0.27, 0.30, 0.08))
	if is_pressed() and not disabled: draw_rect(box, Color(0.24, 0.27, 0.30, 0.10))

extends Control
## Original sign-in scenery. No gameplay camera or simulation changes.
const ART: Texture2D = preload("res://assets/menu/sign_in_alpine_v1.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var factor: float = maxf(size.x / ART.get_width(), size.y / ART.get_height())
	var drawn: Vector2 = ART.get_size() * factor
	draw_texture_rect(ART, Rect2((size - drawn) * 0.5, drawn), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.08, 0.24))

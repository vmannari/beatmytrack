class_name MenuBrand
extends TextureRect
## Owner-supplied transparent logo; trim only empty outer pixels for menu sizing.

const LOGO = preload("res://assets/menu/logo.png")
var logo_scale: float = 1.0

func _ready() -> void:
	custom_minimum_size = Vector2(196,64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atlas := AtlasTexture.new()
	atlas.atlas = LOGO
	atlas.region = Rect2(41, 125, 1857, 576)
	var padding: Vector2 = atlas.region.size * (1.0 / logo_scale - 1.0)
	atlas.margin = Rect2(padding * 0.5, padding)
	texture = atlas
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

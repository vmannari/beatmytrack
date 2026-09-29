extends TextureRect
## Static screen-space ice, below the HUD and independent of simulation.

func _ready() -> void:
	name = "WinterFrost"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = preload("res://assets/textures/winter_frost_v1.png")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	modulate.a = 0.72
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

extends TrackTile
## Featured daily route using the existing authored biome artwork and exact feed geometry.
static var _shade: GradientTexture2D
var caption_height: float = 140

func _ready() -> void:
	super._ready()
	get_node("ToggleFavorite").hide()
	custom_minimum_size = Vector2(200,440)
	preview_only = true
	if _shade == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(0.025,0.06,0.085,0),Color(0.025,0.06,0.085,0.98)])
		_shade = GradientTexture2D.new()
		_shade.width = 8
		_shade.height = 256
		_shade.fill_from = Vector2(0.5,0)
		_shade.fill_to = Vector2(0.5,1)
		_shade.gradient = gradient

func reserve_caption(height: float) -> void:
	caption_height = height+12
	_projected_size = Vector2(-1,-1)
	queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2.ZERO,size)
	_draw_terrain(area)
	if _shade != null: draw_texture_rect(_shade,Rect2(0,size.y*0.42,size.x,size.y*0.58),false)
	# Keep the actual route above the title instead of laying text over its corners.
	_draw_route(Rect2(20,12,maxf(1,size.x-40),maxf(1,size.y-caption_height-12)))
	var frame: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,0)
	frame.set_corner_radius_all(10)
	frame.set_border_width_all(2 if has_focus() else 1)
	frame.border_color = MenuStyle.ACCENT if has_focus() else Color("81999d99") if is_hovered() else Color("455e6c")
	draw_style_box(frame,area)

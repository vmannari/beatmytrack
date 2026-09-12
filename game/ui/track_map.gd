class_name TrackMap
extends Control
## Read-only plan preview using the exact compiled surface grid.

var track: NativeTrack
var surface_texture: ImageTexture
var editable: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func show_track(value: NativeTrack) -> void:
	track = value
	if track == null: return
	var palette: Array[Color] = TrackTheme.palette(str(track.metadata.get("theme", "pine")))
	var raster := Image.create(track.grid_width, track.grid_height, false, Image.FORMAT_RGB8)
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			raster.set_pixel(x, y, palette[track.cells[y * track.grid_width + x]])
	surface_texture = ImageTexture.create_from_image(raster)
	queue_redraw()

func map_rect() -> Rect2:
	if track == null: return Rect2()
	var extent: Vector2 = track.half_extent * 2.0
	var factor: float = minf((size.x - 32) / extent.x, (size.y - 32) / extent.y)
	var target: Vector2 = extent * factor
	return Rect2((size - target) * 0.5, target)

func _draw() -> void:
	draw_style_box(MenuStyle.box(Color("202e35")), Rect2(Vector2.ZERO, size))
	if surface_texture == null: return
	var rect: Rect2 = map_rect()
	draw_texture_rect(surface_texture, rect, false)
	var factor: float = rect.size.x / (track.half_extent.x * 2.0)
	var start: Vector2 = rect.get_center() + Vector2(track.finish_center.x, -track.finish_center.y) * factor
	draw_circle(start, 6, Color("edf1f3"))
	draw_circle(start, 3, Color("172129"))

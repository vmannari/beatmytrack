class_name CircuitEmblem
extends Control

var track: NativeTrack
var surface_outline: ImageTexture

func _ready() -> void:
	custom_minimum_size = Vector2(150,100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	if track != null:
		var raster := Image.create(track.grid_width,track.grid_height,false,Image.FORMAT_RGBA8)
		for y: int in range(track.grid_height):
			for x: int in range(track.grid_width):
				var index: int = y*track.grid_width+x
				var kind: int = track.deck_cells[index] if track.deck_cells[index] >= 0 else track.cells[index]
				if kind in [0,2,5]: raster.set_pixel(x,y,MenuStyle.TEXT if kind == 0 else Color("77858a"))
		surface_outline = ImageTexture.create_from_image(raster)

func _draw() -> void:
	if surface_outline == null: return
	var factor: float = minf((size.x-16)/track.grid_width,(size.y-12)/track.grid_height)
	var extent := Vector2(track.grid_width,track.grid_height)*factor
	draw_texture_rect(surface_outline,Rect2((size-extent)*0.5,extent),false)

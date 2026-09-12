class_name CircuitEmblem
extends Control

var track: NativeTrack
var surface_outline: ImageTexture

func _ready() -> void:
	custom_minimum_size = Vector2(270,145)
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
	var factor: float = minf((size.x-24)/track.grid_width,108.0/track.grid_height)
	var extent := Vector2(track.grid_width,track.grid_height)*factor
	draw_texture_rect(surface_outline,Rect2(Vector2((size.x-extent.x)*0.5,0),extent),false)
	draw_string(MenuStyle.BODY,Vector2(0,137),str(track.metadata.get("theme","pine")).to_upper(),HORIZONTAL_ALIGNMENT_RIGHT,size.x,16,MenuStyle.MUTED)

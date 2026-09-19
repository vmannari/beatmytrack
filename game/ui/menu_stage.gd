class_name MenuStage
extends Control
## Static, original vehicle illustration. No scene, camera or simulation ownership.

# Retain the menu composition API; biome choice never changes the vehicle artwork.
var setting: String = "pine"
var garage: bool = false

var artwork: Texture2D
var vehicle_id: String = VehicleCatalog.selected
const BACKGROUND := Color("112734")


func _ready() -> void:
	artwork = VehicleCatalog.artwork(vehicle_id)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var source_size: Vector2 = artwork.get_size()
	# Preserve the complete illustration and its vertical framing on wide phones.
	# Cover would enlarge the vehicle and crop its roof or tyres at wide ratios.
	var scale_value: float = minf(size.x / source_size.x, size.y / source_size.y)
	if vehicle_id in ["pickup","kart"]: scale_value *= 0.80 if vehicle_id == "pickup" else 0.90
	var drawn_size: Vector2 = source_size * scale_value
	var origin := Vector2(0.0, (size.y - drawn_size.y) * 0.5)
	draw_texture_rect(artwork, Rect2(origin, drawn_size), false)
	if drawn_size.x < size.x:
		# Only the empty studio backdrop extends; the car is left of this blend.
		var left: float = drawn_size.x * (0.84 if vehicle_id == "pickup" else 0.72)
		var right: float = drawn_size.x
		var clear := Color(BACKGROUND, 0.0)
		draw_polygon(PackedVector2Array([
			Vector2(left, origin.y), Vector2(right, origin.y),
			Vector2(right, origin.y + drawn_size.y), Vector2(left, origin.y + drawn_size.y)
		]), PackedColorArray([clear, BACKGROUND, BACKGROUND, clear]))
	if vehicle_id in ["pickup","kart"]:
		# Blend the smaller long-body composition into the full-screen backdrop.
		var clear := Color(BACKGROUND,0.0)
		for edge: int in [0,1]:
			var y: float = origin.y if edge == 0 else origin.y + drawn_size.y
			var inner: float = y + (48.0 if edge == 0 else -48.0)
			draw_polygon(PackedVector2Array([Vector2(0,y),Vector2(drawn_size.x,y),Vector2(drawn_size.x,inner),Vector2(0,inner)]),PackedColorArray([BACKGROUND,BACKGROUND,clear,clear]))

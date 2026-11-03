extends Control
## Offline masks of the actual models; no temporary 3D world or per-frame script.
const Art = preload("res://ui/rivalry_loading_visual.gd")
var vehicle_id: String = "compact":
	set(value):
		vehicle_id = VehicleCatalog.valid_id(value)
		if is_instance_valid(_mask):
			_mask.vehicle_id = vehicle_id
			_mask.queue_redraw()
var _mask: Control

class Mask extends Control:
	var vehicle_id: String = "compact"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var finish := ShaderMaterial.new()
		finish.shader = preload("res://ui/garage_loading_car.gdshader")
		material = finish
		resized.connect(queue_redraw)
		set_process(false)
	func _draw() -> void:
		if size.x <= 0 or size.y <= 0: return
		var index: int = maxi(0,Art.CAR_IDS.find(vehicle_id))
		var width: float = minf(size.x*0.86,size.y*1.5*0.90)
		var dimensions := Vector2(width,width/1.5)
		draw_texture_rect_region(Art.SILHOUETTES,Rect2((size-dimensions)*0.5,dimensions),Rect2(Vector2(index*Art.TILE.x,0),Art.TILE))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var background := ColorRect.new()
	background.color = Color("142127")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	MenuStyle.fill(background)
	_mask = Mask.new()
	_mask.name = "LoadingCarMask"
	_mask.vehicle_id = vehicle_id
	add_child(_mask)
	MenuStyle.fill(_mask)
	set_process(false)

extends Control
## A lightweight selected-car picture; the studio factory is for Garage/baking.
var records: LocalRecords
var preview: TextureRect
var vehicle_id: String = ""
const CHANGE_SECONDS: float = 0.24
const MAX_BLEND_STEP: float = 1.0/30.0
var _outgoing: TextureRect
var _change: Tween
var _placeholder: TextureRect


func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visibility_changed.connect(_visibility_changed)
	resized.connect(_settle)
	refresh()

func refresh() -> void:
	if not is_inside_tree(): return
	var vehicle: String = VehicleCatalog.selected
	if preview == null:
		preview = _picture()
		preview.name = "ProfileCarPicture"
		add_child(preview)
		MenuStyle.fill(preview)
	if vehicle_id == vehicle and preview.texture == preload("res://ui/header_car_icons.gd").texture(vehicle,records): return
	vehicle_id = vehicle
	_sync_placeholder()
	if preview.texture != null and preload("res://ui/header_car_icons.gd").texture(vehicle_id,records) == null:
		# A previous account/design must not remain visible while a miss waits.
		_settle()
		return
	if preview.texture == null or not is_visible_in_tree():
		_settle()
	elif _change == null:
		_change_picture()
	# Coalesce rapid selections until the current blend completes. Only the
	# latest requested car follows it, keeping two pictures in the same fixed slot.

func _picture() -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func _change_picture() -> void:
	var target: Texture2D = preload("res://ui/header_car_icons.gd").texture(vehicle_id,records)
	if preview.texture == target: return
	_outgoing = _picture()
	_outgoing.name = "PreviousProfileCarPicture"
	_outgoing.texture = preview.texture
	add_child(_outgoing)
	move_child(_outgoing,0)
	MenuStyle.fill(_outgoing)
	preview.texture = target
	preview.modulate.a = 0.0
	MenuStyle.fill(preview)
	_change = create_tween().set_parallel(true)
	_change.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_change.tween_property(_outgoing,"modulate:a",0.0,CHANGE_SECONDS)
	_change.tween_property(preview,"modulate:a",1.0,CHANGE_SECONDS)
	_change.finished.connect(_change_finished)
	# A slow appearance/driver frame must not spend the whole visible fade.
	# Step the paused tween once per UI frame, retaining the normal 0.24s pace.
	_change.pause()
	set_process(true)

func _process(delta: float) -> void:
	if _change != null: _change.custom_step(minf(delta,MAX_BLEND_STEP))

func _clear_outgoing() -> void:
	if is_instance_valid(_outgoing):
		remove_child(_outgoing)
		_outgoing.queue_free()
	_outgoing = null

func _change_finished() -> void:
	set_process(false)
	_change = null
	_clear_outgoing()
	preview.modulate = Color.WHITE
	MenuStyle.fill(preview)
	if is_visible_in_tree(): _change_picture()
	else: _settle()

func _settle() -> void:
	set_process(false)
	if _change != null: _change.kill()
	_change = null
	_clear_outgoing()
	if not is_instance_valid(preview): return
	preview.modulate = Color.WHITE
	# Reset every offset. Moving an anchored picture back to zero can preserve
	# a size from its previous parent while this retained widget is reattached.
	MenuStyle.fill(preview)
	if not vehicle_id.is_empty(): preview.texture = preload("res://ui/header_car_icons.gd").texture(vehicle_id,records)
	_sync_placeholder()

func _sync_placeholder() -> void:
	var missing: bool = not vehicle_id.is_empty() and preload("res://ui/header_car_icons.gd").texture(vehicle_id,records) == null
	if missing and _placeholder == null:
		_placeholder = _picture()
		_placeholder.name = "HeaderCarLoadingSilhouette"
		_placeholder.modulate = Color("8399a5")
		add_child(_placeholder)
		move_child(_placeholder,0)
		MenuStyle.fill(_placeholder)
	if _placeholder == null: return
	_placeholder.visible = missing
	if not missing: return
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://assets/menu/rivalry_loading_cars_v1.png")
	texture.region = Rect2(Vector2(maxi(0,VehicleCatalog.IDS.find(vehicle_id))*384,0),Vector2(384,256))
	_placeholder.texture = texture

func _visibility_changed() -> void:
	if not is_visible_in_tree(): _settle()

func _exit_tree() -> void:
	_settle()

static func make_preview(vehicle: String, paint: Dictionary, parts: Dictionary) -> Control:
	return load("res://ui/profile_car_renderer.gd").make_preview(vehicle,paint,parts)

static func apply_presentation(view: Control) -> void:
	load("res://ui/profile_car_renderer.gd").apply_presentation(view)

static func repaint_preview(view: Control, paint: Dictionary) -> void:
	load("res://ui/profile_car_renderer.gd").repaint_preview(view,paint)

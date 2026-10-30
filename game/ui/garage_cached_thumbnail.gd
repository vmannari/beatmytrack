extends "res://ui/car_showroom.gd"
## A photograph of this exact native preview; the interactive Garage stays live.
var preview_service: Node
var preview_key: String = ""
var displayed_key: String = ""
var _image: TextureRect
var _placeholder: CenterContainer

func _ready() -> void:
	read_only = true
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_image)
	MenuStyle.fill(_image)
	_placeholder = CenterContainer.new()
	_placeholder.name = "PreviewLoading"
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_placeholder)
	MenuStyle.fill(_placeholder)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	_placeholder.add_child(column)
	var emblem := TextureRect.new()
	emblem.texture = preload("res://ui/garage_mode_icons.gd").texture("cars")
	emblem.custom_minimum_size = Vector2(28,28)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.modulate = MenuStyle.MUTED
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(emblem)
	var caption: Label = MenuStyle.label("Loading preview…",16,true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	set_process(false)
	refresh_thumbnail()

func refresh_thumbnail() -> void:
	if _image == null or preview_service == null: return
	var key: String = preview_service.identity(self)
	if key == preview_key:
		if displayed_key!=key and preview_service.has_method("_remembered"):
			var ready: Texture2D=preview_service._remembered(vehicle_id,key)
			if ready!=null: publish_preview(key,ready)
		return
	preview_key = key
	# A picture of a different finish must never stand in for the saved car.
	# Exact stock, prepared and cached pictures publish through the same guard.
	displayed_key = ""
	_image.texture = null
	_placeholder.show()
	preview_service.request(self)

func publish_preview(key: String, value: Texture2D) -> void:
	if key == preview_key and _image != null and value != null:
		_image.texture = value
		displayed_key = key
		_placeholder.hide()

func apply_livery(value: Dictionary, _animate_paint: bool = false) -> void:
	livery = value.duplicate(true)
	refresh_thumbnail()

func apply_customisation(value: Dictionary, _animate_kit: bool = false) -> void:
	customisation = value.duplicate(true)
	refresh_thumbnail()

func _exit_tree() -> void: pass

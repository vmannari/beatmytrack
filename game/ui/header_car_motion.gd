extends Node
## Animate the native menu; shared 2D pictures handle its brief exit.
const OPEN_SECONDS: float = 0.22
const CLOSE_SECONDS: float = 0.15
var popup: PopupMenu
var tint: CanvasModulate
var tween: Tween
var exit_layer: CanvasLayer
var exit_image: Control
var has_frame: bool = false
var progress: float = 1.0

func _ready() -> void:
	name = "HeaderCarMotion"
	tint = CanvasModulate.new()
	popup.add_child(tint)
	popup.about_to_popup.connect(_opening)
	popup.popup_hide.connect(_closing)
	get_parent().visibility_changed.connect(_owner_visibility_changed)
	get_viewport().size_changed.connect(_reset)

func _opening() -> void:
	_reset()
	_apply_open(0.0)
	RenderingServer.frame_post_draw.connect(_frame_drawn,CONNECT_ONE_SHOT)
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_apply_open,0.0,1.0,OPEN_SECONDS)
	tween.finished.connect(_open_finished)

func _apply_open(value: float) -> void:
	progress = value
	var scale := Vector2(lerpf(0.985,1.0,value),lerpf(0.96,1.0,value))
	popup.canvas_transform = Transform2D(Vector2(scale.x,0),Vector2(0,scale.y),Vector2(popup.size.x*(1.0-scale.x)*0.5,-10.0*(1.0-value)))
	tint.color = Color(1,1,1,value)

func _open_finished() -> void:
	tween = null
	_apply_open(1.0)

func _frame_drawn() -> void:
	has_frame = popup.visible

func _closing() -> void:
	_stop_tween()
	if not get_parent().is_visible_in_tree() or not has_frame or not popup.is_embedded() or DisplayServer.get_name() == "headless":
		_reset()
		return
	# Recreate only the small 2D menu using its existing textures and labels.
	# Capturing the containing viewport would stall the GPU on every close.
	exit_layer = CanvasLayer.new()
	exit_layer.name = "HeaderCarExit"
	exit_layer.layer = 100
	add_child(exit_layer)
	exit_image = PanelContainer.new()
	exit_image.add_theme_stylebox_override("panel",popup.get_theme_stylebox("panel"))
	exit_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exit_image.position = Vector2(popup.position)
	exit_image.size = Vector2(popup.size)
	exit_image.pivot_offset = Vector2(exit_image.size.x*0.5,0)
	exit_layer.add_child(exit_image)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation",0)
	exit_image.add_child(rows)
	var panel: StyleBox = popup.get_theme_stylebox("panel")
	var row_height: float = (popup.size.y-panel.get_minimum_size().y)/maxi(1,popup.item_count)
	for index: int in range(popup.item_count):
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.custom_minimum_size.y = row_height
		var selected: bool = index == popup.get_focused_item()
		var style: StyleBox = popup.get_theme_stylebox("hover").duplicate() if selected else StyleBoxEmpty.new()
		for side: int in range(4): style.set_content_margin(side,0)
		row.add_theme_stylebox_override("panel",style)
		rows.add_child(row)
		var group := HBoxContainer.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_theme_constant_override("separation",popup.get_theme_constant("h_separation"))
		row.add_child(group)
		var picture := TextureRect.new()
		picture.texture = popup.get_item_icon(index)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(88,56)
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(picture)
		var label := Label.new()
		label.text = popup.tr(popup.get_item_text(index))
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.add_theme_font_override("font",popup.get_theme_font("font"))
		label.add_theme_font_size_override("font_size",popup.get_theme_font_size("font_size"))
		label.add_theme_color_override("font_color",popup.get_theme_color("font_hover_color" if selected else "font_color"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(label)
	tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(exit_image,"modulate:a",0.0,CLOSE_SECONDS)
	tween.tween_property(exit_image,"position:y",exit_image.position.y-8.0,CLOSE_SECONDS)
	tween.tween_property(exit_image,"scale",Vector2(0.985,0.96),CLOSE_SECONDS)
	tween.finished.connect(_reset)

func _stop_tween() -> void:
	if tween != null: tween.kill()
	tween = null

func _reset() -> void:
	_stop_tween()
	if RenderingServer.frame_post_draw.is_connected(_frame_drawn): RenderingServer.frame_post_draw.disconnect(_frame_drawn)
	if is_instance_valid(exit_layer):
		remove_child(exit_layer)
		exit_layer.queue_free()
	exit_layer = null
	exit_image = null
	has_frame = false
	if is_instance_valid(popup): popup.canvas_transform = Transform2D.IDENTITY
	if is_instance_valid(tint): tint.color = Color.WHITE
	progress = 1.0

func _owner_visibility_changed() -> void:
	if get_parent().is_visible_in_tree(): return
	_reset()
	popup.hide()

func _exit_tree() -> void:
	_reset()
	if is_instance_valid(tint): tint.queue_free()

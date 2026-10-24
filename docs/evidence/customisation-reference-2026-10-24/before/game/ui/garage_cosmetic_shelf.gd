extends VBoxContainer
## One native photo and a bounded, snapping row of cosmetic choices.
const Swipe = preload("res://ui/track_carousel.gd")
var photo: TextureRect
var title: Label
var state: Label
var price: Label
var equip: Button
var cancel: Button
var scroll: ScrollContainer
var cards: GridContainer
var counter: Label
var _status_row: HBoxContainer
var _left: Button
var _right: Button
var detail_viewport: SubViewport
var _detail_camera: Camera3D
var _showroom: CarShowroom
var _category: String
var _model_state: Array = []

func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	photo = TextureRect.new()
	photo.name = "CosmeticDetailPhoto"
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	photo.custom_minimum_size.y = 64
	photo.clip_contents = true
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(photo)
	var information := HBoxContainer.new()
	information.add_theme_constant_override("separation",8)
	add_child(information)
	title = MenuStyle.label("",23)
	title.name = "CosmeticPreviewTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	information.add_child(title)
	price = MenuStyle.label("",17)
	price.add_theme_color_override("font_color",MenuStyle.ACCENT)
	information.add_child(price)
	_status_row = HBoxContainer.new()
	add_child(_status_row)
	state = MenuStyle.label("Equipped",14)
	state.name = "CosmeticPreviewState"
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.add_theme_color_override("font_color",MenuStyle.ACCENT)
	_status_row.add_child(state)
	counter = MenuStyle.label("",14,true)
	_status_row.add_child(counter)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	add_child(row)
	_left = _arrow("‹","Previous options",-1)
	row.add_child(_left)
	scroll = Swipe.new()
	scroll.name = "CosmeticCarousel"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 104
	scroll.follow_focus = true
	row.add_child(scroll)
	var holder := MarginContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	cards = GridContainer.new()
	cards.columns = 100
	cards.add_theme_constant_override("h_separation",8)
	holder.add_child(cards)
	_right = _arrow("›","Next options",1)
	row.add_child(_right)
	equip = MenuStyle.button("Equip",func() -> void: pass,true)
	equip.name = "CosmeticEquip"
	equip.custom_minimum_size.y = 52
	equip.add_theme_font_size_override("font_size",20)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation",8)
	add_child(action_row)
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(equip)
	cancel = MenuStyle.button("×",func() -> void: pass)
	cancel.name = "CosmeticCancelPreview"
	cancel.tooltip_text = "Cancel preview"
	cancel.accessibility_name = "Cancel preview"
	cancel.custom_minimum_size = Vector2(52,52)
	cancel.add_theme_font_size_override("font_size",26)
	action_row.add_child(cancel)
	resized.connect(_layout_cards)
	scroll.resized.connect(_layout_cards)
	visibility_changed.connect(_visibility_changed)

func _arrow(glyph: String, hint: String, direction: int) -> Button:
	var button: Button = MenuStyle.button(glyph,func() -> void: scroll.settle_cards(direction))
	button.name = "CarouselPrevious" if direction < 0 else "CarouselNext"
	button.tooltip_text = hint
	button.accessibility_name = hint
	button.custom_minimum_size = Vector2(52,104)
	button.add_theme_font_size_override("font_size",32)
	preload("res://ui/garage_studio_style.gd").tile(button,false,6)
	return button

func _layout_cards() -> void:
	if not is_inside_tree(): return
	var compact: bool = get_viewport_rect().size.y < 650
	# Short landscape screens retain the live car as the large preview.
	photo.visible = not compact
	_status_row.visible = not compact
	add_theme_constant_override("separation",4 if compact else 8)
	cancel.custom_minimum_size.y = 52
	var visible_cards: int = 3 if scroll.size.x >= 340 else 2
	var width: float = maxf(100.0,floorf((scroll.size.x-8.0*(visible_cards-1))/visible_cards))
	scroll.snap_stride = roundi(width)+8
	for card: Control in cards.get_children():
		card.custom_minimum_size = Vector2(width,104)
	if is_instance_valid(detail_viewport):
		detail_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if photo.visible and is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func reveal(card: Control) -> void:
	if not is_instance_valid(card) or not is_visible_in_tree() or card.get_parent()!=cards: return
	scroll._stop_snap()
	scroll.ensure_control_visible(card)

func _visibility_changed() -> void:
	if is_visible_in_tree():
		_layout_cards.call_deferred()
		return
	scroll._stop_snap()
	scroll.pointer = -2
	scroll.target = null
	if is_instance_valid(detail_viewport): detail_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func show_choice(texture: Texture2D, label: String, status: String, cost: String, index: int, total: int) -> void:
	photo.texture = texture
	title.text = label
	state.text = status
	price.text = cost
	counter.text = "%d / %d" % [index+1,total]
	equip.text = "Equipped" if status == "Equipped" else "Equip" if cost.is_empty() or cost == "Owned" else "Unlock & equip · "+cost
	equip.disabled = status == "Equipped"
	cancel.disabled = status == "Equipped"

func present_part(showroom: CarShowroom, category: String) -> void:
	_showroom = showroom
	_category = category
	if DisplayServer.get_name() == "headless" or not is_inside_tree(): return
	if detail_viewport == null:
		# Share the actual showroom world and car; one extra camera, no model copy.
		detail_viewport = SubViewport.new()
		detail_viewport.name = "SelectedPartDetail"
		detail_viewport.size = Vector2i(768,384)
		detail_viewport.msaa_3d = Viewport.MSAA_2X
		detail_viewport.gui_disable_input = true
		detail_viewport.world_3d = showroom.showroom_viewport.find_world_3d()
		add_child(detail_viewport)
		_detail_camera = Camera3D.new()
		_detail_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		detail_viewport.add_child(_detail_camera)
		_detail_camera.current = true
	photo.texture = detail_viewport.get_texture()
	_update_detail()

func _update_detail() -> void:
	var target: Vector3
	var direction: Vector3
	match _category:
		"hood":
			target = Vector3(0,1.0,-1.45)
			direction = Vector3(2,2.5,-3)
			_detail_camera.size = 1.05
		"aero":
			target = Vector3(0,1.39,1.84)
			direction = Vector3(3,0.95,3)
			_detail_camera.size = 1.65
		"rims":
			target = Vector3(0.83,0.37,-1.28)
			direction = Vector3(4,0.8,-0.8)
			_detail_camera.size = 0.95
		_:
			target = Vector3(0,0.45,0)
			direction = Vector3(3,1.1,-4)
			_detail_camera.size = 1.85
	var frame: Transform3D = _showroom.car.global_transform
	var world_target: Vector3 = frame*(target*HandlingConfig.BODY_SCALE)
	_detail_camera.look_at_from_position(world_target+frame.basis*direction,world_target)
	_detail_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_model_state = [frame,_showroom.customisation.duplicate(true)]
	detail_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if photo.visible and is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _process(_delta: float) -> void:
	if detail_viewport == null or not is_visible_in_tree() or not photo.visible or not is_instance_valid(_showroom): return
	if _model_state != [_showroom.car.global_transform,_showroom.customisation]: _update_detail()

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
var _information: HBoxContainer
var _choice_row: HBoxContainer
var _left: Button
var _right: Button
var detail_viewport: SubViewport
var _detail_camera: Camera3D
var _showroom: CarShowroom
var _category: String
var _model_state: Array = []
var _equipped: bool = true
var catalogue_mode: bool = false
var _laying_out: bool = false

func _init(catalogue: bool = false) -> void:
	catalogue_mode = catalogue
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
	photo.visible = not catalogue_mode
	_information = HBoxContainer.new()
	_information.add_theme_constant_override("separation",8)
	add_child(_information)
	title = MenuStyle.label("",22)
	title.add_theme_font_override("font",MenuStyle.DISPLAY)
	title.name = "CosmeticPreviewTitle"
	title.size_flags_horizontal = Control.SIZE_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_information.add_child(title)
	state = MenuStyle.label("Equipped",14)
	state.name = "CosmeticPreviewState"
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.add_theme_font_override("font",MenuStyle.DISPLAY)
	state.add_theme_color_override("font_color",MenuStyle.ACCENT)
	var badge: StyleBoxFlat = MenuStyle.box(Color("302912"),4)
	badge.set_corner_radius_all(3)
	state.add_theme_stylebox_override("normal",badge)
	_information.add_child(state)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_information.add_child(space)
	price = MenuStyle.label("",17)
	price.add_theme_font_override("font",MenuStyle.DISPLAY)
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_theme_color_override("font_color",MenuStyle.ACCENT)
	_information.add_child(price)
	_status_row = HBoxContainer.new()
	_status_row.hide()
	add_child(_status_row)
	counter = MenuStyle.label("",14,true)
	_status_row.add_child(counter)
	var divider := HSeparator.new()
	divider.visible = not catalogue_mode
	add_child(divider)
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation",4)
	add_child(_choice_row)
	if catalogue_mode:
		_choice_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		move_child(_choice_row,0)
	_left = _arrow("‹","Previous options",-1)
	_choice_row.add_child(_left)
	scroll = preload("res://ui/vertical_swipe_scroll.gd").new() if catalogue_mode else Swipe.new()
	scroll.name = "CosmeticCarousel"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if catalogue_mode else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if catalogue_mode else ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 0 if catalogue_mode else 104
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL if catalogue_mode else Control.SIZE_FILL
	scroll.follow_focus = true
	_choice_row.add_child(scroll)
	var holder := MarginContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	cards = GridContainer.new()
	cards.columns = 2 if catalogue_mode else 100
	cards.add_theme_constant_override("v_separation",10)
	cards.add_theme_constant_override("h_separation",8)
	holder.add_child(cards)
	_right = _arrow("›","Next options",1)
	_choice_row.add_child(_right)
	_left.visible = not catalogue_mode
	_right.visible = not catalogue_mode
	equip = MenuStyle.button("Equip",func() -> void: pass,true)
	equip.name = "CosmeticEquip"
	equip.custom_minimum_size.y = 52
	equip.add_theme_font_size_override("font_size",21)
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(equip)
	cancel = MenuStyle.button("Cancel preview",func() -> void: pass)
	cancel.name = "CosmeticCancelPreview"
	cancel.tooltip_text = "Cancel preview"
	cancel.accessibility_name = "Cancel preview"
	cancel.custom_minimum_size = Vector2(52,48)
	cancel.add_theme_font_size_override("font_size",17)
	for ink: String in ["normal","hover","pressed","disabled"]:
		cancel.add_theme_stylebox_override(ink,MenuStyle.box(Color.TRANSPARENT,0))
	cancel.add_theme_color_override("font_color",Color("83b5ca"))
	add_child(cancel)
	resized.connect(_layout_cards)
	scroll.resized.connect(_layout_cards)
	visibility_changed.connect(_visibility_changed)

func _arrow(glyph: String, hint: String, direction: int) -> Button:
	var button: Button = MenuStyle.button(glyph,func() -> void: scroll.settle_cards(direction))
	button.name = "CarouselPrevious" if direction < 0 else "CarouselNext"
	button.tooltip_text = hint
	button.accessibility_name = hint
	button.custom_minimum_size = Vector2(52,52)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",32)
	for ink: String in ["normal","disabled"]:
		button.add_theme_stylebox_override(ink,MenuStyle.box(Color.TRANSPARENT,0))
	button.add_theme_stylebox_override("hover",MenuStyle.box(Color("1a2b35"),0))
	return button

func _layout_cards() -> void:
	if not is_inside_tree() or _laying_out: return
	_laying_out = true
	if catalogue_mode:
		photo.hide()
		cards.columns = 2
		var compact: bool = get_viewport_rect().size.y < 650
		add_theme_constant_override("separation",2 if compact else 8)
		equip.custom_minimum_size.y = 48 if compact else 52
		var height: float = 156.0 if compact else 220.0
		for card: Control in cards.get_children():
			card.custom_minimum_size = Vector2(128,height)
			if card is CompactKitThumbnail: card.image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var caption: Label = card.get_node_or_null("KitOptionTitle")
			if caption != null: caption.add_theme_font_size_override("font_size",18)
		_laying_out = false
		return
	var compact: bool = get_viewport_rect().size.y < 650
	var short: bool = get_viewport_rect().size.y < 800
	# Keep the detail preview on short screens too; the removed footer makes room.
	photo.visible = true
	photo.custom_minimum_size.y = 64 if compact else 112 if short else 144
	title.custom_minimum_size.x = minf(title.get_theme_font("font").get_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+2,size.x*0.52)
	add_theme_constant_override("separation",2 if compact else 8 if short else 12)
	equip.custom_minimum_size.y = 48 if compact else 52
	cancel.custom_minimum_size.y = 48
	cancel.visible = not _equipped
	var visible_cards: int = 4 if size.x >= 460 else 3 if size.x >= 340 else 2
	var width: float = maxf(76.0,floorf((scroll.size.x-6.0*(visible_cards-1))/visible_cards))
	var card_height: float = 84 if compact else 112 if short else 122
	cards.add_theme_constant_override("h_separation",6)
	scroll.custom_minimum_size.y = card_height
	scroll.snap_stride = roundi(width)+6
	for card: Control in cards.get_children():
		card.custom_minimum_size = Vector2(width,card_height)
		var option_title: Label = card.get_node_or_null("KitOptionTitle")
		if option_title != null: option_title.add_theme_font_size_override("font_size",14 if width<84 else 16)
	if is_instance_valid(detail_viewport):
		detail_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if photo.visible and is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	_laying_out = false

func reveal(card: Control) -> void:
	if not is_instance_valid(card) or not is_visible_in_tree() or card.get_parent()!=cards: return
	if not catalogue_mode: scroll._stop_snap()
	scroll.ensure_control_visible(card)

func _visibility_changed() -> void:
	if is_visible_in_tree():
		_layout_cards.call_deferred()
		return
	if not catalogue_mode:
		scroll._stop_snap()
		scroll.pointer = -2
		scroll.target = null
	if is_instance_valid(detail_viewport): detail_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func show_choice(texture: Texture2D, label: String, status: String, cost: String, index: int, total: int) -> void:
	photo.texture = texture
	title.text = label.to_upper()
	_equipped = status == "Equipped"
	state.text = "PREVIEW"
	state.visible = not _equipped
	price.text = cost.to_upper()
	counter.text = "%d / %d" % [index+1,total]
	equip.text = "Equipped" if status == "Equipped" else "Equip" if cost.is_empty() or cost == "Owned" else "Unlock & equip · "+cost
	equip.disabled = _equipped
	equip.visible = not _equipped
	cancel.disabled = _equipped
	cancel.visible = not _equipped
	_layout_cards.call_deferred()

func present_part(showroom: CarShowroom, category: String) -> void:
	if catalogue_mode: return
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
	var frame: Transform3D = _showroom.car.global_transform
	preload("res://ui/garage_part_photos.gd").pose(_detail_camera,_category,frame)
	_model_state = [frame,_showroom.customisation.duplicate(true),_showroom.livery.duplicate(true)]
	detail_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if photo.visible and is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _process(_delta: float) -> void:
	if detail_viewport == null or not is_visible_in_tree() or not photo.visible or not is_instance_valid(_showroom): return
	if _model_state != [_showroom.car.global_transform,_showroom.customisation,_showroom.livery]: _update_detail()

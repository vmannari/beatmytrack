class_name GaragePage
extends Control
## Car discovery and selected-car tools share one local showroom.
signal vehicle_selected(index: int)
signal race_requested
signal circuit_requested
signal save_failed
signal account_requested
signal news_race_requested(story: Dictionary)
signal news_share_requested(story: Dictionary)

const Carousel = preload("res://ui/track_carousel.gd")
const RailIcons = preload("res://ui/garage_mode_icons.gd")
const LIVERY_NAMES: Array[String] = ["Midnight"]
const LIVERY_COLORS: Array[Array] = [["273b50", "ced7dc"]]
const MENU_MOVE_SECONDS: float = 0.32

var _layout: HBoxContainer
var _preview_slot: Control
var _rail_slot: Control
var _tools_slot: Control
var _actions_slot: Control
var _live_menus: Control
var _departing_menus: Control
var _parked_tools: Control
var _menu_motion: Tween
var _menu_weight: float = 1.0
var _menu_starts: Dictionary = {}
var _departures: Array[Dictionary] = []
var _gallery_departing: bool = false
var _layout_presented: bool = false

var records: LocalRecords
var news_client: Node
var economy: Node
var achievements: Node
var _achievement_button: Button
var _wash_achievement_pending: bool = false
var _coin_balance: Label
var _coin_status: Label
var _purchase_dialog: ConfirmationDialog
var showroom: CarShowroom
var draft: Dictionary
var pickers: Dictionary = {}
var vehicle_id: String = VehicleCatalog.selected
var _selected_vehicle_id: String = VehicleCatalog.selected
var circuit_title: String = ""
var wash_button: Button
var view_hint: Label
var _wash_status_panel: PanelContainer
var _wash_status: Label
var _wash_status_icon: TextureRect
var _wash_status_state: Array = []
var section: String = "cars"
var _car_menu_open: bool = false
var gallery: ScrollContainer
var gallery_slot: Control
var gallery_content: Control
var cards: HBoxContainer
var preview: Control
var heading: Label
var tools: VBoxContainer
var rail: VBoxContainer
var main: VBoxContainer
var tools_panel: PanelContainer
var actions: HBoxContainer
var select_button: Button
var thumbnails: Dictionary = {}
var tile_stride: int = 240
var _condition_saved: Dictionary = {}
var _condition_presented: Dictionary = {}
var _livery_saved: Dictionary = {}
var _presets: OptionButton
var kit_draft: Dictionary = {}
var kit_category: String = "hood"
var kit_cards: GridContainer
var kit_scroll: ScrollContainer
var kit_categories: Dictionary = {}
var _customise_tab: String = "livery"
var _sticker_surface: String = "hood"
var _sticker_board: StickerPlacement
var _sticker_choice: OptionButton
var _sticker_sliders: Dictionary = {}
var livery_menu: GarageLiveryMenu
var _retained_livery: GarageLiveryMenu
var _retained_livery_vehicle: String = ""
var customise_layout: HBoxContainer
var _colour_slot: String = "body"
var _sticker_values: Dictionary = {}
var _sticker_editing: bool = false
var records_menu: VBoxContainer
var record_browse_index: int = 0
var _cleanliness := GarageCleanliness.new()
var _customisation_locked: bool = false

func _ready() -> void:
	name = "GaragePage"
	clip_contents = true
	_layout = HBoxContainer.new()
	_layout.name = "GarageLayout"
	_layout.add_theme_constant_override("separation",12)
	add_child(_layout)
	MenuStyle.fill(_layout)
	_rail_slot = Control.new()
	_rail_slot.custom_minimum_size.x = 60
	_layout.add_child(_rail_slot)
	main = VBoxContainer.new()
	main.name = "GarageMain"
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	_layout.add_child(main)
	_preview_slot = Control.new()
	_preview_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_slot.custom_minimum_size.y = 250
	main.add_child(_preview_slot)
	_tools_slot = Control.new()
	main.add_child(_tools_slot)
	# The live viewport never leaves this parent when layout slots move.
	preview = Control.new()
	preview.name = "GaragePreview"
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size.y = 250
	preview.clip_contents = true
	add_child(preview)
	_live_menus = Control.new()
	_live_menus.name = "GarageLiveMenus"
	_live_menus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_live_menus)
	MenuStyle.fill(_live_menus)
	_departing_menus = Control.new()
	_departing_menus.name = "GarageDepartingMenus"
	_departing_menus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_departing_menus)
	MenuStyle.fill(_departing_menus)
	_parked_tools = Control.new()
	_parked_tools.name = "GarageRetainedTools"
	add_child(_parked_tools)
	_parked_tools.hide()
	_create_showroom()
	var shade := TextureRect.new()
	shade.name = "ShowroomHeaderShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.025,0.055,0.075,0.45), Color(0.025,0.055,0.075,0)])
	var shading := GradientTexture2D.new()
	shading.gradient = gradient
	shading.fill_from = Vector2(0,0)
	shading.fill_to = Vector2(0,1)
	shade.texture = shading
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 80
	heading = MenuStyle.label(VehicleCatalog.title(vehicle_id), 36)
	heading.name = "GarageCarTitle"
	preview.add_child(heading)
	heading.position = Vector2(24, 14)
	heading.size = Vector2(520, 46)
	_build_view_controls()
	_build_carousel()
	_actions_slot = Control.new()
	main.add_child(_actions_slot)
	_new_menu_panels()
	_show_section("cars")
	visibility_changed.connect(_visibility_changed)
	if economy != null:
		_coin_balance = MenuStyle.label("",22)
		_coin_balance.name = "GarageCoinBalance"
		_coin_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_coin_balance.add_theme_color_override("font_color",MenuStyle.ACCENT)
		preview.add_child(_coin_balance)
		_coin_balance.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_coin_balance.offset_left = -310
		_coin_balance.offset_right = -24
		_coin_balance.offset_top = 18
		_coin_balance.offset_bottom = 48
		_coin_status = MenuStyle.label("",13,true)
		_coin_status.name = "GarageCoinStatus"
		_coin_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_coin_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		preview.add_child(_coin_status)
		_coin_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_coin_status.offset_left = -370
		_coin_status.offset_right = -24
		_coin_status.offset_top = 49
		_coin_status.offset_bottom = 72
		economy.changed.connect(_shop_changed)
		_shop_changed()
		if is_visible_in_tree(): economy.refresh()

func _shop_changed() -> void:
	if economy == null or not is_instance_valid(_coin_balance): return
	_coin_balance.text = "%d coins" % economy.balance() if economy.authenticated() else "Sign in to earn coins"
	_coin_balance.tooltip_text = "Account coins" if economy.authenticated() else "Guests do not earn coins."
	_coin_status.text = economy.status
	_coin_status.tooltip_text = economy.status
	if is_instance_valid(_purchase_dialog) and _purchase_dialog.get_meta("scope","") != economy.scope: _purchase_dialog.hide()
	if is_instance_valid(_retained_livery): _retained_livery.refresh()
	if is_instance_valid(kit_cards) and section == "tuning":
		for card: Node in kit_cards.get_children():
			var id: String = "kit/compact/"+kit_category+"/"+str(card.name).trim_prefix("KitOption_")
			_shop_badge(card,id)

func _shop_badge(tile: Control, id: String) -> void:
	if economy == null: return
	var badge: Label = tile.get_node_or_null("CoinPrice") as Label
	if badge == null:
		badge = MenuStyle.label("",13)
		badge.name = "CoinPrice"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("normal",MenuStyle.box(Color("0b1823"),3))
		badge.position = Vector2(7,7)
		tile.add_child(badge)
	badge.text = economy.caption(id)
	badge.add_theme_color_override("font_color",MenuStyle.MUTED if economy.owns(id) else MenuStyle.ACCENT)

func _require_owned(id: String, title: String, apply: Callable) -> bool:
	if economy == null or economy.owns(id): return true
	if is_instance_valid(_purchase_dialog): return false
	var expected_car: String = vehicle_id
	var expected_section: String = section
	var expected_scope: String = economy.scope
	var price: int = economy.price(id)
	var dialog := ConfirmationDialog.new()
	_purchase_dialog = dialog
	dialog.name = "CosmeticPurchase"
	dialog.title = "Unlock "+title
	dialog.set_meta("scope",expected_scope)
	var affordable: bool = economy.balance() >= price
	dialog.dialog_text = "%s\n\nPrice: %d coins\nBalance: %d coins\n\n%s" % [title,price,economy.balance(),"Permanent unlock for every car." if id.begins_with("livery/") else "Permanent unlock for the Compact."]
	if not affordable: dialog.dialog_text += "\nComplete more races to earn coins."
	dialog.ok_button_text = "Buy · %d coins" % price
	dialog.get_ok_button().disabled = not affordable or economy.busy or not economy.pending.is_empty()
	if not economy.authenticated():
		dialog.dialog_text = "%s\n\nPrice: %d coins\n\nSign in to earn coins and unlock this item." % [title,price]
		dialog.ok_button_text = "Sign in"
		dialog.get_ok_button().disabled = false
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if not economy.authenticated():
			account_requested.emit()
			return
		var purchased: bool = await economy.purchase(id)
		if purchased and is_inside_tree() and is_visible_in_tree() and expected_car == vehicle_id and expected_section == section and expected_scope == economy.scope: apply.call())
	dialog.visibility_changed.connect(func() -> void:
		if dialog.visible: return
		if _purchase_dialog == dialog: _purchase_dialog = null
		dialog.queue_free())
	dialog.popup_centered(Vector2i(420,260))
	return false

func _new_menu_panels() -> void:
	rail = VBoxContainer.new()
	rail.name = "GarageModes"
	rail.add_theme_constant_override("separation",12)
	_live_menus.add_child(rail)
	tools_panel = PanelContainer.new()
	tools_panel.name = "GarageTools"
	tools_panel.add_theme_stylebox_override("panel",MenuStyle.card(12))
	_live_menus.add_child(tools_panel)
	tools = VBoxContainer.new()
	tools.add_theme_constant_override("separation",8)
	tools_panel.add_child(tools)
	actions = HBoxContainer.new()
	actions.name = "GarageActions"
	_live_menus.add_child(actions)
	for panel: Control in [rail,tools_panel,actions]:
		panel.minimum_size_changed.connect(_sync_menu_minimums)

func _sync_menu_minimums() -> void:
	_rail_slot.custom_minimum_size = rail.get_combined_minimum_size()
	_tools_slot.custom_minimum_size = tools_panel.get_combined_minimum_size() if tools_panel.visible else Vector2.ZERO
	_actions_slot.custom_minimum_size = actions.get_combined_minimum_size()
	custom_minimum_size = _layout.get_combined_minimum_size()

func _slot_rect(slot: Control) -> Rect2:
	return Rect2(get_global_transform().affine_inverse() * slot.global_position,slot.size)

func _set_panel_input(panel: Node, enabled: bool) -> void:
	if panel is Control:
		if enabled and panel.has_meta("garage_motion_mouse"):
			panel.mouse_filter = panel.get_meta("garage_motion_mouse")
			panel.focus_mode = panel.get_meta("garage_motion_focus")
			panel.remove_meta("garage_motion_mouse")
			panel.remove_meta("garage_motion_focus")
		elif not enabled and not panel.has_meta("garage_motion_mouse"):
			panel.set_meta("garage_motion_mouse",panel.mouse_filter)
			panel.set_meta("garage_motion_focus",panel.focus_mode)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.focus_mode = Control.FOCUS_NONE
	for child: Node in panel.get_children(): _set_panel_input(child,enabled)

func _clear_departures() -> void:
	for entry: Dictionary in _departures:
		var panel: Control = entry.panel
		if is_instance_valid(_retained_livery) and panel.is_ancestor_of(_retained_livery):
			_retained_livery.reparent(_parked_tools)
			_retained_livery.hide()
			_set_panel_input(_retained_livery,true)
		panel.get_parent().remove_child(panel)
		panel.queue_free()
	_departures.clear()

func _prepare_menu_move() -> void:
	if _menu_motion != null: _menu_motion.kill()
	_clear_departures()
	_menu_starts = {preview:preview.get_rect()}
	if gallery.visible: _menu_starts[gallery] = gallery.get_rect()
	for panel: Control in [rail,tools_panel,actions]:
		if panel.visible and _layout_presented and is_visible_in_tree():
			var start: Rect2 = panel.get_rect()
			var finish: Rect2 = start
			if panel == rail: finish.position.x = -start.size.x-16
			elif panel == tools_panel: finish.position.x = size.x+16
			else: finish.position.y = size.y+16
			panel.reparent(_departing_menus)
			_set_panel_input(panel,false)
			_departures.append({"panel":panel,"start":start,"finish":finish})
		else:
			if is_instance_valid(_retained_livery) and panel.is_ancestor_of(_retained_livery):
				_retained_livery.reparent(_parked_tools)
				_retained_livery.hide()
			panel.get_parent().remove_child(panel)
			panel.queue_free()
	_new_menu_panels()

func _start_menu_move() -> void:
	_sync_menu_minimums()
	_gallery_departing = section != "cars" and gallery.visible
	if section == "cars":
		gallery.show()
		_layout_gallery()
	if not _layout_presented or not is_visible_in_tree():
		_finish_menu_move()
		return
	_menu_weight = 0.0
	_menu_motion = create_tween()
	_menu_motion.tween_property(self,"_menu_weight",1.0,MENU_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_menu_motion.tween_callback(_finish_menu_move)

func _finish_menu_move() -> void:
	if _menu_motion != null: _menu_motion.kill()
	_menu_motion = null
	_menu_weight = 1.0
	_menu_starts.clear()
	_clear_departures()
	_gallery_departing = false
	gallery.visible = section == "cars"
	_present_menu_layout()

func _place_menu_panel(panel: Control, destination: Rect2, direction: String) -> void:
	var start: Rect2 = _menu_starts.get(panel,destination)
	var weight: float = _menu_weight
	if not _menu_starts.has(panel) and _menu_motion != null:
		# Clear the outgoing controls before the replacement crosses their path.
		weight = clampf((_menu_weight-0.3)/0.7,0.0,1.0)
		if direction == "left": start.position.x = -destination.size.x-16
		elif direction == "right": start.position.x = size.x+16
		else: start.position.y = size.y+16
	panel.position = start.position.lerp(destination.position,weight)
	panel.size = start.size.lerp(destination.size,weight)

func _present_menu_layout() -> void:
	if size.x <= 0 or main.size.x <= 0: return
	if preview.visible: _place_menu_panel(preview,_slot_rect(_preview_slot),"")
	_place_menu_panel(rail,_slot_rect(_rail_slot),"left")
	if tools_panel.visible: _place_menu_panel(tools_panel,_slot_rect(_tools_slot),"right")
	_place_menu_panel(actions,_slot_rect(_actions_slot),"bottom")
	if section == "cars":
		var target: Rect2 = _slot_rect(gallery_slot)
		target.position.x += (target.size.x-gallery.size.x)*0.5
		target.size = gallery.size
		_place_menu_panel(gallery,target,"bottom")
	elif _gallery_departing:
		var target: Rect2 = _menu_starts[gallery]
		target.position.y = size.y+16
		_place_menu_panel(gallery,target,"bottom")
	for entry: Dictionary in _departures:
		entry.panel.position = entry.start.position.lerp(entry.finish.position,minf(1.0,_menu_weight/0.45))
	_layout_presented = true

func _build_rail() -> void:
	for child: Node in rail.get_children():
		rail.remove_child(child)
		child.queue_free()
	var destinations: Array = [["cars", "Select car"], ["records", "Record player"], ["trophies", "Trophy wall"]] if not _car_menu_open else [["customise", "Customise"], ["care", "Care"], ["tuning", "Tuning"], ["records", "Record player"], ["trophies", "Trophy wall"]]
	destinations.append(["news","News"])
	rail.add_theme_constant_override("separation",8 if destinations.size() > 5 else 12)
	for entry: Array in destinations:
		var destination: String = entry[0]
		var active: bool = destination == section
		var button := MenuStyle.button("", _show_section.bind(destination), active)
		button.name = "Garage" + ("Browse" if destination == "cars" else destination.capitalize())
		button.icon = RailIcons.texture(destination)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("h_separation",0)
		button.add_theme_constant_override("icon_max_width",40)
		button.add_theme_color_override("icon_normal_color", MenuStyle.INK if active else MenuStyle.TEXT)
		button.add_theme_color_override("icon_focus_color", MenuStyle.INK if active else MenuStyle.TEXT)
		button.add_theme_color_override("icon_hover_color", MenuStyle.INK if active else Color.WHITE)
		button.add_theme_color_override("icon_pressed_color", MenuStyle.INK)
		# Every state reserves the same box. Native Button layout must not add
		# text spacing or let different icon/padding minimums widen the rail.
		for state: String in ["normal","hover","pressed","disabled","focus"]:
			var color: Color = MenuStyle.ACCENT if active else Color("10212c")
			var border: Color = Color("ffe792") if active else Color("2a4655")
			if state == "hover":
				color = Color("ffe499") if active else Color("1c3543")
				border = Color("fff0b2") if active else Color("577482")
			elif state == "pressed":
				color = Color("e7b744")
				border = Color("ffe792")
			elif state == "disabled":
				color = Color("15232d")
			elif state == "focus":
				color = Color.TRANSPARENT
				border = MenuStyle.INK if active else MenuStyle.ACCENT
			var style := MenuStyle.box(color,0)
			style.set_corner_radius_all(6)
			style.border_color = border
			style.set_border_width_all(2 if state == "focus" else 1)
			if state == "focus": style.set_expand_margin_all(-3)
			button.add_theme_stylebox_override(state,style)
		button.custom_minimum_size = Vector2(60,52 if destinations.size() > 5 else 60)
		button.tooltip_text = entry[1]
		rail.add_child(button)

func _create_showroom() -> void:
	draft = VehicleLivery.for_car(records.settings, vehicle_id)
	_livery_saved = draft.duplicate(true)
	showroom = CarShowroom.new()
	showroom.name = "GarageShowroom"
	showroom.vehicle_id = vehicle_id
	showroom.garage_mode = true
	showroom.interaction_inset_top = 68
	showroom.interaction_inset_bottom = 58
	showroom.framing_scale = 0.96
	showroom.livery = draft
	kit_draft = VehicleCustomisation.for_car(records.settings,vehicle_id)
	showroom.customisation = kit_draft
	showroom.condition = VehicleCondition.read(records, vehicle_id)
	_condition_saved = showroom.condition.duplicate(true)
	showroom.condition_changed.connect(_save_condition)
	showroom.trophy_tapped.connect(_trophy_tapped)
	showroom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_child(showroom)
	preview.move_child(showroom, 0)
	MenuStyle.fill(showroom)
	_condition_presented = showroom.weathering.snapshot()
	showroom.update_records(records.settings)
	if achievements != null:
		achievements.changed.connect(_achievements_changed)
		_achievements_changed()

func _build_view_controls() -> void:
	_wash_status_panel = PanelContainer.new()
	_wash_status_panel.name = "GarageWashStatus"
	_wash_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_status_panel.add_theme_stylebox_override("panel",MenuStyle.card(10))
	preview.add_child(_wash_status_panel)
	_wash_status_panel.position = Vector2(24,72)
	_wash_status_panel.size = Vector2(320,44)
	var status_row := HBoxContainer.new()
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_status_panel.add_child(status_row)
	_wash_status_icon = TextureRect.new()
	_wash_status_icon.custom_minimum_size = Vector2(24,24)
	_wash_status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wash_status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wash_status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(_wash_status_icon)
	_wash_status = MenuStyle.label("",18)
	_wash_status.name = "GarageWashStatusText"
	status_row.add_child(_wash_status)
	var row := HBoxContainer.new()
	row.name = "GarageViewControls"
	preview.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 24
	row.offset_right = -16
	row.offset_top = -60
	row.offset_bottom = -12
	view_hint = MenuStyle.label("Drag to turn", 16, true)
	view_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(view_hint)
	for entry: Array in [["GarageTopView", "Top view", "View the hood and roof"], ["GarageZoomOut", "-", "Zoom out"], ["GarageZoomIn", "+", "Zoom in"], ["GarageResetView", "", "Reset view"]]:
		var button := MenuStyle.button(str(entry[1]), _view_action.bind(str(entry[0])))
		button.name = str(entry[0])
		button.name = str(entry[0])
		button.tooltip_text = str(entry[2])
		button.custom_minimum_size = Vector2(48, 48)
		if entry[0] == "GarageTopView": button.add_theme_font_size_override("font_size",18)
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		if entry[0] == "GarageResetView": button.icon = MenuIcon.texture("restart")
		row.add_child(button)

func _update_wash_status() -> void:
	_wash_status_panel.visible = section == "care"
	if section != "care": return
	var effect: VehicleWeathering = showroom.weathering
	var state: Array = [showroom.car.get_instance_id(),showroom.customisation,effect.bounds,effect.wash_image.get_instance_id(),effect.slow_wash_image.get_instance_id(),effect.wash_mask_uploads,effect.dirt_amount,effect.snow_amount,effect.slow_dirt_amount,effect.slow_snow_amount]
	if state == _wash_status_state: return
	_wash_status_state = state
	var clean: bool = _cleanliness.is_clean(showroom)
	_wash_status.text = _cleanliness.description(showroom)
	_wash_status_panel.tooltip_text = "Ready to customise" if clean else "Wash the exterior before customising"
	var colour: Color = MenuStyle.POSITIVE if clean else MenuStyle.MUTED
	_wash_status.add_theme_color_override("font_color",colour)
	_wash_status_icon.texture = MenuIcon.texture("check" if clean else "care")
	_wash_status_icon.modulate = colour

func _view_action(action: String) -> void:
	match action:
		"GarageTopView":
			showroom.elevation = 0.93
			showroom._orbit()
		"GarageZoomOut": showroom.zoom_by(1.15)
		"GarageZoomIn": showroom.zoom_by(1.0 / 1.15)
		"GarageResetView": showroom.reset_view()

func _build_carousel() -> void:
	gallery_slot = Control.new()
	gallery_slot.name = "GarageCarouselSlot"
	gallery_slot.custom_minimum_size.y = 140
	gallery_slot.resized.connect(_layout_gallery)
	main.add_child(gallery_slot)
	gallery = Carousel.new()
	gallery.name = "CarCarousel"
	gallery.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	gallery.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gallery.scroll_deadzone = 12
	gallery.follow_focus = false
	_live_menus.add_child(gallery)
	gallery_content = Control.new()
	gallery_content.custom_minimum_size.y = 140
	gallery.add_child(gallery_content)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	gallery_content.add_child(cards)
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		var card := MenuStyle.button("", preview_car.bind(index))
		card.name = "GarageCar_" + id
		card.tooltip_text = VehicleCatalog.title(id)
		card.clip_contents = true
		card.focus_entered.connect(_focus_card.bind(index))
		cards.add_child(card)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		card.add_child(column)
		MenuStyle.fill(column)
		var model := CarShowroom.new()
		model.name = "CarModel_" + id
		model.vehicle_id = id
		model.livery = VehicleLivery.for_car(records.settings, id)
		model.customisation = VehicleCustomisation.for_car(records.settings,id)
		model.condition = VehicleCondition.read(records, id)
		model.read_only = true
		model.garage_mode = true
		model.framing_scale = 0.84
		model.custom_minimum_size.y = 104
		model.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(model)
		thumbnails[id] = model
		var footer := MarginContainer.new()
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		footer.add_theme_constant_override("margin_left", 14)
		footer.add_theme_constant_override("margin_right", 14)
		footer.custom_minimum_size.y = 36
		column.add_child(footer)
		var caption := MenuStyle.label(VehicleCatalog.title(id), 22)
		caption.name = "CarCardTitle_" + id
		caption.add_theme_font_override("font", MenuStyle.DISPLAY)
		footer.add_child(caption)
	_update_cards()

func _layout_gallery() -> void:
	if not is_instance_valid(cards) or gallery_slot.size.x <= 0: return
	var first: int = roundi(float(gallery.scroll_horizontal) / tile_stride)
	gallery.call("_stop_snap")
	var slots: int = clampi(floori((gallery_slot.size.x + 12.0) / 240.0), 1, 5)
	tile_stride = floori((gallery_slot.size.x + 12.0) / slots)
	gallery.size = Vector2(slots * tile_stride - 12, 140)
	gallery.set("snap_stride", tile_stride)
	gallery_content.custom_minimum_size.x = VehicleCatalog.IDS.size() * tile_stride - 12
	for card: Control in cards.get_children(): card.custom_minimum_size = Vector2(tile_stride - 12, 140)
	gallery.scroll_horizontal = first * tile_stride

func _focus_card(index: int) -> void:
	if section != "cars": return
	var card := cards.get_child(index) as Control
	if gallery.get_global_rect().encloses(card.get_global_rect()): return
	gallery.call("_stop_snap")
	gallery.scroll_horizontal = index * tile_stride

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or section == "cars": return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		_show_section("cars")
		get_viewport().set_input_as_handled()

func _update_cards() -> void:
	for index: int in range(cards.get_child_count()):
		var card := cards.get_child(index) as Button
		var chosen: bool = VehicleCatalog.IDS[index] == vehicle_id
		var style: StyleBoxFlat = MenuStyle.card(0)
		style.border_color = MenuStyle.ACCENT if chosen else MenuStyle.BORDER
		style.set_border_width_all(2 if chosen else 1)
		card.add_theme_stylebox_override("normal", style)
		(card.find_child("CarCardTitle_" + VehicleCatalog.IDS[index], true, false) as Label).add_theme_color_override("font_color", MenuStyle.ACCENT if chosen else MenuStyle.TEXT)

func preview_car(index: int) -> void:
	if index < 0 or index >= VehicleCatalog.IDS.size(): return
	_finish_tools()
	var chosen: String = VehicleCatalog.IDS[index]
	if chosen != vehicle_id:
		vehicle_id = chosen
		heading.text = VehicleCatalog.title(vehicle_id)
		_replace_showroom_car()
	_update_cards()

func _replace_showroom_car() -> void:
	draft = VehicleLivery.for_car(records.settings,vehicle_id)
	_livery_saved = draft.duplicate(true)
	var wear: Dictionary = VehicleCondition.read(records,vehicle_id)
	kit_draft = VehicleCustomisation.for_car(records.settings,vehicle_id)
	showroom.replace_car(vehicle_id,draft,wear,kit_draft)
	_condition_saved = wear.duplicate(true)
	_condition_presented = showroom.weathering.snapshot()

func _confirm_car() -> void:
	open_car(VehicleCatalog.IDS.find(vehicle_id))

func open_car(index: int) -> void:
	if index < 0 or index >= VehicleCatalog.IDS.size(): return
	preview_car(index)
	_selected_vehicle_id = vehicle_id
	_show_section("customise")
	vehicle_selected.emit(index)

func _refresh_thumbnails() -> void:
	for id: String in thumbnails:
		var model: CarShowroom = thumbnails[id]
		var paint: Dictionary = VehicleLivery.for_car(records.settings, id)
		var condition: Dictionary = VehicleCondition.read(records, id)
		if model.livery != paint: model.apply_livery(paint)
		var parts: Dictionary = VehicleCustomisation.for_car(records.settings,id)
		if model.customisation != parts: model.apply_customisation(parts)
		if model.condition != condition:
			model.condition = condition
			model.weathering.restore(condition)
			model.refresh_thumbnail()

func refresh_selection() -> void:
	# A warmed page may have been built before another page selected a car.
	if _selected_vehicle_id == VehicleCatalog.selected:
		# A retained page can outlive a race. Refresh changed thumbnail cosmetics
		# even when the confirmed car did not change; meshes/worlds stay intact.
		refresh_cosmetics()
		return
	_finish_tools()
	vehicle_id = VehicleCatalog.selected
	_selected_vehicle_id = vehicle_id
	heading.text = VehicleCatalog.title(vehicle_id)
	_replace_showroom_car()
	_show_section("cars")
	_update_cards()

func refresh_cosmetics() -> void:
	if not is_instance_valid(showroom): return
	_refresh_thumbnails()
	# Do not interrupt an uncommitted colour picker or sticker gesture.
	if draft != _livery_saved: return
	var paint: Dictionary = VehicleLivery.for_car(records.settings,vehicle_id)
	if draft != paint:
		draft = paint
		_livery_saved = paint.duplicate(true)
		showroom.apply_livery(paint)
		_update_pickers()
	var parts: Dictionary = VehicleCustomisation.for_car(records.settings,vehicle_id)
	if kit_draft != parts:
		kit_draft = parts
		showroom.apply_customisation(parts)
		if is_instance_valid(kit_cards):
			for index: int in range(kit_cards.get_child_count()):
				(kit_cards.get_child(index) as CompactKitThumbnail).set_selected(kit_draft[kit_category] == VehicleCustomisation.OPTIONS[kit_category][index][0])

func _show_section(next: String) -> void:
	if next == "car": next = "customise"
	if next not in ["cars", "customise", "care", "tuning", "trophies", "records", "news", "achievements"]: return
	_finish_tools()
	_customisation_locked = next in ["customise","tuning"] and not _clean_for_customisation()
	if not _customisation_locked and next=="customise" and section=="customise" and is_instance_valid(livery_menu) and _retained_livery_vehicle==vehicle_id:
		livery_menu.show_tab(_customise_tab)
		return
	_prepare_menu_move()
	_set_customise_layout(next in ["customise","tuning","records"])
	section = next
	_update_wash_status()
	# The newspaper takes the desk. Keep the live car attached and dormant so
	# leaving News restores the same car, camera, condition and reflection rig.
	preview.visible = next not in ["news","achievements"]
	_preview_slot.visible = next not in ["news","achievements"]
	_actions_slot.visible = next not in ["news","achievements"]
	actions.visible = next not in ["news","achievements"]
	_tools_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL if next in ["news","achievements"] or is_instance_valid(customise_layout) else Control.SIZE_FILL
	tools.size_flags_vertical = Control.SIZE_EXPAND_FILL if next in ["news","achievements"] or is_instance_valid(customise_layout) else Control.SIZE_FILL
	if next == "news": tools_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	elif next == "achievements": tools_panel.add_theme_stylebox_override("panel",MenuStyle.card(8))
	if next == "cars": _car_menu_open = false
	elif next not in ["trophies","records","news","achievements"]: _car_menu_open = true
	showroom.set_trophy_view(next == "trophies")
	showroom.set_record_view(next == "records")
	heading.text = "RECORD PLAYER" if next == "records" else "TROPHY WALL" if next == "trophies" else VehicleCatalog.title(vehicle_id)
	preview.get_node("GarageViewControls").visible = next not in ["trophies","records"]
	preview.get_node("GarageViewControls/GarageTopView").visible = next in ["customise","tuning"]
	pickers.clear()
	wash_button = null
	_presets = null
	_sticker_board = null
	_sticker_choice = null
	_sticker_sliders.clear()
	_sticker_values.clear()
	livery_menu = null
	select_button = null
	records_menu = null
	gallery_slot.visible = section == "cars"
	tools_panel.visible = section not in ["cars", "care", "trophies"]
	_build_rail()
	if section == "cars":
		_refresh_thumbnails()
		select_button = MenuStyle.button("SELECT", _confirm_car, true)
		select_button.name = "GarageSelectCar"
		select_button.icon = MenuIcon.texture("arrow")
		select_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for state: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
			select_button.add_theme_color_override(state, MenuStyle.INK)
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_button.custom_minimum_size.y = 60
		select_button.add_theme_color_override("font_focus_color", MenuStyle.INK)
		select_button.add_theme_color_override("font_pressed_color", MenuStyle.INK)
		actions.add_child(select_button)
		_start_menu_move()
		return
	if section not in ["customise","tuning","records","news","achievements"]: tools.add_child(MenuStyle.label(section.to_upper(), 20))
	var back := MenuStyle.button("Trophy Room" if section == "achievements" else "Back to cars", _show_section.bind("trophies" if section == "achievements" else "cars"))
	back.name = "GarageBack"
	back.custom_minimum_size = Vector2(240, 60)
	actions.add_child(back)
	if _customisation_locked:
		_build_wash_requirement()
	elif section == "customise":
		_build_customise()
	elif section == "care":
		wash_button = MenuStyle.button("Wash", _toggle_wash, true)
		wash_button.name = "GarageWash"
		wash_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wash_button.custom_minimum_size.y = 60
		wash_button.add_theme_color_override("font_focus_color", MenuStyle.INK)
		wash_button.add_theme_color_override("font_pressed_color", MenuStyle.INK)
		actions.add_child(wash_button)
	elif section == "trophies":
		_achievement_button = MenuStyle.button("Achievements",_show_section.bind("achievements"),true)
		_achievement_button.name = "GarageAchievements"
		_achievement_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(_achievement_button)
		_achievements_changed()
	elif section == "achievements":
		if achievements != null:
			var album := preload("res://ui/achievements_menu.gd").new()
			album.service = achievements
			album.trophy_room_requested.connect(_show_section.bind("trophies"))
			tools.add_child(album)
	elif section == "tuning":
		_build_tuning()
	elif section == "news":
		var news_menu := preload("res://ui/garage_news_menu.gd").new()
		news_menu.page = self
		news_menu.service = news_client
		tools.add_child(news_menu)
	elif section == "records":
		records_menu = preload("res://ui/garage_records_menu.gd").new()
		records_menu.records = records
		records_menu.browse_index = record_browse_index
		records_menu.changed.connect(func() -> void: showroom.update_records(records.settings))
		records_menu.browsed.connect(func(index: int) -> void: record_browse_index = index)
		records_menu.flipping.connect(showroom.browse_records)
		records_menu.save_failed.connect(func() -> void: save_failed.emit())
		tools.add_child(records_menu)
	else:
		tools.add_child(MenuStyle.label("Coming later", 18, true))
	_start_menu_move()

func _build_wash_requirement() -> void:
	var title: Label = MenuStyle.label("WASH REQUIRED",26)
	title.name = "GarageWashRequired"
	title.add_theme_color_override("font_color",MenuStyle.ACCENT)
	tools.add_child(title)
	var message: Label = MenuStyle.label("This car is dirty. Wash it before changing liveries, colours, stickers or kits.",20)
	message.name = "GarageWashRequirementMessage"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(message)
	var wash: Button = MenuStyle.button("Wash car",_wash_for_customisation,true)
	wash.name = "GarageWashForCustomisation"
	tools.add_child(wash)

func _wash_for_customisation() -> void:
	_show_section("care")
	if not showroom.wash_mode: _toggle_wash()

func _require_clean_car() -> bool:
	if _clean_for_customisation(): return true
	_show_section("tuning" if section == "tuning" else "customise")
	return false

func _clean_for_customisation() -> bool:
	# Retained controls can receive input before the next frame after a race.
	var current: Dictionary = VehicleCondition.read(records,vehicle_id)
	if current != _condition_saved:
		showroom.weathering.restore(current)
		_condition_saved = current.duplicate(true)
		_condition_presented = showroom.weathering.snapshot()
	return _cleanliness.is_clean(showroom)

func _set_customise_layout(active: bool) -> void:
	if active and not is_instance_valid(customise_layout):
		customise_layout = HBoxContainer.new()
		customise_layout.name = "GarageCustomiseLayout"
		customise_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
		customise_layout.add_theme_constant_override("separation",16)
		main.add_child(customise_layout)
		main.move_child(customise_layout,0)
		_preview_slot.reparent(customise_layout)
		_tools_slot.reparent(customise_layout)
		_preview_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tools_slot.size_flags_horizontal = Control.SIZE_FILL
		_tools_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tools.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elif not active and is_instance_valid(customise_layout):
		_preview_slot.reparent(main)
		main.move_child(_preview_slot,0)
		_tools_slot.reparent(main)
		main.move_child(_tools_slot,1)
		_tools_slot.size_flags_vertical = Control.SIZE_FILL
		main.remove_child(customise_layout)
		customise_layout.queue_free()
		customise_layout = null
	tools_panel.custom_minimum_size.x = 344 if active else 0
	tools.size_flags_vertical = Control.SIZE_EXPAND_FILL if active else Control.SIZE_FILL

func _build_tuning() -> void:
	kit_categories.clear()
	var workbench := VBoxContainer.new()
	workbench.name = "GarageTuningWorkbench"
	workbench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workbench.add_theme_constant_override("separation",12)
	tools.add_child(workbench)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",8)
	workbench.add_child(header)
	var title: Label = MenuStyle.label("TUNING",26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if vehicle_id != "compact":
		var unavailable: Label = MenuStyle.label("Kits available for the Compact",18,true)
		unavailable.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		workbench.add_child(unavailable)
		return
	var reset := MenuStyle.button("",_reset_kits)
	reset.name = "GarageResetKits"
	reset.icon = MenuIcon.texture("restart")
	reset.expand_icon = true
	reset.add_theme_constant_override("icon_max_width",21)
	reset.custom_minimum_size = Vector2(48,48)
	reset.tooltip_text = "Reset kits"
	header.add_child(reset)
	kit_draft = VehicleCustomisation.for_car(records.settings,vehicle_id)
	var categories := GridContainer.new()
	categories.name = "CompactKitCategories"
	categories.columns = 2
	categories.add_theme_constant_override("h_separation",2)
	categories.add_theme_constant_override("v_separation",2)
	workbench.add_child(categories)
	for category: String in VehicleCustomisation.CATEGORIES:
		var tab := MenuStyle.tab(str(VehicleCustomisation.LABELS[category]),_select_kit_category.bind(category),category==kit_category)
		tab.name = "KitCategory_"+category
		tab.custom_minimum_size = Vector2(112,48)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",20)
		_style_kit_category(tab,category==kit_category)
		categories.add_child(tab)
		kit_categories[category] = tab
	kit_scroll = preload("res://ui/vertical_swipe_scroll.gd").new()
	kit_scroll.name = "CompactKitScroll"
	kit_scroll.custom_minimum_size.y = 102
	kit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kit_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	kit_scroll.follow_focus = true
	workbench.add_child(kit_scroll)
	kit_cards = GridContainer.new()
	kit_cards.name = "CompactKitCards"
	kit_cards.columns = 2
	kit_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit_cards.add_theme_constant_override("h_separation",10)
	kit_cards.add_theme_constant_override("v_separation",10)
	kit_scroll.add_child(kit_cards)
	_build_kit_cards()

func _style_kit_category(tab: Button, selected: bool) -> void:
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		tab.add_theme_color_override(state,MenuStyle.ACCENT if selected else MenuStyle.MUTED)
	for state: String in ["normal","hover","pressed"]:
		var style := MenuStyle.box(Color("213543") if selected else Color("101f2b"),6)
		style.set_corner_radius_all(7)
		tab.add_theme_stylebox_override(state,style)

func _select_kit_category(category: String) -> void:
	if category not in VehicleCustomisation.CATEGORIES or section != "tuning": return
	kit_category = category
	for id: String in kit_categories:
		var tab: Button = kit_categories[id]
		_style_kit_category(tab,id==category)
	_build_kit_cards()

func _build_kit_cards() -> void:
	for child: Node in kit_cards.get_children():
		kit_cards.remove_child(child)
		child.queue_free()
	for option: Array in VehicleCustomisation.OPTIONS[kit_category]:
		var card := CompactKitThumbnail.make(kit_category,option,kit_draft[kit_category]==option[0],_select_kit.bind(kit_category,str(option[0])))
		card.focus_entered.connect(_reveal_focused_kit.bind(card.get_instance_id()),CONNECT_DEFERRED)
		kit_cards.add_child(card)
		_shop_badge(card,"kit/compact/"+kit_category+"/"+str(option[0]))
	_reveal_selected_kit.call_deferred()

func _reveal_focused_kit(instance: int) -> void:
	var card := instance_from_id(instance) as Control
	if section=="tuning" and vehicle_id=="compact" and is_instance_valid(card) and is_instance_valid(kit_scroll) and card.get_parent()==kit_cards:
		kit_scroll.ensure_control_visible(card)

func _reveal_selected_kit() -> void:
	if section!="tuning" or not is_instance_valid(kit_scroll): return
	for card: CompactKitThumbnail in kit_cards.get_children():
		if card.name=="KitOption_"+str(kit_draft[kit_category]):
			kit_scroll.ensure_control_visible(card)
			return

func _select_kit(category: String, option: String) -> void:
	if vehicle_id != "compact" or section != "tuning": return
	if not _require_clean_car(): return
	var next: Dictionary = kit_draft.duplicate(true)
	next[category] = option
	if not VehicleCustomisation.valid(next) or next==kit_draft: return
	var title: String = option.capitalize()
	for item: Array in VehicleCustomisation.OPTIONS[category]:
		if item[0] == option: title = str(item[1])
	if not _require_owned("kit/compact/"+category+"/"+option,title,_select_kit.bind(category,option)): return
	_save_kits(next)

func _save_kits(value: Dictionary) -> void:
	if not _require_clean_car(): return
	var collection: Dictionary = records.settings.get("vehicle_customisation",{}).duplicate(true)
	collection[vehicle_id] = value.duplicate(true)
	records.settings.vehicle_customisation = collection
	if value != kit_draft and value != VehicleCustomisation.defaults(): AchievementProgress.customise(records,vehicle_id)
	var result: Error = records.save_records()
	kit_draft = VehicleCustomisation.for_car(records.settings,vehicle_id)
	showroom.apply_customisation(kit_draft)
	_condition_presented = showroom.weathering.snapshot()
	for index: int in range(kit_cards.get_child_count()):
		(kit_cards.get_child(index) as CompactKitThumbnail).set_selected(kit_draft[kit_category]==VehicleCustomisation.OPTIONS[kit_category][index][0])
	_reveal_selected_kit.call_deferred()
	if result != OK: save_failed.emit()

func _reset_kits() -> void:
	if vehicle_id == "compact" and section=="tuning": _save_kits(VehicleCustomisation.defaults())

func _build_customise() -> void:
	if is_instance_valid(_retained_livery) and _retained_livery_vehicle!=vehicle_id:
		_retained_livery.get_parent().remove_child(_retained_livery)
		_retained_livery.queue_free()
		_retained_livery = null
	if not is_instance_valid(_retained_livery):
		_retained_livery = GarageLiveryMenu.new()
		_retained_livery.page = self
		_retained_livery_vehicle = vehicle_id
		tools.add_child(_retained_livery)
	elif _retained_livery.get_parent()!=tools:
		_retained_livery.reparent(tools)
	_set_panel_input(_retained_livery,true)
	livery_menu = _retained_livery
	livery_menu.show()
	livery_menu.show_tab(_customise_tab)

func _set_customise_tab(tab: String) -> void:
	if tab not in ["livery","colours","stickers"]: return
	_sticker_editing = false
	_customise_tab = tab
	_show_section("customise")

func _preset_count() -> int:
	return LIVERY_NAMES.size()+LiveryCatalog.patterns.size()

func _preset_value(index: int) -> Dictionary:
	var value: Dictionary = VehicleLivery.defaults(vehicle_id)
	if index >= 0 and index < LIVERY_NAMES.size():
		value.colors.body = LIVERY_COLORS[index][0]
		value.colors.accent = LIVERY_COLORS[index][1]
	elif index >= LIVERY_NAMES.size() and index < _preset_count():
		var pattern: Dictionary = LiveryCatalog.patterns[index-LIVERY_NAMES.size()]
		value.pattern = pattern.id
		for slot: int in range(VehicleLivery.SLOTS.size()): value.colors[VehicleLivery.SLOTS[slot]] = pattern.colours[slot]
	return value

func _preset_index() -> int:
	for index: int in range(_preset_count()):
		var value: Dictionary = _preset_value(index)
		if draft.colors == value.colors and draft.pattern == value.pattern: return index
	return _preset_count()

func _select_livery(index: int) -> void:
	if index < 0 or index >= _preset_count(): return
	if not _require_clean_car(): return
	var value: Dictionary = _preset_value(index)
	var title: String = LIVERY_NAMES[index] if index < LIVERY_NAMES.size() else str(LiveryCatalog.patterns[index-LIVERY_NAMES.size()].title)
	if not _require_owned("livery/"+str(value.pattern),title,_select_livery.bind(index)): return
	var stickers: Dictionary = draft.stickers.duplicate(true)
	draft = _preset_value(index)
	draft.stickers = stickers
	showroom.apply_livery(draft)
	_update_pickers()
	_save()
	if _customise_tab == "livery": _refresh_pattern_selection()

func _refresh_pattern_selection() -> void:
	if is_instance_valid(livery_menu): livery_menu.refresh()

func _build_sticker_tools(parent: Control) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	parent.add_child(header)
	var back := MenuStyle.button("Back",_edit_sticker_position.bind(false))
	back.name = "StickerPlacementBack"
	back.custom_minimum_size = Vector2(72,44)
	header.add_child(back)
	var index: int = LiveryCatalog.sticker_index(draft.stickers[_sticker_surface].id)
	var title_text: String = _sticker_surface.capitalize()+" · "+LiveryCatalog.stickers[index].title if index >= 0 else _sticker_surface.capitalize()
	var title: Label = MenuStyle.label(title_text,20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	_sticker_board = StickerPlacement.new()
	_sticker_board.name = "StickerPlacement"
	_sticker_board.custom_minimum_size = Vector2(280,146)
	_sticker_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sticker_board.vehicle_id = vehicle_id
	_sticker_board.surface = _sticker_surface
	_sticker_board.livery = draft
	_sticker_board.moved.connect(_move_sticker)
	_sticker_board.committed.connect(_save)
	parent.add_child(_sticker_board)
	for property: String in ["size","rotation"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		parent.add_child(row)
		var title_row := VBoxContainer.new()
		title_row.custom_minimum_size.x = 64
		title_row.add_theme_constant_override("separation",2)
		row.add_child(title_row)
		title_row.add_child(MenuStyle.label(property.capitalize(),14,true))
		var value := MenuStyle.label("",16)
		title_row.add_child(value)
		_sticker_values[property] = value
		var slider := HSlider.new()
		slider.name = "Sticker"+property.capitalize()
		slider.custom_minimum_size = Vector2(112,48)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = 0.2 if property == "size" else -180
		slider.max_value = 0.95 if property == "size" else 180
		slider.step = 0.01 if property == "size" else 1
		slider.value = draft.stickers[_sticker_surface][property]
		slider.value_changed.connect(_sticker_property.bind(property))
		slider.drag_ended.connect(func(_changed: bool) -> void: _save())
		slider.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventKey and not event.pressed: _save())
		row.add_child(slider)
		_sticker_sliders[property] = slider
	var centre := MenuStyle.button("Centre",_centre_sticker)
	centre.custom_minimum_size.y = 48
	parent.add_child(centre)
	_refresh_sticker_values()

func _refresh_sticker_values() -> void:
	for property: String in _sticker_values:
		var value: float = draft.stickers[_sticker_surface][property]
		_sticker_values[property].text = ("%d%%" % roundi(value*100)) if property == "size" else ("%d°" % roundi(value))

func _choose_sticker_surface(panel: String) -> void:
	_sticker_editing = false
	_sticker_surface = panel
	_show_section("customise")

func _edit_sticker_position(active: bool) -> void:
	_sticker_editing = active
	_show_section("customise")

func _choose_sticker(index: int) -> void:
	if index < 0 or index > LiveryCatalog.stickers.size(): return
	if not _require_clean_car(): return
	# New sponsor wordmarks face the reader standing in front of the car.
	# Replacing an existing decal retains the owner's placement and rotation.
	if index > 0 and draft.stickers[_sticker_surface].id == "none" and LiveryCatalog.stickers[index-1].category == "sponsors":
		draft.stickers[_sticker_surface].rotation = 180.0
	draft.stickers[_sticker_surface].id = "none" if index == 0 else LiveryCatalog.stickers[index-1].id
	_preview_sticker()
	_save()

func _move_sticker(point: Vector2) -> void:
	if not _require_clean_car(): return
	draft.stickers[_sticker_surface].x = point.x
	draft.stickers[_sticker_surface].y = point.y
	_preview_sticker()

func _sticker_property(value: float, property: String) -> void:
	if not _require_clean_car(): return
	draft.stickers[_sticker_surface][property] = value
	_preview_sticker()

func _centre_sticker() -> void:
	if not _require_clean_car(): return
	draft.stickers[_sticker_surface].x = 0.5
	draft.stickers[_sticker_surface].y = 0.5
	_preview_sticker()
	_save()

func _preview_sticker() -> void:
	showroom.apply_livery(draft)
	if is_instance_valid(_sticker_board):
		_sticker_board.livery = draft
		_sticker_board.queue_redraw()
	_refresh_sticker_values()

func _finish_tools() -> void:
	if showroom == null: return
	if is_instance_valid(records_menu): records_menu.finish()
	if draft != _livery_saved: _save()
	showroom.set_wash_mode(false)
	if is_instance_valid(wash_button): wash_button.text = "Wash"
	for picker: ColorPickerButton in pickers.values():
		if picker.get_popup().visible: picker.get_popup().hide()
	_save_condition()
	_wash_achievement_pending = false
	if view_hint != null: view_hint.text = "Drag to turn"

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		if is_instance_valid(_purchase_dialog): _purchase_dialog.hide()
		_finish_tools()
		showroom.finish_car_transition()
		_finish_menu_move()
	elif economy != null: economy.refresh()

func telemetry_exposures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if section != "cars" or not gallery.is_visible_in_tree(): return result
	var visible_rect: Rect2 = gallery.get_global_rect()
	for index: int in range(cards.get_child_count()):
		var card := cards.get_child(index) as Control
		if visible_rect.intersection(card.get_global_rect()).size.x >= card.size.x * 0.8:
			result.append({"car_id": VehicleCatalog.IDS[index], "position": index})
	return result

func _preview_color(color: Color, slot: String) -> void:
	if not _require_clean_car(): return
	draft.colors[slot] = Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1)).to_html(false)
	showroom.apply_livery(draft)
	if is_instance_valid(_presets): _presets.select(_preset_index())
	_refresh_pattern_selection()

func _save() -> void:
	if draft==_livery_saved: return
	if not _clean_for_customisation():
		draft = _livery_saved.duplicate(true)
		showroom.apply_livery(draft)
		_update_pickers()
		return
	var colors: Dictionary = records.settings.get("vehicle_liveries", {}).duplicate(true)
	colors[vehicle_id] = draft.duplicate(true)
	records.settings.vehicle_liveries = colors
	if draft != VehicleLivery.defaults(vehicle_id): AchievementProgress.customise(records,vehicle_id)
	if records.save_records() != OK:
		draft = VehicleLivery.for_car(records.settings, vehicle_id)
		showroom.apply_livery(draft)
		_update_pickers()
		save_failed.emit()
	else:
		_livery_saved = draft.duplicate(true)
	if is_instance_valid(_presets): _presets.select(_preset_index())
	_refresh_pattern_selection()

func _update_pickers() -> void:
	for slot: String in VehicleLivery.SLOTS:
		if not pickers.has(slot): continue
		(pickers[slot] as ColorPickerButton).color = Color(str(draft.colors[slot]))
	if is_instance_valid(_sticker_choice): _sticker_choice.select(LiveryCatalog.sticker_index(draft.stickers[_sticker_surface].id)+1)
	for property: String in _sticker_sliders: _sticker_sliders[property].set_value_no_signal(draft.stickers[_sticker_surface][property])
	if is_instance_valid(_sticker_board):
		_sticker_board.livery = draft
		_sticker_board.queue_redraw()
	_refresh_sticker_values()
	_refresh_pattern_selection()

func _reset() -> void:
	if not _require_clean_car(): return
	draft = VehicleLivery.defaults(vehicle_id)
	showroom.apply_livery(draft)
	_update_pickers()
	_save()
	if _sticker_editing: _edit_sticker_position(false)

func _toggle_wash() -> void:
	if section != "care": return
	if not showroom.wash_mode: _wash_achievement_pending = not _cleanliness.is_clean(showroom)
	showroom.set_wash_mode(not showroom.wash_mode)
	wash_button.text = "Done" if showroom.wash_mode else "Wash"
	view_hint.text = "Drag to wash / Two fingers to turn" if showroom.wash_mode else "Drag to turn"
	if not showroom.wash_mode: _save_condition()

func _save_condition() -> void:
	if showroom == null: return
	var current: Dictionary = VehicleCondition.read(records, vehicle_id)
	# Prepared/outgoing garage pages must never overwrite newer race wear.
	if current != _condition_saved:
		showroom.weathering.restore(current)
		_condition_saved = current.duplicate(true)
		_condition_presented = showroom.weathering.snapshot()
		return
	var value: Dictionary = showroom.weathering.snapshot()
	# Preparing an untouched clean car must not create a cosmetic save.
	if value == _condition_saved or value == _condition_presented: return
	var completed_wash: bool = _wash_achievement_pending and _cleanliness.is_clean(showroom)
	if completed_wash: AchievementProgress.wash(records)
	if VehicleCondition.save(records, vehicle_id, value) != OK:
		save_failed.emit()
	else:
		_condition_saved = value.duplicate(true)
		_condition_presented = value.duplicate(true)
		if completed_wash: _wash_achievement_pending = false

func _process(_delta: float) -> void:
	if showroom == null or not is_visible_in_tree(): return
	_present_menu_layout()
	var current: Dictionary = VehicleCondition.read(records, vehicle_id)
	if current != _condition_saved:
		showroom.weathering.restore(current)
		_condition_saved = current.duplicate(true)
		_condition_presented = showroom.weathering.snapshot()
		if section in ["customise","tuning"]: _show_section(section)
	_update_wash_status()

func _exit_tree() -> void:
	_finish_tools()
	if _menu_motion != null: _menu_motion.kill()

func _achievements_changed() -> void:
	if achievements == null or showroom == null: return
	preload("res://ui/achievement_display.gd").update(showroom,achievements)
	if is_instance_valid(_achievement_button):
		var earned: int = 0
		for f: Dictionary in AchievementProgress.catalog().families: earned += AchievementProgress.tier(f,achievements.source(f))
		_achievement_button.text = "Achievements  ·  %d / 130" % earned

func _trophy_tapped(position: Vector2) -> void:
	if section != "trophies" or achievements == null: return
	var family: String = preload("res://ui/achievement_display.gd").pick(showroom,position)
	if family.is_empty(): return
	_show_section("achievements")
	var album: Node = find_child("AchievementsMenu",true,false)
	if album != null: album._show_achievement(family)

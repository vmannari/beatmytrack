class_name GarageLiveryMenu
extends VBoxContainer
## Native sidebar workbench. Browsing uses offline model renders only.
const PALETTE: Array[String] = ["ebe3d0","c1c9cb","7b8d96","253747","121b24","317573","50734f","b8a170","d6ab50","cc7448","a44844","764654","9b879e","67849e","b9c8bb"]
var page: GaragePage
var pattern_tiles: Dictionary = {}
var sticker_tiles: Dictionary = {}
var slot_buttons: Dictionary = {}
var colour_chips: Array[LiveryColourChip] = []
var slider_labels: Dictionary = {}
var active_picker: Control
var pattern_scroll: ScrollContainer
var _tabs: Dictionary = {}
var _contents: Dictionary = {}
var _content: VBoxContainer
var _editing_content: VBoxContainer
var colour_pickers: Dictionary = {}
var _sticker_category: String = "emblems"

func _ready() -> void:
	name = "GarageLiveryWorkbench"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",8)
	add_child(header)
	var title: Label = MenuStyle.label("CUSTOMISE",26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var reset := MenuStyle.button("",page._reset)
	reset.name = "ResetLivery"
	reset.icon = MenuIcon.texture("restart")
	reset.expand_icon = true
	reset.add_theme_constant_override("icon_max_width",21)
	reset.custom_minimum_size = Vector2(48,48)
	reset.tooltip_text = "Reset livery"
	header.add_child(reset)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",2)
	add_child(tabs)
	for entry: Array in [["livery","Patterns"],["colours","Colours"],["stickers","Stickers"]]:
		var tab: Button = MenuStyle.tab(entry[1],page._set_customise_tab.bind(entry[0]),page._customise_tab == entry[0])
		tab.name = "LiveryMenu_"+entry[0]
		_tabs[entry[0]] = tab
		tab.custom_minimum_size = Vector2(88,44)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",20)
		for state: String in ["normal","hover","pressed"]:
			var style := MenuStyle.box(Color("213543") if page._customise_tab == entry[0] else Color("101f2b"),6)
			style.set_corner_radius_all(7)
			tab.add_theme_stylebox_override(state,style)
		tabs.add_child(tab)
	show_tab(page._customise_tab)

func show_tab(tab: String) -> void:
	if _tabs.is_empty(): return
	page._sticker_board = null
	page._sticker_sliders.clear()
	page._sticker_values.clear()
	if not LiveryCatalog.has_roof(page.vehicle_id): page._sticker_surface = "hood"
	for id: String in _tabs:
		var button: Button = _tabs[id]
		button.add_theme_color_override("font_color",MenuStyle.ACCENT if id==tab else MenuStyle.MUTED)
		for state: String in ["normal","hover","pressed"]:
			var style := MenuStyle.box(Color("213543") if id==tab else Color("101f2b"),6)
			style.set_corner_radius_all(7)
			button.add_theme_stylebox_override(state,style)
	for root: Control in _contents.values(): root.hide()
	if is_instance_valid(_editing_content):
		remove_child(_editing_content)
		_editing_content.queue_free()
		_editing_content = null
	var editing: bool = tab=="stickers" and page._sticker_editing
	var key: String = tab+"/"+page._sticker_surface+"/"+_sticker_category if tab=="stickers" else tab
	if editing or not _contents.has(key):
		_content = VBoxContainer.new()
		_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content.add_theme_constant_override("separation",12)
		add_child(_content)
		if editing: _editing_content = _content
		else: _contents[key] = _content
		match tab:
			"colours": _colours()
			"stickers": _stickers()
			_: _patterns()
	else:
		_content = _contents[key]
		_content.show()
	# Keep generic UI lookups and focus traversal on the visible tools first.
	move_child(_content,2)
	# A cached hood and roof each own their tiles. Refresh the active set after
	# returning to a pane so selection never targets another hidden gallery.
	sticker_tiles.clear()
	for tile: Node in _content.find_children("Sticker_*","LiveryTile",true,false):
		sticker_tiles[str(tile.name).trim_prefix("Sticker_")] = tile
	page.pickers = colour_pickers.duplicate()
	refresh()

func active_control(control_name: String) -> Control:
	if not is_instance_valid(_content): return null
	return _content.find_child(control_name,true,false) as Control

func _scroll() -> ScrollContainer:
	var scroll: ScrollContainer = preload("res://ui/vertical_swipe_scroll.gd").new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	_content.add_child(scroll)
	return scroll

func _patterns() -> void:
	pattern_scroll = _scroll()
	pattern_scroll.name = "LiveryPatternGallery"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	pattern_scroll.add_child(grid)
	for index: int in range(page._preset_count()):
		var plain_count: int = GaragePage.LIVERY_NAMES.size()
		var title: String = GaragePage.LIVERY_NAMES[index] if index < plain_count else LiveryCatalog.patterns[index-plain_count].title
		var key: String = GaragePage.LIVERY_NAMES[index].to_lower() if index < plain_count else LiveryCatalog.patterns[index-plain_count].id
		var texture: Texture2D = load("res://assets/liveries/previews_v2/"+page.vehicle_id+"/"+key+".png")
		var tile: LiveryTile = LiveryTile.make(title,texture,page._select_livery.bind(index))
		tile.name = "Pattern_"+key
		tile.set_meta("livery_index",index)
		grid.add_child(tile)
		pattern_tiles[index] = tile
	# Restore the selected design to view when reopening this tool.
	var selected_index: int = page._preset_index()
	if pattern_tiles.has(selected_index): pattern_scroll.ensure_control_visible.call_deferred(pattern_tiles[selected_index])

func _colours() -> void:
	var scroll: ScrollContainer = _scroll()
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",20)
	scroll.add_child(content)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation",8)
	content.add_child(slots)
	for slot: String in VehicleLivery.SLOTS:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",4)
		slots.add_child(column)
		var button := LiveryColourChip.new()
		button.name = "ColourSlot_"+slot
		button.custom_minimum_size = Vector2(72,58)
		button.colour = Color(str(page.draft.colors[slot]))
		button.tooltip_text = slot.capitalize()
		button.pressed.connect(_select_slot.bind(slot))
		button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
		button.add_theme_stylebox_override("hover",MenuStyle.box(Color("213543"),0))
		column.add_child(button)
		var label: Label = MenuStyle.label(slot.capitalize(),16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		slot_buttons[slot] = button
	var palette := GridContainer.new()
	palette.name = "LiveryColourPalette"
	palette.columns = 5
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.add_theme_constant_override("h_separation",4)
	palette.add_theme_constant_override("v_separation",4)
	content.add_child(palette)
	for pigment: String in PALETTE:
		var chip := LiveryColourChip.new()
		chip.colour = Color(pigment)
		chip.custom_minimum_size = Vector2(50,50)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_stylebox_override("normal",MenuStyle.box(Color("101f2b"),0))
		chip.add_theme_stylebox_override("hover",MenuStyle.box(Color("213543"),0))
		chip.pressed.connect(_palette_colour.bind(chip.colour))
		palette.add_child(chip)
		colour_chips.append(chip)
	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation",12)
	content.add_child(custom_row)
	var custom_label: Label = MenuStyle.label("Custom colour",18)
	custom_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_row.add_child(custom_label)
	active_picker = HBoxContainer.new()
	custom_row.add_child(active_picker)
	for slot: String in VehicleLivery.SLOTS:
		var picker := ColorPickerButton.new()
		picker.name = "Livery"+slot.capitalize()
		picker.custom_minimum_size = Vector2(72,52)
		picker.edit_alpha = false
		picker.color = Color(str(page.draft.colors[slot]))
		var colour_picker: ColorPicker = picker.get_picker()
		colour_picker.color_modes_visible = false
		colour_picker.sliders_visible = false
		colour_picker.sampler_visible = false
		colour_picker.presets_visible = false
		picker.get_popup().add_theme_stylebox_override("panel",MenuStyle.card(12))
		picker.color_changed.connect(page._preview_color.bind(slot))
		picker.popup_closed.connect(page._save)
		active_picker.add_child(picker)
		page.pickers[slot] = picker
		colour_pickers[slot] = picker

func _select_slot(slot: String) -> void:
	page._colour_slot = slot
	refresh()

func _palette_colour(colour: Color) -> void:
	page._preview_color(colour,page._colour_slot)
	page._update_pickers()
	page._save()

func _stickers() -> void:
	if not LiveryCatalog.has_roof(page.vehicle_id): page._sticker_surface = "hood"
	if page.draft.stickers[page._sticker_surface].id == "none": page._sticker_editing = false
	if page._sticker_editing:
		page._build_sticker_tools(_content)
		return
	var scroll: ScrollContainer = _scroll()
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation",8)
	content.add_child(panels)
	for panel: String in VehicleLivery.SURFACES:
		if panel == "roof" and not LiveryCatalog.has_roof(page.vehicle_id): continue
		var button := MenuStyle.tab(panel.capitalize(),page._choose_sticker_surface.bind(panel),panel == page._sticker_surface)
		button.name = "Sticker"+panel.capitalize()
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panels.add_child(button)
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation",8)
	content.add_child(categories)
	for category: String in ["emblems","sponsors"]:
		var button := MenuStyle.tab(category.capitalize(),_choose_sticker_category.bind(category),category == _sticker_category)
		button.name = "StickerCategory_"+category
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		categories.add_child(button)
	var gallery := GridContainer.new()
	gallery.name = "StickerGallery"
	gallery.columns = 3
	gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery.add_theme_constant_override("h_separation",6)
	gallery.add_theme_constant_override("v_separation",6)
	content.add_child(gallery)
	for index: int in range(LiveryCatalog.stickers.size()):
		var sticker: Dictionary = LiveryCatalog.stickers[index]
		if sticker.category != _sticker_category: continue
		var tile: LiveryTile = LiveryTile.make(sticker.title,LiveryCatalog.texture(sticker.id+"_sticker"),page._choose_sticker.bind(index+1),true)
		tile.name = "Sticker_"+sticker.id
		tile.custom_minimum_size = Vector2(82,92)
		var label: Label = tile.get_child(0).get_child(0).get_child(1)
		label.add_theme_font_size_override("font_size",14)
		gallery.add_child(tile)
		sticker_tiles[sticker.id] = tile
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	content.add_child(footer)
	var place := MenuStyle.button("Place sticker",page._edit_sticker_position.bind(true),true)
	place.name = "PlaceSticker"
	place.custom_minimum_size.y = 48
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(place)
	var clear := MenuStyle.button("",page._choose_sticker.bind(0))
	clear.name = "RemoveSticker"
	clear.icon = MenuIcon.texture("delete")
	clear.expand_icon = true
	clear.add_theme_constant_override("icon_max_width",22)
	clear.tooltip_text = "Remove sticker"
	clear.custom_minimum_size = Vector2(48,48)
	footer.add_child(clear)

func _choose_sticker_category(category: String) -> void:
	if category not in ["emblems","sponsors"]: return
	_sticker_category = category
	page._sticker_editing = false
	show_tab("stickers")

func refresh() -> void:
	var selected_index: int = page._preset_index()
	# A custom colour retains the design's selected card.
	if page.draft.pattern != "plain": selected_index = GaragePage.LIVERY_NAMES.size()+LiveryCatalog.pattern_index(page.draft.pattern)
	else: selected_index = 0 # Custom plain colours still belong to Midnight's design.
	for index: int in pattern_tiles: pattern_tiles[index].set_selected(index == selected_index)
	for slot: String in slot_buttons:
		var button: LiveryColourChip = slot_buttons[slot]
		button.colour = Color(str(page.draft.colors[slot]))
		button.selected = slot == page._colour_slot
		button.queue_redraw()
	for chip: LiveryColourChip in colour_chips:
		chip.selected = chip.colour.to_html(false) == page.draft.colors[page._colour_slot]
		chip.queue_redraw()
	for slot: String in page.pickers: page.pickers[slot].visible = slot == page._colour_slot
	for id: String in sticker_tiles: sticker_tiles[id].set_selected(id == page.draft.stickers[page._sticker_surface].id)
	for button_name: String in ["PlaceSticker","RemoveSticker"]:
		var button: BaseButton = _content.find_child(button_name,true,false)
		if button != null: button.disabled = page.draft.stickers[page._sticker_surface].id == "none"

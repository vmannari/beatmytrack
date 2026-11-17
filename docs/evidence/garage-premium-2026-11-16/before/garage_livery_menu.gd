class_name GarageLiveryMenu
extends VBoxContainer
## Native sidebar workbench. Browsing uses offline model renders only.
const PALETTE: Array[String] = [
	"ebe3d0","c1c9cb","7b8d96","253747","121b24",
	"317573","50734f","b8a170","d6ab50","cc7448",
	"a44844","764654","9b879e","67849e","b9c8bb",
	"3f62b2","6945a0","cf6f91","72b8a3","8b573b"]
const Studio = preload("res://ui/garage_studio_style.gd")
var page: GaragePage
var pattern_tiles: Dictionary = {}
var sticker_tiles: Dictionary = {}
var slot_buttons: Dictionary = {}
var colour_chips: Array[LiveryColourChip] = []
var slider_labels: Dictionary = {}
var active_picker: Control
var pattern_scroll: ScrollContainer
var pattern_shelf: VBoxContainer
var pattern_icons: Node
var _tabs: Dictionary = {}
var _contents: Dictionary = {}
var _content: VBoxContainer
var _editing_content: VBoxContainer
var colour_pickers: Dictionary = {}

func _ready() -> void:
	name = "GarageLiveryWorkbench"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	var reset := MenuStyle.button("",page._reset)
	reset.name = "ResetLivery"
	reset.icon = MenuIcon.texture("restart")
	reset.expand_icon = true
	reset.add_theme_constant_override("icon_max_width",21)
	reset.custom_minimum_size = Vector2(52,52)
	reset.tooltip_text = "Reset livery"
	page._studio_header(self,reset)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",4)
	add_child(tabs)
	for entry: Array in [["livery","Patterns"],["colours","Colours"],["stickers","Stickers"]]:
		var tab: Button = MenuStyle.tab(entry[1],page._set_customise_tab.bind(entry[0]),page._customise_tab == entry[0])
		tab.name = "LiveryMenu_"+entry[0]
		_tabs[entry[0]] = tab
		tab.custom_minimum_size = Vector2(88,52)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",20)
		Studio.tab(tab,page._customise_tab == entry[0])
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
		Studio.tab(button,id==tab)
	for root: Control in _contents.values(): root.hide()
	if is_instance_valid(_editing_content):
		remove_child(_editing_content)
		_editing_content.queue_free()
		_editing_content = null
	var editing: bool = tab=="stickers" and page._sticker_editing
	var key: String = tab+"/"+page._sticker_surface if tab=="stickers" else tab
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
	page._workbench_focus_pending = true

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
	pattern_shelf = preload("res://ui/garage_parts_list.gd").new()
	pattern_shelf.caption_row.hide() # The existing Appearance header owns the wallet.
	pattern_shelf.heading.get_parent().hide() # Patterns need no category heading or selection counter.
	_content.add_child(pattern_shelf)
	pattern_shelf.equip.pressed.connect(page._equip_cosmetic_preview)
	pattern_scroll = pattern_shelf.scroll
	pattern_scroll.name = "LiveryPatternGallery"
	pattern_icons = preload("res://ui/garage_paint_icons.gd").new()
	pattern_icons.scroll = pattern_scroll
	pattern_shelf.add_child(pattern_icons)
	pattern_scroll.resized.connect(_reveal_pattern,CONNECT_DEFERRED)
	pattern_scroll.get_v_scroll_bar().changed.connect(_reveal_pattern,CONNECT_DEFERRED)
	pattern_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _queue_pattern_icons.call_deferred())
	var grid: GridContainer = pattern_shelf.cards
	grid.resized.connect(_reveal_pattern,CONNECT_DEFERRED)
	for index: int in range(page._preset_count()):
		var plain_count: int = GaragePage.LIVERY_NAMES.size()
		var title: String = GaragePage.LIVERY_NAMES[index] if index<plain_count else LiveryCatalog.patterns[index-plain_count].title
		var key: String = GaragePage.LIVERY_NAMES[index].to_lower() if index<plain_count else LiveryCatalog.patterns[index-plain_count].id
		var row := preload("res://ui/garage_part_option.gd").new()
		row.setup(index,[key,title],"Two-tone paint" if index<plain_count else "Graphic paint scheme",page._preview_livery.bind(index))
		row.name = "Pattern_"+key
		row.add_car_icon()
		row.set_meta("livery_index",index)
		row.set_meta("pattern_title",title)
		grid.add_child(row)
		pattern_tiles[index] = row
		row.focus_entered.connect(_reveal_pattern,CONNECT_DEFERRED)
	_queue_pattern_icons.call_deferred()

func _reveal_pattern() -> void:
	if page.section!="customise" or page._customise_tab!="livery" or not is_visible_in_tree(): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and pattern_scroll.is_ancestor_of(focused):
		pattern_scroll.ensure_control_visible(focused)
	else:
		for row: Button in pattern_tiles.values():
			if row.selected:
				pattern_scroll.ensure_control_visible(row)
				break
	_queue_pattern_icons.call_deferred()

func _queue_pattern_icons() -> void:
	if not is_instance_valid(pattern_scroll) or not is_instance_valid(pattern_icons): return
	var active: bool = page.section=="customise" and page._customise_tab=="livery" and pattern_scroll.is_visible_in_tree()
	for index: int in pattern_tiles:
		var row: Button = pattern_tiles[index]
		if active and pattern_scroll.get_global_rect().intersects(row.get_global_rect()):
			var paint: Dictionary = option_livery(index)
			pattern_icons.request(row,page.vehicle_id,paint,page.kit_draft)
		else:
			row.car_icon.texture = null
			row.icon_key = ""

func equipped_index() -> int:
	return 0 if page.draft.pattern=="plain" else GaragePage.LIVERY_NAMES.size()+LiveryCatalog.pattern_index(page.draft.pattern)

func option_livery(index: int) -> Dictionary:
	# The equipped design retains the player's saved palette and stickers.
	if index==equipped_index(): return page.draft.duplicate(true)
	var value: Dictionary = page._preset_value(index)
	value.stickers = page.draft.stickers.duplicate(true)
	return value

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
		button.accessibility_name = slot.capitalize()+" paint"
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
		chip.accessibility_name = "Paint "+pigment
		chip.custom_minimum_size = Vector2(50,52)
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
	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation",8)
	_content.add_child(panels)
	for panel: String in VehicleLivery.SURFACES:
		if panel == "roof" and not LiveryCatalog.has_roof(page.vehicle_id): continue
		var button := MenuStyle.tab(LiveryCatalog.sticker_label(page.vehicle_id,panel),page._choose_sticker_surface.bind(panel),panel == page._sticker_surface)
		button.name = "Sticker"+panel.capitalize()
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panels.add_child(button)
	# Only the artwork scrolls. Panel choices and placement actions stay in view.
	var scroll: ScrollContainer = _scroll()
	scroll.name = "StickerGalleryScroll"
	var gallery := GridContainer.new()
	gallery.name = "StickerGallery"
	gallery.columns = 3
	gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery.add_theme_constant_override("h_separation",6)
	gallery.add_theme_constant_override("v_separation",6)
	scroll.add_child(gallery)
	for index: int in range(LiveryCatalog.stickers.size()):
		var sticker: Dictionary = LiveryCatalog.stickers[index]
		var tile: LiveryTile = LiveryTile.make(sticker.title,LiveryCatalog.texture(sticker.id+"_sticker"),page._choose_sticker.bind(index+1),true)
		tile.name = "Sticker_"+sticker.id
		tile.custom_minimum_size = Vector2(82,92)
		var label: Label = tile.get_child(0).get_child(0).get_child(1)
		label.add_theme_font_size_override("font_size",14)
		gallery.add_child(tile)
		sticker_tiles[sticker.id] = tile
	var footer := HBoxContainer.new()
	footer.name = "StickerActions"
	footer.add_theme_constant_override("separation",8)
	_content.add_child(footer)
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

func refresh() -> void:
	var selected_index: int = equipped_index()
	var preview_index: int = int(page._cosmetic_preview.get("index",selected_index))
	var previewing: bool = page._cosmetic_preview.get("kind","")=="livery"
	for index: int in pattern_tiles:
		var row: Button = pattern_tiles[index]
		var item: String = "livery/"+str(page._preset_value(index).pattern)
		var equipped: bool = index==selected_index
		var owned: bool = equipped or page.economy==null or page.economy.owns(item)
		var cost: int = 0 if page.economy==null else page.economy.price(item)
		row.present(index==preview_index,equipped,owned,cost,previewing and index==preview_index)
		if index==preview_index:
			pattern_shelf.show_choice(str(row.get_meta("pattern_title")),not previewing,owned,cost,index,pattern_tiles.size(),"Patterns")
	if page.section=="customise" and page._customise_tab=="livery" and is_visible_in_tree():
		page._preview_hint.hide()
		_reveal_pattern.call_deferred()
	_queue_pattern_icons.call_deferred()
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

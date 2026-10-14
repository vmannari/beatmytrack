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
		tab.custom_minimum_size = Vector2(88,44)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size",20)
		for state: String in ["normal","hover","pressed"]:
			var style := MenuStyle.box(Color("213543") if page._customise_tab == entry[0] else Color("101f2b"),6)
			style.set_corner_radius_all(7)
			tab.add_theme_stylebox_override(state,style)
		tabs.add_child(tab)
	match page._customise_tab:
		"colours": _colours()
		"stickers": _stickers()
		_: _patterns()
	refresh()

func _scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	add_child(scroll)
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
		var title: String = GaragePage.LIVERY_NAMES[index] if index < 4 else LiveryCatalog.patterns[index-4].title
		var key: String = GaragePage.LIVERY_NAMES[index].to_lower() if index < 4 else LiveryCatalog.patterns[index-4].id
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
		page._build_sticker_tools(self)
		return
	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation",8)
	add_child(panels)
	for panel: String in VehicleLivery.SURFACES:
		if panel == "roof" and not LiveryCatalog.has_roof(page.vehicle_id): continue
		var button := MenuStyle.tab(panel.capitalize(),page._choose_sticker_surface.bind(panel),panel == page._sticker_surface)
		button.name = "Sticker"+panel.capitalize()
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panels.add_child(button)
	var scroll: ScrollContainer = _scroll()
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	var gallery := GridContainer.new()
	gallery.name = "StickerGallery"
	gallery.columns = 3
	gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery.add_theme_constant_override("h_separation",6)
	gallery.add_theme_constant_override("v_separation",6)
	content.add_child(gallery)
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
	footer.add_theme_constant_override("separation",8)
	add_child(footer)
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
	var selected_index: int = page._preset_index()
	# A custom colour retains the design's selected card.
	if page.draft.pattern != "plain": selected_index = 4+LiveryCatalog.pattern_index(page.draft.pattern)
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
		var button: BaseButton = find_child(button_name,true,false)
		if button != null: button.disabled = page.draft.stickers[page._sticker_surface].id == "none"

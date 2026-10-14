class_name ObjectBrowser
extends PanelContainer
signal asset_chosen(kind: String)
signal mode_chosen(mode: String)
signal size_chosen(scale: float)
signal span_chosen(span: float)
signal container_color_chosen(color: String)
signal select_requested
signal populate_requested
var category: String = "All"
var biome: String = "pine"
var current: String = "tree"
var placement: String = "single"
var stamp_scale: float = 1.0
var stamp_span: float = 8.0
var stamp_container_color: String = ContainerPaint.DEFAULT
var recent: Array[String] = []
var tiles: HBoxContainer
var details: VBoxContainer
var options: PopupPanel
var categories: HBoxContainer
var page: int = 0
var previous: Button
var next: Button
var page_size: int = 6
var _tile_key: Array = []
var _detail_key: Array = []
var _styled_category: String = ""

func _ready() -> void:
	name = "ObjectBrowser"
	add_theme_stylebox_override("panel",EditorStyle.panel())
	var column := VBoxContainer.new()
	add_child(column)
	var top := HBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	column.add_child(top)
	categories = _scroll_row(top)
	for value: String in ["All","Recent"]+CreatorCatalog.CATEGORIES:
		var button: Button = _button(value,func() -> void:
			category = value; page = 0; _tiles())
		button.name = "Category_"+value
		categories.add_child(button)
	var populate: Button = _button("Populate",func() -> void: populate_requested.emit())
	populate.name = "PopulateObjects"
	populate.custom_minimum_size = Vector2(100,44)
	top.add_child(populate)
	var paging := HBoxContainer.new()
	column.add_child(paging)
	previous=EditorButton.make("","back",func() -> void: page-=1; _tiles())
	previous.name="PreviousObjects"
	previous.tooltip_text="Previous objects"
	previous.custom_minimum_size=Vector2(44,82)
	paging.add_child(previous)
	tiles = _scroll_row(paging)
	tiles.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tiles.alignment=BoxContainer.ALIGNMENT_BEGIN
	next=EditorButton.make("","next",func() -> void: page+=1; _tiles())
	next.name="NextObjects"
	next.tooltip_text="Next objects"
	next.custom_minimum_size=Vector2(44,82)
	paging.add_child(next)
	resized.connect(func() -> void:
		var count: int=maxi(1,int((size.x-120)/110))
		if count!=page_size: page_size=count; page=0; _tiles())
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree(): _tiles())
	options=PopupPanel.new()
	options.name="ObjectOptionsPopup"
	options.add_theme_stylebox_override("panel",EditorStyle.panel())
	add_child(options)
	preload("res://ui/popup_style.gd").watch(options)
	details=VBoxContainer.new()
	details.add_theme_constant_override("separation",8)
	options.add_child(details)
	refresh()

func _scroll_row(parent: Node) -> HBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	scroll.add_child(row)
	return row

func _button(text: String, action: Callable) -> Button:
	return EditorStyle.button(text,action)

func _clear(row: Node) -> void:
	for child: Node in row.get_children():
		row.remove_child(child); child.queue_free()

func choose(kind: String) -> void:
	current = kind
	var asset: Array = CreatorCatalog.family(kind)
	if not asset.is_empty():
		recent.erase(asset[0]); recent.push_front(asset[0]); recent.resize(mini(12,recent.size()))
	asset_chosen.emit(kind)
	refresh()

func _tiles() -> void:
	if tiles == null or not is_visible_in_tree(): return
	if _styled_category != category:
		_styled_category = category
		for button: Button in categories.get_children(): EditorStyle.apply(button,button.text==category)
	var entries: Array = CreatorCatalog.filtered(category,"",recent,biome)
	page = clampi(page,0,maxi(0,(entries.size()-1)/page_size))
	previous.visible=page>0
	next.visible=(page+1)*page_size<entries.size()
	var key: Array = [biome,category if entries.is_empty() else "",stamp_container_color]
	for index: int in range(page*page_size,mini(entries.size(),(page+1)*page_size)): key.append(entries[index][0])
	if key == _tile_key:
		for tile: Node in tiles.get_children():
			if not tile is Button: continue
			var family: Array = CreatorCatalog.family(tile.name.trim_prefix("Asset_"))
			var chosen: bool = not family.is_empty() and current in family[3]
			if tile.button_pressed == chosen: continue
			tile.set_pressed_no_signal(chosen)
			EditorStyle.card(tile,chosen)
		return
	_tile_key = key
	_clear(tiles)
	for index: int in range(page*page_size,mini(entries.size(),(page+1)*page_size)):
		var asset: Array = entries[index]
		tiles.add_child(ObjectThumbnail.make(asset[0],asset[1],current in asset[3],_activate_asset.bind(asset[0]),biome,stamp_container_color if asset[0] == "container" else ""))
	if entries.is_empty(): tiles.add_child(MenuStyle.label("No matching objects" if category!="Recent" else "Choose an object to add it here",16))

func refresh() -> void:
	if details == null: return
	_tiles()
	var key: Array = [current,placement,stamp_scale,stamp_span,biome,stamp_container_color]
	if key == _detail_key: return
	_detail_key = key
	_clear(details)
	var behavior: Label = MenuStyle.label(CreatorCatalog.behavior(current),14)
	behavior.name = "ObjectBehavior"
	details.add_child(behavior)
	var family: Array = CreatorCatalog.family(current)
	if not family.is_empty() and family[3].size()>1:
		var variants := OptionButton.new()
		variants.name = "ObjectVariant"
		EditorStyle.apply(variants)
		variants.custom_minimum_size = Vector2(125,40)
		for kind: String in family[3]: variants.add_item(CreatorCatalog.label(kind))
		variants.select(family[3].find(current))
		variants.item_selected.connect(func(index: int) -> void: choose(family[3][index]))
		details.add_child(variants)
	if current == "speed_bump":
		var width: Label = MenuStyle.label("Width: %.2f m" % stamp_span,16)
		details.add_child(width)
		var slider := HSlider.new()
		slider.name = "SpeedBumpWidth"
		slider.min_value = SpeedBumpEdit.MIN_SPAN
		slider.max_value = SpeedBumpEdit.MAX_SPAN
		slider.step = 0.25
		slider.value = stamp_span
		slider.custom_minimum_size = Vector2(280,48)
		slider.value_changed.connect(func(value: float) -> void:
			stamp_span = value
			width.text = "Width: %.2f m" % value
			span_chosen.emit(value))
		details.add_child(slider)
	elif current not in CreatorCatalog.LINES:
		var sizes := OptionButton.new()
		sizes.name = "ObjectSize"
		EditorStyle.apply(sizes)
		sizes.custom_minimum_size = Vector2(95,40)
		var presets: Array[float] = CreatorCatalog.size_presets(current)
		for title: String in (["8 m","16 m","24 m"] if current=="cliff" else ["Small","Medium","Large"]): sizes.add_item(title)
		sizes.select(0 if stamp_scale<presets[1] else 2 if stamp_scale>presets[1] else 1)
		sizes.item_selected.connect(func(index: int) -> void:
			stamp_scale = presets[index]; size_chosen.emit(stamp_scale))
		details.add_child(sizes)
	if current == "container":
		details.add_child(ContainerColorButton.make(stamp_container_color,func(color: String) -> void:
			stamp_container_color = color
			container_color_chosen.emit(color)
			refresh()))
	if current in CreatorCatalog.LINES:
		for mode: String in ["single","line","curve","road edge"]:
			var button: Button = _button(mode.capitalize(),func() -> void:
				placement=mode; mode_chosen.emit(mode); refresh())
			button.name="Placement_"+mode.replace(" ","_")
			EditorStyle.apply(button,placement==mode)
			details.add_child(button)

func _activate_asset(kind: String) -> void:
	var already_selected: bool=current==kind
	choose(kind)
	if already_selected:
		options.popup(Rect2i(Vector2i(get_global_rect().end-Vector2(330,360)),Vector2i(320,250)))

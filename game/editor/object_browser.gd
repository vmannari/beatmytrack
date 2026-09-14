class_name ObjectBrowser
extends PanelContainer
signal asset_chosen(kind: String)
signal mode_chosen(mode: String)
signal size_chosen(scale: float)
signal select_requested
var category: String = "All"
var query: String = ""
var biome: String = "pine"
var current: String = "tree"
var placement: String = "single"
var stamp_scale: float = 1.0
var recent: Array[String] = []
var tiles: HBoxContainer
var details: HBoxContainer
var categories: HBoxContainer
var page: int = 0

func _ready() -> void:
	name = "ObjectBrowser"
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035,0.065,0.075,0.96)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(8)
	add_theme_stylebox_override("panel",box)
	var column := VBoxContainer.new()
	add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var search := LineEdit.new()
	search.name = "ObjectSearch"
	search.placeholder_text = "Search objects..."
	search.text=query
	search.custom_minimum_size = Vector2(180,40)
	top.add_child(search)
	search.text_changed.connect(func(value: String) -> void:
		query = value; page = 0; _tiles())
	categories = _scroll_row(top)
	for value: String in ["All","Recent"]+CreatorCatalog.CATEGORIES:
		var button: Button = _button(value,func() -> void:
			category = value; page = 0; _tiles())
		button.name = "Category_"+value
		categories.add_child(button)
	tiles = _scroll_row(column)
	details = _scroll_row(column)
	refresh()

func _scroll_row(parent: Node) -> HBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	scroll.add_child(row)
	return row

func _button(text: String, action: Callable) -> Button:
	var button: Button = MenuStyle.button(text,action)
	button.custom_minimum_size = Vector2(64,40)
	button.add_theme_font_size_override("font_size",15)
	return button

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
	if tiles == null: return
	_clear(tiles)
	for button: Button in categories.get_children():
		button.modulate = EditorButton.CYAN if button.text == category else Color.WHITE
	var entries: Array = CreatorCatalog.filtered(category,query,recent,biome)
	page = clampi(page,0,maxi(0,(entries.size()-1)/8))
	if page>0: tiles.add_child(_button("<",func() -> void: page-=1; _tiles()))
	for index: int in range(page*8,mini(entries.size(),page*8+8)):
		var asset: Array = entries[index]
		tiles.add_child(ObjectThumbnail.make(asset[0],asset[1],current in asset[3],choose.bind(asset[0])))
	if (page+1)*8<entries.size(): tiles.add_child(_button("More >",func() -> void: page+=1; _tiles()))
	if entries.is_empty(): tiles.add_child(MenuStyle.label("No matching objects" if category!="Recent" else "Choose an object to add it here",16))

func refresh() -> void:
	if details == null: return
	_tiles()
	_clear(details)
	details.add_child(_button("Select / move",func() -> void: select_requested.emit()))
	var behavior: Label = MenuStyle.label(CreatorCatalog.behavior(current),14)
	behavior.name = "ObjectBehavior"
	details.add_child(behavior)
	var family: Array = CreatorCatalog.family(current)
	if not family.is_empty() and family[3].size()>1:
		var variants := OptionButton.new()
		variants.name = "ObjectVariant"
		variants.custom_minimum_size = Vector2(125,40)
		for kind: String in family[3]: variants.add_item(CreatorCatalog.label(kind))
		variants.select(family[3].find(current))
		variants.item_selected.connect(func(index: int) -> void: choose(family[3][index]))
		details.add_child(variants)
	if current not in CreatorCatalog.LINES:
		var sizes := OptionButton.new()
		sizes.name = "ObjectSize"
		sizes.custom_minimum_size = Vector2(95,40)
		for title: String in ["Small","Medium","Large"]: sizes.add_item(title)
		sizes.select(0 if stamp_scale<1 else 2 if stamp_scale>1 else 1)
		sizes.item_selected.connect(func(index: int) -> void:
			stamp_scale = [0.75,1.0,1.5][index]; size_chosen.emit(stamp_scale))
		details.add_child(sizes)
	if current in CreatorCatalog.LINES:
		for mode: String in ["single","line","curve","road edge"]:
			var button: Button = _button(mode.capitalize(),func() -> void:
				placement=mode; mode_chosen.emit(mode); refresh())
			button.name="Placement_"+mode.replace(" ","_")
			button.modulate = EditorButton.CYAN if placement==mode else Color.WHITE
			details.add_child(button)

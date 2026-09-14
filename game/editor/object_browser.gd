class_name ObjectBrowser
extends PanelContainer
signal asset_chosen(kind: String)
signal mode_chosen(mode: String)
signal size_chosen(scale: float)
signal select_requested
var category: String = "All"
var biome: String = "pine"
var current: String = "tree"
var placement: String = "single"
var stamp_scale: float = 1.0
var recent: Array[String] = []
var tiles: HBoxContainer
var details: VBoxContainer
var options: PopupPanel
var categories: HBoxContainer
var page: int = 0
var previous: Button
var next: Button
var page_size: int = 6

func _ready() -> void:
	name = "ObjectBrowser"
	add_theme_stylebox_override("panel",EditorStyle.box())
	var column := VBoxContainer.new()
	add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	categories = _scroll_row(top)
	for value: String in ["All","Recent"]+CreatorCatalog.CATEGORIES:
		var button: Button = _button(value,func() -> void:
			category = value; page = 0; _tiles())
		button.name = "Category_"+value
		categories.add_child(button)
	var settings: Button=EditorButton.make("","options",func() -> void:
		options.popup(Rect2i(Vector2i(get_global_rect().end-Vector2(330,360)),Vector2i(320,250))))
	settings.name="ObjectOptions"
	settings.tooltip_text="Object variants and placement"
	settings.custom_minimum_size=Vector2(40,38)
	top.add_child(settings)
	var paging := HBoxContainer.new()
	column.add_child(paging)
	previous=EditorButton.make("","back",func() -> void: page-=1; _tiles())
	previous.name="PreviousObjects"
	previous.tooltip_text="Previous objects"
	previous.custom_minimum_size=Vector2(44,88)
	paging.add_child(previous)
	tiles = _scroll_row(paging)
	next=EditorButton.make("","next",func() -> void: page+=1; _tiles())
	next.name="NextObjects"
	next.tooltip_text="Next objects"
	next.custom_minimum_size=Vector2(44,88)
	paging.add_child(next)
	resized.connect(func() -> void:
		var count: int=maxi(1,int((size.x-120)/110))
		if count!=page_size: page_size=count; page=0; _tiles())
	options=PopupPanel.new()
	options.name="ObjectOptionsPopup"
	options.add_theme_stylebox_override("panel",EditorStyle.box())
	add_child(options)
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
	if tiles == null: return
	_clear(tiles)
	for button: Button in categories.get_children():
		EditorStyle.apply(button,button.text==category)
	var entries: Array = CreatorCatalog.filtered(category,"",recent,biome)
	page = clampi(page,0,maxi(0,(entries.size()-1)/page_size))
	previous.disabled=page==0
	next.disabled=(page+1)*page_size>=entries.size()
	for index: int in range(page*page_size,mini(entries.size(),(page+1)*page_size)):
		var asset: Array = entries[index]
		tiles.add_child(ObjectThumbnail.make(asset[0],asset[1],current in asset[3],choose.bind(asset[0])))
	if entries.is_empty(): tiles.add_child(MenuStyle.label("No matching objects" if category!="Recent" else "Choose an object to add it here",16))

func refresh() -> void:
	if details == null: return
	_tiles()
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
	if current not in CreatorCatalog.LINES:
		var sizes := OptionButton.new()
		sizes.name = "ObjectSize"
		EditorStyle.apply(sizes)
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
			EditorStyle.apply(button,placement==mode)
			details.add_child(button)

class_name ObjectBrowser
extends PanelContainer
const Properties = preload("res://editor/object_properties.gd")
signal asset_chosen(kind: String)
signal mode_chosen(mode: String)
signal size_chosen(scale: float)
signal span_chosen(span: float)
signal container_color_chosen(color: String)
signal select_requested
signal populate_requested
signal rotation_requested
signal rotation_chosen(angle: float)
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
var options: Properties
var categories: HBoxContainer
var page: int = 0
var previous: Button
var next: Button
var page_size: int = 6
var _tile_key: Array = []
var _detail_key: Array = []
var _styled_category: String = ""
var rotation_button: Button
var stamp_rotation: float = 0.0
var properties_button: Button

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
	rotation_button = _button("",func() -> void: rotation_requested.emit())
	rotation_button.name = "ObjectRotation"
	rotation_button.tooltip_text = "16 orientations or Free rotation"
	rotation_button.custom_minimum_size = Vector2(76,44)
	properties_button = _button("Properties",open_properties)
	properties_button.name = "ObjectProperties"
	properties_button.custom_minimum_size = Vector2(170,44)
	top.add_child(properties_button)
	top.add_child(rotation_button)
	set_stamp_rotation(stamp_rotation)
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
		if is_visible_in_tree():
			if not CreatorCatalog.available(current,biome):
				var allowed: Array = CreatorCatalog.filtered("All","",[],biome)
				if not allowed.is_empty(): choose(allowed[0][0])
			_tiles())
	_make_options()
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

func set_stamp_rotation(value: float) -> void:
	stamp_rotation = value
	if is_instance_valid(rotation_button): rotation_button.text = preload("res://editor/object_rotation.gd").angle_text(value)

func _clear(row: Node) -> void:
	for child: Node in row.get_children():
		row.remove_child(child); child.queue_free()

func choose(kind: String) -> void:
	if not CreatorCatalog.available(kind,biome): return
	current = kind
	var asset: Array = CreatorCatalog.family(kind)
	if not asset.is_empty():
		recent.erase(asset[0]); recent.push_front(asset[0]); recent.resize(mini(12,recent.size()))
	asset_chosen.emit(kind)
	if CreatorCatalog.JUMP_ASSETS.has(kind) and is_instance_valid(options): options.hide()
	refresh()

func _tiles() -> void:
	if tiles == null or not is_visible_in_tree(): return
	if category not in ["All","Recent"] and CreatorCatalog.filtered(category,"",[],biome).is_empty(): category = "All"; page = 0
	for button: Button in categories.get_children(): button.visible = button.text in ["All","Recent"] or not CreatorCatalog.filtered(button.text,"",[],biome).is_empty()
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
			var chosen: bool = not family.is_empty() and (current == family[0] or current in family[3])
			if tile.button_pressed == chosen: continue
			tile.set_pressed_no_signal(chosen)
			EditorStyle.card(tile,chosen)
		return
	_tile_key = key
	_clear(tiles)
	for index: int in range(page*page_size,mini(entries.size(),(page+1)*page_size)):
		var asset: Array = entries[index]
		tiles.add_child(ObjectThumbnail.make(asset[0],asset[1],current == asset[0] or current in asset[3],_activate_asset.bind(asset[0]),biome,stamp_container_color if asset[0] == "container" else ""))
	if entries.is_empty(): tiles.add_child(MenuStyle.label("No matching objects" if category!="Recent" else "Choose an object to add it here",16))

func refresh() -> void:
	if not is_instance_valid(tiles): return
	_tiles()
	if is_instance_valid(properties_button):
		properties_button.text = GameText.message("%s ? Properties") % CreatorCatalog.label(current)
		properties_button.tooltip_text = "Size, orientation and placement settings"

func _properties_state() -> Dictionary:
	var profile: String = str(CreatorCatalog.JUMP_ASSETS.get(current,""))
	return {"kind":"jump" if not profile.is_empty() else current,"display_kind":current,"rotation":stamp_rotation,"scale":stamp_scale,
		"span":stamp_span,"placement":placement,"jump_profile":profile if not profile.is_empty() else JumpProfiles.default_for(biome),"color":stamp_container_color}

func _make_options() -> void:
	if is_instance_valid(options):
		remove_child(options)
		options.queue_free()
	options = Properties.new()
	options.state = _properties_state()
	options.edited.connect(_property_edited)
	add_child(options)
	details = options.body

func open_properties() -> void:
	_make_options()
	options.open(get_global_rect())

func _property_edited(property: String, value: Variant) -> void:
	match property:
		"kind":
			choose(str(value))
			open_properties.call_deferred()
		"scale":
			stamp_scale = float(value)
			size_chosen.emit(stamp_scale)
		"span":
			stamp_span = float(value)
			span_chosen.emit(stamp_span)
		"rotation":
			set_stamp_rotation(float(value))
			rotation_chosen.emit(stamp_rotation)
		"placement":
			placement = str(value)
			mode_chosen.emit(placement)
		"color":
			stamp_container_color = str(value)
			container_color_chosen.emit(stamp_container_color)
	refresh()

func _activate_asset(kind: String) -> void:
	if not CreatorCatalog.available(kind,biome): return
	var family: Array = CreatorCatalog.family(kind)
	if current == kind or (not family.is_empty() and current in family[3]):
		open_properties()
	else:
		choose(kind)

extends VBoxContainer
## Selected local draft and its editing/test/publication actions.
signal edit_requested(load_id: String)
signal test_requested(load_id: String)
signal publish_requested(load_id: String)
signal delete_requested(id: String, title: String)
signal back_requested

var library: TrackLibrary
var entries: Array[Dictionary] = []
var query: String = ""
var page: int = 0
var selection: Dictionary = {}
const PAGE_SIZE: int = 4
var gallery: HBoxContainer
var detail: PanelContainer
var count: Label
var previous: Button
var next: Button

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	entries = library.editable_entries()
	for item: Dictionary in entries: item.tested = library.is_tested(item.document)
	var header := HBoxContainer.new()
	add_child(header)
	var title := MenuStyle.label("LOAD TRACK",32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(MenuStyle.button("Back",func() -> void: back_requested.emit()))
	add_child(MenuStyle.label("Choose a draft to edit, test or publish.",18,true))
	var filters := HBoxContainer.new()
	add_child(filters)
	var search := LineEdit.new()
	search.name = "DraftSearch"
	search.placeholder_text = "Search drafts by name or biome…"
	search.custom_minimum_size.y = 54
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(search)
	count = MenuStyle.label("",16,true)
	filters.add_child(count)
	previous = MenuStyle.button("‹",func() -> void: page -= 1; _refresh())
	previous.custom_minimum_size.x = 54
	filters.add_child(previous)
	next = MenuStyle.button("›",func() -> void: page += 1; _refresh())
	next.custom_minimum_size.x = 54
	filters.add_child(next)
	gallery = HBoxContainer.new()
	gallery.name = "DraftGallery"
	gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery.add_theme_constant_override("separation",16)
	add_child(gallery)
	detail = PanelContainer.new()
	detail.name = "DraftActions"
	detail.custom_minimum_size.y = 148
	detail.add_theme_stylebox_override("panel",MenuStyle.card(14))
	add_child(detail)
	search.text_changed.connect(func(value: String) -> void: query = value; page = 0; _refresh())
	_refresh()

func _refresh() -> void:
	for child: Node in gallery.get_children():
		gallery.remove_child(child)
		child.queue_free()
	var matches: Array[Dictionary] = []
	for item: Dictionary in entries:
		var doc: Dictionary = item.document
		if query.is_empty() or (str(doc.name)+" "+TrackTheme.title(str(doc.theme))).to_lower().contains(query.to_lower()): matches.append(item)
	var pages: int = maxi(1,ceili(float(matches.size())/PAGE_SIZE))
	page = clampi(page,0,pages-1)
	count.text = "%d drafts  ·  %d / %d" % [matches.size(),page+1,pages]
	previous.disabled = page == 0
	next.disabled = page == pages-1
	var visible_entries: Array[Dictionary] = matches.slice(page*PAGE_SIZE,(page+1)*PAGE_SIZE)
	if visible_entries.is_empty():
		selection = {}
		var empty := MenuStyle.label("No drafts saved yet. Create a track to get started." if entries.is_empty() else "No drafts match your search.",24,true)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gallery.add_child(empty)
	else:
		if not visible_entries.has(selection): selection = visible_entries[0]
		for item: Dictionary in visible_entries: _card(item)
		for index: int in range(PAGE_SIZE-visible_entries.size()):
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gallery.add_child(spacer)
	_show_detail()

func _tile(item: Dictionary) -> TrackTile:
	var doc: Dictionary = item.document
	var tile := TrackTile.new()
	tile.name = "Draft_"+str(doc.id)
	tile.draft_mode = true
	tile.entry = {"name":doc.name,"creator":doc.get("creator",""),"theme":doc.theme,"pieces":doc.pieces,"points":[],
		"draft_status":_counts(doc),"tested":item.tested}
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return tile

func _card(item: Dictionary) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",4)
	gallery.add_child(column)
	var tile: TrackTile = _tile(item)
	tile.selected = selection == item
	tile.pressed.connect(func() -> void: selection = item; _refresh())
	column.add_child(tile)
	tile.custom_minimum_size.y = 190
	column.add_child(MenuStyle.label("Last saved  "+_stamp(item),14,true))

func _show_detail() -> void:
	for child: Node in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	detail.visible = not selection.is_empty()
	if selection.is_empty(): return
	var item: Dictionary = selection
	var doc: Dictionary = item.document
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	detail.add_child(row)
	var preview: TrackTile = _tile(item)
	preview.preview_only = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.focus_mode = Control.FOCUS_NONE
	row.add_child(preview)
	preview.custom_minimum_size = Vector2(140,110)
	preview.size_flags_horizontal = Control.SIZE_FILL
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size.x = 190
	info.add_theme_constant_override("separation",4)
	row.add_child(info)
	var title := MenuStyle.label(str(doc.name).to_upper(),26)
	title.clip_text = true
	title.tooltip_text = str(doc.name)
	info.add_child(title)
	info.add_child(MenuStyle.label(TrackTheme.title(str(doc.theme))+" biome",15,true))
	info.add_child(MenuStyle.label("Last saved "+_stamp(item),14,true))
	info.add_child(MenuStyle.label(_counts(doc),14,true))
	var edit: Button = _action("Edit track","edit",func() -> void: edit_requested.emit(str(item.load_id)))
	edit.name = "ContinueEditing"
	edit.custom_minimum_size.x = 150
	row.add_child(edit)
	var test: Button = _action("Test drive","play",func() -> void: test_requested.emit(str(item.load_id)))
	test.name = "TestDraft"
	test.custom_minimum_size.x = 155
	row.add_child(test)
	var publish: Button = _action("Publish","publish",func() -> void: publish_requested.emit(str(item.load_id)),true)
	publish.name = "PublishDraft"
	publish.tooltip_text = "Upload to the backend, then complete five timed laps for server verification and publication."
	publish.custom_minimum_size.x = 252
	publish.disabled = not bool(item.tested)
	if publish.disabled:
		publish.text = "Publish\nComplete test run to publish"
		publish.add_theme_font_size_override("font_size",17)
		publish.add_theme_stylebox_override("disabled",MenuStyle.box(Color("30383f")))
		publish.add_theme_color_override("font_disabled_color",Color("aeb8bf"))
	row.add_child(publish)
	var remove: Button = _action("","delete",func() -> void: delete_requested.emit(str(doc.id),str(doc.name)))
	remove.name = "DeleteDraft"
	remove.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remove.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	remove.expand_icon = true
	remove.add_theme_constant_override("icon_max_width",28)
	remove.tooltip_text = "Delete draft"
	remove.custom_minimum_size = Vector2(64,64)
	remove.add_theme_stylebox_override("normal",MenuStyle.box(Color("8d233a")))
	remove.add_theme_stylebox_override("hover",MenuStyle.box(Color("b3314b")))
	row.add_child(remove)

func _action(caption: String, glyph: String, action: Callable, primary: bool = false) -> Button:
	var button := MenuStyle.button(caption,action,primary)
	button.icon = MenuIcon.texture(glyph)
	button.custom_minimum_size.y = 64
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if primary:
		button.add_theme_color_override("icon_normal_color",MenuStyle.INK)
		button.add_theme_color_override("icon_hover_color",MenuStyle.INK)
	return button

static func _counts(doc: Dictionary) -> String:
	return "%d road pieces  ·  %d objects" % [doc.pieces.size(),doc.objects.size()]

static func _stamp(item: Dictionary) -> String:
	if int(item.modified) <= 0: return "Unknown"
	var local_time: int = int(item.modified)+int(Time.get_time_zone_from_system().bias)*60
	return Time.get_datetime_string_from_unix_time(local_time,true).left(16)

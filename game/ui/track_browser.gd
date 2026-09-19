class_name TrackBrowser
extends VBoxContainer

signal race_requested(track: NativeTrack)
signal track_selected(track: NativeTrack)
signal edit_requested(document: Dictionary)
signal delete_requested(id: String, title: String)
signal import_requested
signal notice(message: String)

const PAGE_SIZE: int = 6
var library: TrackLibrary
var records: LocalRecords
var builtin_ids: Array[String]
var selected_track: NativeTrack
var state: Dictionary
var catalog: TrackCatalog
var matches: Array[Dictionary] = []
var grid: GridContainer
var detail: VBoxContainer
var count_label: Label
var page_label: Label
var previous: Button
var next: Button
var random_button: Button
var sections: Dictionary = {}
var loading: bool = true
var detail_costs: Dictionary = {}
var selecting: bool = false
var _resolve_thread: Thread
var _requested_entry: Dictionary = {}
var _working_entry: Dictionary = {}
var _selection_serial: int = 0
var _working_serial: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	rng.randomize()
	if catalog == null: catalog = TrackCatalog.new(library)
	var title_row := HBoxContainer.new()
	add_child(title_row)
	var title := MenuStyle.label("TRACKS",34)
	title_row.add_child(title)
	count_label = MenuStyle.label("Loading…",14,true)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.clip_text = true
	title_row.add_child(count_label)
	title_row.add_child(_compact_button("Import track",func() -> void: import_requested.emit()))
	title_row.add_child(_compact_button("Refresh",func() -> void:
		if loading or selecting: return
		catalog.indexed_revision = -1
		_load_catalog()))
	random_button = _compact_button("Surprise me",_random)
	random_button.icon = MenuIcon.texture("surprise")
	random_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	random_button.name = "RandomTrack"
	title_row.add_child(random_button)
	previous = _compact_button("‹",_page.bind(-1))
	previous.custom_minimum_size.x = 48
	previous.tooltip_text = "Previous page"
	title_row.add_child(previous)
	page_label = MenuStyle.label("",14,true)
	page_label.custom_minimum_size.x = 44
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(page_label)
	next = _compact_button("›",_page.bind(1))
	next.custom_minimum_size.x = 48
	next.tooltip_text = "Next page"
	title_row.add_child(next)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation",6)
	add_child(filters)
	for pair: Array in [["all","FOR YOU"],["favorites","FAVORITES"],["saved","MY TRACKS"]]:
		var id: String = pair[0]
		var button: Button = _compact_button(pair[1],func() -> void:
			state.section = id
			state.page = 0
			_refresh())
		button.name = "Filter_"+id
		sections[id] = button
		filters.add_child(button)
	for field: String in ["name","creator"]:
		var edit := LineEdit.new()
		edit.name = "Search_"+field
		edit.placeholder_text = "Track name…" if field == "name" else "Creator…"
		edit.text = str(state.get(field,""))
		edit.max_length = 80
		edit.clear_button_enabled = true
		edit.custom_minimum_size = Vector2(156,48)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.add_theme_font_size_override("font_size",16)
		filters.add_child(edit)
		edit.text_changed.connect(func(value: String) -> void:
			state[field] = value
			state.page = 0
			_refresh())
	var themes := OptionButton.new()
	themes.custom_minimum_size.y = 48
	themes.add_theme_font_size_override("font_size",16)
	themes.add_item("All biomes")
	for theme: String in TrackTheme.IDS: themes.add_item(TrackTheme.title(theme))
	themes.selected = (["all"]+TrackTheme.IDS).find(state.get("theme","all"))
	themes.item_selected.connect(func(index: int) -> void:
		state.theme = (["all"]+TrackTheme.IDS)[index]
		state.page = 0
		_refresh())
	filters.add_child(themes)
	var sorting := OptionButton.new()
	sorting.custom_minimum_size.y = 48
	sorting.add_theme_font_size_override("font_size",16)
	sorting.add_item("Name A–Z")
	sorting.add_item("Creator A–Z")
	sorting.selected = 1 if state.get("sort","name") == "creator" else 0
	sorting.item_selected.connect(func(index: int) -> void:
		state.sort = "name" if index == 0 else "creator"
		state.page = 0
		_refresh())
	filters.add_child(sorting)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 282
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	var selection := PanelContainer.new()
	selection.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var selection_style: StyleBoxFlat = MenuStyle.box(Color("0c202c"),12)
	selection_style.border_color = MenuStyle.BORDER
	selection_style.set_border_width_all(1)
	selection.add_theme_stylebox_override("panel",selection_style)
	row.add_child(selection)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation",6)
	selection.add_child(detail)
	_show_detail()
	call_deferred("_load_catalog")

func _compact_button(text: String, action: Callable) -> Button:
	var button: Button = MenuStyle.button(text,action)
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size",20)
	return button

func _load_catalog() -> void:
	if not is_inside_tree(): return
	if catalog.indexed_revision == library.revision:
		loading = false
		_refresh()
		_random_on_open()
		return
	loading = true
	catalog.clear_resolved()
	await get_tree().process_frame
	if not is_inside_tree(): return
	var revision: int = library.revision
	var slice_start: int = Time.get_ticks_usec()
	catalog.entries.clear()
	for index: int in range(builtin_ids.size()):
		catalog.add_builtin(builtin_ids[index])
		if Time.get_ticks_usec()-slice_start >= 3000:
			count_label.text = "Loading circuits  /  %d of %d" % [index+1,builtin_ids.size()]
			await get_tree().process_frame
			if not is_inside_tree(): return
			slice_start = Time.get_ticks_usec()
	_refresh()
	var ids: Array[String] = catalog.local_ids()
	for index: int in range(ids.size()):
		catalog.add_local(ids[index])
		if Time.get_ticks_usec()-slice_start >= 3000:
			count_label.text = "Indexing saved tracks  /  %d of %d" % [index+1,ids.size()]
			await get_tree().process_frame
			if not is_inside_tree(): return
			slice_start = Time.get_ticks_usec()
	loading = false
	catalog.indexed_revision = revision
	_refresh()
	_random_on_open()

func _random_on_open() -> void:
	if state.get("random_on_open",false):
		state.erase("random_on_open")
		_random()

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	if not is_instance_valid(grid): return
	matches = catalog.query(state,records.settings.get("favorites",[]))
	var pages: int = maxi(1,ceili(float(matches.size())/PAGE_SIZE))
	state.page = clampi(int(state.get("page",0)),0,pages-1)
	_clear(grid)
	for index: int in range(int(state.page)*PAGE_SIZE,mini(matches.size(),(int(state.page)+1)*PAGE_SIZE)):
		var entry: Dictionary = matches[index]
		var tile := TrackTile.new()
		tile.entry = entry
		tile.favorite = entry.id in records.settings.get("favorites",[])
		tile.selected = entry.id == selected_track.identity
		tile.name = "Track_"+str(entry.id)
		tile.pressed.connect(_select.bind(entry))
		grid.add_child(tile)
	if matches.is_empty():
		var empty := MenuStyle.label("No tracks found.\nTry another name or creator,\nor change your filters.",20,true)
		if state.get("section") == "favorites" and str(state.get("name","")).is_empty() and str(state.get("creator","")).is_empty():
			empty.text = "Your favorites start here.\nSelect a circuit and tap its star."
		empty.custom_minimum_size.y = 166
		grid.add_child(empty)
	count_label.text = "%d / %d circuits%s" % [matches.size(),catalog.entries.size()," · indexing…" if loading else ""]
	count_label.tooltip_text = "%d matching tracks out of %d in your library" % [matches.size(),catalog.entries.size()]
	page_label.text = "%d / %d" % [int(state.page)+1,pages]
	previous.disabled = int(state.page) == 0
	next.disabled = int(state.page) == pages-1
	random_button.disabled = matches.is_empty() or loading
	for id: String in sections:
		var active: bool = id == state.get("section","all")
		sections[id].add_theme_stylebox_override("normal",MenuStyle.box(MenuStyle.ACCENT if active else MenuStyle.PANEL))
		sections[id].add_theme_color_override("font_color",MenuStyle.INK if active else MenuStyle.MUTED)

func _page(direction: int) -> void:
	state.page = int(state.get("page",0))+direction
	_refresh()

func _random() -> void:
	var entry: Dictionary = TrackCatalog.random_entry(matches,selected_track.identity,rng)
	if entry.is_empty(): return
	state.page = matches.find(entry)/PAGE_SIZE
	_refresh()
	_select(entry)

func _select(entry: Dictionary) -> void:
	_selection_serial += 1
	_requested_entry = entry
	selecting = true
	# A new request replaces any pending request. The worker never touches UI,
	# live library state, or a track already used by the main thread.
	_clear(detail)
	detail.add_child(MenuStyle.label(str(entry.name).to_upper(),30))
	detail.add_child(MenuStyle.label("Loading track…",18,true))
	for tile: Node in grid.get_children():
		if tile is TrackTile:
			tile.selected = tile.entry.id == entry.id
			tile.queue_redraw()
	_start_selection()

func _start_selection() -> void:
	if _resolve_thread != null: return
	_working_entry = _requested_entry
	_working_serial = _selection_serial
	var cached: NativeTrack = catalog.cached_track(_working_entry)
	if cached != null:
		_finish_selection({"track":cached,"draft":{}})
		return
	_resolve_thread = Thread.new()
	var error: Error = _resolve_thread.start(_resolve_track.bind(library.directory,_working_entry.duplicate(true)))
	if error != OK:
		_resolve_thread = null
		selecting = false
		notice.emit("The track could not be loaded. Please try again.")

static func _resolve_track(directory: String, entry: Dictionary) -> Dictionary:
	var source := TrackLibrary.new(directory)
	if entry.source == "builtin": return {"track":NativeTrack.read(entry.path),"draft":{}}
	var draft: Dictionary = source.load_document(entry.local_id)
	return {"track":null if draft.is_empty() else TrackCompiler.compile(draft),"draft":draft}

func _process(_delta: float) -> void:
	if _resolve_thread == null or _resolve_thread.is_alive(): return
	var result: Dictionary = _resolve_thread.wait_to_finish()
	_resolve_thread = null
	if result.track != null: catalog.remember_track(_working_entry,result.track)
	if _working_serial != _selection_serial:
		_start_selection()
		return
	_finish_selection(result)

func _exit_tree() -> void:
	if _resolve_thread != null:
		_resolve_thread.wait_to_finish()
		_resolve_thread = null

func _finish_selection(result: Dictionary) -> void:
	selecting = false
	var track: NativeTrack = result.track
	if track == null:
		var draft: Dictionary = result.draft
		if not draft.is_empty():
			_clear(detail)
			var draft_title := MenuStyle.label(str(draft.name)+" - draft",23)
			draft_title.clip_text = true
			draft_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			draft_title.tooltip_text = draft_title.text
			detail.add_child(draft_title)
			var errors: Array[String] = TrackDocument.validate(draft)
			var issue := MenuStyle.label(errors[0] if not errors.is_empty() else "Track needs repair before driving.",18,true)
			issue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.add_child(issue)
			detail.add_child(MenuStyle.button("Edit draft",func() -> void: edit_requested.emit(draft)))
			_delete_button(draft)
			return
		notice.emit("This track could not be opened. Its saved route may need repair or reimporting.")
		return
	selected_track = track
	track_selected.emit(track)
	_show_detail()

func _show_detail() -> void:
	var began: int = Time.get_ticks_usec()
	_clear(detail)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation",20)
	detail_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(detail_row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",4)
	var preview_frame := Control.new()
	preview_frame.clip_contents = true
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.custom_minimum_size = Vector2(220,150)
	detail_row.add_child(preview_frame)
	detail_row.add_child(info)
	var setup_done: int = Time.get_ticks_usec()
	var preview := TrackShowroom.new()
	preview.track = selected_track
	MenuStyle.fill(preview)
	preview_frame.add_child(preview)
	var preview_done: int = Time.get_ticks_usec()
	var badge := PanelContainer.new()
	badge.position = Vector2(8,8)
	badge.add_theme_stylebox_override("panel",MenuStyle.box(Color("0c202ce8"),7))
	preview_frame.add_child(badge)
	badge.add_child(MenuStyle.label(TrackTheme.title(str(selected_track.metadata.get("theme","pine"))).to_upper(),13))
	var favorite: bool = selected_track.identity in records.settings.get("favorites",[])
	var favorite_button: Button = MenuStyle.button("",_favorite)
	favorite_button.icon = MenuIcon.texture("star_filled" if favorite else "star")
	favorite_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	favorite_button.name = "ToggleFavorite"
	favorite_button.tooltip_text = "Remove favorite" if favorite else "Save favorite"
	favorite_button.custom_minimum_size = Vector2(48,48)
	favorite_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	favorite_button.offset_left = -56
	favorite_button.offset_top = 8
	favorite_button.offset_right = -8
	favorite_button.offset_bottom = 56
	favorite_button.add_theme_color_override("icon_normal_color",MenuStyle.ACCENT if favorite else MenuStyle.TEXT)
	preview_frame.add_child(favorite_button)
	var favorite_done: int = Time.get_ticks_usec()
	var title := MenuStyle.label(str(selected_track.metadata.get("title",selected_track.metadata.get("name",selected_track.identity.replace("_"," ").to_upper()))).to_upper(),30)
	title.clip_text = true
	title.tooltip_text = title.text
	info.add_child(title)
	var source_author: Dictionary = catalog.source_metadata.get(selected_track.identity,{})
	var creator: String = str(selected_track.metadata.get("creator_document",{}).get("creator","Unknown creator")) if selected_track.metadata.has("creator_document") else str(source_author.get("creator",selected_track.metadata.get("creator","Unknown creator")))
	if source_author.get("creator_kind", "source") == "fictional": creator += " (fictional)"
	var byline := MenuStyle.label("by "+creator,15,true)
	byline.clip_text = true
	byline.tooltip_text = byline.text
	info.add_child(byline)
	var personal_best: float = records.best_for(selected_track,HandlingSelection.config())
	var info_done: int = Time.get_ticks_usec()
	var facts := HBoxContainer.new()
	info.add_child(facts)
	var format := VBoxContainer.new()
	format.add_theme_constant_override("separation",0)
	format.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_child(format)
	format.add_child(MenuStyle.label("RACE FORMAT",12,true))
	format.add_child(MenuStyle.label("5 LAPS",22))
	var best := VBoxContainer.new()
	best.add_theme_constant_override("separation",0)
	facts.add_child(best)
	best.add_child(MenuStyle.label("YOUR BEST / " + VehicleCatalog.CLASSES[VehicleCatalog.IDS.find(VehicleCatalog.selected)].to_upper(),12,true))
	var best_time := MenuStyle.label(MenuStyle.time_text(personal_best) if personal_best > 0.0 else "SET A TIME",22)
	best_time.name = "LibraryBestTime"
	best.add_child(best_time)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	info.add_child(actions)
	var race: Button = MenuStyle.button("DRIVE",func() -> void: race_requested.emit(selected_track),true)
	race.icon = MenuIcon.texture("arrow")
	race.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	race.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	race.name = "LibraryRace"
	race.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(race)
	if selected_track.metadata.has("creator_document"):
		actions.add_child(MenuStyle.button("Edit",func() -> void: edit_requested.emit(selected_track.metadata.creator_document.duplicate(true))))

		if selected_track.identity not in builtin_ids: _delete_button(selected_track.metadata.creator_document,actions)
	else:
		var remix: Button = MenuStyle.button("Remix",func() -> void: edit_requested.emit(TrackDocument.from_builtin(selected_track)))
		remix.name = "RemixTrack"
		actions.add_child(remix)
	detail_costs = {"setup":(setup_done-began)/1000.0,"preview":(preview_done-setup_done)/1000.0,"favorite":(favorite_done-preview_done)/1000.0,"info":(info_done-favorite_done)/1000.0,"actions":(Time.get_ticks_usec()-info_done)/1000.0}

func _favorite() -> void:
	var favorites: Array = records.settings.get("favorites",[]).duplicate()
	if selected_track.identity in favorites: favorites.erase(selected_track.identity)
	else: favorites.append(selected_track.identity)
	records.settings.favorites = favorites
	if records.save_records() != OK: notice.emit("Favorite could not be saved. Check available storage.")
	_show_detail()
	_refresh()


func _delete_button(draft: Dictionary, parent: Node = null) -> void:
	var button: Button = MenuStyle.button("Delete track",func() -> void: delete_requested.emit(str(draft.id),str(draft.name)))
	button.name = "DeleteUserTrack"
	(parent if parent != null else detail).add_child(button)

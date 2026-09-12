class_name TrackBrowser
extends VBoxContainer

signal race_requested(track: NativeTrack)
signal track_selected(track: NativeTrack)
signal edit_requested(document: Dictionary)
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
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	rng.randomize()
	if catalog == null: catalog = TrackCatalog.new(library)
	var title_row := HBoxContainer.new()
	add_child(title_row)
	var title := MenuStyle.label("Find your next circuit.",34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(MenuStyle.button("Import track",func() -> void: import_requested.emit()))
	title_row.add_child(MenuStyle.button("Refresh",func() -> void:
		if loading: return
		catalog.indexed_revision = -1
		_load_catalog()))
	random_button = MenuStyle.button("Random track  ↗",_random,true)
	random_button.name = "RandomTrack"
	title_row.add_child(random_button)
	var filters := HBoxContainer.new()
	add_child(filters)
	for pair: Array in [["all","All tracks"],["favorites","★ Favorites"],["saved","Saved tracks"]]:
		var id: String = pair[0]
		var button: Button = MenuStyle.button(pair[1],func() -> void:
			state.section = id
			state.page = 0
			_refresh())
		button.name = "Filter_"+id
		sections[id] = button
		filters.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(spacer)
	var themes := OptionButton.new()
	themes.custom_minimum_size.y = 52
	for label: String in ["Every theme","Pine","Coast","Desert"]: themes.add_item(label)
	themes.selected = ["all","pine","coast","desert"].find(state.get("theme","all"))
	themes.item_selected.connect(func(index: int) -> void:
		state.theme = ["all","pine","coast","desert"][index]
		state.page = 0
		_refresh())
	filters.add_child(themes)
	var sorting := OptionButton.new()
	sorting.custom_minimum_size.y = 52
	sorting.add_item("Name A–Z")
	sorting.add_item("Creator A–Z")
	sorting.selected = 1 if state.get("sort","name") == "creator" else 0
	sorting.item_selected.connect(func(index: int) -> void:
		state.sort = "name" if index == 0 else "creator"
		state.page = 0
		_refresh())
	filters.add_child(sorting)
	var search := HBoxContainer.new()
	add_child(search)
	for field: String in ["name","creator"]:
		var edit := LineEdit.new()
		edit.name = "Search_"+field
		edit.placeholder_text = "Search by "+field+"…"
		edit.text = str(state.get(field,""))
		edit.max_length = 80
		edit.clear_button_enabled = true
		edit.custom_minimum_size.y = 52
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search.add_child(edit)
		edit.text_changed.connect(func(value: String) -> void:
			state[field] = value
			state.page = 0
			_refresh())
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	detail = VBoxContainer.new()
	detail.custom_minimum_size.x = 300
	row.add_child(detail)
	var footer := HBoxContainer.new()
	add_child(footer)
	count_label = MenuStyle.label("Loading your library…",16,true)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(count_label)
	previous = MenuStyle.button("Previous page",_page.bind(-1))
	footer.add_child(previous)
	page_label = MenuStyle.label("",16,true)
	footer.add_child(page_label)
	next = MenuStyle.button("Next page",_page.bind(1))
	footer.add_child(next)
	_show_detail()
	_load_catalog()

func _load_catalog() -> void:
	if catalog.indexed_revision == library.revision:
		loading = false
		_refresh()
		_random_on_open()
		return
	loading = true
	var revision: int = library.revision
	catalog.entries.clear()
	for index: int in range(builtin_ids.size()):
		catalog.add_builtin(builtin_ids[index])
		if index % 16 == 15:
			count_label.text = "Loading circuits  /  %d of %d" % [index+1,builtin_ids.size()]
			await get_tree().process_frame
			if not is_inside_tree(): return
	_refresh()
	var ids: Array[String] = catalog.local_ids()
	for index: int in range(ids.size()):
		catalog.add_local(ids[index])
		if index % 24 == 23:
			count_label.text = "Indexing saved tracks  /  %d of %d" % [index+1,ids.size()]
			await get_tree().process_frame
			if not is_inside_tree(): return
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
			empty.text = "Your favorites start here.\nSelect a track and tap Save favorite."
		empty.custom_minimum_size.y = 166
		grid.add_child(empty)
	count_label.text = "%d tracks  /  %d in library%s" % [matches.size(),catalog.entries.size(),"  ·  indexing…" if loading else ""]
	page_label.text = "%d / %d" % [int(state.page)+1,pages]
	previous.disabled = int(state.page) == 0
	next.disabled = int(state.page) == pages-1
	random_button.disabled = matches.is_empty() or loading
	for id: String in sections:
		var active: bool = id == state.get("section","all")
		sections[id].add_theme_stylebox_override("normal",MenuStyle.box(Color("40515a") if active else MenuStyle.PANEL))

func _page(direction: int) -> void:
	state.page = int(state.get("page",0))+direction
	_refresh()

func _random() -> void:
	var entry: Dictionary = TrackCatalog.random_entry(matches,selected_track.identity,rng)
	if entry.is_empty(): return
	state.page = matches.find(entry)/PAGE_SIZE
	_select(entry)

func _select(entry: Dictionary) -> void:
	var track: NativeTrack = catalog.resolve(entry)
	if track == null:
		notice.emit("This track could not be opened. Its saved route may need repair or reimporting.")
		return
	selected_track = track
	track_selected.emit(track)
	_show_detail()
	_refresh()

func _show_detail() -> void:
	_clear(detail)
	var preview := TrackShowroom.new()
	preview.track = selected_track
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size.y = 90
	detail.add_child(preview)
	var title := MenuStyle.label(str(selected_track.metadata.get("title",selected_track.metadata.get("name",selected_track.identity.trim_prefix("slicks_").trim_suffix("_test").to_upper()))),23)
	title.custom_minimum_size.x = 300
	title.clip_text = true
	detail.add_child(title)
	var source_author: Dictionary = catalog.source_metadata.get(selected_track.identity,{})
	var creator: String = str(selected_track.metadata.get("creator_document",{}).get("creator","Unknown creator")) if selected_track.metadata.has("creator_document") else str(source_author.get("creator",selected_track.metadata.get("creator","Unknown creator")))
	if source_author.get("creator_kind", "source") == "fictional": creator += " (fictional)"
	var byline := MenuStyle.label("by "+creator,16,true)
	byline.clip_text = true
	detail.add_child(byline)
	detail.add_child(MenuStyle.label("5 LAPS  /  "+str(selected_track.metadata.get("theme","pine")).to_upper(),15,true))
	var favorite: bool = selected_track.identity in records.settings.get("favorites",[])
	var favorite_button: Button = MenuStyle.button("★ Saved favorite" if favorite else "☆ Save favorite",_favorite)
	favorite_button.name = "ToggleFavorite"
	detail.add_child(favorite_button)
	var actions := HBoxContainer.new()
	detail.add_child(actions)
	var race: Button = MenuStyle.button("Race  →",func() -> void: race_requested.emit(selected_track),true)
	race.name = "LibraryRace"
	race.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(race)
	if selected_track.metadata.has("creator_document"):
		actions.add_child(MenuStyle.button("Edit",func() -> void: edit_requested.emit(selected_track.metadata.creator_document.duplicate(true))))

func _favorite() -> void:
	var favorites: Array = records.settings.get("favorites",[]).duplicate()
	if selected_track.identity in favorites: favorites.erase(selected_track.identity)
	else: favorites.append(selected_track.identity)
	records.settings.favorites = favorites
	if records.save_records() != OK: notice.emit("Favorite could not be saved. Check available storage.")
	_show_detail()
	_refresh()

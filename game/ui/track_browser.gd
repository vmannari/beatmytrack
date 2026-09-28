class_name TrackBrowser
extends VBoxContainer

signal home_requested
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
var discovery := TrackDiscoveryProvider.new()
var race_button: Button
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
	discovery.changed.connect(_discovery_changed)
	if catalog == null: catalog = TrackCatalog.new(library)
	var title_row := HBoxContainer.new()
	add_child(title_row)
	var title := MenuStyle.label("TRACKS",34)
	title_row.add_child(title)
	count_label = MenuStyle.label("Loading…",14,true)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.clip_text = true
	title_row.add_child(count_label)
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
	var discover := OptionButton.new()
	discover.name = "Discover"
	discover.custom_minimum_size = Vector2(170,48)
	for caption: String in ["Recommended","Trending","Friends","New","Rivals"]: discover.add_icon_item(MenuIcon.texture("compass"),caption)
	discover.add_theme_constant_override("icon_max_width",22)
	discover.selected = maxi(0,["recommended","trending","friends","new","rivals"].find(state.get("feed","recommended")))
	discover.item_selected.connect(func(index: int) -> void:
		state.section = "all"
		state.feed = ["recommended","trending","friends","new","rivals"][index]
		state.page = 0
		_refresh())
	filters.add_child(discover)
	sections["all"] = discover
	for pair: Array in [["favorites","Favorites"],["saved","My tracks"]]:
		var id: String = pair[0]
		var button: Button = _compact_button(pair[1],func() -> void:
			state.section = id
			state.page = 0
			_refresh())
		button.icon = MenuIcon.texture("star" if id == "favorites" else "person")
		button.name = "Filter_"+id
		sections[id] = button
		filters.add_child(button)
	for field: String in ["search"]:
		var edit := LineEdit.new()
		edit.name = "Search_"+field
		edit.placeholder_text = "Search tracks or creators..."
		edit.text = str(state.get(field,""))
		edit.max_length = 80
		edit.clear_button_enabled = true
		edit.right_icon = MenuIcon.texture("search")
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
	themes.add_icon_item(MenuIcon.texture("biomes"),"All biomes")
	for theme: String in TrackTheme.IDS: themes.add_icon_item(MenuIcon.texture("biomes"),TrackTheme.title(theme))
	themes.selected = (["all"]+TrackTheme.IDS).find(state.get("theme","all"))
	themes.item_selected.connect(func(index: int) -> void:
		state.theme = (["all"]+TrackTheme.IDS)[index]
		state.page = 0
		_refresh())
	filters.add_child(themes)
	var sorting := OptionButton.new()
	sorting.custom_minimum_size.y = 48
	sorting.add_theme_font_size_override("font_size",16)
	sorting.add_icon_item(MenuIcon.texture("sort"),"A-Z")
	sorting.add_icon_item(MenuIcon.texture("sort"),"User score")
	sorting.add_icon_item(MenuIcon.texture("sort"),"Playthroughs")
	sorting.selected = maxi(0,["name","score","plays"].find(state.get("sort","name")))
	sorting.item_selected.connect(func(index: int) -> void:
		state.sort = ["name","score","plays"][index]
		state.page = 0
		_refresh())
	filters.add_child(sorting)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 188
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
	_build_actions()
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
	catalog.add_shared_tracks()
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
	matches = discovery.query(catalog,state,records.settings.get("favorites",[]))
	var pages: int = maxi(1,ceili(float(matches.size())/PAGE_SIZE))
	state.page = clampi(int(state.get("page",0)),0,pages-1)
	_clear(grid)
	for index: int in range(int(state.page)*PAGE_SIZE,mini(matches.size(),(int(state.page)+1)*PAGE_SIZE)):
		var entry: Dictionary = matches[index]
		var tile := TrackTile.new()
		tile.entry = entry
		tile.favorite = entry.id in records.settings.get("favorites",[])
		tile.personal_rating = int(records.settings.get("track_ratings",{}).get(str(entry.id),0))
		tile.selected = entry.id == selected_track.identity
		tile.name = "Track_"+str(entry.id)
		tile.pressed.connect(_select.bind(entry))
		tile.favorite_requested.connect(_favorite_id.bind(str(entry.id)))
		grid.add_child(tile)
		tile.custom_minimum_size.y = 180
	if matches.is_empty():
		var empty := MenuStyle.label("No tracks found.\nTry another name or creator,\nor change your filters.",20,true)
		if state.get("section") == "favorites" and str(state.get("name","")).is_empty() and str(state.get("creator","")).is_empty():
			empty.text = "Your favorites start here.\nSelect a circuit and tap its star."
		if state.get("section","all") == "all" and state.get("feed","recommended") != "recommended" and not discovery.available:
			empty.text = "This discovery feed needs online data.\nYour local tracks are in Recommended."
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
		sections[id].add_theme_color_override("icon_normal_color",MenuStyle.INK if active else MenuStyle.MUTED)

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
	var cached: NativeTrack = catalog.cached_track(entry)
	if cached != null:
		# A cached choice must not wait behind a superseded cold compilation.
		_requested_entry = {}
		_finish_selection({"track":cached,"draft":{}})
		# Do not carry an unrelated menu worker into live racing.
		race_button.disabled = _resolve_thread != null
		for tile: Node in grid.get_children():
			if tile is TrackTile:
				tile.selected = tile.entry.id == entry.id
				tile.queue_redraw()
		return
	selecting = true
	race_button.disabled = true
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
	if _resolve_thread != null or _requested_entry.is_empty(): return
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
	var source := TrackLibrary.new(str(entry.get("library_directory", directory)))
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
		if _requested_entry.is_empty(): race_button.disabled = false
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
			detail.add_child(MenuStyle.label("Open Create to repair this draft.",18,true))
			return
		notice.emit("This track could not be opened. Its saved route may need repair or reimporting.")
		return
	selected_track = track
	track_selected.emit(track)
	_show_detail()

func _discovery_changed() -> void:
	_refresh()
	if not selecting: _show_detail()

func _build_actions() -> void:
	var actions := HBoxContainer.new()
	actions.name = "PlayActions"
	add_child(actions)
	var home := MenuStyle.button("Main menu",func() -> void: home_requested.emit())
	home.name = "PlayMainMenu"
	home.icon = MenuIcon.texture("home")
	home.custom_minimum_size = Vector2(180,56)
	actions.add_child(home)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.35
	actions.add_child(spacer)
	random_button = MenuStyle.button("Surprise me",_random)
	random_button.icon = MenuIcon.texture("dice")
	random_button.name = "RandomTrack"
	random_button.custom_minimum_size.x = 240
	actions.add_child(random_button)
	race_button = MenuStyle.button("RACE",func() -> void: race_requested.emit(selected_track),true)
	race_button.name = "LibraryRace"
	race_button.icon = MenuIcon.texture("arrow")
	race_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	race_button.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	race_button.add_theme_color_override("icon_hover_color",MenuStyle.INK)
	race_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	race_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	actions.add_child(race_button)

func _heading(parent: Control, caption: String, icon: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	parent.add_child(row)
	row.add_child(ResultsIcons.view(icon,20))
	var label := MenuStyle.label(caption,21,true)
	label.add_theme_font_override("font",MenuStyle.DISPLAY)
	row.add_child(label)

func _show_detail() -> void:
	_clear(detail)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",12)
	detail.add_child(row)
	var title: String = str(selected_track.metadata.get("title",selected_track.metadata.get("name",selected_track.identity))).to_upper()
	var theme_id: String = str(selected_track.metadata.get("theme","pine"))
	var preview := PanelContainer.new()
	preview.name = "SelectedTrackScenery"
	preview.custom_minimum_size.x = 260
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_stretch_ratio = 0.65
	preview.clip_contents = true
	preview.add_theme_stylebox_override("panel",MenuStyle.box(Color.TRANSPARENT,0))
	row.add_child(preview)
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(theme_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(art)
	var shade := MenuScrim.new()
	preview.add_child(shade)
	var inset := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+side,12)
	preview.add_child(inset)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation",4)
	inset.add_child(info)
	info.add_child(MenuStyle.label(TrackTheme.title(theme_id).to_upper(),13))
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(space)
	var name_label := MenuStyle.label(title,28)
	name_label.clip_text = true
	name_label.tooltip_text = title
	info.add_child(name_label)
	var creator := MenuStyle.label("by "+str(selected_track.metadata.get("creator_document",{}).get("creator",selected_track.metadata.get("creator","Unknown creator"))),14,true)
	creator.clip_text = true
	info.add_child(creator)
	var personal := VBoxContainer.new()
	personal.custom_minimum_size.x = 165
	personal.add_theme_constant_override("separation",2)
	row.add_child(personal)
	_heading(personal,"YOUR RECORDS","timer")
	var key: String = records.key_for(selected_track,HandlingSelection.config())
	var pb: Dictionary = records.records.get(key,{})
	var snapshot: Dictionary = discovery.record_snapshot(key)
	for metric: String in ["race","lap"]:
		if metric == "lap": personal.add_child(HSeparator.new())
		personal.add_child(MenuStyle.label("Best race time" if metric == "race" else "Best lap",14,true))
		var milliseconds: int = int(pb.get("race_ms" if metric == "race" else "flying_ms",0))
		var timer := MenuStyle.label(MenuStyle.time_text(milliseconds/1000.0) if milliseconds > 0 else "--",26)
		if metric == "race": timer.name = "LibraryBestTime"
		timer.add_theme_color_override("font_color",MenuStyle.ACCENT)
		personal.add_child(timer)
		var percentile: float = float(snapshot.get(metric+"_top_percent",-1))
		personal.add_child(MenuStyle.label("Top %d%%" % ceili(percentile) if percentile >= 0 else "Unranked",12,true))
	row.add_child(VSeparator.new())
	var distribution := VBoxContainer.new()
	distribution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distribution.size_flags_stretch_ratio = 1.4
	distribution.add_theme_constant_override("separation",8)
	row.add_child(distribution)
	_heading(distribution,"WHERE YOU STAND","bars")
	var charts := HBoxContainer.new()
	charts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	charts.add_theme_constant_override("separation",8)
	distribution.add_child(charts)
	for metric: String in ["race","lap"]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",MenuStyle.card(10))
		charts.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",4)
		card.add_child(column)
		_heading(column,"RACE TIME" if metric == "race" else "BEST LAP","timer")
		var percentile: float = float(snapshot.get(metric+"_top_percent",-1))
		column.add_child(MenuStyle.label("TOP %d%%" % ceili(percentile) if percentile >= 0 else "Unranked",13,true))
		var histogram := TrackDistribution.new()
		histogram.name = "RaceDistribution" if metric == "race" else "LapDistribution"
		histogram.snapshot = snapshot.get(metric+"_distribution",{})
		histogram.bar_color = Color("41667b") if metric == "race" else Color("42865d")
		histogram.custom_minimum_size = Vector2(164,84)
		histogram.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(histogram)
	row.add_child(VSeparator.new())
	var friends := VBoxContainer.new()
	friends.custom_minimum_size.x = 160
	friends.add_theme_constant_override("separation",8)
	row.add_child(friends)
	_heading(friends,"FRIENDS","friends")
	var standings: Array = snapshot.get("friends",[])
	var friend_space := Control.new()
	friend_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	friends.add_child(friend_space)
	if standings.is_empty():
		friends.add_child(ResultsIcons.view("friends",44))
		friends.add_child(MenuStyle.label("No friend records yet",13,true))
	else:
		for index: int in range(mini(3,standings.size())):
			var friend: Dictionary = standings[index]
			var line := MenuStyle.label("%s  %s" % [str(friend.player),MenuStyle.time_text(float(friend.race_ms)/1000)],12)
			line.clip_text = true
			friends.add_child(line)
	var challenge := MenuStyle.button("Challenge friends",func() -> void: notice.emit("Friend challenges are not connected yet."))
	challenge.icon = MenuIcon.texture("friends")
	challenge.add_theme_font_size_override("font_size",17)
	challenge.tooltip_text = "Friend challenges are not connected yet"
	friends.add_child(challenge)
	race_button.text = "RACE "+title
	race_button.disabled = false
	detail_costs = {"preview":0.0}

func _favorite() -> void:
	_favorite_id(selected_track.identity)

func _favorite_id(id: String) -> void:
	var favorites: Array = records.settings.get("favorites",[]).duplicate()
	if id in favorites: favorites.erase(id)
	else: favorites.append(id)
	records.settings.favorites = favorites
	if records.save_records() != OK: notice.emit("Favorite could not be saved. Check available storage.")
	_refresh()

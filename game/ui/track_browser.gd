class_name TrackBrowser
extends VBoxContainer

signal home_requested
signal race_requested(track: NativeTrack)
signal track_selected(track: NativeTrack)
signal edit_requested(document: Dictionary)
signal delete_requested(id: String, title: String)
signal import_requested
signal notice(message: String)

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
var random_button: Button
var discovery := TrackDiscoveryProvider.new()
var race_button: Button
var loading: bool = true
var detail_costs: Dictionary = {}
var selecting: bool = false
var preview_entry: Dictionary = {}
var pending_records: Label
var _resolve_thread: Thread
var _requested_entry: Dictionary = {}
var _working_entry: Dictionary = {}
var _selection_serial: int = 0
var _working_serial: int = 0
var rng := RandomNumberGenerator.new()
var cloud: Node
var cloud_status: Label
var gallery: ScrollContainer
var gallery_content: Control
const HERO_FADE_SECONDS: float = 0.42
var _slide_distance: float = 0.0
var _outgoing_panels: Array[Control] = []
var _outgoing_serial: int = -1
var _hero_direction: float = 1.0
var _section_motion: Tween
var _section_offset: float = 0.0
var records_panel: PanelContainer
var _hero_serial: int = -1
var _hero_scenery: Control
var _hero_art: TextureRect
var hero: PanelContainer
const FilterDrawer = preload("res://ui/track_filter_drawer.gd")
var filter_dialog: FilterDrawer
var filter_button: Button
const SearchDrawer = preload("res://ui/track_search_drawer.gd")
var search_dialog: SearchDrawer
var _tile_start: int = -1
var _query_signature: String = ""
var tile_stride: int = 202
var gallery_slot: Control

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	rng.randomize()
	discovery.changed.connect(_discovery_changed)
	if catalog == null: catalog = TrackCatalog.new(library)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_build_mode_rail(body)
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation",8)
	body.add_child(main)
	var hero_slot := Control.new()
	hero_slot.name = "HeroSlot"
	hero_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_slot.custom_minimum_size.y = 200
	hero_slot.clip_contents = true
	main.add_child(hero_slot)
	hero = PanelContainer.new()
	hero.name = "RaceHero"
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.custom_minimum_size.y = 0
	hero.clip_contents = true
	hero.add_theme_stylebox_override("panel",MenuStyle.box(Color.TRANSPARENT,0))
	hero_slot.add_child(hero)
	MenuStyle.fill(hero)
	var records_slot := Control.new()
	records_slot.name = "RecordsSlot"
	records_slot.custom_minimum_size.y = 160
	records_slot.clip_contents = true
	main.add_child(records_slot)
	var selection := PanelContainer.new()
	records_panel = selection
	selection.add_theme_stylebox_override("panel",MenuStyle.box(Color("091720dd"),12))
	records_slot.add_child(selection)
	MenuStyle.fill(selection)
	detail = VBoxContainer.new()
	selection.add_child(detail)
	pending_records = MenuStyle.label("",18,true)
	pending_records.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selection.add_child(pending_records)
	pending_records.hide()
	gallery_slot = Control.new()
	gallery_slot.name = "GallerySlot"
	gallery_slot.custom_minimum_size.y = 140
	gallery_slot.resized.connect(_layout_gallery)
	main.add_child(gallery_slot)
	gallery = preload("res://ui/track_carousel.gd").new()
	gallery.name = "TrackCarousel"
	gallery.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	gallery.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gallery.custom_minimum_size.y = 140
	gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery.scroll_deadzone = 12
	gallery.follow_focus = false
	gallery_slot.add_child(gallery)
	gallery_content = Control.new()
	gallery_content.custom_minimum_size.y = 140
	gallery.add_child(gallery_content)
	grid = GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation",12)
	gallery_content.add_child(grid)
	gallery.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void: _render_tiles())
	count_label = MenuStyle.label("Loading?",12,true)
	count_label.clip_text = true
	main.add_child(count_label)
	count_label.hide()
	_build_actions()
	get_node("PlayActions").reparent(main)
	filter_dialog = FilterDrawer.new()
	filter_dialog.catalog = catalog
	filter_dialog.discovery = discovery
	filter_dialog.records = records
	add_child(filter_dialog)
	filter_dialog.applied.connect(func(filters: Dictionary) -> void:
		state.merge(filters,true)
		_refresh()
		if cloud != null: cloud.search(state))
	filter_dialog.closed.connect(func() -> void: gallery.set_process_input(true))
	search_dialog = SearchDrawer.new()
	search_dialog.catalog = catalog
	search_dialog.discovery = discovery
	search_dialog.records = records
	add_child(search_dialog)
	search_dialog.applied.connect(func(search: Dictionary) -> void:
		state.merge(search,true)
		state.page = 0
		_refresh()
		if cloud != null: cloud.search(state))
	search_dialog.selected.connect(_select)
	search_dialog.closed.connect(func() -> void: gallery.set_process_input(true))
	if cloud != null:
		cloud.changed.connect(_cloud_changed)
		cloud_status = count_label
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
		if cloud != null: cloud.add_to_catalog(catalog,discovery,records.settings.get("favorites",[]))
		loading = false
		_refresh()
		_show_detail()
		_random_on_open()
		if cloud != null: cloud.refresh()
		return
	loading = true
	catalog.clear_resolved()
	await get_tree().process_frame
	if not is_inside_tree(): return
	var revision: int = library.revision
	var slice_start: int = Time.get_ticks_usec()
	catalog.entries.clear()
	if cloud != null:
		cloud.add_to_catalog(catalog,discovery,records.settings.get("favorites",[]))
		loading = false
		catalog.indexed_revision = revision
		_refresh()
		_show_detail()
		_random_on_open()
		cloud.refresh()
		return
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
	if cloud != null: cloud.add_to_catalog(catalog,discovery,records.settings.get("favorites",[]))
	loading = false
	catalog.indexed_revision = revision
	_refresh()
	_random_on_open()
	if cloud != null: cloud.refresh()

func _cloud_changed() -> void:
	cloud.add_to_catalog(catalog,discovery,records.settings.get("favorites",[]))
	if is_instance_valid(cloud_status): cloud_status.text = cloud.status
	_refresh()
	if not selecting:
		for entry: Dictionary in catalog.entries:
			if str(entry.id) == selected_track.identity and str(entry.get("version_id","")) != str(selected_track.metadata.get("cloud_version","")):
				_select(entry)
				return
		if not _selected_is_available(): _show_detail()

func _selected_is_available() -> bool:
	if cloud == null: return true
	return selected_track.metadata.has("cloud_version") and catalog.entries.any(func(entry: Dictionary) -> bool: return str(entry.id) == selected_track.identity)

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
	gallery.call("_stop_snap")
	matches = discovery.query(catalog,state,records.settings.get("favorites",[]),records.settings.get("track_ratings",{}),records.settings.get("raced_tracks",[]))
	var signature: String = str([state.get("section","all"),state.get("feed","recommended"),state.get("search",""),state.get("search_kind",0),state.get("theme","all"),state.get("sort","name"),state.get("minimum_rating",0.0),state.get("race_count","any")])
	if signature != _query_signature: gallery.scroll_horizontal = 0
	_query_signature = signature
	_tile_start = -1
	gallery_content.custom_minimum_size.x = maxi(1,matches.size()*tile_stride-12)
	_render_tiles()
	if matches.is_empty():
		var empty := MenuStyle.label("No tracks found.\nTry another name or creator,\nor change your filters.",20,true)
		if state.get("section") == "favorites" and str(state.get("name","")).is_empty() and str(state.get("creator","")).is_empty():
			empty.text = "Your favorites start here.\nSelect a circuit and tap its star."
		if state.get("section","all") == "all" and state.get("feed","recommended") != "recommended" and not discovery.available:
			empty.text = "This discovery feed needs online data.\nYour local tracks are in Recommended."
		empty.custom_minimum_size.y = 128
		grid.add_child(empty)
	count_label.text = "%d / %d circuits%s" % [matches.size(),catalog.entries.size()," · indexing…" if loading else ""]
	if cloud != null: count_label.text += " · "+str(cloud.status)
	count_label.tooltip_text = "%d matching tracks out of %d in your library" % [matches.size(),catalog.entries.size()]
	random_button.disabled = matches.is_empty() or loading
	var filter_count: int = FilterDrawer.active_count(state)
	filter_button.text = "Filters"+(" - %d" % filter_count if filter_count > 0 else "")
	filter_button.add_theme_color_override("font_color",MenuStyle.ACCENT if filter_count > 0 else MenuStyle.TEXT)
	filter_button.add_theme_color_override("icon_normal_color",MenuStyle.ACCENT if filter_count > 0 else MenuStyle.TEXT)
	if filter_dialog.visible: filter_dialog.refresh_choices()
	if search_dialog != null and search_dialog.visible: search_dialog.refresh_results()

func _render_tiles() -> void:
	if not is_instance_valid(grid): return
	var first: int = maxi(0,int(gallery.scroll_horizontal/tile_stride)-1)
	if first == _tile_start: return
	# Keep overlapping cards alive: scrolling one card must not rebuild twelve
	# buttons, resample every route and invalidate all their draw commands.
	if _tile_start == -1: _clear(grid)
	_tile_start = first
	var end: int = mini(matches.size(),first+12)
	var retained: Dictionary = {}
	for child: Node in grid.get_children():
		var index: int = int(child.get_meta("catalog_index",-1))
		if index < first or index >= end:
			grid.remove_child(child)
			child.queue_free()
		else: retained[index] = child
	grid.position.x = first*tile_stride+float(gallery.get("overscroll_offset"))
	for index: int in range(first,end):
		if retained.has(index):
			grid.move_child(retained[index],index-first)
			continue
		var entry: Dictionary = matches[index]
		var tile := TrackTile.new()
		tile.set_meta("catalog_index",index)
		tile.compact = true
		tile.entry = entry
		tile.favorite = entry.id in records.settings.get("favorites",[])
		tile.personal_rating = int(records.settings.get("track_ratings",{}).get(str(entry.id),0))
		tile.selected = entry.id == preview_entry.get("id",selected_track.identity)
		tile.name = "Track_"+str(entry.id)
		tile.pressed.connect(_select.bind(entry))
		tile.focus_entered.connect(_focus_card.bind(index))
		tile.favorite_requested.connect(_favorite_id.bind(str(entry.id)))
		grid.add_child(tile)
		grid.move_child(tile,index-first)
		tile.custom_minimum_size = Vector2(tile_stride-12,140)
		tile.size_flags_horizontal = Control.SIZE_FILL

func _layout_gallery() -> void:
	if not is_instance_valid(grid): return
	gallery.call("_stop_snap")
	var first: int = roundi(float(gallery.scroll_horizontal)/tile_stride)
	var slots: int = maxi(1,floori((gallery_slot.size.x+12.0)/202.0))
	tile_stride = floori((gallery_slot.size.x+12.0)/slots)
	gallery.position.x = (gallery_slot.size.x-(slots*tile_stride-12))*0.5
	gallery.size = Vector2(slots*tile_stride-12,140)
	gallery.set("snap_stride",tile_stride)
	gallery_content.custom_minimum_size.x = maxi(1,matches.size()*tile_stride-12)
	gallery.scroll_horizontal = first*tile_stride
	_tile_start = -1
	_render_tiles()

func _random() -> void:
	var entry: Dictionary = TrackCatalog.random_entry(matches,selected_track.identity,rng)
	if entry.is_empty(): return
	gallery.call("_stop_snap")
	gallery.scroll_horizontal = matches.find(entry)*tile_stride
	_select(entry)

func _select(entry: Dictionary) -> void:
	if cloud != null and cloud.client.has_method("cancel_public_reads"): cloud.client.cancel_public_reads(get_instance_id())
	var previous_id: String = str(preview_entry.get("id",selected_track.identity))
	var previous_index: int = -1
	var next_index: int = -1
	for index: int in range(matches.size()):
		if str(matches[index].id) == previous_id: previous_index = index
		if str(matches[index].id) == str(entry.id): next_index = index
	_hero_direction = -1.0 if previous_index >= 0 and next_index >= 0 and next_index < previous_index else 1.0
	_selection_serial += 1
	_requested_entry = {}
	var cached: NativeTrack = catalog.cached_track(entry)
	if cached != null:
		_finish_selection({"track":cached,"draft":{}})
		race_button.disabled = selecting or _resolve_thread != null
	else:
		selecting = true
		preview_entry = entry
		race_button.disabled = true
		race_button.text = "LOADING "+str(entry.name).to_upper()
		# Keep the complete previous section visible until the next one is ready.
		if _section_motion != null: _section_motion.kill()
		_clear_outgoing_section()
		_set_section_offset(0.0)
		hero.modulate.a = 1.0
		records_panel.modulate.a = 1.0
	for tile: Node in grid.get_children():
		if tile is TrackTile:
			tile.selected = tile.entry.id == entry.id
			tile.queue_redraw()
	if cached != null: return
	var serial: int = _selection_serial
	if entry.source == "cloud" and cloud != null:
		# Present the metadata before any disk validation or HTTP work.
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_inside_tree() or serial != _selection_serial: return
		var downloaded: bool = await cloud.download(entry)
		if not is_inside_tree() or serial != _selection_serial: return
		if not downloaded:
			selecting = false
			pending_records.text = "Track unavailable. Select it again to retry."
			notice.emit(cloud.last_error)
			return
	_requested_entry = entry
	_start_selection()

func _start_selection() -> void:
	if _resolve_thread != null or _requested_entry.is_empty(): return
	_working_entry = _requested_entry
	_requested_entry = {}
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
		pending_records.text = "Track unavailable. Select it again to retry."
		notice.emit("The track could not be loaded. Please try again.")

static func _resolve_track(directory: String, entry: Dictionary) -> Dictionary:
	if entry.source == "cloud": return {"track":preload("res://backend/cloud_tracks.gd").compile_entry(entry),"draft":{}}
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
		if _requested_entry.is_empty() and not selecting and preview_entry.is_empty(): race_button.disabled = not _selected_is_available()
		return
	_finish_selection(result)

func _exit_tree() -> void:
	_selection_serial += 1
	if cloud != null and cloud.client.has_method("cancel_public_reads"): cloud.client.cancel_public_reads(get_instance_id())
	if _resolve_thread != null:
		_resolve_thread.wait_to_finish()
		_resolve_thread = null

func _finish_selection(result: Dictionary) -> void:
	var track: NativeTrack = result.track
	if track == null:
		selecting = false
		var draft: Dictionary = result.draft
		if not draft.is_empty():
			pending_records.hide()
			detail.show()
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
		pending_records.text = "Track unavailable. Select it again to retry."
		notice.emit("This track could not be opened. Its saved route may need repair or reimporting.")
		return
	selected_track = track
	selecting = false
	preview_entry = {}
	pending_records.hide()
	detail.show()
	track_selected.emit(track)
	_show_detail()
	if cloud != null and track.metadata.has("cloud_version"):
		_load_cloud_detail(track) # Optional records hydrate after the playable selection.

func _load_cloud_detail(track: NativeTrack) -> void:
	var serial: int = _selection_serial
	cloud.client.cancel_public_reads(get_instance_id())
	var response: Dictionary = await cloud.client.request_public("/track-versions/"+str(track.metadata.cloud_version)+"/leaderboard?vehicle_id="+VehicleCatalog.selected.uri_encode(),get_instance_id())
	if not is_inside_tree() or track != selected_track or serial != _selection_serial: return
	var standings: Array = []
	if response.ok:
		for item: Dictionary in response.data.items:
			standings.append({"player":"%d. %s" % [int(item.rank),str(item.display_name)],"race_ms":float(item.time_ticks)*1000.0/120.0})
	var key: String = records.key_for(track,HandlingSelection.config())
	discovery.records_by_rules_key[key] = {"friends":standings,"board_error":"" if response.ok else str(response.error)}
	if response.ok and int(response.data.population) > 0:
		var board: String = str(response.data.board_id)
		var histogram: Dictionary = await cloud.client.request_public("/boards/"+board+"/histogram",get_instance_id())
		if not is_inside_tree() or track != selected_track or serial != _selection_serial: return
		if histogram.ok:
			var bins: Array = []
			for bin: Dictionary in histogram.data.bins: bins.append(int(bin.count))
			discovery.records_by_rules_key[key].race_distribution = {"bins":bins,"min_ms":float(histogram.data.minimum_ticks)*1000.0/120.0,"max_ms":float(histogram.data.maximum_ticks)*1000.0/120.0}
		if cloud.client.signed_in():
			var own: Dictionary = await cloud.client.request_api("/boards/"+board+"/around-me",HTTPClient.METHOD_GET,{},"",true)
			if not is_inside_tree() or track != selected_track or serial != _selection_serial: return
			if own.ok and own.data.player != null:
				discovery.records_by_rules_key[key].race_ms = float(own.data.player.time_ticks)*1000.0/120.0
				discovery.records_by_rules_key[key].race_rank = int(own.data.player.rank)
				discovery.records_by_rules_key[key].population = int(own.data.population)
				if own.data.faster_than_percent != null: discovery.records_by_rules_key[key].race_top_percent = 100.0-float(own.data.faster_than_percent)
				if histogram.ok:
					for index: int in range(histogram.data.bins.size()):
						var bin: Dictionary = histogram.data.bins[index]
						if int(own.data.player.time_ticks) >= int(bin.from_ticks) and int(own.data.player.time_ticks) < int(bin.to_ticks_exclusive): discovery.records_by_rules_key[key].race_distribution.player_bin = index
	if is_inside_tree() and serial == _selection_serial: _show_detail()

func _open_scores() -> void:
	var dialog := preload("res://ui/cloud_leaderboard.gd").new()
	dialog.client = cloud.client
	dialog.version = str(selected_track.metadata.cloud_version)
	dialog.vehicle = VehicleCatalog.selected
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _discovery_changed() -> void:
	_refresh()
	if not selecting: _show_detail()

func _build_actions() -> void:
	var actions := HBoxContainer.new()
	actions.name = "PlayActions"
	add_child(actions)
	random_button = MenuStyle.button("Random track",_random)
	random_button.icon = MenuIcon.texture("dice")
	random_button.name = "RandomTrack"
	actions.add_child(random_button)
	var filters := MenuStyle.button("Filters",func() -> void:
		gallery.call("_stop_snap")
		gallery.set_process_input(false)
		filter_dialog.open_for(state,filter_button))
	filter_button = filters
	filters.name = "RaceFilters"
	filters.icon = MenuIcon.texture("filter")
	actions.add_child(filters)
	var search := MenuStyle.button("Search",func() -> void:
		gallery.call("_stop_snap")
		gallery.set_process_input(false)
		search_dialog.open_for(state,find_child("RaceSearch",true,false)))
	search.name = "RaceSearch"
	search.icon = MenuIcon.texture("search")
	actions.add_child(search)
	for button: Button in [random_button,filters,search]:
		button.custom_minimum_size = Vector2(196,60)
		button.size_flags_horizontal = Control.SIZE_FILL
	race_button = MenuStyle.button("RACE",func() -> void: race_requested.emit(selected_track),true)
	race_button.name = "LibraryRace"
	race_button.icon = MenuIcon.texture("arrow")
	race_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	race_button.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	race_button.add_theme_color_override("icon_hover_color",MenuStyle.INK)
	race_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	race_button.clip_text = true
	race_button.custom_minimum_size = Vector2(240,60)
	race_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	actions.add_child(race_button)

func _heading(parent: Control, caption: String, icon: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	parent.add_child(row)
	var indent := Control.new()
	indent.custom_minimum_size.x = 4
	row.add_child(indent)
	row.add_child(ResultsIcons.view(icon,20))
	var label := MenuStyle.label(caption,21,true)
	label.add_theme_font_override("font",MenuStyle.DISPLAY)
	row.add_child(label)

func _show_detail() -> void:
	if selecting or not preview_entry.is_empty(): return
	if not _selected_is_available():
		_clear(detail)
		_show_hero("CHOOSE A TRACK","pine")
		detail.add_child(MenuStyle.label("Connect to load published tracks. Downloaded tracks remain available offline.",18,true))
		if is_instance_valid(race_button): race_button.disabled = true
		return
	_prepare_outgoing_section()
	_clear(detail)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",12)
	detail.add_child(row)
	var title: String = str(selected_track.metadata.get("title",selected_track.metadata.get("name",selected_track.identity))).to_upper()
	var theme_id: String = str(selected_track.metadata.get("theme","pine"))
	_show_hero(title,theme_id)
	var personal := VBoxContainer.new()
	personal.custom_minimum_size.x = 0
	personal.add_theme_constant_override("separation",2)
	_fixed_column(row,personal,"PersonalRecords",230)
	_heading(personal,"YOUR RECORDS","timer")
	var personal_body: VBoxContainer = _section_body(personal)
	var key: String = records.key_for(selected_track,HandlingSelection.config())
	var pb: Dictionary = records.records.get(key,{})
	var snapshot: Dictionary = discovery.record_snapshot(key)
	var best_ms: int = int(snapshot.get("race_ms",pb.get("race_ms",0)))
	if best_ms <= 0:
		var empty_time := MenuStyle.label("No time yet",18)
		empty_time.name = "LibraryBestTime"
		personal_body.add_child(empty_time)
		_friendly_hint(personal_body,"Set your first record and see how you perform.")
	else:
		personal_body.add_child(MenuStyle.label("Best race time",14,true))
		var timer := MenuStyle.label(MenuStyle.time_text(best_ms/1000.0),26)
		timer.name = "LibraryBestTime"
		timer.add_theme_color_override("font_color",MenuStyle.ACCENT)
		personal_body.add_child(timer)
		if snapshot.has("race_rank"):
			personal_body.add_child(MenuStyle.label("Rank %d of %d" % [int(snapshot.race_rank),int(snapshot.population)],12,true))
		elif float(snapshot.get("race_top_percent",-1)) >= 0:
			personal_body.add_child(MenuStyle.label("Top %d%%" % ceili(float(snapshot.race_top_percent)),12,true))
		if int(pb.get("flying_ms",0)) > 0:
			personal_body.add_child(MenuStyle.label("Best lap  "+MenuStyle.time_text(float(pb.flying_ms)/1000.0),16,true))
	row.add_child(VSeparator.new())
	var distribution := VBoxContainer.new()
	distribution.name = "RaceComparison"
	distribution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distribution.size_flags_stretch_ratio = 1.4
	distribution.add_theme_constant_override("separation",2)
	row.add_child(distribution)
	_heading(distribution,"WHERE YOU STAND","bars")
	var distribution_body: VBoxContainer = _section_body(distribution)
	var charts := HBoxContainer.new()
	charts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	charts.add_theme_constant_override("separation",8)
	distribution_body.add_child(charts)
	for metric: String in ["race"]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",MenuStyle.box(Color.TRANSPARENT,0))
		charts.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",4)
		card.add_child(column)
		var percentile: float = float(snapshot.get(metric+"_top_percent",-1))
		var rank_text: String = "TOP %d%%" % ceili(percentile) if percentile >= 0 else "Not ranked yet"
		if metric == "race" and snapshot.has("race_rank"): rank_text = "RANK %d / %d" % [int(snapshot.race_rank),int(snapshot.population)]
		column.add_child(MenuStyle.label(rank_text,13 if snapshot.has(metric+"_distribution") else 18, snapshot.has(metric+"_distribution")))
		var histogram := TrackDistribution.new()
		histogram.name = "RaceDistribution" if metric == "race" else "LapDistribution"
		histogram.snapshot = snapshot.get(metric+"_distribution",{}).duplicate(true)
		if histogram.snapshot.get("bins",[]).is_empty():
			histogram.hide()
			_friendly_hint(column,"Share this track and set a time to see how you compare." if not selected_track.metadata.has("cloud_version") else "Set a time to see how you compare.")
		histogram.bar_color = Color("41667b") if metric == "race" else Color("42865d")
		histogram.custom_minimum_size = Vector2(164,64)
		histogram.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(histogram)
	row.add_child(VSeparator.new())
	var friends := VBoxContainer.new()
	friends.custom_minimum_size.x = 0
	friends.add_theme_constant_override("separation",8)
	if selected_track.metadata.has("cloud_version"): friends.add_theme_constant_override("separation",2)
	_fixed_column(row,friends,"Standings",270)
	_heading(friends,"HIGH SCORES" if selected_track.metadata.has("cloud_version") else "FRIENDS","friends")
	var friends_body: VBoxContainer = _section_body(friends)
	var standings: Array = snapshot.get("friends",[])
	if standings.is_empty():
		friends_body.add_child(MenuStyle.label("No times yet" if selected_track.metadata.has("cloud_version") else "No friend times",18))
		_friendly_hint(friends_body,"Be the first to set a time!" if selected_track.metadata.has("cloud_version") else "Share this track and challenge a friend.")
	else:
		for index: int in range(mini(3,standings.size())):
			var friend: Dictionary = standings[index]
			var line := MenuStyle.label("%s  %s" % [str(friend.player),MenuStyle.time_text(float(friend.race_ms)/1000)],12)
			line.clip_text = true
			friends_body.add_child(line)
	if selected_track.metadata.has("cloud_version"):
		var actions := HBoxContainer.new()
		friends_body.add_child(actions)
		var scores_button := MenuStyle.button("High scores",_open_scores)
		scores_button.add_theme_font_size_override("font_size",18)
		scores_button.custom_minimum_size.y = 48
		actions.add_child(scores_button)
		var rate := MenuStyle.button("Rate",_open_rating)
		rate.add_theme_font_size_override("font_size",18)
		rate.custom_minimum_size.y = 48
		actions.add_child(rate)
		if not str(snapshot.get("board_error","")).is_empty(): scores_button.tooltip_text = "Scores unavailable - retry"
	race_button.text = "RACE "+title
	race_button.disabled = false
	detail_costs = {"preview":0.0}

func _open_rating() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Rate this track"
	add_child(dialog)
	var column := VBoxContainer.new()
	dialog.add_child(column)
	var rating := TrackRating.new()
	rating.records = records
	rating.track_id = selected_track.identity
	rating.cloud_client = cloud.client if cloud != null else null
	rating.cloud_version = str(selected_track.metadata.cloud_version)
	rating.cloud_sync = cloud
	column.add_child(rating)
	rating.caption.reparent(column)
	if cloud != null: rating.rated.connect(func() -> void: cloud.refresh(true))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _favorite() -> void:
	if selecting: return
	_favorite_id(str(preview_entry.get("id",selected_track.identity)))
	_show_hero(str(selected_track.metadata.get("title",selected_track.metadata.get("name",selected_track.identity))).to_upper(),str(selected_track.metadata.get("theme","pine")))

func _favorite_id(id: String) -> void:
	var favorites: Array = records.settings.get("favorites",[]).duplicate()
	if id in favorites: favorites.erase(id)
	else: favorites.append(id)
	records.settings.favorites = favorites
	if records.save_records() != OK: notice.emit("Favorite could not be saved. Check available storage.")
	_refresh()

func _build_mode_rail(parent: Control) -> void:
	var rail := VBoxContainer.new()
	rail.name = "RaceModes"
	rail.add_theme_constant_override("separation",12)
	parent.add_child(rail)
	for item: Array in [["trophy","Season"],["flag","Free race"],["target","Challenges"],["friends","Friends"]]:
		var active: bool = item[1] == "Free race"
		var button := MenuStyle.button("",func() -> void: pass,active)
		button.icon = preload("res://ui/race_mode_icons.gd").texture(item[0])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",38)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		button.add_theme_color_override("icon_normal_color",MenuStyle.INK if active else MenuStyle.TEXT)
		button.add_theme_color_override("icon_disabled_color",Color("9cbbc8"))
		var tile_style := MenuStyle.box(MenuStyle.ACCENT if active else Color("10212c"),10)
		tile_style.border_color = Color("ffe792") if active else Color("2a4655")
		tile_style.set_border_width_all(1)
		button.add_theme_stylebox_override("normal" if active else "disabled",tile_style)
		button.name = "Mode_"+str(item[0])
		button.custom_minimum_size = Vector2(60,60)
		button.tooltip_text = str(item[1])+("" if active else " - Coming soon")
		button.disabled = not active
		rail.add_child(button)

func _show_hero(title: String, theme_id: String) -> void:
	_prepare_outgoing_section()
	if not preview_entry.is_empty():
		title = str(preview_entry.name).to_upper()
		theme_id = str(preview_entry.get("theme","pine"))
	var hero_points: PackedVector2Array = selected_track.route
	var hero_length: float = selected_track.route_length
	var hero_creator: String = str(selected_track.metadata.get("cloud_creator",selected_track.metadata.get("creator_document",{}).get("creator",selected_track.metadata.get("creator","Unknown creator"))))
	if not preview_entry.is_empty():
		hero_creator = str(preview_entry.get("creator","Unknown creator"))
		hero_points = PackedVector2Array()
		for point: Array in preview_entry.get("points",[]): hero_points.append(Vector2(point[0],point[1]))
		hero_length = 0.0
		for index: int in range(hero_points.size()): hero_length += hero_points[index].distance_to(hero_points[(index+1)%hero_points.size()])
	var animate: bool = _hero_serial >= 0 and _hero_serial != _selection_serial
	_hero_serial = _selection_serial
	if _hero_scenery != null: hero.remove_child(_hero_scenery)
	_clear(hero)
	if _hero_scenery == null:
		_hero_scenery = Control.new()
		_hero_scenery.name = "HeroSceneryLayers"
		_hero_scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hero_scenery.clip_contents = true
	hero.add_child(_hero_scenery)
	var art := TextureRect.new()
	art.name = "SelectedTrackScenery"
	art.texture = TrackTile.scenery_texture(theme_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear(_hero_scenery)
	_hero_scenery.add_child(art)
	MenuStyle.fill(art)
	_hero_art = art
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.05,0.07,0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(shade)
	var inset := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+side,24 if side in ["left","right"] else 16)
	hero.add_child(inset)
	var row := HBoxContainer.new()
	inset.add_child(row)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation",0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)
	info.add_child(preload("res://ui/biome_badge.gd").view(theme_id,16))
	var heading := MenuStyle.label(title,60)
	heading.name = "HeroTrackTitle"
	heading.clip_text = true
	heading.tooltip_text = title
	info.add_child(heading)
	var creator := MenuStyle.label("by "+hero_creator,18)
	creator.clip_text = true
	var attribution := HBoxContainer.new()
	attribution.add_theme_constant_override("separation",16)
	info.add_child(attribution)
	creator.custom_minimum_size.x = minf(280.0,MenuStyle.BODY.get_string_size(creator.text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x)
	attribution.add_child(creator)
	var rating_entry: Dictionary = preview_entry
	if rating_entry.is_empty():
		for candidate: Dictionary in catalog.entries:
			if str(candidate.id) == selected_track.identity:
				rating_entry = candidate
				break
	var rating_tile := TrackTile.new()
	rating_tile.entry = rating_entry
	rating_tile.personal_rating = int(records.settings.get("track_ratings",{}).get(str(rating_entry.get("id",selected_track.identity)),0))
	var rating := HBoxContainer.new()
	rating.name = "HeroRating"
	rating.add_theme_constant_override("separation",7)
	rating.tooltip_text = "Verified racers" if rating_entry.get("source") == "cloud" else "Local votes on this device"
	attribution.add_child(rating)
	var rating_star := TextureRect.new()
	rating_star.texture = MenuIcon.texture("star_filled" if rating_tile.has_rating() else "star")
	rating_star.modulate = MenuStyle.ACCENT if rating_tile.has_rating() else MenuStyle.MUTED
	rating_star.custom_minimum_size = Vector2(22,22)
	rating_star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rating_star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rating.add_child(rating_star)
	rating.add_child(MenuStyle.label(rating_tile.rating_text(),18,true))
	rating_tile.free()
	var is_favorite: bool = preview_entry.get("id",selected_track.identity) in records.settings.get("favorites",[])
	var favorite := MenuStyle.button("",_favorite)
	favorite.name = "HeroFavorite"
	favorite.icon = MenuIcon.texture("star_filled" if is_favorite else "star")
	favorite.tooltip_text = "Remove favorite" if is_favorite else "Save favorite"
	favorite.custom_minimum_size = Vector2(48,48)
	favorite.add_theme_stylebox_override("normal",MenuStyle.box(Color("0b202b99"),8))
	favorite.add_theme_color_override("icon_normal_color",MenuStyle.ACCENT if is_favorite else MenuStyle.TEXT)
	var route_column := VBoxContainer.new()
	route_column.add_theme_constant_override("separation",4)
	route_column.custom_minimum_size.x = 220
	row.add_child(route_column)
	var favorite_column := VBoxContainer.new()
	row.add_child(favorite_column)
	favorite_column.add_child(favorite)
	var outline := Control.new()
	outline.name = "HeroRouteOutline"
	outline.custom_minimum_size = Vector2(220,96)
	outline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_column.add_child(outline)
	outline.draw.connect(func() -> void:
		var points: PackedVector2Array = hero_points
		if points.size() < 2: return
		var bounds := Rect2(points[0],Vector2.ZERO)
		for point: Vector2 in points: bounds = bounds.expand(point)
		var scale_factor: float = minf((outline.size.x-24)/maxf(1,bounds.size.x),(outline.size.y-24)/maxf(1,bounds.size.y))
		var path := PackedVector2Array()
		for point: Vector2 in points:
			var offset: Vector2 = (point-bounds.get_center())*scale_factor
			path.append(outline.size*0.5+Vector2(offset.x,-offset.y))
		path.append(path[0])
		outline.draw_polyline(path,Color("06131c"),8,true)
		outline.draw_polyline(path,Color.WHITE,4,true))
	outline.resized.connect(outline.queue_redraw)
	route_column.add_child(MenuStyle.label(("~ " if not preview_entry.is_empty() else "")+"%.2f KM / LAP" % (hero_length/1000.0),20,true))
	if animate: _slide_section()

func _slide_section() -> void:
	if _section_motion != null: _section_motion.kill()
	_slide_distance = hero.get_parent_control().size.x
	_set_section_offset(_hero_direction*_slide_distance)
	_section_motion = create_tween().set_parallel(true)
	_section_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_section_motion.tween_method(_set_section_offset,_section_offset,0.0,HERO_FADE_SECONDS)
	_section_motion.chain().tween_callback(_clear_outgoing_section)

func _prepare_outgoing_section() -> void:
	if _hero_serial < 0 or _hero_serial == _selection_serial or _outgoing_serial == _selection_serial: return
	if _section_motion != null: _section_motion.kill()
	_clear_outgoing_section()
	_outgoing_serial = _selection_serial
	# Retain the actual controls, including custom route drawing and old records.
	for panel: PanelContainer in [hero, records_panel]:
		panel.position.x = 0.0
		_disable_outgoing_input(panel)
		_outgoing_panels.append(panel)
		var replacement := PanelContainer.new()
		var panel_name: String = panel.name
		panel.name = "Outgoing" + panel_name
		replacement.name = panel_name
		replacement.clip_contents = panel.clip_contents
		replacement.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel"))
		panel.get_parent().add_child(replacement)
		panel.get_parent().move_child(replacement, 0)
		MenuStyle.fill(replacement)
		if panel == hero:
			hero = replacement
			_hero_scenery = null
		else:
			records_panel = replacement
			detail = VBoxContainer.new()
			replacement.add_child(detail)
			pending_records = MenuStyle.label("",18,true)
			replacement.add_child(pending_records)
			pending_records.hide()

func _disable_outgoing_input(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children(): _disable_outgoing_input(child)

func _clear_outgoing_section() -> void:
	for panel: Control in _outgoing_panels:
		panel.get_parent().remove_child(panel)
		panel.queue_free()
	_outgoing_panels.clear()

func _set_section_offset(value: float) -> void:
	_section_offset = value
	hero.position.x = value
	records_panel.position.x = value
	for panel: Control in _outgoing_panels:
		panel.position.x = value - _hero_direction*_slide_distance


func _section_body(parent: VBoxContainer) -> VBoxContainer:
	var inset := MarginContainer.new()
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_left",40)
	inset.add_theme_constant_override("margin_right",12)
	inset.add_theme_constant_override("margin_top",8)
	inset.add_theme_constant_override("margin_bottom",8)
	parent.add_child(inset)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",3)
	inset.add_child(content)
	return content

func _friendly_hint(parent: Control, text: String) -> void:
	var hint := MenuStyle.label(text,15,true)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)

func _fixed_column(parent: Control, column: Control, column_name: String, width: float) -> void:
	var slot := Control.new()
	slot.name = column_name
	slot.custom_minimum_size.x = width
	slot.clip_contents = true
	parent.add_child(slot)
	slot.add_child(column)
	MenuStyle.fill(column)

func _focus_card(index: int) -> void:
	var left: int = index*tile_stride
	if left < gallery.scroll_horizontal or left+tile_stride-12 > gallery.scroll_horizontal+gallery.size.x:
		gallery.call("_stop_snap")
		gallery.scroll_horizontal = left

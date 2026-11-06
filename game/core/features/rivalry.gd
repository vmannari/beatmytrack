extends Node
## Rivalry composition; state and callbacks remain owned by App.
const RaceLoading = preload("res://ui/race_loading.gd")
const SelectedEvent = preload("res://race/selected_event.gd")

func run_rivalry(app: Node, parent: VBoxContainer = null) -> void:
	if parent == null: parent = app.content
	if parent == app.content and app.screen == "rivalry": app._remember_rivalry_standings(parent)
	var page: WeeklyRivalryPage = parent.find_child("WeeklyRivalryPage",true,false) as WeeklyRivalryPage
	var parked: bool = false
	if page == null and is_instance_valid(app._retained_rivalry_page) and app._retained_rivalry_page.get_parent() == app._rivalry_parking:
		if app._retained_rivalry_scope == app.rivalry.scope():
			page = app._retained_rivalry_page
			parked = true
		else:
			app._retained_rivalry_page.get_parent().remove_child(app._retained_rivalry_page)
			app._retained_rivalry_page.queue_free()
			app._retained_rivalry_page = null
	var retained: bool = page != null
	if not retained or parked:
		for child: Node in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	if not retained:
		page = WeeklyRivalryPage.new()
	app._retained_rivalry_page = page
	app._retained_rivalry_scope = app.rivalry.scope()
	page.safety_client = app.online.client
	page.circuit_mode = app.rivalry.circuit_mode
	page.model = app.rivalry.model
	page.finale_livery = VehicleLivery.for_car(app.records.settings,app.rivalry.model.vehicle_id)
	page.finale_customisation = VehicleCustomisation.for_car(app.records.settings,app.rivalry.model.vehicle_id)
	page.finale_condition = VehicleCondition.read(app.records,app.rivalry.model.vehicle_id)
	page.standings_identity = app.rivalry.scope()+"/"+app.rivalry.model.group_id+"/"+str(app.rivalry.model.week)
	if app.rivalry_standings_view.get("key","") == page.standings_identity:
		page.standings_scroll_offset = int(app.rivalry_standings_view.offset)
	page.section = app.rivalry_section
	page.selected = app.rivalry_track
	page.ghost_choice = app.rivalry_ghost_choice
	page.busy = app.rivalry.busy or app.rivalry.cached_snapshot or app.cloud_starting
	page.background_refresh = app.rivalry.busy and not app.rivalry.model.sample and not app.rivalry.cached_snapshot and not app.cloud_starting and app.rivalry.has_snapshot()
	page.error = app.rivalry.error
	page.signed_in = app.online.client.signed_in()
	page.pending_result = app.rivalry_result_pending
	page.race_details = app.rivalry_race_details
	if retained:
		var rebuilt: bool = page.refresh_presentation()
		if parked:
			page.reparent(parent,false)
			var rail: Control = page.find_child("RaceModes",true,false)
			if rail != null: rail.modulate.a = 1.0
		app._keep_race_mode_rail_fixed(page)
		if rebuilt and page.section == "detail" and not app.rivalry.model.sample and not app.rivalry.model.tracks.is_empty(): app._prepare_rivalry_track_preview(page,app.rivalry_track)
		if parent == app.content and app.screen == "rivalry": app._maybe_rivalry_summary.call_deferred()
		return
	page.section_requested.connect(func(section: String) -> void:
		if is_instance_valid(app.game):
			app.remove_child(app.game)
			app.game.queue_free()
			app.game = null
			app.rivalry_racing = false
		app.rivalry_section = section
		app._rivalry()
		if not app.rivalry.model.sample: app.rivalry.refresh(false))
	page.track_requested.connect(func(index: int) -> void:
		app.rivalry_track = index
		app.rivalry_section = "detail"
		app._rivalry())
	page.track_selected.connect(func(index: int) -> void: app.rivalry_track = index)
	page.race_requested.connect(app._start_rivalry_race)
	page.free_race_requested.connect(func() -> void:
		if is_instance_valid(app.game):
			app.remove_child(app.game)
			app.game.queue_free()
			app.game = null
			app.rivalry_racing = false
		app._open_free_race())
	page.join_requested.connect(func() -> void:
		if app.online.client.signed_in(): app.rivalry.join()
		else: app._open_account())
	page.refresh_requested.connect(func() -> void: app.rivalry.refresh())
	page.circuit_requested.connect(app._open_world_circuit)
	page.car_rivalry_requested.connect(func() -> void:
		app.rivalry.set_circuit_mode(false)
		app._open_rivalry())
	page.challenges_requested.connect(app._open_challenges)
	page.daily_requested.connect(app._open_track_of_day)
	page.continue_requested.connect(func() -> void:
		if app.rivalry.model.sample:
			app.rivalry.model.next_week()
			app._rivalry()
		else: app.rivalry.continue_week())
	page.share_requested.connect(app._share_rivalry_results)
	page.retry_requested.connect(app._retry_race)
	parent.add_child(page)
	app._keep_race_mode_rail_fixed(page)
	if page.section == "detail" and not app.rivalry.model.sample and not app.rivalry.model.tracks.is_empty():
		app._prepare_rivalry_track_preview(page,app.rivalry_track)
	if parent == app.content and app.screen == "rivalry": app._maybe_rivalry_summary.call_deferred()

func run_prepare_rivalry_track_preview(app: Node, page: WeeklyRivalryPage, index: int) -> void:
	if index < 0 or index >= app.rivalry.model.tracks.size(): return
	var scope: String = app.rivalry.scope()
	var group: String = app.rivalry.model.group_id
	var week: int = app.rivalry.model.week
	var entry: Dictionary = app.cloud.entry_from_metadata(app.rivalry.model.tracks[index].entry)
	var document: Dictionary = app.cloud.cached_document(entry)
	if document.is_empty():
		if not bool(app.rivalry.model.tracks[index].get("available",true)): return
		if not await app.cloud.download(entry): return
		document = app.cloud.cached_document(entry)
	if not is_instance_valid(page) or not page.is_inside_tree() or app.screen != "rivalry" or page.section != "detail" or index != app.rivalry_track: return
	if scope != app.rivalry.scope() or group != app.rivalry.model.group_id or week != app.rivalry.model.week or index >= app.rivalry.model.tracks.size(): return
	if entry.get("version_id","") != app.rivalry.model.tracks[index].entry.get("version_id","") or entry.get("content_hash","") != app.rivalry.model.tracks[index].entry.get("content_hash",""): return
	page.apply_track_preview(document)
	app._prepare_selected_event("rivalry",page,entry,document)

func run_rivalry_ghost(app: Node, index: int, choice: int, wait_for_recording: bool = false) -> Dictionary:
	if choice == 3: return {}
	var target: Dictionary = app.rivalry.model.ghost_target(index,choice)
	var driver: String = str(target.get("driver_id",""))
	if wait_for_recording: return await app.rivalry.ghost(index,driver)
	app.rivalry.prefetch_ghost(index,driver)
	return app.rivalry.cached_ghost(index,driver)

func run_start_rivalry_race(app: Node, index: int, choice: int) -> void:
	if app.cloud_starting or not app.online.client.signed_in() or app.rivalry.model.sample: return
	if not app._result_capacity_available(): return
	if index < 0 or index >= app.rivalry.model.tracks.size(): return
	var navigation: int = app._navigation_generation
	var original_scope: String = app.rivalry.scope()
	var original_group: String = app.rivalry.model.group_id
	var original_week: int = app.rivalry.model.week
	var original_version: String = str(app.rivalry.model.tracks[index].entry.get("version_id",""))
	var vehicle: String = VehicleCatalog.selected
	var selection: NativeTrack = app.selected_track
	var account_scope: String = app.lifecycle.scope()
	var original_event: Array = SelectedEvent.rivalry_pin(app,index)
	app.cloud_starting = true
	app._rivalry()
	var loading: RaceLoading = app._open_race_loading()
	var loading_id: int = loading.get_instance_id()
	var metadata: Dictionary = app.rivalry.model.tracks[index].entry
	var points = PackedVector2Array()
	for point: Array in metadata.get("points", []): points.append(Vector2(point[0], point[1]))
	loading.configure(str(metadata.get("name", "Weekly Rivalry")), str(metadata.get("theme", "pine")), points)
	loading.stage("Connecting race…")
	await app._present_race_loading()
	if not app._race_loading_matches(loading_id): return
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope() or original_event != SelectedEvent.rivalry_pin(app,index):
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		return
	# A background refresh can be syncing appearance before it emits changed.
	# Retain this explicit start instead of silently losing its first tap.
	while app.rivalry.busy:
		await app.get_tree().process_frame
		if not app._race_loading_matches(loading_id): return
		if navigation != app._navigation_generation or original_scope != app.rivalry.scope() or original_event != SelectedEvent.rivalry_pin(app,index):
			app._close_race_loading(loading_id)
			return
	var same_track: bool = index < app.rivalry.model.tracks.size() and str(app.rivalry.model.tracks[index].entry.get("version_id","")) == original_version
	var same_week: bool = app.rivalry.model.group_id == original_group and app.rivalry.model.week == original_week
	var available: bool = same_track and bool(app.rivalry.model.tracks[index].get("available",true))
	if app.rivalry.cached_snapshot or app.rivalry.snapshot_scope != original_scope or not same_week or not available or app.rivalry.model.completed or app.rivalry.model.status != "active":
		app._close_race_loading(loading_id)
		app._rivalry()
		app._notice(app.rivalry.error if not app.rivalry.error.is_empty() else "Rivalry changed while preparing the race. Open the track and try again.")
		return
	app._rivalry_ghost(index,choice) # Fetch presentation in parallel with required race data.
	var issued: Dictionary = await app.rivalry.ticket(index)
	if not app._race_loading_matches(loading_id): return
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope() or original_event != SelectedEvent.rivalry_pin(app,index):
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		return
	if issued.is_empty():
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		if app.rivalry.error.is_empty(): app.rivalry.error = "Could not connect the race. Refresh Rivalry and try again."
		app._rivalry()
		app._notice(app.rivalry.error)
		return
	var entry: Dictionary = app.cloud.entry_from_metadata(app.rivalry.model.tracks[index].entry)
	loading.stage("Downloading track…")
	var track: NativeTrack = app._selected_event_track(entry)
	if not await app._await_selected_preparation(track,loading_id,account_scope,navigation,"rivalry",vehicle,selection): return
	var downloaded: Dictionary = await app.cloud.download_document(entry) if track.metadata.get("metadata_only",false) else {}
	if not app._race_loading_matches(loading_id): return
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope() or original_event != SelectedEvent.rivalry_pin(app,index):
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		return
	if downloaded.is_empty() and track.metadata.get("metadata_only",false):
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		app.rivalry.error = app.cloud.last_error if not app.cloud.last_error.is_empty() else "Track download failed. Check your connection and try again."
		app._rivalry()
		app._notice(app.rivalry.error)
		return
	loading.stage("Preparing track…")
	await app._present_race_loading()
	if not app._race_loading_matches(loading_id): return
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope() or original_event != SelectedEvent.rivalry_pin(app,index):
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		return
	if track.metadata.get("metadata_only",false): track = await app.online.client._background(app.cloud.compile_document.bind(entry,downloaded))
	if not app._race_loading_matches(loading_id): return
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope() or original_event != SelectedEvent.rivalry_pin(app,index):
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		return
	if track == null:
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		app.rivalry.error = "Track could not be prepared. Try again."
		app._rivalry()
		app._notice(app.rivalry.error)
		return
	loading.stage("Loading ghost…")
	var recording: Dictionary = await app._rivalry_ghost(index,choice,true)
	if not app._race_loading_matches(loading_id): return
	app.cloud_starting = false
	app._close_race_loading(loading_id)
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope() or original_event != SelectedEvent.rivalry_pin(app,index): return
	app.rivalry_track = index
	app.rivalry_ghost_choice = choice
	app.rivalry_recording = recording
	app.rivalry_result_pending = false
	app.rivalry_race_details = {}
	app.rivalry.result_ticket = ""
	app.rivalry.result_state = ""
	app.selected_track = track
	await app._start_race(track,false,false,issued)


extends RefCounted
## Menu composition. State and scene ownership stay with App.
const RaceLoading = preload("res://ui/race_loading.gd")

static func _track_of_day(app: Node, parent: Control = null, preview: bool = false) -> void:
	if parent == null: parent = app.content
	var page = preload("res://ui/track_of_day_page.gd").new()
	page.client = app.online.client
	page.cloud = app.cloud
	page.records = app.records
	page.page_preview = preview
	var scope: String = app._daily_cache_scope()
	if scope == app._daily_track_cache_scope: page.cached_state = app._daily_track_cache.duplicate(true)
	page.track_loaded.connect(func(state: Dictionary) -> void:
		if scope == app._daily_cache_scope():
			app._daily_track_cache_scope = scope
			app._daily_track_cache = state.duplicate(true))
	page.track_invalidated.connect(func() -> void:
		if scope == app._daily_track_cache_scope:
			app._daily_track_cache.clear()
			app._daily_track_cache_scope = "")
	page.mode_requested.connect(app._request_race_mode)
	page.vehicle_selected.connect(app._select_vehicle)
	page.race_requested.connect(func(entry: Dictionary) -> void:
		app.selected_track = app.cloud.presentation_track(entry)
		app._start_race(app.selected_track,false,false,{},null,{"day":int(entry.daily_day),"version_id":str(entry.version_id)}))
	parent.add_child(page)
	app._keep_race_mode_rail_fixed(page)

static func _ensure_track_catalog(app: Node) -> void:
	if app.track_catalog == null:
		app.track_catalog = TrackCatalog.new(app.library)
		if app.cloud != null: return # Race uses backend publications and their caches.
		if app.library.directory != app.guest_library.directory:
			app.track_catalog.shared_directories.append(app.guest_library.directory.path_join(".published"))
		var profiles = DirAccess.open(app.profile_root.path_join("players"))
		if profiles != null:
			for profile: String in profiles.get_directories():
				if profile == app.active_profile: continue
				app.track_catalog.shared_directories.append(app.profile_root.path_join("players").path_join(profile).path_join("tracks/.published"))

static func _tracks(app: Node, parent: VBoxContainer = null, preview: bool = false) -> void:
	if parent == null: parent = app.content
	var began: int = Time.get_ticks_usec()
	var browser = TrackBrowser.new()
	var created: int = Time.get_ticks_usec()
	browser.name = "TrackBrowser"
	browser.library = app.library
	app._ensure_track_catalog()
	browser.catalog = app.track_catalog
	browser.cloud = app.cloud
	browser.discovery = app.discovery_provider
	if app.cloud != null and app.online.client.signed_in():
		var comparison_scope: String = app.online.client.base_url()+"/"+str(app.online.client.player.get("id",""))+"/"+str(app.online.client.test_drivers_available())
		app.discovery_provider.configure_cache(app.cloud.cache_root().path_join("menu/"+comparison_scope.sha256_text()+".json"),comparison_scope)
	browser.records = app.records
	browser.builtin_ids = app.BUILTIN_IDS
	browser.selected_track = app.selected_track
	browser.page_preview = preview
	browser.state = app.browser_state.duplicate(true) if preview else app.browser_state
	browser.race_requested.connect(func(track: NativeTrack) -> void: app._start_race(track,false))
	browser.track_selected.connect(app._menu_track_selected)
	browser.preparation_requested.connect(app._prepare_selected_track.bind(browser))
	browser.home_requested.connect(func() -> void: app._show_screen("tracks"))
	browser.import_requested.connect(app._import_dialog)
	browser.delete_requested.connect(app._confirm_delete_track)
	browser.notice.connect(app._notice)
	browser.share_requested.connect(app._share_track_link)
	browser.rivalry_requested.connect(app._open_rivalry)
	browser.challenges_requested.connect(app._open_challenges)
	browser.daily_requested.connect(app._open_track_of_day)
	browser.edit_requested.connect(func(doc: Dictionary) -> void:
		app.document = doc.duplicate(true)
		app.editor_view.clear()
		app.history.clear()
		app.redo_history.clear()
		app._show_screen("create"))
	parent.add_child(browser)
	if not preview: app.menu_open_costs = {"browser_new_ms":(created-began)/1000.0,"browser_ready_ms":(Time.get_ticks_usec()-created)/1000.0}

static func _prepare_selected_track(app: Node, track: NativeTrack, browser: TrackBrowser) -> void:
	if app.screen != "tracks" or app.selected_track != track or app.cloud_starting or is_instance_valid(app.game): return
	app._cancel_selected_preparation()
	app._selected_preparation_track = track
	app._selected_preparation_browser = weakref(browser)
	app._selected_preparation_scope = app.lifecycle.scope()
	app._selected_preparation_navigation = app._navigation_generation
	app._selected_preparation_vehicle = VehicleCatalog.selected
	app._selected_preparation_serial = browser._selection_serial
	app._selected_preparation_entry = track.metadata.get("cloud_entry",{}).duplicate(true)
	app._selected_preparation_pin = [track.identity,track.content_hash,track.metadata.get("cloud_version",""),track.metadata.get("cloud_entry",{}).get("content_hash","")]
	app._selected_preparation_pending = true
	var generation: int = app._selected_preparation_generation
	if app._selected_preparation_obsolete(generation): app._cancel_selected_preparation(); return
	if track.metadata.get("metadata_only",false):
		if app.cloud == null or not app.cloud.has_method("download_document") or app._selected_preparation_entry.is_empty(): app._cancel_selected_preparation(); return
		app.SELECTED_PREPARATION.download(weakref(app),generation,app.cloud,app._selected_preparation_entry)
	else:
		app._begin_selected_geometry(generation,app._selected_preparation_entry,{})

static func _selected_preparation_obsolete(app: Node, generation: int) -> bool:
	if generation != app._selected_preparation_generation or not app.is_inside_tree() or not app._selected_preparation_pending: return true
	if app.screen != "tracks" or app._navigation_generation != app._selected_preparation_navigation or app.lifecycle == null or app.lifecycle.scope() != app._selected_preparation_scope: return true
	if VehicleCatalog.selected != app._selected_preparation_vehicle or app.selected_track != app._selected_preparation_track or app._selected_preparation_browser == null: return true
	if [app.selected_track.identity,app.selected_track.content_hash,app.selected_track.metadata.get("cloud_version",""),app.selected_track.metadata.get("cloud_entry",{}).get("content_hash","")] != app._selected_preparation_pin: return true
	var browser: TrackBrowser = app._selected_preparation_browser.get_ref()
	if not is_instance_valid(browser) or not browser.is_inside_tree() or browser.page_preview or browser.list_open or browser.selected_track != app.selected_track or browser._selection_serial != app._selected_preparation_serial: return true
	if not app._selected_preparation_entry.is_empty() and str(app.selected_track.metadata.get("cloud_version","")) != str(app._selected_preparation_entry.get("version_id","")): return true
	if app.cloud != null and is_instance_valid(app.online.client.get("safety")) and not app.online.client.safety.allows(app._selected_preparation_entry): return true
	return false

static func _begin_selected_geometry(app: Node, generation: int, entry: Dictionary, source: Dictionary) -> void:
	if app._selected_preparation_obsolete(generation): return
	if app._selected_preparation_track.metadata.get("metadata_only",false) and source.is_empty():
		app._cancel_selected_preparation(); return
	var layout_ready: bool = app.SELECTED_PREPARATION.ready_for_job() and app._selected_preparation_track._race_gates.get("rules_key","") == RaceRules.KEY and app._selected_preparation_track._race_gates.get("notice_version",0) == TrackSession.NOTICE_LAYOUT_VERSION
	if not app._selected_preparation_track.metadata.get("metadata_only",false) and not NativeTrackVisual.race_roads_need_preparation(app._selected_preparation_track) and layout_ready:
		app._cancel_selected_preparation(); return
	app._selected_preparation_entry = entry.duplicate(true)
	app._selected_preparation_source = source
	app._selected_preparation_queued = true
	app._poll_selected_preparation()

static func _poll_selected_preparation(app: Node) -> void:
	if not app._selected_preparation_pending: return
	if app._selected_preparation_obsolete(app._selected_preparation_generation): app._cancel_selected_preparation(); return
	if app._selected_preparation_job == null:
		if app._selected_preparation_queued and app.SELECTED_PREPARATION.ready_for_job():
			app._selected_preparation_job = app.SELECTED_PREPARATION.start(app._selected_preparation_track,app._selected_preparation_entry,app._selected_preparation_source,app.get_tree())
			app._selected_preparation_source = {}; app._selected_preparation_queued = false
		return
	if not app._selected_preparation_job.done: return
	var job: RefCounted = app._selected_preparation_job
	app._selected_preparation_job = null
	var result: Dictionary = job.result if job.result is Dictionary else {}
	job.result = null
	var ready: NativeTrack = result.get("track")
	if ready != null:
		if not result.get("winter_cover",{}).is_empty(): ready.editor_winter_cover = result.winter_cover
		var receipt: Dictionary = result.get("receipt",{})
		if not receipt.is_empty(): NativeTrackVisual.ROAD_DISK_CACHE.publish_arrays(receipt)
		if ready != app._selected_preparation_track:
			for property: Dictionary in ready.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: app._selected_preparation_track.set(property.name,ready.get(property.name))
			app.cloud.remember_compiled_entry(app._selected_preparation_entry,app._selected_preparation_track)
			app._ensure_track_catalog()
			app.track_catalog.remember_track(app._selected_preparation_entry,app._selected_preparation_track)
	else:
		NativeTrackVisual.ROAD_DISK_CACHE.discard_arrays(result.get("receipt",{}))
	app._selected_preparation_pending = false
	app._selected_preparation_track = null
	app._selected_preparation_browser = null
	app._selected_preparation_entry = {}
	app._selected_preparation_pin = []
	app._selected_preparation_source = {}; app._selected_preparation_queued = false

static func _cancel_selected_preparation(app: Node) -> void:
	app._selected_preparation_generation += 1
	app.SELECTED_PREPARATION.cancel(app._selected_preparation_job)
	app._selected_preparation_job = null
	app._selected_preparation_pending = false
	app._selected_preparation_track = null
	app._selected_preparation_browser = null
	app._selected_preparation_entry = {}
	app._selected_preparation_pin = []
	app._selected_preparation_source = {}; app._selected_preparation_queued = false

static func _await_selected_preparation(app: Node, track: NativeTrack, loading_id: int, scope: String, navigation: int, starting_screen: String, vehicle: String, selection: NativeTrack) -> bool:
	while app._selected_preparation_pending and app._selected_preparation_track == track:
		app._poll_selected_preparation()
		if not app._selected_preparation_pending: break
		await app.get_tree().process_frame
		if app._race_preparation_changed(loading_id,scope,navigation,starting_screen,vehicle,selection): return false
	return not app._race_preparation_changed(loading_id,scope,navigation,starting_screen,vehicle,selection)

static func _challenges(app: Node, parent: VBoxContainer = null) -> void:
	if parent == null: parent = app.content
	var detail_tab: int = 0
	var inbox_scroll: int = 0
	var draft_query: String = app.challenges.search
	var query_focus: bool = false
	var query_caret: int = 0
	var previous: ChallengesPage = parent.find_child("ChallengesPage",true,false)
	if previous != null and previous.browser_scope == app.challenges.scope():
		if str(previous.selected.get("code","")) == str(app.challenges.selected.get("code","")):
			var views: TabContainer = previous.find_child("ChallengeRaceViews",true,false)
			if views != null: detail_tab = views.current_tab
		if [previous.folder,previous.search,previous.mode_filter,previous.vehicle_filter,previous.sort_order] == [app.challenges.folder,app.challenges.search,app.challenges.mode_filter,app.challenges.vehicle_filter,app.challenges.sort_order]:
			var inbox: ScrollContainer = previous.find_child("ChallengeInboxScroll",true,false)
			if inbox != null: inbox_scroll = inbox.scroll_vertical
			if previous._search != null:
				draft_query = previous._search.text
				query_focus = previous._search.has_focus()
				query_caret = previous._search.caret_column
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var page = ChallengesPage.new()
	page.safety_client = app.online.client
	page.items = app.challenges.items
	page.selected = app.challenges.selected
	page.detail_tab = detail_tab
	page.browser_scope = app.challenges.scope()
	page.inbox_scroll = inbox_scroll
	page.selected_stage = app.challenges.selected_stage
	page.stage_requested.connect(app.challenges.select_stage)
	page.folder = app.challenges.folder
	page.search = app.challenges.search
	page.mode_filter = app.challenges.mode_filter
	page.vehicle_filter = app.challenges.vehicle_filter
	page.sort_order = app.challenges.sort_order
	page.signed_in = app.online.client.signed_in()
	page.busy = app.challenges.busy or app.cloud_starting
	page.error = app.challenges.error
	page.has_more = not app.challenges.next_cursor.is_empty()
	page.result_view = app.challenge_result_view
	page.landing_view = not app.challenge_browsing
	page.result_state = app.challenges.result_state
	page.outcome = app.challenges.outcome
	page.mode_requested.connect(app._request_race_mode)
	page.folder_requested.connect(func(folder: String) -> void:
		app.challenges.select_folder(folder))
	page.selected_requested.connect(func(code: String) -> void: app.challenges.open(code))
	page.filters_requested.connect(app.challenges.set_filters)
	page.create_requested.connect(func() -> void: app._create_challenge_dialog())
	page.browse_requested.connect(app._browse_challenges)
	page.landing_requested.connect(app._open_challenges)
	page.code_requested.connect(app._challenge_code_dialog)
	page.race_requested.connect(app._start_challenge_race)
	page.share_requested.connect(app._share_challenge)
	page.rematch_requested.connect(func() -> void:
		await app.challenges.rematch()
		if app.challenges.error.is_empty():
			app.challenge_result_view = false
			app._clear_challenge_game()
			app._open_challenges(true)
			app._share_challenge())
	page.cancel_requested.connect(app._cancel_challenge_dialog)
	page.refresh_requested.connect(func() -> void:
		if app.challenges.folder == "sent" and not app.challenges.selected.is_empty(): app.challenges.open(str(app.challenges.selected.code))
		else: app.challenges.refresh())
	page.more_requested.connect(func() -> void: app.challenges.refresh(true))
	page.sign_in_requested.connect(app._open_account)
	page.back_requested.connect(func() -> void:
		app.challenge_result_view = false
		app._clear_challenge_game()
		app._open_challenges(true))
	parent.add_child(page)
	if page._search != null:
		page._search.text = draft_query
		if query_focus:
			page._search.grab_focus()
			page._search.caret_column = mini(query_caret,draft_query.length())
	app._keep_race_mode_rail_fixed(page)

static func _create_challenge_dialog(app: Node, version: String = "", vehicle: String = "", ticket_id: String = "", duration_seconds: int = 604800, finished: Dictionary = {}, attempt_limit: int = 0, configuration: Dictionary = {}, results_only: bool = false) -> void:
	if app.game_configuration != null and not app.game_configuration.settings.get("features.challenge_creation",true):
		app._notice("New challenges are temporarily unavailable.")
		return
	if not app.online.client.signed_in():
		app._open_account()
		return
	var dialog = ChallengeCreate.new()
	dialog.adapter = app.challenges
	dialog.library = app.library
	dialog.records = app.records
	dialog.selected_track = app.selected_track
	dialog.browser_state = app.browser_state.duplicate(true)
	dialog.entries = app.cloud.entries.duplicate(true)
	dialog.initial_version = version if not version.is_empty() else str(app.selected_track.metadata.get("cloud_version",""))
	dialog.initial_vehicle = VehicleCatalog.selected if vehicle.is_empty() else vehicle
	dialog.initial_ticket = ticket_id
	dialog.initial_duration = duration_seconds
	dialog.initial_attempt_limit = attempt_limit
	dialog.initial_configuration = configuration.duplicate(true)
	dialog.results_only = results_only
	if not ticket_id.is_empty():
		if finished.is_empty() and is_instance_valid(app.game) and app.game.preparation_complete and app.game.get("track_session").finished:
			finished = app._challenge_finished_context(app.game.get("native_track"),app.game.get("track_session").race_time_seconds(),app.game.get("track_session").completed_laps,ticket_id,str(app.game.get("vehicle_id")))
		dialog.result_context = finished.duplicate(true)
		if not finished.is_empty():
			dialog.initial_version = str(finished.entry.version_id)
			dialog.initial_vehicle = str(finished.vehicle_id)
			dialog.initial_ticket = str(finished.ticket_id)
	var retained: Dictionary = app.cloud.retained_entry(app.selected_track.identity)
	if not retained.is_empty() and not dialog.entries.any(func(entry: Dictionary) -> bool: return str(entry.version_id) == str(retained.version_id)):
		dialog.entries.push_front(retained)
	if not app.challenges.selected.is_empty() and not dialog.entries.any(func(entry: Dictionary) -> bool: return str(entry.version_id) == str(app.challenges.selected.entry.version_id)):
		dialog.entries.push_front(app.challenges.selected.entry)
	dialog.created_callback = func() -> void:
		var race_now: bool = dialog.start_after_create
		app._telemetry_observe("challenge_created",{"challenge_id":str(app.challenges.selected.get("id","")),"reason":"create"})
		app._clear_challenge_game()
		app.challenge_result_view = false
		app.challenges.folder = "sent"
		app._open_challenges(true)
		if race_now: app._race_created_challenge.call_deferred(str(app.challenges.selected.code),app.challenges.scope())
		else: app._show_challenge_ready()
	dialog.race_to_set_requested.connect(app._race_for_challenge)
	if not ticket_id.is_empty() and is_instance_valid(app.game) and not is_instance_valid(app.content):
		app._challenge_return_ui = app.root_ui
		app._challenge_return_screen = app.screen
		app.menu_layer.remove_child(app.root_ui)
		app.root_ui = null
	app._show_screen("challenge_create")
	app.content.add_child(dialog)
	dialog.canceled.connect(app._close_challenge_create)
	dialog.popup_centered()

static func _race_created_challenge(app: Node, code: String, scope: String) -> void:
	# The Created folder refresh owns its request first. Retain the explicit race
	# intent across that read, while navigation/account/selection changes cancel it.
	var navigation: int = app._navigation_generation
	var deadline: int = Time.get_ticks_msec()+30000
	while app.is_inside_tree() and app.screen == "challenges" and navigation == app._navigation_generation and app.challenges.scope() == scope and str(app.challenges.selected.get("code","")) == code:
		if not app.challenges.busy:
			app._start_challenge_race()
			return
		if Time.get_ticks_msec() >= deadline: return
		await app.get_tree().process_frame

static func _show_challenge_ready(app: Node) -> void:
	if app.challenges.selected.is_empty(): return
	var invitation: Dictionary = app.challenges.selected.duplicate(true)
	var scope: String = app.challenges.scope()
	var dialog = preload("res://ui/challenge_ready_dialog.gd").new()
	dialog.snapshot = invitation
	dialog.context_current = func() -> bool: return app.challenges.scope() == scope
	app._own_dialog(dialog)
	dialog.share_requested.connect(func() -> void:
		if app.challenges.scope() == scope: app._share_challenge(invitation))
	dialog.popup_centered(Vector2i(mini(700,int(app.get_viewport().get_visible_rect().size.x)-32),mini(460,int(app.get_viewport().get_visible_rect().size.y)-32)))

static func _close_challenge_create(app: Node) -> void:
	if is_instance_valid(app._challenge_return_ui):
		app.menu_layer.remove_child(app.root_ui)
		app.root_ui.queue_free()
		app.root_ui = app._challenge_return_ui
		app._challenge_return_ui = null
		app.screen = app._challenge_return_screen
		app.content = null
		app.menu_layer.add_child(app.root_ui)
		return
	app._open_challenges(app.challenge_browsing)

static func _challenge_finished_context(app: Node, track: NativeTrack, total: float, laps: int, ticket_id: String, vehicle: String) -> Dictionary:
	var version: String = str(track.metadata.get("cloud_version",""))
	var entry: Dictionary = {}
	for candidate: Dictionary in app.cloud.entries:
		if str(candidate.get("version_id","")) == version:
			entry = candidate.duplicate(true)
			break
	if entry.is_empty():
		var points: Array = []
		for point: Vector2 in track.route: points.append([point.x,point.y])
		entry = {"version_id":version,"track_id":str(track.metadata.get("cloud_track_id","")),"content_hash":track.content_hash,"name":app.track_title(track),"creator":str(track.metadata.get("cloud_creator","")),"theme":str(track.metadata.get("theme","pine")),"points":points}
	return {"entry":entry,"ticket_id":ticket_id,"vehicle_id":vehicle,"total":total,"laps":laps,"scope":app.challenges.scope()}

static func _race_for_challenge(app: Node, metadata: Dictionary, vehicle: String, duration_seconds: int = 604800, attempt_limit: int = 0, configuration: Dictionary = {}) -> void:
	var original: String = app.challenges.scope()
	var navigation: int = app._navigation_generation
	var entry: Dictionary = app.cloud.entry_from_metadata(metadata)
	var downloaded: Dictionary = await app.cloud.download_document(entry)
	if downloaded.is_empty():
		app._notice(app.cloud.last_error)
		return
	if navigation != app._navigation_generation or original != app.challenges.scope(): return
	var track: NativeTrack = await app.online.client._background(app.cloud.compile_document.bind(entry,downloaded))
	if navigation != app._navigation_generation or original != app.challenges.scope(): return
	if track == null:
		app._notice("Track could not be prepared. Try again.")
		return
	app._clear_challenge_game()
	VehicleCatalog.selected = vehicle
	app.selected_track = track
	app.challenge_seed = {"version_id":str(metadata.version_id),"vehicle_id":vehicle,"duration_seconds":duration_seconds,"attempt_limit":attempt_limit,"configuration":configuration.duplicate(true)}
	await app._start_race(track,false)

static func _start_challenge_race(app: Node) -> void:
	if app.cloud_starting or app.challenges.busy or app.challenges.selected.is_empty(): return
	if app.online.client.signed_in() and not app._result_capacity_available(): return
	var original: String = app.challenges.scope()
	var navigation: int = app._navigation_generation
	var selected: Dictionary = app.challenges.selected.duplicate(true)
	var stage_index: int = app.challenges.selected_stage
	var stage: Dictionary = app.challenges.race_stage().duplicate(true)
	var guest: bool = not app.online.client.signed_in()
	# Joining is also part of this start; a second press must not reserve a try.
	app.cloud_starting = true
	if not guest and not selected.joined:
		await app.challenges.join()
		if not app.challenges.error.is_empty():
			app._abort_challenge_start()
			return
		app._telemetry_observe("challenge_joined",{"challenge_id":str(selected.get("id","")),"reason":"join"})
	if not app._challenge_selection_current(original,navigation,str(selected.code),stage_index):
		app._abort_challenge_start()
		return
	app._challenges()
	var loading: RaceLoading = app._open_race_loading()
	var loading_id: int = loading.get_instance_id()
	var points = PackedVector2Array()
	for point: Array in stage.entry.points: points.append(Vector2(point[0],point[1]))
	loading.configure(str(stage.entry.name),str(stage.entry.get("theme","pine")),points)
	loading.stage("Connecting race…")
	await app._present_race_loading()
	if not app._race_loading_matches(loading_id): return
	if not app._challenge_selection_current(original,navigation,str(selected.code),stage_index):
		app._abort_challenge_start(loading_id)
		return
	var issued: Dictionary = await app.challenges.ticket(stage_index) if not guest else {}
	if not app._race_loading_matches(loading_id): return
	if not app._challenge_selection_current(original,navigation,str(selected.code),stage_index):
		app._abort_challenge_start(loading_id)
		return
	var entry: Dictionary = app.cloud.entry_from_metadata(stage.entry)
	var downloaded: Dictionary = await app.cloud.download_document(entry) if guest or not issued.is_empty() else {}
	if not app._race_loading_matches(loading_id): return
	if not app._challenge_selection_current(original,navigation,str(selected.code),stage_index):
		app._abort_challenge_start(loading_id)
		return
	var track: NativeTrack = await app.online.client._background(app.cloud.compile_document.bind(entry,downloaded)) if not downloaded.is_empty() else null
	if not app._race_loading_matches(loading_id): return
	if not app._challenge_selection_current(original,navigation,str(selected.code),stage_index):
		app._abort_challenge_start(loading_id)
		return
	var recording: Dictionary = await app.challenges.ghost(stage_index) if track != null else {}
	if not app._race_loading_matches(loading_id): return
	app.cloud_starting = false
	app._close_race_loading(loading_id)
	if not app._challenge_selection_current(original,navigation,str(selected.code),stage_index):
		app._abort_challenge_start()
		return
	if track == null or (not guest and issued.is_empty()):
		if app.challenges.error.is_empty(): app.challenges.error = app.cloud.last_error if not app.cloud.last_error.is_empty() else "Track could not be prepared. Try again."
		app._challenges()
		return
	app._clear_challenge_game()
	VehicleCatalog.selected = str(selected.vehicle_id)
	app.selected_track = track
	app.challenge_recording = recording
	app.challenge_result_view = false
	await app._start_race(track,false,guest,issued)

static func _challenge_selection_current(app: Node, owner_scope: String, navigation: int, code: String, stage_index: int) -> bool:
	return navigation == app._navigation_generation and owner_scope == app.challenges.scope() and str(app.challenges.selected.get("code","")) == code and app.challenges.selected_stage == stage_index

static func _rivalry(app: Node, parent: VBoxContainer = null) -> void:
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

static func _prepare_rivalry_track_preview(app: Node, page: WeeklyRivalryPage, index: int) -> void:
	var entry: Dictionary = app.cloud.entry_from_metadata(app.rivalry.model.tracks[index].entry)
	var document: Dictionary = app.cloud.cached_document(entry)
	if document.is_empty():
		if not bool(app.rivalry.model.tracks[index].get("available",true)): return
		if not await app.cloud.download(entry): return
		document = app.cloud.cached_document(entry)
	if is_instance_valid(page) and page.is_inside_tree(): page.apply_track_preview(document)

static func _rivalry_ghost(app: Node, index: int, choice: int, wait_for_recording: bool = false) -> Dictionary:
	if choice == 3: return {}
	var target: Dictionary = app.rivalry.model.ghost_target(index,choice)
	var driver: String = str(target.get("driver_id",""))
	if wait_for_recording: return await app.rivalry.ghost(index,driver)
	app.rivalry.prefetch_ghost(index,driver)
	return app.rivalry.cached_ghost(index,driver)

static func _start_rivalry_race(app: Node, index: int, choice: int) -> void:
	if app.cloud_starting or not app.online.client.signed_in() or app.rivalry.model.sample: return
	if not app._result_capacity_available(): return
	if index < 0 or index >= app.rivalry.model.tracks.size(): return
	var navigation: int = app._navigation_generation
	var original_scope: String = app.rivalry.scope()
	var original_group: String = app.rivalry.model.group_id
	var original_week: int = app.rivalry.model.week
	var original_version: String = str(app.rivalry.model.tracks[index].entry.get("version_id",""))
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
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope():
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		return
	# A background refresh can be syncing appearance before it emits changed.
	# Retain this explicit start instead of silently losing its first tap.
	while app.rivalry.busy:
		await app.get_tree().process_frame
		if not app._race_loading_matches(loading_id): return
		if navigation != app._navigation_generation or original_scope != app.rivalry.scope():
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
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope():
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
	var downloaded: Dictionary = await app.cloud.download_document(entry)
	if not app._race_loading_matches(loading_id): return
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope():
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		return
	if downloaded.is_empty():
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		app.rivalry.error = app.cloud.last_error if not app.cloud.last_error.is_empty() else "Track download failed. Check your connection and try again."
		app._rivalry()
		app._notice(app.rivalry.error)
		return
	loading.stage("Preparing track…")
	await app._present_race_loading()
	if not app._race_loading_matches(loading_id): return
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope():
		app.cloud_starting = false
		app._close_race_loading(loading_id)
		return
	var track: NativeTrack = await app.online.client._background(app.cloud.compile_document.bind(entry,downloaded))
	if not app._race_loading_matches(loading_id): return
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope():
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
	if navigation != app._navigation_generation or original_scope != app.rivalry.scope(): return
	app.rivalry_track = index
	app.rivalry_ghost_choice = choice
	app.rivalry_recording = recording
	app.rivalry_result_pending = false
	app.rivalry_race_details = {}
	app.rivalry.result_ticket = ""
	app.rivalry.result_state = ""
	app.selected_track = track
	await app._start_race(track,false,false,issued)

static func _settings(app: Node) -> void:
	var page = SettingsPage.new()
	page.records = app.records
	page.purchase_client = app.online.client
	page.signed_in = app.online.client.signed_in()
	page.player_name = app.online.player_name() if page.signed_in else "Guest"
	page.country_code = str(app.online.client.player.get("country_code","")) if page.signed_in else ""
	page.customize_requested.connect(app._customize_controls)
	page.account_requested.connect(app._open_account)
	page.privacy_changed.connect(app._apply_privacy_choice)
	page.tutorial_requested.connect(func() -> void:
		if app.tutorial != null: app.tutorial.replay())
	page.help_requested.connect(func(topic: String) -> void:
		if app.tutorial != null: app.tutorial.show_help(topic))
	app.content.add_child(page)

static func _customize_controls(app: Node) -> void:
	var editor = ControlLayoutEditor.new()
	editor.records = app.records
	app.root_ui.visible = false
	app.add_child(editor)
	editor.closed.connect(func() -> void: app._show_screen("settings"))


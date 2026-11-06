extends Node
## Challenges composition; state and callbacks remain owned by App.
const RaceLoading = preload("res://ui/race_loading.gd")

func run_challenges(app: Node, parent: VBoxContainer = null) -> void:
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

func run_create_challenge_dialog(app: Node, version: String = "", vehicle: String = "", ticket_id: String = "", duration_seconds: int = 604800, finished: Dictionary = {}, attempt_limit: int = 0, configuration: Dictionary = {}, results_only: bool = false) -> void:
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

func run_race_created_challenge(app: Node, code: String, scope: String) -> void:
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

func run_show_challenge_ready(app: Node) -> void:
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

func run_close_challenge_create(app: Node) -> void:
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

func run_challenge_finished_context(app: Node, track: NativeTrack, total: float, laps: int, ticket_id: String, vehicle: String) -> Dictionary:
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

func run_race_for_challenge(app: Node, metadata: Dictionary, vehicle: String, duration_seconds: int = 604800, attempt_limit: int = 0, configuration: Dictionary = {}) -> void:
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

func run_start_challenge_race(app: Node) -> void:
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

func run_challenge_selection_current(app: Node, owner_scope: String, navigation: int, code: String, stage_index: int) -> bool:
	return navigation == app._navigation_generation and owner_scope == app.challenges.scope() and str(app.challenges.selected.get("code","")) == code and app.challenges.selected_stage == stage_index


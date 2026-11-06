extends Node
## Garage composition. State and scene ownership stay with App.
const RaceLoading = preload("res://ui/race_loading.gd")

func run_garage(app: Node, parent: Control = null) -> void:
	if parent == null: parent = app.content
	if is_instance_valid(app._retained_garage) and app._retained_garage.records != app.records:
		app._retained_garage.get_parent().remove_child(app._retained_garage)
		app._retained_garage.queue_free()
		app._retained_garage = null
	if is_instance_valid(app._retained_garage) and app._retained_garage.records == app.records:
		if app._retained_garage.get_parent() != parent: app._retained_garage.reparent(parent,false)
		app._retained_garage.showroom._reflection_visibility()
		app._retained_garage.refresh_selection()
		app._retained_garage.circuit_title = app.track_title(app.selected_track).to_upper()
		return
	var page = GaragePage.new()
	app._retained_garage = page
	# A prepared studio transfers directly; an early visit presents the page
	# with a neutral car while the exact saved live studio prepares underneath.
	page.cached_carousel = true
	page.prepared_pictures=app._garage_preloader.picture_pool() if is_instance_valid(app._garage_preloader) else {}
	page.preview_can_render=func() -> bool: return app._publishing_slots_foreground and app._background_work_allowed() and not app.header_car_cache.capture_active() and (app.menu_page_motion==null or not app.menu_page_motion.is_running())
	if is_instance_valid(app._garage_preloader): page.preloaded_showroom=app._garage_preloader.take()
	page.progressive_entry=page.preloaded_showroom==null
	page.opening_can_begin=func() -> bool: return app._publishing_slots_foreground and app._background_work_allowed() and not app.editor_memory.pressure_requested and (app.menu_page_motion==null or not app.menu_page_motion.is_running())
	page.achievements = app.achievements
	page.news_client = app.online.client.news
	page.account_requested.connect(app._open_account)
	page.records = app.records
	page.economy = app.cosmetic_economy
	page.circuit_title = app.track_title(app.selected_track).to_upper()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.vehicle_selected.connect(app._select_vehicle)
	page.race_requested.connect(func() -> void: app._start_race(app.selected_track,false))
	page.free_drive_requested.connect(app._start_garage_free_drive)
	page.news_race_requested.connect(app._race_news_story)
	page.news_share_requested.connect(app._share_track_link)
	page.circuit_requested.connect(app._open_library.bind("all"))
	page.save_failed.connect(func() -> void: app._notice("Garage changes could not be saved. Check free storage space."))
	parent.add_child(page)

func run_start_garage_free_drive(app: Node) -> void:
	if app.screen != "garage" or app.cloud_starting or is_instance_valid(app.game) or is_instance_valid(app.race_loading): return
	var original_scope: String = app.lifecycle.scope()
	var navigation: int = app._navigation_generation
	var vehicle: String = VehicleCatalog.selected
	var selection: NativeTrack = app.selected_track
	var loading: RaceLoading = app._open_race_loading()
	var loading_id: int = loading.get_instance_id()
	loading.configure("Parking hall","night_city",PackedVector2Array(),true)
	loading.facts_label.text = "P1 parking hall · Free drive · 120 × 72 m"
	loading.stage("Opening parking hall…")
	app.cloud_starting = true
	await app._present_race_loading()
	if app._race_preparation_changed(loading_id,original_scope,navigation,"garage",vehicle,selection): return
	app._stop_menu_page_motion()
	app._race_menu_visible(false)
	# Driving dependencies are needed only after the explicit Test drive cover.
	# Loading this feature for ordinary Garage entry must not parse that scene.
	app.game = load("res://garage/parking_hall_drive.tscn").instantiate()
	app.game.process_mode = Node.PROCESS_MODE_DISABLED
	app.game.cooperative_preparation = true
	app.game.preparation_current = app._race_installation_current.bind(loading_id,original_scope,navigation,"garage",vehicle,selection)
	app.game.vehicle_id = vehicle
	app.game.preference_records = app.records
	app.game.exit_requested.connect(app._leave_race)
	app.add_child(app.game)
	var prepared_game: Node = app.game
	while is_instance_valid(prepared_game) and app.game == prepared_game and not prepared_game.preparation_complete:
		await app.get_tree().process_frame
		if app._race_preparation_changed(loading_id,original_scope,navigation,"garage",vehicle,selection):
			app._discard_preparing_game(prepared_game)
			return
	if not is_instance_valid(prepared_game) or app.game != prepared_game: return
	if is_instance_valid(prepared_game.world_render_preparation):
		loading.stage("Preparing your drive...")
		var stage_current: Callable = app._race_installation_current.bind(loading_id,original_scope,navigation,"garage",vehicle,selection)
		if not await prepared_game.world_render_preparation.prepare(app._present_race_loading,stage_current):
			if app.is_queued_for_deletion(): return
			app._race_preparation_changed(loading_id,original_scope,navigation,"garage",vehicle,selection)
			if is_instance_valid(prepared_game): app._discard_preparing_game(prepared_game)
			app._close_race_loading(loading_id)
			return
	var touch: TouchControls = app.game.hud.touch
	touch.control_scale = app.ui_touch_scale
	touch.left_handed = app.ui_left_handed
	touch.haptic_strength = float(app.records.settings.get("steering_haptics",0.2))
	touch.layout = ControlLayout.from_settings(app.records.settings)
	touch.show_labels = bool(app.records.settings.get("control_labels",true))
	app.game.call("_process",0.0)
	await app._present_race_loading()
	if app._race_preparation_changed(loading_id,original_scope,navigation,"garage",vehicle,selection):
		app._discard_preparing_game(prepared_game)
		return
	app.game.preparation_current = Callable()
	app.game.process_mode = Node.PROCESS_MODE_INHERIT
	app._close_race_loading(loading_id)

func run_leave_garage_free_drive(app: Node) -> void:
	var previous_game: Node = app.game
	app.game = null
	previous_game.cancel_preparation()
	app.remove_child(previous_game)
	previous_game.queue_free()
	if app.product_telemetry != null: app.product_telemetry.set_transport_allowed(true)
	app._race_menu_visible(true)
	GameSoundtrack.instance().show_menu()
	if not app._queued_track_link.is_empty():
		var value: String = app._queued_track_link
		app._queued_track_link = ""
		app._receive_track_link.call_deferred(value)
	elif not app.challenge_queued_invitation.is_empty():
		var value: String = app.challenge_queued_invitation
		app.challenge_queued_invitation = ""
		app._receive_challenge.call_deferred(value)

func run_race_news_story(app: Node, story: Dictionary) -> void:
	if app.screen != "garage" or not is_instance_valid(app._retained_garage) or app._retained_garage.section != "news" or app.cloud_starting or is_instance_valid(app.race_loading): return
	if str(story.get("version_id","")).is_empty() and str(story.get("authoring_id","")).is_empty(): return
	var scope: String = app.lifecycle.scope()
	var navigation: int = app._navigation_generation
	var vehicle: String = VehicleCatalog.selected
	var selection: NativeTrack = app.selected_track
	var preview_track = NativeTrack.new()
	preview_track.metadata = {"title":str(story.get("track_name","Track"))}
	var points: Variant = story.get("track_points",[])
	if points is Array:
		for point: Variant in points.slice(0,96):
			if point is Array and point.size() >= 2 and (point[0] is float or point[0] is int) and (point[1] is float or point[1] is int):
				var p = Vector2(float(point[0]),float(point[1]))
				if is_finite(p.x) and is_finite(p.y) and absf(p.x) <= 100000 and absf(p.y) <= 100000: preview_track.route.append(p)
	var loading: RaceLoading = app._open_race_loading(preview_track)
	var loading_id: int = loading.get_instance_id()
	# The article has no biome metadata; show only known facts until it arrives.
	loading.scenery.texture = null
	loading.facts_label.text = "5 laps  ·  "+VehicleCatalog.title()
	loading.stage("Opening track...")
	app.cloud_starting = true
	await app._present_race_loading()
	if app._news_race_changed(loading_id,scope,navigation,vehicle,selection): return
	var cancelled: Callable = app._news_race_changed.bind(loading_id,scope,navigation,vehicle,selection)
	var entry: Dictionary = await app.cloud.news_story_entry(story,cancelled)
	if app._news_race_changed(loading_id,scope,navigation,vehicle,selection): return
	if entry.is_empty():
		app._close_race_loading(loading_id)
		app._notice(app.cloud.last_error)
		return
	loading.configure(str(entry.name),str(entry.get("theme","pine")),app.cloud.metadata_track(entry).route)
	loading.stage("Downloading track...")
	var downloaded: Dictionary = await app.cloud.download_document(entry,cancelled)
	if app._news_race_changed(loading_id,scope,navigation,vehicle,selection): return
	if downloaded.is_empty():
		app._close_race_loading(loading_id)
		app._notice(app.cloud.last_error)
		return
	loading.stage("Preparing track...")
	var ready: Variant = await app.online.client._background(app.cloud.compile_document.bind(entry,downloaded))
	if app._news_race_changed(loading_id,scope,navigation,vehicle,selection): return
	if not ready is NativeTrack:
		app._close_race_loading(loading_id)
		app._notice("Track could not be prepared. Try again.")
		return
	app.cloud.remember_compiled_entry(entry,ready)
	app._ensure_track_catalog()
	app.track_catalog.remember_track(entry,ready)
	app.selected_track = ready
	app.cloud_starting = false
	await app._start_race(ready,false,false,{},loading)
	# Standard admission can reject a newly blocked creator before starting.
	if not app.cloud_starting: app._close_race_loading(loading_id)

func run_news_race_changed(app: Node, loading_id: int, scope: String, navigation: int, vehicle: String, selection: NativeTrack) -> bool:
	if app._race_preparation_changed(loading_id,scope,navigation,"garage",vehicle,selection): return true
	if not is_instance_valid(app._retained_garage) or app._retained_garage.section != "news":
		app._close_race_loading(loading_id)
		return true
	return false


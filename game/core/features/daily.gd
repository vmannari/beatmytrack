extends Node
## Daily composition; state and callbacks remain owned by App.
const MenuCache = preload("res://persistence/daily_menu_cache.gd")

func run_track_of_day(app: Node, parent: Control = null, preview: bool = false) -> void:
	if parent == null: parent = app.content
	var page = preload("res://ui/track_of_day_page.gd").new()
	page.client = app.online.client
	page.cloud = app.cloud
	page.records = app.records
	page.page_preview = preview
	var scope: String = app._daily_cache_scope()
	if scope == app._daily_track_cache_scope: page.cached_state = app._daily_track_cache.duplicate(true)
	else: page.cached_state = MenuCache.read(app.records,scope,"track")
	page.track_loaded.connect(func(state: Dictionary) -> void:
		if scope == app._daily_cache_scope():
			app._daily_track_cache_scope = scope
			app._daily_track_cache = state.duplicate(true)
			MenuCache.write(app.records,scope,"track",state))
	page.track_invalidated.connect(func() -> void:
		if scope == app._daily_track_cache_scope:
			app._daily_track_cache.clear()
			app._daily_track_cache_scope = ""
		MenuCache.erase(app.records,scope,"track"))
	page.mode_requested.connect(app._request_race_mode)
	page.vehicle_selected.connect(app._select_vehicle)
	page.preparation_requested.connect(func(entry: Dictionary) -> void:
		# Speculation must not initialize the race/editor script graph while
		# the page is drawing. A first race loads it behind the loading cover;
		# subsequent visits can still use the existing exact-event CPU worker.
		for path: String in ["res://core/features/selected_track.gd","res://race/selected_track_preparation.gd","res://track/native_track_visual.gd"]:
			if not ResourceLoader.has_cached(path): return
		app._prepare_selected_event("daily",page,entry))
	page.race_requested.connect(func(entry: Dictionary) -> void:
		app.selected_track = app._selected_event_track(entry)
		app._start_race(app.selected_track,false,false,{},null,{"day":int(entry.daily_day),"version_id":str(entry.version_id)}))
	parent.add_child(page)
	app._keep_race_mode_rail_fixed(page)


extends Node
## Tracks composition; state and callbacks remain owned by App.

func run_ensure_track_catalog(app: Node) -> void:
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

func run_tracks(app: Node, parent: VBoxContainer = null, preview: bool = false) -> void:
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


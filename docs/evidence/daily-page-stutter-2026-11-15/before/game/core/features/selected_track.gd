extends Node
## Selected Track composition; state and callbacks remain owned by App.
const Event = preload("res://race/selected_event.gd")

func run_prepare_selected_event(app: Node, kind: String, page: Control, entry: Dictionary, source: Dictionary = {}) -> void:
	Event.prepare(app,kind,page,entry,source)

func run_selected_event_track(app: Node, entry: Dictionary) -> NativeTrack:
	return app.selected_track if Event.matches(app.selected_track,entry) else app.cloud.presentation_track(entry)

func run_prepare_selected_track(app: Node, track: NativeTrack, browser: TrackBrowser) -> void:
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

func run_selected_preparation_obsolete(app: Node, generation: int) -> bool:
	if generation != app._selected_preparation_generation or not app.is_inside_tree() or not app._selected_preparation_pending: return true
	var event: bool = not app._selected_preparation_event.is_empty()
	if (not event and app.screen != "tracks") or app._navigation_generation != app._selected_preparation_navigation or app.lifecycle == null or app.lifecycle.scope() != app._selected_preparation_scope: return true
	if VehicleCatalog.selected != app._selected_preparation_vehicle or app.selected_track != app._selected_preparation_track or app._selected_preparation_browser == null: return true
	if [app.selected_track.identity,app.selected_track.content_hash,app.selected_track.metadata.get("cloud_version",""),app.selected_track.metadata.get("cloud_entry",{}).get("content_hash","")] != app._selected_preparation_pin: return true
	if event:
		if not Event.current(app): return true
	else:
		var browser: TrackBrowser = app._selected_preparation_browser.get_ref()
		if not is_instance_valid(browser) or not browser.is_inside_tree() or browser.page_preview or browser.list_open or browser.selected_track != app.selected_track or browser._selection_serial != app._selected_preparation_serial: return true
	if not app._selected_preparation_entry.is_empty() and str(app.selected_track.metadata.get("cloud_version","")) != str(app._selected_preparation_entry.get("version_id","")): return true
	if app.cloud != null and is_instance_valid(app.online.client.get("safety")) and not app.online.client.safety.allows(app._selected_preparation_entry): return true
	return false

func run_begin_selected_geometry(app: Node, generation: int, entry: Dictionary, source: Dictionary) -> void:
	if app._selected_preparation_obsolete(generation): return
	if app._selected_preparation_track.metadata.get("metadata_only",false) and source.is_empty():
		app._cancel_selected_preparation(); return
	var layout_ready: bool = app.SELECTED_PREPARATION.ready_for_job() and app._selected_preparation_track._race_gates.get("rules_key","") == RaceRules.KEY and app._selected_preparation_track._race_gates.get("notice_version",0) == TrackSession.NOTICE_LAYOUT_VERSION
	if not app._selected_preparation_track.metadata.get("metadata_only",false) and not preload("res://track/track_visual_identity.gd").race_roads_need_preparation(app._selected_preparation_track) and layout_ready:
		app._cancel_selected_preparation(); return
	app._selected_preparation_entry = entry.duplicate(true)
	app._selected_preparation_source = source
	app._selected_preparation_queued = true
	app._poll_selected_preparation()

func run_poll_selected_preparation(app: Node) -> void:
	if not app._selected_preparation_pending: return
	if app._selected_preparation_obsolete(app._selected_preparation_generation): app._cancel_selected_preparation(); return
	if not app._selected_preparation_event.is_empty() and not app._selected_preparation_event.started:
		if Time.get_ticks_msec() < int(app._selected_preparation_event.due) and not app.cloud_starting: return
		app._selected_preparation_event.started = true
		if app._selected_preparation_track.metadata.get("metadata_only",false) and app._selected_preparation_source.is_empty():
			app.SELECTED_PREPARATION.download(weakref(app),app._selected_preparation_generation,app.cloud,app._selected_preparation_entry)
		else: app._begin_selected_geometry(app._selected_preparation_generation,app._selected_preparation_entry,app._selected_preparation_source)
		return
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
		if not receipt.is_empty(): preload("res://track/road_mesh_disk_cache.gd").publish_arrays(receipt)
		if ready != app._selected_preparation_track:
			for property: Dictionary in ready.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: app._selected_preparation_track.set(property.name,ready.get(property.name))
			# Compilation replaces metadata. Keep the validated selection pin for
			# exact event handoff instead of constructing another metadata track.
			app._selected_preparation_track.metadata["cloud_entry"] = app._selected_preparation_entry.duplicate(true)
			app.cloud.remember_compiled_entry(app._selected_preparation_entry,app._selected_preparation_track)
			app._ensure_track_catalog()
			app.track_catalog.remember_track(app._selected_preparation_entry,app._selected_preparation_track)
	else:
		preload("res://track/road_mesh_disk_cache.gd").discard_arrays(result.get("receipt",{}))
	app._selected_preparation_pending = false
	app._selected_preparation_track = null
	app._selected_preparation_browser = null
	app._selected_preparation_entry = {}
	app._selected_preparation_pin = []
	app._selected_preparation_source = {}; app._selected_preparation_queued = false

func run_await_selected_preparation(app: Node, track: NativeTrack, loading_id: int, scope: String, navigation: int, starting_screen: String, vehicle: String, selection: NativeTrack) -> bool:
	while app._selected_preparation_pending and app._selected_preparation_track == track:
		app._poll_selected_preparation()
		if not app._selected_preparation_pending: break
		await app.get_tree().process_frame
		if app._race_preparation_changed(loading_id,scope,navigation,starting_screen,vehicle,selection): return false
	return not app._race_preparation_changed(loading_id,scope,navigation,starting_screen,vehicle,selection)


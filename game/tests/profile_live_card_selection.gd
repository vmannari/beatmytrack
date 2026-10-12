extends SceneTree
## Existing diagnostic account, isolated client files; no races/score writes.
var app: Node
var rows: Array[Dictionary] = []

class TimedCache extends "res://backend/menu_snapshot_cache.gd":
	func _save() -> void:
		var start: int = Time.get_ticks_usec()
		super._save()
		var ms: float = (Time.get_ticks_usec()-start)/1000.0
		if ms > 10: print("LIVE_CARD_CACHE_WRITE ms=",ms)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = ProjectSettings.globalize_path("res://../build/card-selection-latency/live-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	OS.set_environment("BMT_API_URL",OS.get_environment("BMT_PROFILE_URL"))
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var login: Dictionary = await app.online.client.development_login(OS.get_environment("BMT_PROFILE_SUBJECT"),OS.get_environment("BMT_PROFILE_NAME"),OS.get_environment("BMT_DEV_AUTH_KEY"))
	if not login.ok: print("LIVE_CARD_PROFILE login failed status=",login.status); quit(1); return
	app._show_screen("tracks")
	var browser: TrackBrowser = app.root_ui.find_child("TrackBrowser",true,false)
	while browser.loading or app.cloud.discovery_pages.total < 0: await process_frame
	for cache_owner: Object in [browser.discovery,browser.discovery.comparisons]:
		var property: String = "snapshot_cache" if cache_owner == browser.discovery else "cache"
		var old: RefCounted = cache_owner.get(property)
		var timed := TimedCache.new()
		timed.path = old.path;timed.scope = old.scope;timed.entries = old.entries
		cache_owner.set(property,timed)
	for step: Dictionary in [{"index":10,"dwell":0},{"index":18,"dwell":0},{"index":25,"dwell":0},{"index":10,"dwell":0},{"index":6,"dwell":600}]:
		var index: int = int(step.index)
		if index >= app.cloud.discovery_pages.total: continue
		browser.gallery.scroll_horizontal = int(index*browser.tile_stride)
		browser._render_tiles(true)
		var deadline: int = Time.get_ticks_msec()+30000
		while app.cloud.discovery_pages.entry_at(index).is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		var entry: Dictionary = app.cloud.entry_from_metadata(app.cloud.discovery_pages.entry_at(index))
		if int(step.dwell) > 0: await create_timer(float(step.dwell)/1000.0).timeout
		var start: int = Time.get_ticks_usec()
		var previous: int = start
		var worst: float = 0.0
		var chart_ms: float = -1
		var geometry_ms: float = -1
		var select_ms: float = -1
		browser._select(entry)
		select_ms = (Time.get_ticks_usec()-start)/1000.0
		while Time.get_ticks_usec()-start < 12000000:
			await process_frame
			var now: int = Time.get_ticks_usec()
			worst = maxf(worst,(now-previous)/1000.0)
			previous = now
			var chart: TrackDistribution = browser.detail.find_child("RaceDistribution",true,false)
			if chart_ms < 0 and chart != null and chart.is_visible_in_tree() and not chart.snapshot.get("bins",[]).is_empty(): chart_ms = (now-start)/1000.0
			if geometry_ms < 0 and not browser.selecting and not browser.selected_track.metadata.get("metadata_only",false) and browser.selected_track.metadata.get("cloud_version","") == entry.version_id: geometry_ms = (now-start)/1000.0
			if chart_ms >= 0 and (geometry_ms >= 0 or browser.selected_track.metadata.get("metadata_only",false)): break
		var row: Dictionary = {"index":index,"dwell_ms":int(step.dwell),"name":entry.name,"select_ms":select_ms,"chart_ms":chart_ms,"geometry_ms":geometry_ms,"worst_frame_ms":worst,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"comparison_pending":browser.discovery.comparisons.pending(entry.version_id,VehicleCatalog.selected)}
		rows.append(row)
		print("LIVE_CARD_SELECTION ",JSON.stringify(row))
	var path: String = ProjectSettings.globalize_path("res://../build/card-selection-latency/live-timings.json")
	var output := FileAccess.open(path,FileAccess.WRITE)
	output.store_string(JSON.stringify(rows,"\t"));output.close()
	if DisplayServer.get_name() != "headless":
		await create_timer(0.5).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/card-selection-latency-2026-10-10")
		DirAccess.make_dir_recursive_absolute(evidence)
		root.get_texture().get_image().save_png(evidence.path_join("live-warmed-selection.png"))
	app.queue_free()
	await process_frame
	quit()

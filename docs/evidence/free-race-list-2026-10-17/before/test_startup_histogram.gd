extends "res://tests/test_menu_loading_speed.gd"
## Actual restored selection and cached-page activation, without manual hydration.

class StartupService extends Service:
	var signed: bool = true
	var fail_comparison: bool = false
	func signed_in() -> bool: return signed
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		while hold_comparison: await get_tree().process_frame
		return {"ok":not fail_comparison,"data":packet if not fail_comparison else {},"error":"Unavailable" if fail_comparison else ""}

class StartupCloud extends Cloud:
	func add_to_catalog(catalog: TrackCatalog, provider: TrackDiscoveryProvider, _favorites: Array = []) -> void:
		catalog.entries.assign(entries)
		provider.available = true
	func query_discovery(_state: Dictionary, _favorites: Array = [], _raced: Array = []) -> void: pass

func make_browser(service: StartupService, track: NativeTrack, preview: bool, provider: TrackDiscoveryProvider = null) -> TrackBrowser:
	var cloud := StartupCloud.new()
	cloud.client = service
	cloud.entries.append({"id":track.identity,"source":"cloud","version_id":track.metadata.cloud_version,"name":track.metadata.get("title","Startup circuit"),"creator":"Beat my track","theme":track.metadata.get("theme","pine"),"points":track.metadata.get("creator_document",{}).get("points",TrackDocument.create_default().points)})
	root.add_child(cloud)
	var browser := TrackBrowser.new()
	browser.name = "StartupHistogramBrowser"
	browser.theme = MenuStyle.theme()
	browser.library = TrackLibrary.new(folder.path_join("tracks"))
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.catalog = TrackCatalog.new(browser.library)
	browser.catalog.indexed_revision = browser.library.revision
	browser.catalog.entries.assign(cloud.entries)
	browser.catalog.remember_track(cloud.entries[0],track)
	browser.selected_track = track
	browser.cloud = cloud
	browser.state = {}
	browser.page_preview = preview
	if provider != null: browser.discovery = provider
	root.add_child(browser)
	MenuStyle.fill(browser)
	browser.offset_top = 112
	browser.offset_bottom = -16
	return browser

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/startup-histogram/fixture")
	DirAccess.make_dir_recursive_absolute(folder)
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/startup-histogram-2026-10-10")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	track.metadata.cloud_version = "startup-histogram-fixture"
	track.metadata.title = "Startup circuit"
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/histogram-grid-2026-10-09/verified-silmukka-histograms.json")).packet
	for preview: bool in [false,true]:
		var service := StartupService.new()
		service.packet = packet
		root.add_child(service)
		var browser: TrackBrowser = make_browser(service,track,preview)
		await settle()
		if preview:
			check(service.paths.is_empty(),"preparing an adjacent menu page starts no HTTP work")
			browser.activate_page()
			await settle()
		check(service.paths.size() == 2,"initial visible restored selection starts exactly one leaderboard and one histogram request")
		check(browser._cloud_detail_pending.size() == 1,"initial loading indicator corresponds to a real histogram request")
		check(not browser.race_button.disabled,"histogram never holds the race action")
		if preview: await capture("promoted-loading")
		else: await capture("startup-loading")
		service.hold_comparison = false
		await settle()
		var key: String = browser.records.key_for(track,HandlingSelection.config())
		check(browser._comparison_ready(browser.discovery.record_snapshot(key)),"initial request replaces loading with both server histograms")
		check(browser._cloud_detail_pending.is_empty(),"completed request clears pending state")
		check(not texts(browser.find_child("RaceComparison",true,false)).contains("Loading..."),"histogram loading caption disappears while leaderboard remains held")
		var before: int = service.paths.size()
		for repeat: int in range(3):
			browser._show_detail()
			browser.cloud.changed.emit()
			browser._select(browser.catalog.entries[0])
			await settle()
		check(service.paths.size() == before,"same selection and catalog notifications do not poll histograms")
		if preview: await capture("promoted-ready")
		else: await capture("startup-ready")
		service.hold_board = false
		await settle()
		browser.cloud.queue_free()
		browser.queue_free()
		service.queue_free()
		await process_frame
	var failed := StartupService.new()
	failed.packet = packet
	failed.hold_comparison = false
	failed.hold_board = false
	failed.fail_comparison = true
	root.add_child(failed)
	var failed_browser: TrackBrowser = make_browser(failed,track,false)
	await settle()
	check(texts(failed_browser.find_child("RaceComparison",true,false)).contains("Comparison unavailable"),"failed initial comparison becomes an unavailable state")
	check(failed_browser._cloud_detail_pending.is_empty(),"failure clears the loading operation")
	failed_browser.cloud.queue_free()
	failed_browser.queue_free()
	failed.queue_free()
	await process_frame
	var immediate := StartupService.new()
	immediate.packet = packet
	immediate.hold_comparison = false
	immediate.hold_board = false
	root.add_child(immediate)
	var immediate_browser: TrackBrowser = make_browser(immediate,track,false)
	await settle()
	check(immediate.paths.size() == 2,"synchronous replies do not recursively start extra reads")
	check(not immediate_browser._detail_loading,"immediate response cannot be overwritten by an earlier loading render")
	check(immediate_browser._comparison_ready(immediate_browser.discovery.record_snapshot(immediate_browser.records.key_for(track,HandlingSelection.config()))),"synchronous response keeps the completed histogram")
	immediate_browser.cloud.queue_free()
	immediate_browser.queue_free()
	immediate.queue_free()
	await process_frame
	var guest := StartupService.new()
	guest.signed = false
	guest.hold_comparison = false
	guest.hold_board = false
	root.add_child(guest)
	var guest_browser: TrackBrowser = make_browser(guest,track,false)
	await settle()
	check(guest.paths.size() == 1 and not guest.paths[0].contains("results-comparison"),"guest startup preserves the authenticated comparison gate")
	check(not guest_browser._detail_loading and texts(guest_browser.find_child("RaceComparison",true,false)).contains("Sign in to compare"),"guest comparison does not remain loading")
	guest_browser.cloud.queue_free()
	guest_browser.queue_free()
	guest.queue_free()
	await process_frame
	print("STARTUP_HISTOGRAM checks=",checks," failures=",failures)
	quit(1 if failures else 0)

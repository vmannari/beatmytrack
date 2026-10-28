extends "res://tests/test_startup_histogram.gd"
const PRELOADER = preload("res://backend/comparison_preloader.gd")
const REUSE = preload("res://backend/comparison_reuse.gd")
var summary: Dictionary = {}
var late_response: Dictionary = {}

func late_comparison(preloader: RefCounted) -> void:
	late_response = await preloader.comparison("late-account","compact",13000,2500,[13000,2500])

class ReuseService extends StartupService:
	var bad_overlay: bool = false
	func request_public(path: String, _owner: int) -> Dictionary:
		paths.append(path)
		while hold_board: await get_tree().process_frame
		var rows: Array = []
		var limit: int = 3 if path.contains("limit=3") else 20
		for index: int in limit: rows.append({"rank":index+1,"player_id":"fixture-%d" % index,"display_name":"Fixture_%02d" % (index+1),"country_code":"FI","time_ticks":12240+index*12})
		return {"ok":true,"data":{"board_id":"fixture","population":20,"items":rows,"next_cursor":null,"next_offset":null},"error":""}
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		if path.contains("/leaderboard"): return await request_public(path,0)
		paths.append(path)
		while hold_comparison: await get_tree().process_frame
		var data: Dictionary = packet.duplicate(true)
		for pair: Array in [["race","race"],["best_lap","lap"]]:
			for part: String in path.split("&"):
				if part.begins_with(pair[1]+"_ticks="):
					data[pair[0]].comparison = {"candidate_ticks":int(part.get_slice("=",1)),"position":50,"population":100,"top_percent":50}
		if path.contains("known_histogram="):
			data.schema = "bmt-comparison-overlay-v1"
			for metric: String in ["race","best_lap"]: data[metric].erase("bins")
			if bad_overlay: data.histogram_key = "b".repeat(64)
		return {"ok":true,"data":data,"error":""}

func comparisons(service: ReuseService) -> int:
	return service.paths.filter(func(path: String) -> bool: return path.contains("results-comparison")).size()

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/statistics-request-reuse/fixture-"+TrackLibrary.unique_id())
	evidence = ""
	DirAccess.make_dir_recursive_absolute(folder)
	VehicleCatalog.selected = "compact"
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/instant-comparisons-2026-10-10/slippery-compact-packet.json"))
	var clock: int = int(Time.get_unix_time_from_system())
	fixture.packet.freshness = {"generated_at":clock-10,"expires_at":clock+900}
	fixture.packet.histogram_key = "a".repeat(64)
	for pair: Array in [["race",13000],["best_lap",2500]]:
		fixture.packet[pair[0]].own_best_ticks = pair[1]
		fixture.packet[pair[0]].opponent_count = 99
		fixture.packet[pair[0]].comparison = {"candidate_ticks":pair[1],"position":50,"population":100,"top_percent":50}
	var service := ReuseService.new()
	service.packet = fixture.packet
	service.hold_comparison = false
	service.hold_board = false
	root.add_child(service)
	var provider := TrackDiscoveryProvider.new()
	provider.configure_cache(folder.path_join("records.json"),"fixture/account-a")
	provider.prime_comparisons(service,[fixture.entry],"compact")
	await settle()
	check(service.paths.size() == 2,"one cold prefetch uses one chart read and one three-row leaderboard")
	check(service.paths[0].contains("limit=3"),"prefetched leaderboard requests only the three displayed rows")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/instant-comparisons-2026-10-10/slippery-document.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	track.metadata.cloud_version = fixture.entry.version_id
	track.metadata.title = "Statistics reuse"
	var browser: TrackBrowser = make_browser(service,track,true,provider)
	var key: String = browser.records.key_for(track,HandlingSelection.config())
	browser.records.records[key] = {"race_ms":roundi(13000.0*1000.0/120.0),"flying_ms":roundi(2500.0*1000.0/120.0)}
	browser.page_preview = false
	browser._show_detail()
	await settle()
	check(comparisons(service) == 1,"matching verified race/lap PB opens from the fresh prefetch without another histogram request")
	check(provider.comparisons.diagnostics().speculative_used == 1,"cache hits count actual prefetch consumption for later hit-rate measurement")
	check(texts(browser).contains("Fixture_03") and not texts(browser).contains("Fixture_04"),"same three standing entries remain visible")
	for repeat: int in 3: browser._show_detail()
	check(comparisons(service) == 1,"unchanged detail redraws issue zero comparison reads")
	var cache_identity: String = PRELOADER.key(fixture.entry.version_id,"compact")
	var stale_board: Dictionary = provider.comparisons._finished[cache_identity].duplicate(true)
	stale_board._board_fetched_at = clock-601
	provider.comparisons._finished[cache_identity] = stale_board
	provider.comparisons.cache.remember(cache_identity,stale_board)
	var board_reads: int = service.paths.filter(func(path: String) -> bool: return path.contains("leaderboard")).size()
	await browser._load_cloud_detail(track)
	await browser._load_cloud_detail(track)
	check(service.paths.filter(func(path: String) -> bool: return path.contains("leaderboard")).size() == board_reads+1,"a refreshed three-row leaderboard is shared by repeated detail consumers")
	check(comparisons(service) == 1 and int(provider.comparisons.peek(fixture.entry.version_id,"compact")._fetched_at) == int(stale_board._fetched_at),"refreshing standings does not re-fetch histograms or renew their receipt timestamp")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image_path: String = ProjectSettings.globalize_path("res://../docs/evidence/statistics-request-reuse-2026-10-26/cache-detail-"+RenderingServer.get_current_rendering_method()+".png")
		check(root.get_texture().get_image().save_png(image_path) == OK,"save actual browser cache-hit appearance")
	var retained: Dictionary = provider.comparisons.peek(fixture.entry.version_id,"compact")
	check(REUSE.fresh(retained,clock+899) and not REUSE.fresh(retained,clock+900),"absolute server expiry bounds reuse")
	var old: Dictionary = retained.duplicate(true)
	old._fetched_at = clock+899
	check(not REUSE.fresh(old,clock+900),"receiving an old snapshot again cannot restart its deadline")
	var expired: Dictionary = retained.duplicate(true)
	expired.packet.freshness.expires_at = clock-1
	check(not REUSE.fresh(expired,clock),"expired server metadata cannot be reused")
	var future: Dictionary = retained.duplicate(true)
	future._fetched_at = clock+1
	check(not REUSE.fresh(future,clock),"backward local clock changes cannot extend reuse")
	var legacy: Dictionary = retained.duplicate(true)
	legacy.packet.erase("freshness")
	check(REUSE.fresh(legacy,clock+599) and not REUSE.fresh(legacy,clock+600),"older backend responses retain the bounded ten-minute fallback")
	check(not REUSE.matches(retained,12900,2500) and not REUSE.matches(retained,13000,2490),"race PB and flying-lap PB changes independently invalidate cached positions")
	var unchanged: Dictionary = await provider.comparisons.comparison(fixture.entry.version_id,"compact",13000,2500,[13000,2500])
	check(unchanged.get("cached",false) and comparisons(service) == 1,"unchanged PB consumes no HTTP request")
	var slower: Dictionary = await provider.comparisons.comparison(fixture.entry.version_id,"compact",13100,2510,[13000,2500])
	check(service.paths[-1].contains("known_histogram="),"slower result with unchanged PB requests positions without histogram bins")
	check(slower.ok and slower.data.race.bins == fixture.packet.race.bins and slower.data.race.comparison.candidate_ticks == 13100,"overlay retains the exact bars and binds the slower result's position")
	var before: int = comparisons(service)
	var repeated: Dictionary = await provider.comparisons.comparison(fixture.entry.version_id,"compact",13100,2510,[13000,2500])
	check(repeated.ok and comparisons(service) == before,"identical slower-result consumers reuse their cached comparison")
	var improved: Dictionary = await provider.comparisons.comparison(fixture.entry.version_id,"compact",12900,2500,[12900,2500])
	check(improved.ok and not service.paths[-1].contains("known_histogram="),"new race PB requests a complete refreshed comparison")
	var improved_lap: Dictionary = await provider.comparisons.comparison(fixture.entry.version_id,"compact",12900,2490,[12900,2490])
	check(improved_lap.ok and not service.paths[-1].contains("known_histogram="),"best-lap improvement also requests a complete comparison")
	var wrong: Dictionary = fixture.packet.duplicate(true)
	wrong.schema = "bmt-comparison-overlay-v1"
	wrong.histogram_key = "b".repeat(64)
	check(REUSE.merge_overlay(wrong,fixture.packet).is_empty(),"an overlay cannot use a different population/grid identity")
	var outside: Dictionary = await provider.comparisons.comparison(fixture.entry.version_id,"compact",999999,2490,[12900,2490])
	check(outside.ok and not service.paths[-1].contains("known_histogram="),"a time outside the retained chart frame requests full histogram data")
	while not preload("res://backend/menu_snapshot_writer.gd").idle(): await process_frame
	var restarted := PRELOADER.new()
	restarted.configure(service,provider.comparisons.cache.path,"fixture/account-a")
	check(restarted.peek(fixture.entry.version_id,"compact").has("packet"),"fresh validated histograms survive adapter restart")
	restarted.configure(service,provider.comparisons.cache.path,"fixture/account-b")
	check(restarted.peek(fixture.entry.version_id,"compact").is_empty(),"private comparisons never cross accounts")
	check(provider.comparisons.peek(fixture.entry.version_id,"kart").is_empty(),"different vehicle/configuration cannot reuse a packet")
	provider.comparisons.remember_comparison(fixture.entry.version_id,"compact",fixture.packet,[13000,2500],[13000,2500])
	var source := RaceResults.new()
	source.laps = [30.0,20.0,20.0,20.0,19.1666666667]
	source.total = 13100.0/120.0
	source.best = 13000.0/120.0
	source.previous = source.best
	source.clean = true
	var result_page := RaceComplete.new()
	result_page.results = source
	result_page.facts = {"flying":2510.0/120.0,"previous_lap":2500.0/120.0}
	result_page.cloud_client = service
	result_page.comparison_cache = provider.comparisons
	root.add_child(result_page)
	result_page.cloud_version = fixture.entry.version_id
	await result_page._refresh_rank()
	check(service.paths[-1].contains("known_histogram=") and result_page.last_comparison.race.bins == fixture.packet.race.bins,"actual results panel reuses the unchanged-PB bars through a position-only response")
	check(result_page.last_comparison.race.comparison.candidate_ticks == 13100 and result_page.global_rank.text == "TOP 50%","the slower result keeps its own position rather than borrowing the PB placement")
	before = comparisons(service)
	await result_page._refresh_rank()
	check(comparisons(service) == before,"same results panel consumers cause no repeat histogram or position request")
	source.total = 13200.0/120.0
	await result_page._refresh_rank()
	check(result_page.last_comparison.race.comparison.candidate_ticks == 13200 and service.paths[-1].contains("known_histogram="),"another non-improving race receives its own position while retaining exact bins")
	service.bad_overlay = true
	before = comparisons(service)
	var recovered: Dictionary = await provider.comparisons.comparison(fixture.entry.version_id,"compact",13300,2510,[13000,2500])
	check(recovered.ok and comparisons(service) == before+2 and not service.paths[-1].contains("known_histogram="),"a mismatched overlay retries exactly once with a full response")
	service.bad_overlay = false
	service.player.id = "other-account"
	check(provider.comparisons.peek(fixture.entry.version_id,"compact").is_empty(),"account changes reject already-cached private data before reconfiguration")
	var denied: Dictionary = await provider.comparisons.comparison(fixture.entry.version_id,"compact",13300,2510,[13000,2500])
	check(not denied.ok,"a stale account-bound cache cannot issue a new-account comparison")
	provider.comparisons.configure(service,provider.comparisons.cache.path,"fixture/account-a")
	check(provider.comparisons.peek(fixture.entry.version_id,"compact").is_empty(),"even an unchanged caller scope cannot expose the previous actor's persisted cache")
	service.player.id = "you"
	provider.comparisons.configure(service,provider.comparisons.cache.path,"fixture/account-a")
	service.hold_comparison = true
	late_comparison(provider.comparisons)
	await settle()
	service.player.id = "other-account"
	service.hold_comparison = false
	await settle()
	check(not late_response.get("ok",true),"late responses are fenced even before the main account-change callback reconfigures caches")
	service.player.id = "you"
	check(provider.comparisons.peek("late-account","compact").is_empty(),"late old-account response was not persisted")
	result_page.queue_free()
	source.free()
	await settle()
	var boards_before: int = service.paths.filter(func(path: String) -> bool: return path.contains("leaderboard")).size()
	browser._open_scores()
	await settle()
	check(service.paths.filter(func(path: String) -> bool: return path.contains("leaderboard")).size() == boards_before+1 and not service.paths[-1].contains("limit=3"),"full scores are fetched on explicit dialog opening rather than prefetched")
	service.hold_board = true
	service.hold_comparison = true
	provider.comparisons.prime([{"version_id":"unused-a"},{"version_id":"unused-b"}],"compact")
	provider.comparisons.prime([{"version_id":"queued-a"},{"version_id":"queued-b"}],"compact")
	check(provider.comparisons._queue.size() == 2,"fixture holds two genuinely queued speculative jobs")
	var held_reads: int = service.paths.size()
	browser.page_preview = true
	check(provider.comparisons._queue.is_empty(),"leaving the active browser clears queued background statistics")
	service.hold_board = false
	service.hold_comparison = false
	await settle()
	await settle()
	check(service.paths.size() == held_reads,"finishing old requests does not restart cancelled queued speculation")
	var foreground: Dictionary = await provider.comparisons.fetch("foreground-after-cancel","compact")
	check(foreground.has("packet"),"explicit foreground consumers still work after speculation is cancelled")
	var stale_packet: Dictionary = fixture.packet.duplicate(true)
	stale_packet.freshness.expires_at = clock-1
	provider.comparisons.remember_comparison("expired","compact",stale_packet)
	check(provider.comparisons.peek("expired","compact").is_empty(),"disk and memory caches both reject expired packets")
	before = comparisons(service)
	var refreshed: Dictionary = await provider.comparisons.comparison("expired","compact",13000,2500,[13000,2500])
	check(refreshed.ok and comparisons(service) == before+1,"an expired snapshot performs exactly one complete refresh")
	summary = {"checks":checks,"failures":failures,"matching_PB_histogram_reads":1,"preview_limit":3,"cancelled_queue_did_not_restart":service.paths.size() >= held_reads,"engine":Engine.get_version_info().string}
	var output := FileAccess.open(ProjectSettings.globalize_path("res://../docs/evidence/statistics-request-reuse-2026-10-26/native.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(summary,"  "))
	output.close()
	browser.cloud.queue_free()
	browser.queue_free()
	service.queue_free()
	await settle()
	while not preload("res://backend/menu_snapshot_writer.gd").idle(): await process_frame
	print("STATISTICS_REUSE ",JSON.stringify(summary))
	quit(1 if failures else 0)

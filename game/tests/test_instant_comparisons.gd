extends "res://tests/test_startup_histogram.gd"
const Preloader = preload("res://backend/comparison_preloader.gd")
var waiting_result: Dictionary = {}
var foreground_done: bool = false

func foreground(preloader: RefCounted, version: String) -> void:
	waiting_result = await preloader.fetch(version,"compact")
	foreground_done = true

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/instant-comparisons/fixture-"+TrackLibrary.unique_id())
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/instant-comparisons-2026-10-10")
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/instant-comparisons-2026-10-10/slippery-compact-packet.json"))
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/instant-comparisons-2026-10-10/slippery-document.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"actual published Slippery document compiles")
	if track == null: quit(1); return
	track.metadata.cloud_version = fixture.entry.version_id
	track.metadata.title = "Slippery"
	var service := StartupService.new()
	service.packet = fixture.packet
	service.hold_comparison = false
	service.hold_board = false
	root.add_child(service)
	var provider := TrackDiscoveryProvider.new()
	provider.configure_cache(folder.path_join("records.json"),"fixture/account-a")
	provider.prime_comparisons(service,[fixture.entry],"compact")
	var value: Dictionary = await provider.comparisons.fetch(fixture.entry.version_id,"compact")
	check(value.has("packet") and value.packet.race.population == 100,"preloading retains Slippery's actual 100-driver race field")
	check(service.paths.size() == 2,"preload and foreground requests coalesce for the same track/car")
	var browser: TrackBrowser = make_browser(service,track,true,provider)
	browser.page_preview = false
	browser._show_detail()
	await settle()
	check(not texts(browser).contains("Loading..."),"first visible warmed Slippery view has no loading caption")
	var chart: TrackDistribution = browser.find_child("RaceDistribution",true,false)
	check(chart.visible and chart.snapshot.bins.size() == 16,"Slippery shows all sixteen race bins on first open")
	check(browser.find_child("LapDistribution",true,false).visible,"Slippery shows its lap field on first open")
	var sum: int = 0
	for amount: int in chart.snapshot.bins: sum += amount
	check(sum == 100,"first-open chart preserves the exact live population")
	await capture("slippery-first-open")
	var reopened := TrackDiscoveryProvider.new()
	reopened.configure_cache(folder.path_join("records.json"),"fixture/account-a")
	reopened.prime_comparisons(service,[fixture.entry],"compact")
	check(reopened.comparisons.peek(fixture.entry.version_id,"compact").has("packet"),"restart restores the prefetched packet before network work")
	reopened.configure_cache(folder.path_join("records.json"),"fixture/account-b")
	check(reopened.comparisons.peek(fixture.entry.version_id,"compact").is_empty(),"another account cannot restore prefetched own-time data")
	check(provider.comparisons.peek(fixture.entry.version_id,"kart").is_empty(),"another car cannot reuse compact data")
	var corrupt := Preloader.new()
	corrupt.configure(service,provider.comparisons.cache.path,"fixture/account-a")
	var identity: String = Preloader.key(fixture.entry.version_id,"compact")
	corrupt.cache.entries[identity].data.packet.population_scope = "wrong"
	check(corrupt.peek(fixture.entry.version_id,"compact").is_empty(),"corrupt stored packets become a cache miss before display")
	browser.cloud.queue_free();browser.queue_free()
	await process_frame
	# Cold fallback stays quiet during a normal response interval.
	service.hold_comparison = true
	service.paths.clear()
	var cold: TrackBrowser = make_browser(service,track,false)
	await settle()
	check(not texts(cold).contains("Loading..."),"ordinary cold response interval exposes no loading caption")
	check(not texts(cold.find_child("RaceComparison",true,false)).contains("No times yet"),"pending data is never reported as empty")
	cold._detail_wait_started = Time.get_ticks_msec()-TrackBrowser.COMPARISON_NOTICE_DELAY_MS-1
	cold._show_detail()
	check(texts(cold.find_child("RaceComparison",true,false)).contains("Loading..."),"exceptional delay uses the existing loading notice")
	await capture("exceptional-delay")
	service.hold_comparison = false
	await settle()
	check(not texts(cold.find_child("RaceComparison",true,false)).contains("Loading..."),"completed exceptional request removes its notice")
	cold.cloud.queue_free();cold.queue_free()
	await process_frame
	# A genuine empty car field remains explicit, never substituted from compact.
	VehicleCatalog.selected = "kart"
	service.packet = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/instant-comparisons-2026-10-10/slippery-kart-packet.json"))
	var empty: TrackBrowser = make_browser(service,track,false)
	await settle()
	check(texts(empty.find_child("RaceComparison",true,false)).contains("No times yet"),"Slippery's actual empty kart field has an explicit empty state")
	check(not empty.find_child("RaceDistribution",true,false).visible,"empty kart field never borrows compact counts")
	await capture("slippery-kart-empty")
	empty.cloud.queue_free();empty.queue_free()
	await process_frame
	service.queue_free()
	await process_frame
	var held := StartupService.new()
	held.packet = fixture.packet
	root.add_child(held)
	var bounded := Preloader.new()
	bounded.configure(held,"","bounded/account-a")
	var entries: Array = []
	for index: int in range(20): entries.append({"version_id":"fixture-version-%d" % index})
	bounded.prime(entries,"compact")
	bounded.prime(entries,"compact")
	check(bounded._active == 2 and bounded._queue.size() <= Preloader.MAX_TARGETS,"warming has at most two active comparison jobs and a bounded queue")
	check(held.paths.size() == 4,"repeat startup notifications coalesce both active tracks")
	foreground_done = false
	foreground(bounded,"fixture-version-5")
	check(bounded._foreground_active == 1 and held.paths.any(func(path: String) -> bool: return path.contains("fixture-version-5") and path.contains("results-comparison")),"a selected track starts independently of two held background jobs")
	held.hold_comparison = false
	await settle()
	check(foreground_done and waiting_result.has("packet"),"foreground consumes the existing warming job")
	check(held.paths.filter(func(path: String) -> bool: return path.contains("fixture-version-5") and path.contains("results-comparison")).size() == 1,"foreground and warming do not duplicate the selected histogram")
	check(bounded.peek("fixture-version-5","compact").has("packet"),"histograms complete without waiting for the held leaderboard")
	held.hold_board = false
	await settle()
	held.hold_comparison = true
	held.hold_board = true
	bounded.prime([{"version_id":"old-account-version"}],"compact")
	bounded.configure(held,"","bounded/account-b")
	held.hold_comparison = false
	held.hold_board = false
	await settle()
	check(bounded.peek("old-account-version","compact").is_empty(),"a late response cannot populate another account's cache")
	bounded._finished["expired"] = {"_fetched_at":int(Time.get_unix_time_from_system())-610,"comparison_error":"Unavailable"}
	bounded._finished[Preloader.key("expired-version","compact")] = bounded._finished.expired
	check(bounded.peek("expired-version","compact").is_empty(),"process-memory responses obey the same maximum age")
	held.queue_free()
	await process_frame
	print("INSTANT_COMPARISONS checks=",checks," failures=",failures)
	quit(1 if failures else 0)

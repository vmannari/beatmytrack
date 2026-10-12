extends "res://tests/test_carousel_histograms.gd"
## Observe every handoff frame, including a local PB and a late score list.

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/histogram-continuity/fixture-"+TrackLibrary.unique_id())
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/histogram-continuity-2026-10-10")
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/instant-comparisons-2026-10-10/slippery-compact-packet.json")).packet
	var service := WindowService.new()
	service.packet = packet
	service.hold_board = false
	root.add_child(service)
	var document: Dictionary = TrackDocument.create_default()
	var track: NativeTrack = TrackCompiler.compile(document)
	track.metadata.cloud_version = "continuity-first"
	track.metadata.title = "First track"
	var target_document: Dictionary = document.duplicate(true)
	target_document.id = "continuity_target"
	target_document.name = "Next track"
	var body: String = JSON.stringify(target_document)
	var path: String = folder.path_join("next-track.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(body)
	file.close()
	var cloud := MetadataCloud.new()
	cloud.client = service
	cloud.entries = [
		{"id":track.identity,"source":"cloud","version_id":"continuity-first","name":"First track","creator":"Beat my track","theme":"pine","points":document.points},
		{"id":"continuity-next","source":"cloud","version_id":"continuity-next","track_id":"continuity-next","name":"Next track","creator":"Beat my track","theme":"pine","points":target_document.points,"cache_path":path,"content_hash":body.sha256_text()},
	]
	cloud.ready_versions = ["continuity-next"]
	root.add_child(cloud)
	var browser := TrackBrowser.new()
	browser.theme = MenuStyle.theme()
	browser.library = TrackLibrary.new(folder.path_join("tracks"))
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	var target: NativeTrack = RealCloud.compile_entry(cloud.entries[1])
	browser.records.records[browser.records.key_for(target,HandlingSelection.config())] = {"race_ms":88000,"flying_ms":16000}
	browser.catalog = TrackCatalog.new(browser.library)
	browser.catalog.indexed_revision = browser.library.revision
	browser.catalog.entries.assign(cloud.entries)
	browser.catalog.remember_track(cloud.entries[0],track)
	browser.selected_track = track
	browser.cloud = cloud
	browser.state = {}
	root.add_child(browser)
	MenuStyle.fill(browser)
	browser.offset_top = 112
	browser.offset_bottom = -16
	await wait_frames(12)
	service.hold_board = true
	browser.discovery.prime_comparisons(service,[cloud.entries[1]],"compact")
	await wait_frames(12)
	browser._select(cloud.entries[1])
	await wait_frames(12)
	var race: TrackDistribution = browser.detail.find_child("RaceDistribution",true,false)
	var lap: TrackDistribution = browser.detail.find_child("LapDistribution",true,false)
	check(race != null and race.visible and lap != null and lap.visible,"both warmed preview histograms are visible before geometry is ready")
	if race == null or lap == null: quit(1); return
	var race_bins: Array = race.snapshot.bins.duplicate()
	var lap_bins: Array = lap.snapshot.bins.duplicate()
	await create_timer(0.45).timeout
	await capture("preview-ready")
	service.held_versions = ["continuity-next"]
	browser._finish_selection({"track":target,"draft":{}}) # Explicit diagnostic handoff; browsing no longer compiles.
	var observed: Array[Dictionary] = []
	for frame: int in range(36):
		await process_frame
		var active_race: TrackDistribution = browser.detail.find_child("RaceDistribution",true,false)
		var active_lap: TrackDistribution = browser.detail.find_child("LapDistribution",true,false)
		var visible: bool = active_race != null and active_lap != null and active_race.is_visible_in_tree() and active_lap.is_visible_in_tree() and active_race.size.y >= 90 and active_lap.size.y >= 90
		var same_controls: bool = active_race == race and active_lap == lap
		var same_counts: bool = active_race != null and active_lap != null and active_race.snapshot.get("bins",[]) == race_bins and active_lap.snapshot.get("bins",[]) == lap_bins
		observed.append({"frame":frame,"selecting":browser.selecting,"visible":visible,"same_controls":same_controls,"same_counts":same_counts})
	check(not browser.selecting and browser.selected_track.metadata.cloud_version == "continuity-next","compiled target completes while its local-PB comparison read remains held")
	check(observed.all(func(sample: Dictionary) -> bool: return sample.visible and sample.same_counts),"every geometry-handoff frame retains both histograms and their exact counts")
	check(observed.all(func(sample: Dictionary) -> bool: return sample.same_controls),"geometry handoff preserves both chart controls")
	await capture("compiled-read-pending")
	service.held_versions.clear()
	await wait_frames(12)
	check(browser.detail.find_child("RaceDistribution",true,false) == race and browser.detail.find_child("LapDistribution",true,false) == lap,"same-shaped local-PB response updates the existing charts")
	service.hold_board = false
	await wait_frames(12)
	check(browser.detail.find_child("RaceDistribution",true,false) == race and browser.detail.find_child("LapDistribution",true,false) == lap,"late standings preserve both visible chart controls")
	check(browser.detail.find_child("RaceDistribution",true,false).snapshot.bins == race_bins,"late standings retain exact server counts")
	await capture("standings-ready")
	service.packet = service.packet.duplicate(true)
	for metric: String in ["race","best_lap"]:
		service.packet[metric].bins[0].count += 1
		service.packet[metric].population += 1
	await browser._load_cloud_detail(browser.selected_track)
	await wait_frames()
	check(browser.detail.find_child("RaceDistribution",true,false) == race and browser.detail.find_child("LapDistribution",true,false) == lap,"actual changed counts update both charts without replacing their controls")
	check(race.snapshot.bins[0] == race_bins[0]+1 and lap.snapshot.bins[0] == lap_bins[0]+1,"retained controls display the new exact counts rather than freezing the old shape")
	VehicleCatalog.selected = "kart"
	service.held_versions = ["continuity-next"]
	browser._show_detail()
	await wait_frames()
	check(browser.detail.find_child("RaceDistribution",true,false) != race and browser.detail.find_child("LapDistribution",true,false) != lap,"a different car cannot retain the compact chart controls")
	var kart_race: TrackDistribution = browser.detail.find_child("RaceDistribution",true,false)
	check(kart_race.snapshot.get("bins",[]).is_empty() and not kart_race.visible,"a pending kart field never displays the previous car's counts")
	service.packet = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/instant-comparisons-2026-10-10/slippery-kart-packet.json"))
	service.held_versions.clear()
	await wait_frames()
	check(texts(browser.detail.find_child("RaceComparison",true,false)).contains("No times yet"),"a confirmed empty car field still has its correct empty state")
	VehicleCatalog.selected = "compact"
	var report := FileAccess.open(evidence.path_join("frames.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(observed,"\t"))
	report.close()
	browser.queue_free()
	cloud.queue_free()
	await wait_frames()
	service.queue_free()
	await process_frame
	print("HISTOGRAM_CONTINUITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

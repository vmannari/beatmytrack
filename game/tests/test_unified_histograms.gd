extends "res://tests/test_race_results.gd"
## Discovery and results use one comparison field; no implementation captions in UI.

class PreviewBrowser extends TrackBrowser:
	func _load_catalog() -> void:
		loading = false
		_show_detail()

class Client extends Node:
	var packet: Dictionary
	var paths: Array[String] = []
	var hold: bool = false
	var fail: bool = false
	func signed_in() -> bool: return true
	func cancel_public_reads(_owner: int) -> void: pass
	func request_public(path: String, _owner: int) -> Dictionary:
		paths.append(path)
		return {"ok":true,"data":{"items":[{"rank":1,"display_name":"You","time_ticks":10336}],"population":1},"error":""}
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		while hold: await get_tree().process_frame
		if fail: return {"ok":false,"data":{},"error":"Fixture unavailable"}
		return {"ok":true,"data":packet,"error":""}

class Cloud extends Node:
	signal changed
	var status: String = ""
	var refreshing: bool = false
	var client: Node
	var discovery_pages: Node
	var entries: Array[Dictionary] = []
	func paged_discovery_available() -> bool: return false

func run() -> void:
	await test_completion_distributions()
	var directory: String = OS.get_environment("BMT_RESULTS_EVIDENCE")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../docs/evidence/unified-driver-histograms-2026-10-08")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("verified-silmukka-histograms.json")))
	var client := Client.new()
	client.packet = fixture.packet
	client.hold = true
	root.add_child(client)
	var cloud := Cloud.new()
	cloud.client = client
	root.add_child(cloud)
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	track.metadata.cloud_version = "unified-silmukka-fixture"
	track.metadata.title = "Silmukka"
	var browser := PreviewBrowser.new()
	browser.theme = MenuStyle.theme()
	browser.library = TrackLibrary.new("user://unified_histogram_fixture/drafts")
	browser.catalog = TrackCatalog.new(browser.library)
	browser.catalog.entries.append({"id":track.identity,"version_id":"unified-silmukka-fixture","source":"cloud","name":"Silmukka","creator":"Beat my track","theme":"pine","points":TrackDocument.create_default().points})
	browser.records = LocalRecords.new("user://unified_histogram_fixture/records.json")
	browser.records.records[browser.records.key_for(track,HandlingSelection.config())] = {"race_ms":86130,"flying_ms":15881}
	browser.cloud = cloud
	browser.selected_track = track
	browser.state = {"sort":"name"}
	var old_key: String = browser.records.key_for(track,HandlingSelection.config())
	browser.discovery.records_by_rules_key[old_key] = {"comparison_scope":"all","comparison_bins":8,"race_distribution":{"bins":[101]}}
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280,720)
	root.add_child(browser)
	MenuStyle.fill(browser)
	# Match the space available below the real menu header and outer margins.
	browser.offset_top = 112
	browser.offset_bottom = -16
	browser.offset_left = 18
	browser.offset_right = -18
	await settle()
	var initial_chart: TrackDistribution = browser.find_child("RaceDistribution",true,false)
	check(initial_chart == null or initial_chart.snapshot.get("bins",[]).is_empty(),"old coarse cache never flashes before the finer response")
	check(not ui_text(browser).contains("No times yet"),"first loading frame never claims the track has no times")
	if DisplayServer.get_name() != "headless":
		capture = true
		await screenshot("initial-loading")
	client.hold = false
	await settle()
	var key: String = browser.records.key_for(track,HandlingSelection.config())
	var snapshot: Dictionary = browser.discovery.record_snapshot(key)
	check(snapshot.comparison_scope == "all","discovery uses the unified population")
	check(snapshot.comparison_bins == 16,"discovery cache identifies the finer histogram contract")
	var count: int = 0
	for amount: int in snapshot.race_distribution.bins: count += amount
	check(count == 101,"one discovery chart contains all 100 retained drivers and the player's fixture")
	check(snapshot.race_distribution.markers.size() == 1 and snapshot.race_distribution.markers[0].value_ms == 86130,"player time is marked in the same chart")
	var geometry: Dictionary = TrackDistribution.comparison_geometry(snapshot.race_distribution,500)
	check(geometry.window == Vector2i(0,snapshot.race_distribution.bins.size()-1),"unified view renders every bin instead of cropping the sparse real-player tail")
	check(browser.find_child("TestHistogramToggle",true,false) == null,"discovery has no driver-source selector")
	check(not snapshot.has("test_population"),"no diagnostic population caption in the display cache")
	var labels: String = ui_text(browser).to_lower()
	for forbidden: String in ["test data","player data","simulated drivers","samples"]:
		check(not labels.contains(forbidden),"ordinary discovery UI excludes "+forbidden)
	var before: Dictionary = snapshot.duplicate(true)
	client.hold = true
	browser.call_deferred("_load_cloud_detail",track)
	await settle()
	var pending_requests: int = client.paths.size()
	browser.call_deferred("_load_cloud_detail",track)
	await settle()
	check(client.paths.size() == pending_requests,"duplicate pending histogram reads are coalesced")
	check(browser.discovery.record_snapshot(key) == before,"pending discovery read preserves the complete unified chart")
	client.hold = false
	await settle()
	check(browser.discovery.record_snapshot(key) == before,"identical discovery data stays stable")
	check(client.paths[-1].contains("bins=16") and client.paths[-1].contains("race_from_ticks="),"discovery preserves the displayed grid during refresh")
	browser.catalog.indexed_revision = browser.library.revision
	browser.catalog.remember_track(browser.catalog.entries[0],track)
	var selection_requests: int = client.paths.size()
	var selected_chart: TrackDistribution = browser.find_child("RaceDistribution",true,false)
	for repeat: int in range(3):
		browser._select(browser.catalog.entries[0])
		browser.discovery.changed.emit()
		await settle()
	check(client.paths.size() == selection_requests,"same track selection and discovery signals never refresh histograms")
	check(browser.find_child("RaceDistribution",true,false) == selected_chart,"unchanged discovery events preserve the displayed chart instance")
	check(client.paths.all(func(path: String) -> bool: return not path.contains("/histogram") and not path.contains("test_population")),"discovery never queries split histogram sources")
	var chart: Control = browser.find_child("RaceDistribution",true,false)
	check(chart != null and chart.size.y >= 90,"removed captions leave usable chart height")
	var lap_chart: Control = browser.find_child("LapDistribution",true,false)
	check(lap_chart != null and lap_chart.visible,"discovery displays the best-lap histogram alongside the race histogram")
	if DisplayServer.get_name() != "headless":
		capture = true
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
			root.size = dimensions
			await settle()
			var actions: Control = browser.find_child("PlayActions",true,false)
			check(actions.get_global_rect().end.y <= browser.get_global_rect().end.y,"complete Free Race action row fits below the menu header")
			await screenshot("discovery-%dx%d" % [dimensions.x,dimensions.y])
	# A driver without either a local or verified PB still sees the complete field.
	client.packet = client.packet.duplicate(true)
	for metric: String in ["race","best_lap"]:
		client.packet[metric].own_best_ticks = null
		client.packet[metric].comparison = null
	browser.records.records.clear()
	browser.discovery.records_by_rules_key.clear()
	client.paths.clear()
	browser.catalog.indexed_revision = browser.library.revision
	browser.catalog.remember_track(browser.catalog.entries[0],track)
	# A reopened browser begins with no selection request, even if its retained
	# selected track and comparison cache were prepared by the previous page.
	browser._comparison_selection = ""
	browser._select(browser.catalog.entries[0])
	await settle()
	check(client.paths.any(func(path: String) -> bool: return path.contains("/results-comparison")),"reopening the cached selected track hydrates its histograms without a player record")
	check_no_time_charts(browser,track)
	check(client.paths.any(func(path: String) -> bool: return path.contains("/results-comparison") and not path.contains("&race_ticks=") and not path.contains("&lap_ticks=")),"a track with no personal time requests both distributions without a candidate")
	if DisplayServer.get_name() != "headless":
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
			root.size = dimensions
			await settle()
			check_chart_layout(browser)
			await screenshot("discovery-no-time-%dx%d" % [dimensions.x,dimensions.y])
	for index: int in range(2):
		var document: Dictionary = TrackDocument.create_default()
		document.id = "unraced_discovery_%d" % index
		document.name = "Unraced track %d" % index
		var unraced: NativeTrack = TrackCompiler.compile(document)
		unraced.metadata.cloud_version = "unraced-fixture-%d" % index
		browser.catalog.entries.append({"id":unraced.identity,"version_id":unraced.metadata.cloud_version,"source":"cloud","name":document.name,"creator":"Beat my track","theme":"pine"})
		client.hold = true
		var previous_chart: TrackDistribution = browser.find_child("RaceDistribution",true,false)
		var requests_before_selection: int = client.paths.size()
		browser._finish_selection({"track":unraced,"draft":{}})
		await settle()
		var loading_chart: TrackDistribution = browser.find_child("RaceDistribution",true,false)
		check(loading_chart != previous_chart and loading_chart.snapshot.is_empty() and not loading_chart.visible,"cold track never presents the previous track's histogram")
		check((browser.hero.find_child("HeroTrackTitle",true,false) as Label).text == document.name.to_upper(),"cold track hero appears without waiting for comparison data")
		check(not ui_text(browser).contains("No times yet"),"pending track selection never flashes an empty histogram message")
		check(not browser.race_button.disabled,"optional comparison loading never blocks a resolved track from racing")
		for frame: int in range(12):
			await process_frame
			check(browser.find_child("RaceDistribution",true,false) == loading_chart and not ui_text(browser).contains("No times yet"),"delayed histogram keeps the current track's truthful loading view on frame %d" % frame)
		await screenshot("track-%d-waiting" % index)
		client.hold = false
		await settle()
		check(client.paths.size() == requests_before_selection+2,"new track selection makes one leaderboard and one comparison request")
		check_no_time_charts(browser,unraced)
		check(not browser._detail_loading,"ready comparison releases the pending track reveal")
		await screenshot("track-%d-ready" % index)
	# Revisit a complete cache: values appear immediately while refresh is pending.
	client.hold = true
	browser._finish_selection({"track":track,"draft":{}})
	await settle()
	check(not browser._detail_loading and not browser.race_button.disabled,"warm track cache reveals immediately without blocking racing")
	check_no_time_charts(browser,track)
	client.hold = false
	await settle()
	# Service failure releases the view with an honest unavailable state; only a
	# successful zero-population response may claim there are no recorded times.
	browser.discovery.records_by_rules_key.clear()
	client.fail = true
	browser._finish_selection({"track":track,"draft":{}})
	await settle()
	check(not browser._detail_loading and not browser.race_button.disabled,"comparison failure never leaves the track loading or blocks racing")
	check(ui_text(browser).contains("Comparison unavailable") and not ui_text(browser).contains("No times yet"),"failed histogram reads never masquerade as an empty population")
	client.fail = false
	client.packet = client.packet.duplicate(true)
	for metric: String in ["race","best_lap"]:
		client.packet[metric].bins = []
		client.packet[metric].population = 0
		client.packet[metric].minimum_ticks = null
		client.packet[metric].maximum_ticks = null
	client.hold = true
	browser.call_deferred("_load_cloud_detail",track)
	await settle()
	check(not ui_text(browser).contains("No times yet"),"zero-population response is not guessed while the read is pending")
	client.hold = false
	await settle()
	check(ui_text(browser).contains("No times yet") and not ui_text(browser).contains("Comparison unavailable"),"confirmed empty comparison shows the truthful empty state and clears the prior error")
	browser.free()
	cloud.free()
	client.free()
	print("UNIFIED_HISTOGRAMS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

func check_no_time_charts(browser: TrackBrowser, track: NativeTrack) -> void:
	var snapshot: Dictionary = browser.discovery.record_snapshot(browser.records.key_for(track,HandlingSelection.config()))
	check(not snapshot.has("race_ms") and not snapshot.has("lap_ms"),"unraced track does not invent a player time")
	for metric: String in ["race","lap"]:
		var chart: TrackDistribution = browser.find_child("RaceDistribution" if metric == "race" else "LapDistribution",true,false)
		check(chart != null and chart.visible and not chart.snapshot.get("bins",[]).is_empty(),metric+" histogram is visible without a player record")
		check(chart != null and chart.snapshot.get("markers",[]).is_empty(),metric+" histogram does not invent a YOU marker")
		check(snapshot[metric+"_distribution"].bins == chart.snapshot.bins,metric+" chart preserves the complete server distribution")
	check(not ui_text(browser).contains("Set a time to see how you compare."),"missing personal time never gates available comparisons")

func check_chart_layout(browser: TrackBrowser) -> void:
	var race: Control = browser.find_child("RaceDistribution",true,false)
	var lap: Control = browser.find_child("LapDistribution",true,false)
	check(race.get_global_rect().end.x <= lap.get_global_rect().position.x,"race and lap charts sit side by side without overlap")
	check(is_equal_approx(race.global_position.y,lap.global_position.y),"both histogram baselines align")
	var panel: Control = browser.find_child("RecordsSlot",true,false)
	check(panel.get_global_rect().encloses(race.get_global_rect()) and panel.get_global_rect().encloses(lap.get_global_rect()),"both complete charts fit inside the records panel")

func ui_text(node: Node) -> String:
	var value: String = node.text if node is Label or node is Button else ""
	for child: Node in node.get_children(): value += "\n"+ui_text(child)
	return value

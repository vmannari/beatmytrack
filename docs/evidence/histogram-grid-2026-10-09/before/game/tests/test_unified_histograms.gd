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
	func signed_in() -> bool: return true
	func cancel_public_reads(_owner: int) -> void: pass
	func request_public(path: String, _owner: int) -> Dictionary:
		paths.append(path)
		return {"ok":true,"data":{"items":[{"rank":1,"display_name":"You","time_ticks":10336}],"population":1},"error":""}
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		while hold: await get_tree().process_frame
		return {"ok":true,"data":packet,"error":""}

class Cloud extends Node:
	signal changed
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
	browser.catalog.entries.append({"id":track.identity,"version_id":"unified-silmukka-fixture","source":"cloud","name":"Silmukka","creator":"Beat my track","theme":"pine"})
	browser.records = LocalRecords.new("user://unified_histogram_fixture/records.json")
	browser.records.records[browser.records.key_for(track,HandlingSelection.config())] = {"race_ms":86130,"flying_ms":15881}
	browser.cloud = cloud
	browser.selected_track = track
	browser.state = {"sort":"name"}
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280,720)
	root.add_child(browser)
	MenuStyle.fill(browser)
	await settle()
	await browser._load_cloud_detail(track)
	var key: String = browser.records.key_for(track,HandlingSelection.config())
	var snapshot: Dictionary = browser.discovery.record_snapshot(key)
	check(snapshot.comparison_scope == "all","discovery uses the unified population")
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
	check(browser.discovery.record_snapshot(key) == before,"pending discovery read preserves the complete unified chart")
	client.hold = false
	await settle()
	check(browser.discovery.record_snapshot(key) == before,"identical discovery data stays stable")
	check(client.paths.all(func(path: String) -> bool: return not path.contains("/histogram") and not path.contains("test_population")),"discovery never queries split histogram sources")
	var chart: Control = browser.find_child("RaceDistribution",true,false)
	check(chart != null and chart.size.y >= 90,"removed captions leave usable chart height")
	if DisplayServer.get_name() != "headless":
		capture = true
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
			root.size = dimensions
			await settle()
			await screenshot("discovery-%dx%d" % [dimensions.x,dimensions.y])
	browser.free()
	cloud.free()
	client.free()
	print("UNIFIED_HISTOGRAMS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

func ui_text(node: Node) -> String:
	var value: String = node.text if node is Label or node is Button else ""
	for child: Node in node.get_children(): value += "\n"+ui_text(child)
	return value

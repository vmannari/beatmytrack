extends "res://tests/test_startup_histogram.gd"
## A local PB, verified PB and warmed placement must refer to the same time.

class PersonalService extends StartupService:
	var held_ticks: Dictionary = {}
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		while hold_comparison: await get_tree().process_frame
		for held: String in held_ticks.keys():
			while path.contains("&"+held+"&") and held_ticks.get(held,false): await get_tree().process_frame
		var response: Dictionary = packet.duplicate(true)
		for metric: String in ["race","best_lap"]:
			var prefix: String = "race" if metric == "race" else "lap"
			var candidate: int = int(response[metric].own_best_ticks)
			for part: String in path.split("&"):
				if part.begins_with(prefix+"_ticks="): candidate = int(part.get_slice("=",1))
			var faster: int = 0
			if candidate > int(response[metric].minimum_ticks): faster = 39
			response[metric].comparison = {"position":faster+1,"population":100,"top_percent":faster+1,"candidate_ticks":candidate}
		return {"ok":true,"data":response,"error":""}

func packet() -> Dictionary:
	var result: Dictionary = {"board_id":"personal-fixture","population_scope":"all"}
	for metric: String in ["race","best_lap"]:
		var low: int = 11400 if metric == "race" else 2300
		var step: int = 300 if metric == "race" else 60
		var own: int = low+step*6
		var bins: Array[Dictionary] = []
		for index: int in range(16): bins.append({"from_ticks":low+index*step,"to_ticks_exclusive":low+(index+1)*step,"count":39 if index == 0 else 1 if index == 6 else 60 if index == 15 else 0})
		result[metric] = {"board_id":result.board_id,"metric":metric,"population":100,"opponent_count":99,"minimum_ticks":low,"maximum_ticks":low+step*15,"own_best_ticks":own,"bins":bins,"comparison":{"position":40,"population":100,"top_percent":40,"candidate_ticks":own}}
	return result

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/personal-comparison/fixture-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/personal-comparison-2026-10-11")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280,720)
	var document: Dictionary = TrackDocument.create_default()
	document.theme = "winter"
	var track: NativeTrack = TrackCompiler.compile(document)
	track.metadata.cloud_version = "personal-comparison-fixture"
	track.metadata.title = "Slippery fixture"
	var service := PersonalService.new()
	service.packet = packet()
	root.add_child(service)
	var browser: TrackBrowser = make_browser(service,track,true)
	var key: String = browser.records.key_for(track,HandlingSelection.config())
	browser.records.records[key] = {"race_ms":91750,"flying_ms":17789}
	var snapshot: Dictionary = {}
	check(browser._apply_cloud_comparison(snapshot,service.packet,track),"warmed packet with an older verified PB is accepted")
	browser.discovery.remember_record(key,snapshot)
	browser._show_detail()
	await settle()
	check(not texts(browser.detail).contains("TOP 40%"),"faster local PB never inherits the older verified PB's Top 40 percent")
	check(snapshot.race_distribution.markers[0].value_ms == 91750,"warmed histogram retains the actual local PB marker")
	await capture("stale-placement-hidden")
	service.hold_comparison = false
	await browser._load_cloud_detail(track)
	await settle()
	check(service.paths[-1].contains("race_ticks=11010") and service.paths[-1].contains("lap_ticks=2135"),"foreground comparison requests the displayed local race and lap PBs")
	check(texts(browser.detail).contains("POSITION 1") and not texts(browser.detail).contains("TOP 40%"),"completed overlay aligns fastest local PB with position one")
	var aligned: Dictionary = browser.discovery.record_snapshot(key)
	check(aligned.lap_comparison is Dictionary and aligned.lap_comparison.candidate_ticks == 2135,"millisecond lap display retains its exact quantized-tick comparison")
	await capture("aligned-fastest")
	# The server has a better PB than this device: request that displayed PB.
	service.packet.race.own_best_ticks = 10800
	service.packet.race.comparison = {"position":1,"population":100,"top_percent":1,"candidate_ticks":10800}
	service.packet.best_lap.own_best_ticks = 2040
	service.packet.best_lap.comparison = {"position":1,"population":100,"top_percent":1,"candidate_ticks":2040}
	snapshot = {}
	browser._apply_cloud_comparison(snapshot,service.packet,track)
	browser.discovery.remember_record(key,snapshot)
	await browser._load_cloud_detail(track)
	check(service.paths[-1].contains("race_ticks=10800"),"a faster verified PB is the comparison candidate rather than the slower device PB")
	check(service.paths[-1].contains("lap_ticks=2040") and texts(browser.detail).contains("Best lap  00:17.000"),"lap caption, marker and requested comparison also use the faster verified PB")
	check((browser.find_child("LibraryBestTime",true,false) as Label).text == "01:30.000","record caption shows the same faster verified PB")
	await capture("aligned-verified-pb")
	# Cached results must also react to a new local record without a reselection.
	var old_selection: String = browser._comparison_selection_key(track)
	browser.records.records[key].race_ms = 89000
	check(browser._comparison_selection_key(track) != old_selection,"a newly completed local PB creates one new comparison selection")
	service.hold_comparison = true
	service.hold_board = false
	browser.page_preview = false
	var requests_before: int = service.paths.filter(func(path: String) -> bool: return path.contains("results-comparison")).size()
	browser._show_detail()
	await settle()
	var chart: TrackDistribution = browser.find_child("RaceDistribution",true,false)
	check(chart.snapshot.markers[0].value_ms == 89000 and (browser.find_child("LibraryBestTime",true,false) as Label).text == "01:29.000","cached chart marker and record caption advance together to the new local PB")
	check(not texts(browser.detail).contains("POSITION 1"),"cached placement for the previous PB is withheld until the new candidate returns")
	for repeat: int in range(3): browser._show_detail()
	check(service.paths.filter(func(path: String) -> bool: return path.contains("results-comparison")).size() == requests_before+1,"a new local PB automatically starts exactly one overlay read without reselection or polling")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.race_comparison.erase("candidate_ticks")
	browser.discovery.remember_record(key,legacy)
	browser._show_detail()
	check(not texts(browser.detail).contains("POSITION 1"),"unbound legacy cached placements never label a different time")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		await capture("cached-new-pb-%dx%d" % [dimensions.x,dimensions.y])
	service.hold_comparison = false
	await settle()
	check(texts(browser.detail).contains("POSITION 1") and (browser.find_child("RaceDistribution",true,false) as TrackDistribution).snapshot.markers[0].value_ms == 89000,"new local PB placement appears when its exact overlay read completes")
	service.held_ticks["race_ticks=10560"] = true
	browser.records.records[key].race_ms = 88000
	browser._show_detail()
	await settle()
	browser.records.records[key].race_ms = 87000
	browser._show_detail()
	await settle()
	check(browser.discovery.record_snapshot(key).race_comparison.candidate_ticks == 10440,"a later PB's comparison completes independently of an older held request")
	service.held_ticks["race_ticks=10560"] = false
	await settle()
	check(browser.discovery.record_snapshot(key).race_comparison.candidate_ticks == 10440 and texts(browser.detail).contains("POSITION 1"),"late comparison for an older PB cannot erase the latest placement")
	browser.queue_free()
	await settle()
	service.queue_free()
	print("PERSONAL_COMPARISON: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

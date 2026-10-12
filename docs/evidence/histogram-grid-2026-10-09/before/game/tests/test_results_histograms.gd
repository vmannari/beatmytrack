extends "res://tests/test_race_results.gd"
## Focused histogram acceptance; the broader results fixture has unrelated catalog assumptions.

func run() -> void:
	var requested_capture: bool = capture or (DisplayServer.get_name() != "headless" and not OS.get_environment("BMT_RESULTS_EVIDENCE").is_empty())
	capture = false
	await test_completion_distributions()
	await test_histogram_tails()
	var live_path: String = OS.get_environment("BMT_LIVE_RESULTS_PACKET")
	if not live_path.is_empty(): await test_live_comparison(live_path)
	capture = requested_capture
	if capture: await capture_comparisons()
	print("RESULTS_HISTOGRAMS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

func test_live_comparison(path: String) -> void:
	var response: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(response is Dictionary and response.get("comparison_status") == 200,"live results endpoint returned a complete packet")
	if not response is Dictionary or not response.get("packet") is Dictionary: return
	# The owner-supplied result times are display fixtures, never submitted races.
	# Zero lap placeholders supply only the five-lap heading; no lap analysis runs.
	var source := RaceResults.new()
	source.circuit = str(response.track)
	source.vehicle_name = "Compact / 01"
	source.total = 66.377
	source.best = source.total
	source.clean = true
	source.laps.resize(5)
	var page := RaceComplete.new()
	page.theme = MenuStyle.theme()
	page.results = source
	page.facts = {"complete":true,"flying":12.699}
	root.add_child(page)
	check(page._apply_comparison(response.packet),"native results accepts the actual deployed unified packet")
	for metric: String in ["race","best_lap"]:
		var chart: TrackDistribution = page.race_chart if metric == "race" else page.lap_chart
		var count: int = 0
		for amount: int in chart.snapshot.get("bins",[]): count += amount
		check(count == int(response.packet[metric].population) and count >= 100,"live "+metric+" chart retains every driver")
		var expected: int = 66377 if metric == "race" else 12699
		check(int(chart.snapshot.markers[0].value_ms) == expected,"live "+metric+" chart retains the completed-result marker")
	var before: Dictionary = page.race_chart.snapshot.duplicate(true)
	check(page._apply_comparison(response.packet) and page.race_chart.snapshot == before,"identical live packet leaves the histogram stable")
	page.free()
	source.free()

func capture_comparisons() -> void:
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var evidence: String = OS.get_environment("BMT_RESULTS_EVIDENCE")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("verified-silmukka-histograms.json")))
	check(data is Dictionary,"capture uses retained verified driver times and flying laps")
	if not data is Dictionary: return
	var source := RaceResults.new()
	source.circuit = "Silmukka"
	source.vehicle_name = "Compact / 01"
	source.laps = [19.828,16.959,16.808,16.350,16.239]
	source.total = 86.184
	source.previous = 86.130
	source.best = 86.130
	source.clean = true
	root.add_child(source)
	source.hide()
	var shell := Control.new()
	shell.theme = MenuStyle.theme()
	root.add_child(shell)
	MenuStyle.fill(shell)
	var backdrop := TextureRect.new()
	backdrop.texture = TrackTile.scenery_texture("pine")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	shell.add_child(backdrop)
	MenuStyle.fill(backdrop)
	var tint := ColorRect.new()
	tint.color = Color(0.015,0.03,0.04,0.60)
	shell.add_child(tint)
	MenuStyle.fill(tint)
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	shell.add_child(margin)
	MenuStyle.fill(margin)
	var page := RaceComplete.new()
	page.results = source
	page.facts = {"complete":true,"total":source.total,"previous":source.previous,"previous_lap":15.881,"flying":16.239}
	var catalog := TrackCatalog.new(TrackLibrary.new("user://histogram_capture_empty"))
	for entry: Dictionary in catalog.entries.slice(0,3):
		var track: NativeTrack = catalog.resolve(entry)
		if track == null: continue
		page.recommendations.append({"name":entry.name,"entry":entry,"route":track.route,"laps":5,"estimated_seconds":110,"reason":"Different scenery / New challenge","category":"different_biome"})
	margin.add_child(page)
	page.comparison_scope = "all"
	check(page._apply_comparison(data.packet),"capture applies both metrics and positions from the same packet")
	await create_timer(1.8).timeout
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		check(shell.get_global_rect().encloses(page.get_global_rect()),"results charts fit %s" % dimensions)
		check(page.race_chart.size.y >= 100 and page.lap_chart.size.y >= 100,"both marker lanes and bars remain visible %s" % dimensions)
		await screenshot("comparison-%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1280,720)
	source.previous = 0
	source.best = source.total
	page.race_chart.snapshot.markers = page._comparison_markers("RACE TIME")
	page._update_best_caption(page.race_best_caption,page.race_chart.snapshot.markers)
	page.race_chart.queue_redraw()
	await screenshot("new-personal-best-1280x720")
	source.total = float(data.midfield.race_seconds)
	source.best = source.total
	page.facts.flying = float(data.midfield.lap_seconds)
	page._apply_comparison(data.midfield)
	await screenshot("percentile-1280x720")
	shell.free()
	source.free()

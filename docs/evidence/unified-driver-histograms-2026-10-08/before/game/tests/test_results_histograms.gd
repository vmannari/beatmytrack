extends "res://tests/test_race_results.gd"
## Focused histogram acceptance; the broader results fixture has unrelated catalog assumptions.

func run() -> void:
	var requested_capture: bool = capture or (DisplayServer.get_name() != "headless" and not OS.get_environment("BMT_RESULTS_EVIDENCE").is_empty())
	capture = false
	await test_completion_distributions()
	await test_histogram_tails()
	capture = requested_capture
	if capture: await capture_comparisons()
	print("RESULTS_HISTOGRAMS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

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
	source.laps = [22.451,17.286,16.423,16.008,15.239]
	source.total = 83.407
	source.previous = 81.552
	source.best = 81.552
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
	page.facts = {"complete":true,"total":source.total,"previous":source.previous,"previous_lap":14.992,"flying":15.239}
	var catalog := TrackCatalog.new(TrackLibrary.new("user://histogram_capture_empty"))
	for entry: Dictionary in catalog.entries.slice(0,3):
		var track: NativeTrack = catalog.resolve(entry)
		if track == null: continue
		page.recommendations.append({"name":entry.name,"entry":entry,"route":track.route,"laps":5,"estimated_seconds":110,"reason":"Different scenery / New challenge","category":"different_biome"})
	margin.add_child(page)
	page.comparison_scope = "development"
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
	source.best = 83.407
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

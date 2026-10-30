extends SceneTree
## Evidence-only: render literals read directly from the task-start/current App.
const Loading = preload("res://ui/race_loading.gd")
const OUT: String = "res://../docs/evidence/loading-text-2026-10-28"
var failures: int = 0
var checks: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", description)

func literal(source: String, prefix: String) -> String:
	var start: int = source.find(prefix)
	if start < 0:
		check(false, "source contains " + prefix)
		return ""
	start += prefix.length()
	return source.substr(start, source.find('"', start) - start)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var track := NativeTrack.read("res://resources/tracks/ellipse.json")
	for version: String in ["before", "after"]:
		var path: String = OUT.path_join("before/game/core/app.gd") if version == "before" else "res://core/app.gd"
		var source: String = FileAccess.get_file_as_string(path)
		for locale: String in ["en", "fi"]:
			GameFonts.configure(locale)
			TranslationServer.set_locale(locale)
			var loading := Loading.new()
			root.add_child(loading)
			loading.configure("Ellipse", "pine", track.route)
			loading.stage(literal(source, 'loading.stage("Loading track'))
			# Prefix lookup retains the actual complete caption, including its noun.
			loading.stage("Loading track" + loading.status_label.text)
			await capture(loading, version + "-" + locale + "-track")
			if version == "after":
				check(loading.status_label.text == "Loading track…", "source has a single Unicode ellipsis")
				check(not TranslationServer.translate("Loading track…").is_empty(), "loading caption has a packaged translation")
			loading.configure("Parking hall", "night_city", PackedVector2Array(), true)
			loading.facts_label.text = literal(source, 'loading.facts_label.text = "P1 parking hall')
			loading.facts_label.text = "P1 parking hall" + loading.facts_label.text
			loading.stage("Opening parking hall" + literal(source, 'loading.stage("Opening parking hall'))
			await capture(loading, version + "-" + locale + "-parking")
			if version == "after":
				check(loading.facts_label.text == "P1 parking hall · Free drive · 120 × 72 m", "parking facts use the intended separators and dimensions")
				check(loading.status_label.text == "Opening parking hall…", "parking loading caption has a single Unicode ellipsis")
			root.remove_child(loading)
			loading.queue_free()
			await process_frame
	print("LOADING_TEXT_CAPTURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func capture(loading, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(loading.panel.get_global_rect().encloses(loading.status_label.get_global_rect()), "loading text fits its original panel")
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(name + ".png"))) == OK, "native screenshot saved")

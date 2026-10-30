extends SceneTree
## Actual restoring screen and its random-fact catalogue, with isolated records.
const Facts = preload("res://ui/loading_facts.gd")
var checks: int = 0
var failures: int = 0
var output: String = ""

class HoldingStartupApp extends "res://core/app.gd":
	func _show_screen(next: String) -> void:
		# Leave the real startup cover in place long enough to inspect it.
		if next != "restoring": return
		super._show_screen(next)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	create_timer(120).timeout.connect(func() -> void: print("FAIL: loading fact deadline"); quit(1))
	check(Facts.FACTS.size() == 100, "catalogue contains 100 facts")
	var unique: Dictionary = {}
	for fact: String in Facts.FACTS:
		check(not fact.strip_edges().is_empty() and not unique.has(fact), "fact is nonempty and unique: " + fact)
		unique[fact] = true
	# A fixed seed makes coverage reproducible without imposing a no-repeat rule.
	Facts._random.seed = 247193
	Facts._seeded = true
	var selected: Dictionary = {}
	for i: int in range(2000):
		var fact: String = Facts.random_fact()
		check(unique.has(fact), "selection comes from the catalogue")
		selected[fact] = true
	check(selected.size() >= 95, "selection reaches the catalogue broadly with a fixed seed")
	var profile: String = "user://loading_fact_test_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(profile)
	var app := HoldingStartupApp.new()
	app.records = LocalRecords.new(profile.path_join("records.json"))
	app.library = TrackLibrary.new(profile.path_join("tracks"))
	app.cloud_root_override = profile.path_join("cloud")
	root.size = Vector2i(1280, 720)
	root.add_child(app)
	await process_frame
	check(app.screen == "restoring", "real startup shows restoring cover")
	var label: Label = app.root_ui.find_child("LoadingFact", true, false)
	check(label != null, "startup cover contains named fact label")
	if label != null:
		check(unique.has(label.text), "startup shows a selected fact")
		var first: String = label.text
		await process_frame
		check(label.text == first, "fact stays stable during loading")
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(640, 360)]:
			root.size = size
			for i: int in range(4): await process_frame
			check(label.is_visible_in_tree(), "fact is visible at " + str(size))
			var bounds: Rect2 = label.get_global_rect()
			var viewport: Rect2 = root.get_visible_rect()
			check(viewport.encloses(bounds), "fact bounds fit at " + str(size))
			if DisplayServer.get_name() != "headless" and not output.is_empty():
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output.path_join("startup-%dx%d.png" % [size.x, size.y])) == OK, "save startup capture")
		# Exercise every candidate in the smallest viewport, including wrapping.
		var longest: String = ""
		for fact: String in Facts.FACTS:
			label.text = fact
			for i: int in range(2): await process_frame
			var bounds: Rect2 = label.get_global_rect()
			var line_height: float = label.get_theme_font("font").get_height(label.get_theme_font_size("font_size"))
			check(label.is_visible_in_tree() and root.get_visible_rect().encloses(bounds) and label.get_line_count() * line_height <= bounds.size.y + 2.0, "complete fact fits small viewport: " + fact)
			if fact.length() > longest.length(): longest = fact
		label.text = longest
		for i: int in range(4): await process_frame
		if DisplayServer.get_name() != "headless" and not output.is_empty():
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("startup-longest-640x360.png")) == OK, "save longest fact capture")
	app.queue_free()
	for i: int in range(5): await process_frame
	print("LOADING_FACTS: %d checks, %d failures; %d distinct sampled" % [checks, failures, selected.size()])
	quit(1 if failures else 0)

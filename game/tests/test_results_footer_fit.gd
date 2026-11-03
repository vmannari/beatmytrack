extends SceneTree
## Isolated completion layout: no App, network or owner records.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	for frame: int in range(8): await process_frame

func run() -> void:
	var source := RaceResults.new()
	source.circuit = "Blind Spot"
	source.vehicle_name = "Volt"
	source.total = 90.142
	source.laps = [25.0,16.097,16.5,16.5,15.0]
	var page := RaceComplete.new()
	page.theme = MenuStyle.theme()
	page.results = source
	page.facts = {"flying":16.097,"incident_free":true}
	page.rating_records = LocalRecords.new("user://footer-fit-unused.json")
	page.rating_track_id = "footer-fit"
	for index: int in range(3):
		page.recommendations.append({"name":["Knot","Slippery","Silmukka"][index],"entry":{"id":str(index),"theme":"winter" if index == 1 else "pine"},"category":"different_biome" if index == 1 else "local","route":PackedVector2Array([Vector2.ZERO,Vector2(100,0),Vector2(100,100),Vector2.ZERO]),"laps":5,"estimated_seconds":120,"reason":"Similar length · New challenge"})
	root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 32
	page.offset_top = 16
	page.offset_right = -32
	page.offset_bottom = -16
	var scroll := page.get_node("CompletionScroll") as ScrollContainer
	for dimensions: Vector2i in [Vector2i(1280,683),Vector2i(1280,720),Vector2i(960,540),Vector2i(1920,1080),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		# Canvas-items stretch keeps a logical canvas at small window sizes.
		var viewport_rect: Rect2 = root.get_visible_rect()
		check(viewport_rect.encloses(page.get_global_rect()),"page fits "+str(dimensions))
		for button: Node in page.race_button.get_parent().get_children():
			check(viewport_rect.encloses((button as Button).get_global_rect()),"footer button fits "+str(dimensions))
			check((button as Button).size.y >= 60,"touch target retained")
		var footer_before: Rect2 = page.race_button.get_global_rect()
		scroll.scroll_vertical = 10000
		await settle()
		check(page.race_button.get_global_rect() == footer_before,"scroll keeps footer fixed")
		check(scroll.get_global_rect().encloses(page.cards[0].get_global_rect()),"recommendations reachable "+str(dimensions))
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			var directory: String = ProjectSettings.globalize_path("res://../docs/evidence/results-footer-2026-11-02")
			DirAccess.make_dir_recursive_absolute(directory)
			check(root.get_texture().get_image().save_png(directory.path_join("footer-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"capture saved")
		scroll.scroll_vertical = 0
	page.select_track(2)
	check(page.race_button.text.contains("SILMUKKA"),"recommendation still updates action")
	page.queue_free()
	source.free()
	await settle()
	print("RESULTS_FOOTER_FIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends SceneTree
## Preview harness retained from the earlier full-height trial; now checks restored podium.
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		var backdrop := MenuBackdrop.new()
		root.add_child(backdrop)
		backdrop.size = Vector2(dimensions)
		var page := WeeklyRivalryPage.new()
		page.model = WeeklyRivalry.new(true)
		page.model.status = "active"
		root.add_child(page)
		page.position = Vector2(24,90)
		page.size = Vector2(dimensions)-Vector2(48,114)
		for frame: int in range(8): await process_frame
		var body := page.find_child("RivalryBody",true,false) as Control
		var table := page.find_child("RivalryDriversPanel",true,false) as Control
		if table.global_position.y <= body.global_position.y: failures += 1
		if page.find_child("RivalryPodium_1",true,false) == null: failures += 1
		page._update_scores()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../docs/evidence/rivalry-garage-podium-2026-10-24/overview-%dx%d.png" % [dimensions.x,dimensions.y])
		print("RESTORED_PODIUM_LAYOUT ",dimensions," body=",body.size.y," table=",table.size.y)
		page.queue_free()
		backdrop.queue_free()
		await process_frame
	print("RIVALRY_RESTORED_PODIUM: 3 sizes, ",failures," failures")
	quit(failures)

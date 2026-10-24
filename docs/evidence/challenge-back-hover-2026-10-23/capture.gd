extends "res://tests/test_challenge_cards.gd"
## Temporary native captures of the reported Back hover clipping.

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.content_scale_size = Vector2i.ZERO
	output = ProjectSettings.globalize_path("res://../docs/evidence/challenge-back-hover-2026-10-23/"+OS.get_environment("BMT_BACK_HOVER_PHASE")+"-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	var client := StubClient.new()
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://back-hover-"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	var margin := MarginContainer.new()
	margin.clip_contents = true
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_"+side, 24)
	root.add_child(margin)
	MenuStyle.fill(margin)
	var page := ChallengeCreate.new()
	page.adapter = adapter
	page.entries = [entry()]
	margin.add_child(page)
	var receipts: Array[Dictionary] = []
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(844,390), Vector2i(390,844)]:
		root.size = dimensions
		await settle()
		var button: Button = page._close_button
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var point: Vector2 = button.get_global_rect().get_center() if state in ["hover", "pressed"] else Vector2(-50,-50)
			var motion := InputEventMouseMotion.new()
			motion.position = point
			root.push_input(motion,true)
			if state == "pressed": button.set_pressed_no_signal(true)
			if state == "focus": button.grab_focus()
			await settle()
			var image_path: String = output.path_join(str(dimensions.x)+"x"+str(dimensions.y)+"-"+state+".png")
			var saved: int = root.get_texture().get_image().save_png(image_path)
			var style: StyleBox = button.get_theme_stylebox(state)
			receipts.append({"size":str(dimensions),"state":state,"hovered":button.is_hovered(),"button_rect":str(button.get_global_rect()),"style_minimum":str(style.get_minimum_size()),"saved":saved,"image":image_path})
			button.set_pressed_no_signal(false)
			button.release_focus()
	var receipt := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify(receipts,"  "))
	receipt.close()
	margin.queue_free()
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await settle()
	print("BACK_HOVER_CAPTURE: "+str(receipts.size())+" states captured")
	quit()

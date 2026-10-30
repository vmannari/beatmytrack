extends SceneTree

var checks := 0
var failures := 0
var selected := -99

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)

func run() -> void:
	for car_id: String in VehicleCatalog.IDS:
		var hud := PlaygroundHUD.new()
		hud.config = VehicleCatalog.config(car_id)
		hud.driver = DriverInput.new()
		hud.production_mode = true
		hud.handling_test_requested.connect(func(index: int) -> void: selected = index)
		root.add_child(hud)
		await process_frame
		var choice: OptionButton = hud.handling_test_choice
		if car_id in ["compact", "electric", "forklift", "kart"]:
			check(choice == null, car_id + " has no test selector")
		else:
			var expected_count: int = 7 if car_id == "hovercraft" else 6
			check(choice != null and choice.item_count == expected_count and choice.selected == 0, car_id + " has current handling and its test choices")
			if choice != null:
				if car_id == "hovercraft":
					check(choice.get_item_text(1) == "Slide 5 (reference)", "Hover retains the chosen reference")
					for index: int in range(1, 6):
						check(choice.get_item_text(index + 1) == "Slide 5.%d" % index, "Hover names slide alternative %d" % index)
				choice.select(expected_count - 1)
				choice.item_selected.emit(expected_count - 1)
				check(selected == expected_count - 2, car_id + " emits the last preset")
				choice.select(0)
				choice.item_selected.emit(0)
				check(selected == -1, car_id + " can restore current handling")
		hud.queue_free()
		await process_frame
	var disabled := PlaygroundHUD.new()
	disabled.config = VehicleCatalog.config("pickup")
	disabled.driver = DriverInput.new()
	disabled.handling_test_enabled = false
	root.add_child(disabled)
	await process_frame
	check(disabled.handling_test_choice == null, "competitive races can suppress the selector")
	disabled.queue_free()
	await process_frame
	var sample := PlaygroundHUD.new()
	sample.config = VehicleCatalog.config("pickup")
	sample.driver = DriverInput.new()
	sample.production_mode = true
	sample.handling_test_index = 2
	root.add_child(sample)
	for dimensions: Vector2i in [Vector2i(960,540), Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		await process_frame
		var choice := sample.handling_test_choice
		check(choice.selected == 3, "selected test survives HUD creation")
		check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(choice.get_global_rect()), "selector fits at " + str(dimensions))
		var caption: Label = sample.find_child("HandlingTestCaption",true,false)
		check(caption != null and caption.text.contains("PRACTICE"), "practice warning is visible")
		if DisplayServer.get_name() != "headless":
			var output: String = OS.get_environment("BMT_HANDLING_TEST_CAPTURE")
			if not output.is_empty():
				DirAccess.make_dir_recursive_absolute(output)
				root.get_texture().get_image().save_png(output.path_join("selector-%dx%d.png" % [dimensions.x,dimensions.y]))
	sample.queue_free()
	await process_frame
	print("HANDLING_TEST_SELECTOR: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

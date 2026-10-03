extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var controls := TouchControls.new()
	controls.driver = DriverInput.new()
	root.add_child(controls)
	await process_frame
	for extent: Vector2 in [Vector2(1280,720), Vector2(1600,720)]:
		controls.size = extent
		for scale_value: float in [1.0,1.2,1.4]:
			controls.control_scale = scale_value
			for mobile: bool in [false,true]:
				controls.mobile_layout = mobile
				for mirrored: bool in [false,true]:
					controls.left_handed = mirrored
					var art: Array[Rect2] = controls.zones()
					var hits: Array[Rect2] = controls.touch_zones()
					for i: int in range(TouchControls.ACTIONS.size()):
						check(hits[i].encloses(art[i]), "target encloses its artwork")
						check(hits[i].get_area() > art[i].get_area()*1.5, "target is substantially larger than artwork")
						var outside := Vector2(art[i].get_center().x, art[i].position.y-24)
						check(controls.action_at(outside) == TouchControls.ACTIONS[i], "press above artwork reaches intended action")
						check(controls.action_at(art[i].get_center()) == TouchControls.ACTIONS[i], "artwork center remains correct")
						for j: int in range(i+1,TouchControls.ACTIONS.size()):
							check(not hits[i].intersects(hits[j]), "expanded targets never overlap")
					check(controls.action_at(Vector2(extent.x/2,extent.y-30)) == &"", "central HUD stays outside driving zones")
	controls.mobile_layout = true
	controls.left_handed = false
	controls.control_scale = 1.0
	var boxes: Array[Rect2] = controls.zones()
	for i: int in [0,3]:
		var touch := InputEventScreenTouch.new()
		touch.index = i
		touch.pressed = true
		touch.position = Vector2(boxes[i].get_center().x,boxes[i].position.y-24)
		controls._input(touch)
	check(controls.driver.sample().steer == -127 and controls.driver.sample().throttle == 255, "two fingers outside art steer and accelerate together")
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.canceled = true
	controls._input(release)
	check(controls.driver.sample().steer == 0 and controls.driver.sample().throttle == 255, "cancellation releases only its finger")
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(controls.size.x/2,100)
	controls._input(drag)
	check(controls.driver.sample().throttle == 0, "leaving expanded target releases throttle")
	if DisplayServer.get_name() != "headless":
		controls.size = root.size
		await process_frame
		var gas: Vector2 = controls.zones()[3].get_center()
		var press := InputEventScreenTouch.new()
		press.index = 3
		press.position = gas
		press.pressed = true
		controls._input(press)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var held_draws: int = controls.draw_count
		for tick: int in range(30):
			for sample: int in range(TouchControls.ACTIONS.size()):
				var motion := InputEventScreenDrag.new()
				motion.index = 3
				motion.position = gas+Vector2(sin(tick+sample)*4,0)
				controls._input(motion)
			await process_frame
		await RenderingServer.frame_post_draw
		check(controls.draw_count == held_draws,"120 within-button drag events retain drawing commands")
		check(controls.last_pressed_mask == 8 and controls.driver.sample().throttle == 255,"held artwork and input remain pressed")
		controls.driver.clear()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(controls.last_pressed_mask == 0 and controls.draw_count == held_draws,"external input clear switches retained artwork")
		Input.action_press(&"steer_left")
		await process_frame
		await process_frame
		check(controls.last_pressed_mask == 1,"keyboard press updates cached artwork")
		Input.action_release(&"steer_left")
		await process_frame
		await process_frame
		check(controls.last_pressed_mask == 0,"keyboard release updates cached artwork")
		var artwork_draws: int = 0
		for art: TouchControlArt in controls.artwork: artwork_draws += art.draw_count
		for mask: int in range(16):
			controls.driver.clear()
			for index: int in range(TouchControls.ACTIONS.size()):
				if mask & (1 << index): controls.driver.set_touch(index,TouchControls.ACTIONS[index])
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			for art: TouchControlArt in controls.artwork:
				check((art.modulate.a == 1.0) == (art.pressed == ((mask & (1 << art.button_index)) != 0)),"retained artwork matches every input combination")
		var final_draws: int = 0
		for art: TouchControlArt in controls.artwork: final_draws += art.draw_count
		check(final_draws == artwork_draws,"all press/release combinations reuse prepared vectors")
	print("MOBILE_CONTROLS_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

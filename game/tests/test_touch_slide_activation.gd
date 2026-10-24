extends SceneTree
## TSA01-TSA03: occupancy-driven buttons, independent fingers and lifecycle fences.
const EVIDENCE := "res://../docs/evidence/touch-slide-activation-2026-10-23"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func press(control: TouchControls, finger: int, point: Vector2, down: bool = true, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = control.get_global_transform_with_canvas()*point
	event.pressed = down
	event.canceled = canceled
	root.push_input(event,true)

func drag(control: TouchControls, finger: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = control.get_global_transform_with_canvas()*point
	root.push_input(event,true)

func only_action(control: TouchControls, finger: int, index: int) -> bool:
	return control.driver.touches.get(finger) == TouchControls.ACTIONS[index] and control.driver.touch_strengths.get(finger) == 1.0 and control.pressed_mask() == 1 << index

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var control := TouchControls.new()
	control.driver = DriverInput.new()
	control.haptic_strength = 0.0
	root.add_child(control)
	await process_frame
	for dimensions: Vector2 in [Vector2(960,540),Vector2(1280,720),Vector2(1600,720)]:
		control.size = dimensions
		for mirrored: bool in [false,true]:
			for scale_value: float in [0.65,1.0,1.6]:
				control.layout = ControlLayout.preset(mirrored,scale_value)
				_test_buttons(control)
	control.size = Vector2(1280,720)
	control.layout = {}
	_test_buttons(control)
	control.layout = ControlLayout.preset(true)
	control.safe_override = Rect2(44,24,1210,660)
	control.position = Vector2(17,23)
	control.scale = Vector2(0.8,0.8)
	_test_buttons(control)
	control.position = Vector2.ZERO
	control.scale = Vector2.ONE
	control.safe_override = Rect2()
	control.layout = ControlLayout.preset()
	_test_multitouch(control)
	_test_lifecycle(control)
	await _test_analog_handbrake(control)
	control.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await _capture()
	print("TOUCH_SLIDE_ACTIVATION: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _test_buttons(control: TouchControls) -> void:
	var outside := Vector2(control.size.x*0.5,100)
	check(control.action_at(outside) == &"","slide begins outside all driving targets")
	var faces: Array[Rect2] = control.zones()
	for source: int in range(faces.size()):
		press(control,1,outside)
		check(control.driver.touches.is_empty(),"outside press is neutral")
		drag(control,1,faces[source].get_center())
		check(only_action(control,1,source),"sliding from elsewhere activates each button at full strength")
		drag(control,1,outside)
		check(control.driver.touches.is_empty() and control.pressed_mask() == 0,"leaving a button releases its action")
		drag(control,1,faces[source].get_center())
		check(only_action(control,1,source),"same finger can reenter without another press")
		press(control,1,outside,false)
		check(control.driver.touches.is_empty() and control.fingers_down.is_empty(),"release outside clears tracked finger")
		for destination: int in range(faces.size()):
			press(control,1,faces[source].get_center())
			drag(control,1,faces[destination].get_center())
			check(only_action(control,1,destination),"each button can transfer directly to every other button")
			press(control,1,faces[destination].get_center(),false)
		# Invisible enlarged margins use the same arbitration on slide as on press.
		var margin := Vector2(faces[source].get_center().x,faces[source].position.y-24)
		press(control,1,outside)
		drag(control,1,margin)
		check(only_action(control,1,source),"sliding into padded target activates the intended button")
		press(control,1,margin,false,true)
		check(control.driver.touches.is_empty() and control.fingers_down.is_empty(),"cancellation releases a slide-acquired action")

func _test_multitouch(control: TouchControls) -> void:
	var faces: Array[Rect2] = control.zones()
	var outside := Vector2(640,100)
	for finger: int in [1,2,3]: press(control,finger,outside)
	drag(control,1,faces[0].get_center())
	drag(control,2,faces[3].get_center())
	drag(control,3,faces[3].get_center())
	check(control.driver.sample().steer == -127 and control.driver.sample().throttle == 255,"independent slides activate steering and two fingers on gas")
	drag(control,2,faces[2].get_center())
	check(control.driver.sample().throttle == 255 and control.driver.sample().brake == 255,"one finger crossing pedals preserves the other finger's gas")
	press(control,3,outside,false)
	check(control.driver.sample().throttle == 0 and control.driver.sample().brake == 255 and control.driver.sample().steer == -127,"release removes only that finger's action")
	drag(control,1,faces[1].get_center())
	check(control.driver.sample().steer == 127 and control.driver.sample().brake == 255,"same-event steering reversal preserves independent brake")
	press(control,2,outside,false,true)
	check(control.driver.sample().brake == 0 and control.driver.sample().steer == 127,"cancellation preserves the remaining steering finger")
	control.release_all()
	# Two fingers can hold the same button; exiting one does not cancel the other.
	press(control,1,faces[3].get_center())
	press(control,2,faces[3].get_center())
	drag(control,1,outside)
	check(control.driver.sample().throttle == 255,"leaving shared button preserves other occupant")
	control.release_all()

func _test_lifecycle(control: TouchControls) -> void:
	var gas: Vector2 = control.zones()[3].get_center()
	var outside := Vector2(640,100)
	for boundary: String in ["release","cancel","disable","hide","focus","pause","layout","resize","clear"]:
		press(control,1,outside)
		drag(control,1,gas)
		press(control,2,outside)
		match boundary:
			"release":
				press(control,1,outside,false)
				press(control,2,outside,false)
			"cancel":
				press(control,1,outside,false,true)
				press(control,2,outside,false,true)
			"disable":
				control.enabled = false
				press(control,3,gas)
				control.enabled = true
			"hide":
				control.hide()
				press(control,3,gas)
				control.show()
			"focus": control._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"pause": control._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			"layout": control.layout = ControlLayout.preset()
			"resize": control.size.x += 1
			"clear": control.release_all()
		check(control.driver.touches.is_empty() and control.owners.is_empty() and control.fingers_down.is_empty(),"lifecycle clears active and outside fingers: "+boundary)
		for finger: int in [1,2,3]: drag(control,finger,gas)
		check(control.driver.touches.is_empty(),"late drags cannot restore cleared input: "+boundary)
	# A completed finger ID can be reused for a fresh gesture.
	press(control,1,outside)
	drag(control,1,gas)
	check(control.driver.sample().throttle == 255,"new contact after lifecycle reset can slide in")
	control.release_all()

func _test_analog_handbrake(control: TouchControls) -> void:
	for method: String in ["horizontal","joystick"]:
		control.layout = ControlLayout.preset()
		control.layout.steering_type = method
		var outside := Vector2(640,100)
		press(control,1,outside)
		await process_frame
		drag(control,1,control.zones()[4].get_center())
		check(control.driver.sample().handbrake == 255,"analog mode's separate handbrake supports slide entry")
		drag(control,1,outside)
		check(control.driver.sample().handbrake == 0,"analog handbrake releases on exit")
		var steering: Rect2 = control.group_rects()[method]
		drag(control,1,steering.get_center())
		check(control.driver.touches.is_empty(),"slide entry does not change relative analog origins")
		press(control,1,outside,false)
		press(control,2,steering.get_center())
		drag(control,2,steering.get_center()+Vector2(steering.size.x*0.5,0))
		check(control.driver.sample().steer == 127,"relative steering keeps its captured origin")
		control.release_all()

func _capture() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	var control: TouchControls = game.get("hud").touch
	control.layout = ControlLayout.preset()
	control.haptic_strength = 0.0
	await process_frame
	await process_frame
	var faces: Array[Rect2] = control.zones()
	var output: String = ProjectSettings.globalize_path(EVIDENCE.path_join(RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(output)
	press(control,1,Vector2(640,100))
	press(control,2,Vector2(640,100))
	drag(control,1,faces[0].get_center())
	drag(control,2,faces[3].get_center())
	await _save(output.path_join("slide-left-gas.png"))
	check(control.driver.sample().steer == -127 and control.driver.sample().throttle == 255 and control.last_pressed_mask == 9,"native artwork shows slide-acquired left and gas")
	var draws: int = control.draw_count
	drag(control,2,faces[2].get_center())
	await _save(output.path_join("slide-left-brake.png"))
	check(control.driver.sample().throttle == 0 and control.driver.sample().brake == 255 and control.last_pressed_mask == 5,"native artwork transfers gas to brake")
	drag(control,1,Vector2(640,100))
	drag(control,2,Vector2(640,100))
	await _save(output.path_join("slide-exit-neutral.png"))
	check(control.driver.touches.is_empty() and control.last_pressed_mask == 0 and control.draw_count == draws,"exit clears native artwork without redrawing geometry")
	control.release_all()
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout

func _save(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK,"native gameplay capture: "+path.get_file())

extends SceneTree
## HIT01-HIT04: off-button presses, exclusive neighbours, immediate reversal and safe bounds.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func press(control: TouchControls, finger: int, point: Vector2, down: bool = true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = control.get_global_transform_with_canvas()*point
	event.pressed = down
	root.push_input(event,true)

func drag(control: TouchControls, finger: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = control.get_global_transform_with_canvas()*point
	root.push_input(event,true)

func bases(control: TouchControls) -> Array[Rect2]:
	var groups: Dictionary = control.group_rects()
	return [groups.steer_left,groups.steer_right,groups.brake,groups.accelerator,groups.handbrake]

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
				_check_geometry(control)
				var originals: Array[Rect2] = bases(control)
				for i: int in range(originals.size()):
					var point := Vector2(originals[i].get_center().x,originals[i].position.y-32)
					if not control.usable_area().has_point(point): continue
					check(control.action_at(point) == TouchControls.ACTIONS[i],"press 32 units above saved button is accepted")
					press(control,1,point)
					check(control.driver.touches.get(1) == TouchControls.ACTIONS[i] and control.driver.touch_strengths.get(1) == 1.0,"off-button viewport press applies full intended input")
					press(control,1,Vector2.ZERO,false)
					check(control.driver.touches.is_empty(),"off-button release clears its input")
	control.size = Vector2(1280,720)
	control.layout = ControlLayout.preset()
	_test_reversal_and_ownership(control)
	_test_wider_coverage(control)
	# An isolated custom pedal can use empty space on all four sides.
	ControlLayout.move(control.layout,"brake",Vector2(500,300),control.usable_area())
	ControlLayout.move(control.layout,"accelerator",Vector2(940,300),control.usable_area())
	var gas: Rect2 = control.group_rects().accelerator
	for margin: float in [32.0,96.0]:
		for point: Vector2 in [Vector2(gas.position.x-margin,gas.get_center().y),Vector2(gas.end.x+margin,gas.get_center().y),Vector2(gas.get_center().x,gas.position.y-margin),Vector2(gas.get_center().x,gas.end.y+margin)]:
			press(control,1,point)
			check(control.driver.sample().throttle == 255,"isolated pedal accepts full presses %d units beyond each edge" % int(margin))
			press(control,1,Vector2.ZERO,false)
	# Stack and offset neighbouring controls; their original faces must never be stolen.
	for offset: Vector2 in [Vector2(0,-205),Vector2(70,-205),Vector2(-170,-60)]:
		control.layout = ControlLayout.preset()
		var right: Rect2 = control.group_rects().steer_right
		ControlLayout.move(control.layout,"steer_left",right.position+offset,control.usable_area())
		_check_geometry(control)
	# Also exercise physical safe insets and a transformed control canvas.
	control.safe_override = Rect2(44,24,1210,660)
	control.position = Vector2(17,23)
	control.scale = Vector2(0.8,0.8)
	_check_geometry(control)
	var left: Rect2 = control.group_rects().steer_left
	press(control,1,Vector2(left.get_center().x,left.position.y-24))
	check(control.driver.sample().steer == -127,"off-button input survives canvas transform and safe insets")
	control.release_all()
	control.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await _capture()
	print("TOUCH_TARGET_PADDING: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _check_geometry(control: TouchControls) -> void:
	var originals: Array[Rect2] = bases(control)
	var hits: Array[Rect2] = control.touch_zones()
	for i: int in range(hits.size()):
		check(control.usable_area().encloses(hits[i]),"expanded target respects safe bounds and top HUD")
		check(hits[i].encloses(originals[i]),"neighbour expansion never steals an original button face")
		for fraction: Vector2 in [Vector2(0.02,0.02),Vector2(0.98,0.02),Vector2(0.02,0.98),Vector2(0.98,0.98),Vector2(0.5,0.5)]:
			check(control.action_at(originals[i].position+originals[i].size*fraction) == TouchControls.ACTIONS[i],"original button corners and centre keep their own action")
		for j: int in range(i+1,hits.size()):
			if hits[i].intersects(hits[j]):
				press(control,8,originals[j].get_center())
				check(control.driver.touches.get(8) == TouchControls.ACTIONS[j],"shared padding cannot capture another button's actual press")
				press(control,8,Vector2.ZERO,false)
	check(control.action_at(Vector2(control.size.x-35,45)) == &"","pause button region remains outside driving input")
	check(control.action_at(Vector2(control.size.x*0.5,100)) == &"","top race HUD remains outside driving input")

func _test_reversal_and_ownership(control: TouchControls) -> void:
	var originals: Array[Rect2] = bases(control)
	var divider: float = (originals[0].end.x+originals[1].position.x)*0.5
	var y: float = minf(originals[0].position.y,originals[1].position.y)-24
	press(control,1,Vector2(divider-2,y))
	check(control.driver.sample().steer == -127,"shared steering gap starts as left input")
	for tick: int in range(12):
		var direction: int = 1 if tick%2 == 0 else -1
		drag(control,1,Vector2(divider+direction*2,y))
		check(control.driver.sample().steer == direction*127,"four-unit thumb slide reverses fully in the same event")
	press(control,2,originals[3].get_center()-Vector2(0,originals[3].size.y*0.5+24))
	press(control,3,originals[4].get_center()-Vector2(0,originals[4].size.y*0.5+24))
	check(control.driver.sample().throttle == 255 and control.driver.sample().handbrake == 255,"off-button gas and handbrake remain independent")
	press(control,1,Vector2.ZERO,false)
	check(control.driver.sample().steer == 0 and control.driver.sample().throttle == 255,"steering release preserves other fingers")
	control.release_all()
	press(control,1,originals[3].get_center())
	drag(control,1,originals[2].get_center())
	check(control.driver.sample().throttle == 0 and control.driver.sample().brake == 0,"sliding a captured pedal cannot activate its neighbour")
	press(control,2,originals[2].get_center())
	check(control.driver.sample().brake == 255 and control.driver.sample().throttle == 0,"neighbour button stays independently reachable")
	control.release_all()

func _test_wider_coverage(control: TouchControls) -> void:
	var originals: Array[Rect2] = bases(control)
	var bounds: Rect2 = control.usable_area()
	var previous: Array[Rect2] = []
	for rect: Rect2 in originals:
		previous.append(rect.grow_individual(56,64,56,72).intersection(bounds))
	var old_samples: int = 0
	var new_samples: int = 0
	for y: int in range(int(bounds.position.y)+8,int(bounds.end.y),16):
		for x: int in range(int(bounds.position.x)+8,int(bounds.end.x),16):
			var point := Vector2(x,y)
			var was_active: bool = false
			for rect: Rect2 in previous:
				if rect.has_point(point): was_active = true; break
			if was_active: old_samples += 1
			if control.action_at(point) != &"": new_samples += 1
	check(new_samples >= old_samples*1.5,"actual registered input area grows by at least 50 percent over the deployed targets")
	print("TOUCH_COVERAGE: previous_samples=%d new_samples=%d ratio=%.3f" % [old_samples,new_samples,float(new_samples)/old_samples])
	for i: int in range(originals.size()):
		var point := Vector2(originals[i].get_center().x,originals[i].position.y-144)
		press(control,1,point)
		check(control.driver.touches.get(1) == TouchControls.ACTIONS[i] and control.driver.touch_strengths.get(1) == 1.0,"full input 144 units above each button")
		press(control,1,Vector2.ZERO,false)

func _capture() -> void:
	var output: String = ProjectSettings.globalize_path("res://../build/wide-touch-targets-2026-10-16/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	var control: TouchControls = game.get("hud").touch
	control.layout = ControlLayout.preset()
	control.haptic_strength = 0.0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("normal-buttons.png")) == OK,"native unchanged-art capture")
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(overlay)
	overlay.draw.connect(func() -> void:
		var colours: Array[Color] = [Color("e8c654"),Color("ac83ee"),Color("e87b65"),Color("69d78b"),Color("6bc5df")]
		for y: int in range(180,int(control.size.y),12):
			for x: int in range(0,int(control.size.x),12):
				var point := Vector2(x+6,y+6)
				var index: int = TouchControls.ACTIONS.find(control.action_at(point))
				if index >= 0: overlay.draw_rect(Rect2(Vector2(x,y),Vector2(12,12)),Color(colours[index],0.22)))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("diagnostic-expanded-targets.png")) == OK,"diagnostic overlay shows nearest-button ownership in expanded touch areas")
	var left: Rect2 = control.group_rects().steer_left
	press(control,1,Vector2(left.get_center().x,left.position.y-32))
	var gas: Rect2 = control.group_rects().accelerator
	press(control,2,Vector2(gas.get_center().x,gas.position.y-32))
	check(control.driver.sample().steer == -127 and control.driver.sample().throttle == 255,"native viewport accepts simultaneous off-button presses: enabled=%s owners=%s inputs=%s" % [control.enabled,control.owners,control.driver.touches])
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("diagnostic-off-button-held.png")) == OK,"native capture of off-button held input")
	control.release_all()
	game.queue_free()
	await process_frame

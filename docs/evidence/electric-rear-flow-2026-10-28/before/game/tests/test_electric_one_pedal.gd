extends SceneTree
const _NATIVE_TRACK = preload("res://track/native_track.gd")
const OUTPUT: String = "res://../docs/evidence/electric-refinement-2026-10-25"
var output: String = OUTPUT
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	var config: HandlingConfig = VehicleCatalog.config("electric")
	check(config.single_pedal and config.rear_wheel_drive,"strict accelerator-only rear-drive tune")
	var lift := VehicleSimulation.new(config)
	lift.state.velocity = Vector2(0,20)
	lift.step(DriveFrame.new())
	metrics.first_tick_deceleration = (20-lift.state.velocity.y)*120
	check(float(metrics.first_tick_deceleration) >= 20.0 and float(metrics.first_tick_deceleration) < 21.0,"controlled regeneration acts on first 120 Hz lift tick")
	var tick: int = 1
	while lift.state.velocity.length() > 0 and tick < 1200:
		lift.step(DriveFrame.new())
		tick += 1
	metrics.stop_72_kph_seconds = tick/120.0
	metrics.stop_72_kph_metres = lift.state.position.y
	check(tick >= 114 and tick <= 126 and lift.state.velocity == Vector2.ZERO,"release stops from 72 kph within the stronger 0.95 to 1.05 second range")
	for idle: int in range(600): lift.step(DriveFrame.new())
	check(lift.state.velocity == Vector2.ZERO and lift.state.reverse_wait == 0,"release holds without reverse or creep")
	var raw := DriverInput.new()
	raw.single_pedal = true
	for action: StringName in [&"accelerate",&"brake",&"handbrake"]: Input.action_press(action,1)
	var frame: DriveFrame = raw.sample()
	check(frame.throttle == 255 and frame.brake == 0 and frame.handbrake == 0,"keyboard/gamepad brake and handbrake inputs are ignored")
	raw.reverse_selected = true
	frame = raw.sample()
	check(frame.throttle == 255 and frame.brake == 255 and frame.handbrake == 0,"D/R selector is distinct from accelerator and handbrake")
	raw.clear()
	check(raw.reverse_selected and raw.sample().throttle == 0,"pause/focus clearing releases gas and preserves chosen direction")
	for direction: int in [0,255]:
		var standard := VehicleSimulation.new(config)
		var abused := VehicleSimulation.new(config)
		var exact: bool = true
		for t: int in range(960):
			var a := DriveFrame.sample(sin(t*0.02)*0.65,1 if t%240<140 else 0,float(direction)/255,0)
			var b := DriveFrame.sample(float(a.steer)/127,float(a.throttle)/255,float(direction)/255,1)
			standard.step(a)
			abused.step(b)
			exact = exact and standard.state.snapshot() == abused.state.snapshot() and abused.state.handbrake_pressure == 0
		check(exact,"handbrake requests have zero canonical effect, direction="+str(direction))
	# Every touch method/handedness has exactly one pedal and no inactive targets.
	root.size = Vector2i(1280,720)
	for method: String in ControlLayout.METHODS:
		for left: bool in [false,true]:
			var controls := TouchControls.new()
			controls.driver = DriverInput.new()
			controls.driver.single_pedal = true
			controls.vehicle_id = "electric"
			controls.layout = ControlLayout.preset(left)
			controls.layout.steering_type = method
			root.add_child(controls)
			await process_frame
			var zones: Array[Rect2] = controls.touch_zones()
			check(not zones[2].has_area() and not zones[4].has_area() and zones[3].has_area(),method+str(left)+" one accelerator, no brake or handbrake hit areas")
			check(controls.direction_rect().has_area() and not controls.direction_rect().intersects(controls.zones()[3]),method+str(left)+" D/R reserves the saved brake position beside gas")
			check(controls.action_at(controls.direction_rect().get_center()) == &"",method+str(left)+" D/R cannot enter accelerator padding")
			var valid: bool = true
			for x: int in range(0,1280,32):
				for y: int in range(0,720,32): valid = valid and controls.action_at(Vector2(x,y)) not in [&"brake",&"handbrake"]
			check(valid,method+str(left)+" no phantom disabled actions in touch padding")
			for art: TouchControlArt in controls.artwork:
				if art.button_index in [2,4]: check(not art.visible,method+str(left)+" absent pedal artwork")
			controls.queue_free()
			await process_frame
	var reverse := VehicleSimulation.new(config)
	for t: int in range(240): reverse.step(DriveFrame.sample(0,1,1))
	check(reverse.state.velocity.y < -6.5 and reverse.state.velocity.y >= -config.reverse_speed,"same accelerator drives bounded reverse")
	for t: int in range(240): reverse.step(DriveFrame.sample(0,0,1))
	check(reverse.state.velocity == Vector2.ZERO,"release stops reverse without a brake control")
	var surfaces := SurfaceAudioModel.new()
	surfaces.configure(config)
	var reverse_state := VehicleState.new()
	reverse_state.velocity = Vector2(0,-5)
	surfaces.sample(reverse_state,DriveFrame.sample(0,1,1),null,1,true)
	check(surfaces.drive > 0.65,"reverse surface sound follows the single accelerator")
	surfaces.sample(reverse_state,DriveFrame.sample(0,0,1),null,1,true)
	check(surfaces.drive < 0.001,"D/R selection cannot sound like powered tyres during reverse lift")
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
	var trajectory := RacingTrajectory.new()
	trajectory.build(track,config)
	var controlled := VehicleSimulation.new(config)
	controlled.reset(track.spawn,track.spawn_heading)
	controlled.state.route_index = track.nearest_route(track.spawn)
	var profile := ProfiledRouteDriver.new({"seed":7,"skill":0.7,"consistency":1.0,"aggression":0.5,"learning":0.5,"strengths":{}},"pine",track.content_hash,0)
	profile.trajectory = trajectory
	var session := TrackSession.new(120,5)
	var channels_valid: bool = true
	for t: int in range(1200):
		var command: DriveFrame = profile.sample(controlled.state,track,config,session)
		channels_valid = channels_valid and command.brake == 0 and command.handbrake == 0
		var before: Vector2 = controlled.state.position
		controlled.step(command,track)
		session.advance(track,before,controlled.state.position,controlled.state.route_index,controlled.state.track_elevated)
	check(channels_valid and controlled.state.position.distance_to(track.spawn) > 10,"predictive development driver uses only accelerator in Drive")
	profile.obstacle_detours = true
	profile.reverse_until = profile.tick+120
	frame = profile.sample(controlled.state,track,config,session)
	check(frame.throttle == 255 and frame.brake == 255 and frame.handbrake == 0,"development recovery selects Reverse and uses the same accelerator")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var report := FileAccess.open(output+"/one-pedal.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	await process_frame
	print("ONE_PEDAL: %d checks, %d failures, %s" % [checks,failures,JSON.stringify(metrics)])
	quit.call_deferred(1 if failures else 0)

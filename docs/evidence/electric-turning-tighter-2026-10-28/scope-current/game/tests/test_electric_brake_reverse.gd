extends SceneTree
const _NATIVE_TRACK = preload("res://track/native_track.gd")

const OUTPUT = "res://../docs/evidence/electric-brake-reverse-2026-10-28"
var output: String = OUTPUT
var checks := 0
var failures := 0
var metrics := {}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var config: HandlingConfig = VehicleCatalog.config("electric")
	var old: HandlingConfig = load(OUTPUT+"/before/game/resources/cars/electric.tres")
	check(config.version == "electric-24" and not config.single_pedal and not config.handbrake_enabled,"versioned brake/reverse pedals without handbrake")
	var before := old.snapshot()
	var after := config.snapshot()
	for key: String in before:
		if key in ["version","single_pedal","power_lateral_response_scale","engine_force","low_speed_turn_radius","low_speed_turn_acceleration"]: continue
		check(before[key] == after[key],"retained tune: "+key)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	for id: String in fixture.expected_manifest.vehicles:
		if id == "electric": continue
		var other: HandlingConfig = VehicleCatalog.config(id) if id == "compact" else load("res://resources/cars/"+id+".tres")
		check(JSON.stringify(other.snapshot(),"",true).sha256_text() == fixture.expected_manifest.vehicles[id].config_hash,"unchanged other car: "+id)
	metrics.electric = {"handling_version":config.version,"config_hash":JSON.stringify(config.snapshot(),"",true).sha256_text()}
	# Isolate the brake/reverse contract from the later powered-drift adjustment.
	old.power_lateral_response_scale = config.power_lateral_response_scale
	old.low_speed_turn_radius = config.low_speed_turn_radius
	old.low_speed_turn_acceleration = config.low_speed_turn_acceleration
	old.engine_force = config.engine_force # Later acceleration tune is checked independently.
	# Forward power and lift remain bit exact against the previous one-pedal tune.
	for steer: float in [0.0,0.5,-1.0]:
		var a := VehicleSimulation.new(old)
		var b := VehicleSimulation.new(config)
		var exact := true
		for tick: int in range(1200):
			var frame := DriveFrame.sample(steer,1.0 if tick % 300 < 200 else 0.0,0.0)
			a.step(frame)
			b.step(frame)
			exact = exact and a.state.snapshot() == b.state.snapshot()
		check(exact,"exact retained power/lift steering="+str(steer))
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(0,20)
	var ticks := 0
	while sim.state.velocity.y > 0.0 and ticks < 600:
		sim.step(DriveFrame.sample(0,0,1))
		ticks += 1
	metrics.brake_stop_seconds = ticks / 120.0
	check(sim.state.velocity.y == 0.0 and ticks < 180,"brake stops forward travel before reverse")
	for tick: int in range(20): sim.step(DriveFrame.sample(0,0,1))
	check(sim.state.velocity == Vector2.ZERO,"stopped hold delay prevents immediate reverse")
	for tick: int in range(240): sim.step(DriveFrame.sample(0,0,1))
	check(sim.state.velocity.y < -6.0 and sim.state.velocity.y >= -config.reverse_speed,"holding brake drives capped reverse")
	for tick: int in range(240): sim.step(DriveFrame.new())
	check(sim.state.velocity == Vector2.ZERO and sim.state.reverse_wait == 0.0,"release stops reverse and clears hold")
	for tick: int in range(240): sim.step(DriveFrame.sample(0,1,0))
	check(sim.state.velocity.y > 10,"accelerator returns to forward drive")
	var both := VehicleSimulation.new(config)
	for tick: int in range(240): both.step(DriveFrame.sample(0,1,1,1))
	check(both.state.velocity == Vector2.ZERO and both.state.handbrake_pressure == 0,"brake wins simultaneous pedals; handbrake stays disabled")
	var replay := VehicleSimulation.new(config)
	var replay2 := VehicleSimulation.new(config)
	var deterministic := true
	for tick: int in range(2400):
		var command := DriveFrame.sample(sin(tick*0.01),1 if tick%600<200 else 0,1 if tick%600>=200 and tick%600<500 else 0,tick%2)
		replay.step(command)
		replay2.step(command)
		deterministic = deterministic and replay.state.snapshot() == replay2.state.snapshot()
	check(deterministic,"mixed power/braking/reverse replay is tick exact")
	root.size = Vector2i(1280,720)
	for method: String in ControlLayout.METHODS:
		for left: bool in [false,true]:
			var hud := PlaygroundHUD.new()
			hud.config = config
			hud.driver = DriverInput.new()
			root.add_child(hud)
			hud.touch.layout = ControlLayout.preset(left)
			hud.touch.layout.steering_type = method
			await process_frame
			check(hud.direction_button == null and not hud.driver.single_pedal,"actual HUD removes D/R selector")
			var zones := hud.touch.touch_zones()
			check(zones[2].has_area() and zones[3].has_area() and not zones[4].has_area(),method+str(left)+" active brake/gas and absent handbrake")
			var point := zones[2].get_center()
			if not hud.touch.layout.is_empty(): point = hud.touch._cached_hit_bases[2].get_center()
			check(hud.touch.action_at(point) == &"brake",method+str(left)+" brake hit target")
			hud.driver.set_touch(9,&"brake")
			check(hud.driver.sample().brake == 255 and hud.driver.sample().throttle == 0,"touch brake reaches replay channel")
			hud.driver.clear()
			Input.action_press("brake")
			Input.action_press("handbrake")
			check(hud.driver.sample().brake == 255 and hud.driver.sample().handbrake == 0,"keyboard/gamepad brake enabled and handbrake ignored")
			hud.driver.clear()
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output+"/"+method+str(left)+".png") == OK,"native control capture")
			hud.free()
			await process_frame
	var report := FileAccess.open(output+"/results-"+DisplayServer.get_name()+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_BRAKE_REVERSE: %d checks, %d failures %s" % [checks,failures,JSON.stringify(metrics)])
	await process_frame
	quit.call_deferred(1 if failures else 0)

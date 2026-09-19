extends Node
## Explicit local debug marker only. Unscored, bounded physical-device A/B run.
var game: Node
var elapsed: float = 0.0
var stage: int = 0
var frame_ms: Array[float] = []
var process_ms: Array[float] = []
var physics_ms: Array[float] = []
var reports: Array[Dictionary] = []
var scales: Array[float] = [1.0, 0.75, 1.0]
var original_scale: float
var last_usec: int = 0
var batches: Array[bool] = [true,true,true]
var shadows: Array[bool] = [true,true,true]
var sample_seconds: float = 20.0
var costs: Dictionary = {"sim":[],"rules":[],"ai":[],"present":[]}
var slow_frames: Array[Dictionary] = []
var track_id: String = "starter_circuit"
var original_shadows: bool = true
var record_samples: bool = false
var driven_metres: float = 0.0
var last_position := Vector2.ZERO
var touch_stress: bool = false
var speeds: Array[float] = []
var alternate_controls: bool = false
var tyre_impact: bool = false
var warmup_seconds: float = 5.0
var peak_moving_tyres: int = 0
var lamp_modes: Array[bool] = [true,true,true]

func _ready() -> void:
	set_process(false)
	call_deferred("_start")

func _start() -> void:
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://mobile_probe.json"))
	if config is Dictionary and config.get("compare_batches",false):
		scales = [0.667,0.667,0.667]
		batches = [true,false,true]
	var app: Node = get_parent()
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	if config is Dictionary and config.has("track_id"):
		track_id = str(config.track_id)
		var document: Dictionary = TrackLibrary.new().load_document(track_id)
		if document.is_empty():
			push_error("Device probe track is missing or invalid: " + track_id)
			queue_free()
			return
		track = TrackCompiler.compile(document)
		scales = [0.667,0.5,0.667]
		shadows = [true,true,false]
		if config.get("sustained",false):
			scales = [0.667]
			shadows = [true]
		sample_seconds = clampf(float(config.get("seconds",45.0)),10.0,180.0)
		record_samples = true
	touch_stress = config is Dictionary and config.get("touch_stress",false)
	if config is Dictionary and config.get("compare_lights",false):
		scales = [0.667,0.667,0.667]
		shadows = [true,true,true]
		lamp_modes = [true,false,true]
	if config is Dictionary and config.has("render_scale"):
		for index: int in range(scales.size()): scales[index] = clampf(float(config.render_scale),0.5,1.0)
	alternate_controls = config is Dictionary and config.get("alternate_controls",false)
	# Build the actual racing HUD too: the editor practice UI hides its cards.
	app.call("_start_race", track, not record_samples)
	game = app.get("game")
	game.set("ai_enabled", true)
	tyre_impact = config is Dictionary and config.get("tyre_impact",false)
	if tyre_impact:
		warmup_seconds = 2.0
		game.set("ai_enabled",false)
		var sim: VehicleSimulation = game.get("sim")
		var origin: Vector2 = track.tyre_origins[0] if not track.tyre_origins.is_empty() else track.spawn
		var approach: Array = config.get("impact_position",[origin.x,origin.y+4.0])
		sim.reset(Vector2(float(approach[0]),float(approach[1])),PI)
		sim.state.velocity = Vector2(0,-clampf(float(config.get("impact_speed",24.0)),1.0,46.0))
		sim.state.route_index = track.nearest_route(sim.state.position)
		game.set("previous_position",sim.state.position)
		game.set("previous_heading",sim.state.heading)
		(game.get("driver") as DriverInput).set_touch(999,&"accelerate")
		(game.get("camera") as FollowCamera).follow(sim.state.position,Vector2.ZERO,PI,0.0,true)
	if config is Dictionary:
		(game.get("route_driver") as RouteDriver).speed_scale = float(config.get("speed_scale",1.0))
	if record_samples:
		game.set("profile_enabled",true)
		# Exercise the real timed-route validator without saving an AI personal best.
		game.set("editor_test",false)
		game.set("attempt_practice",true)
		(game.get("track_session") as TrackSession).target_laps = 10000
	original_scale = get_viewport().scaling_3d_scale
	if config is Dictionary and config.get("use_game_scale",false):
		for index: int in range(scales.size()): scales[index] = original_scale
	original_shadows = (game.get("biome_light") as DirectionalLight3D).shadow_enabled
	_configure_stage()
	last_position = game.get("sim").state.position
	last_usec = Time.get_ticks_usec()
	set_process(true)
	print("MOBILE_PROBE_START scale=", scales[stage])

func _process(_delta: float) -> void:
	if touch_stress:
		var touch: TouchControls = (game.get("hud") as PlaygroundHUD).touch
		var active: Array[int] = [0,3]
		if alternate_controls:
			active = [int(elapsed*4.0)%2,2 if int(elapsed)%5 == 0 else 3]
			for index: int in range(4): touch.driver.release_touch(900+index)
		for index: int in active:
			var event := InputEventScreenTouch.new()
			event.index = 900+index
			event.pressed = true
			event.position = touch.zones()[index].get_center()+Vector2(sin(elapsed*8.0)*4.0,0)
			touch._input(event)
	var now: int = Time.get_ticks_usec()
	var duration: float = (now - last_usec) / 1000.0
	last_usec = now
	elapsed += duration / 1000.0
	var current_position: Vector2 = game.get("sim").state.position
	driven_metres += current_position.distance_to(last_position)
	last_position = current_position
	var moving: int = 0
	for tyre: Array in game.get("sim").state.loose_tyres:
		if float(tyre[2]) != 0.0 or float(tyre[3]) != 0.0: moving += 1
	peak_moving_tyres = maxi(peak_moving_tyres,moving)
	if elapsed > warmup_seconds:
		speeds.append(game.get("sim").state.velocity.length()*3.6)
		frame_ms.append(duration)
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		for key: String in costs:
			costs[key].append(float(game.get("profile_"+key+"_us"))/1000.0)
		if record_samples and duration > 25.0:
			var state: VehicleState = game.get("sim").state
			slow_frames.append({"ms":duration,"tick":state.tick,"x":state.position.x,"y":state.position.y,
				"sim_ms":game.get("profile_sim_us")/1000.0,"rules_ms":game.get("profile_rules_us")/1000.0,
				"present_ms":game.get("profile_present_us")/1000.0})
	for key: String in costs: game.set("profile_"+key+"_us",0)
	if elapsed < warmup_seconds + sample_seconds: return
	frame_ms.sort()
	process_ms.sort()
	physics_ms.sort()
	var report: Dictionary = {"scale":scales[stage], "batch_parts":batches[stage], "frames":frame_ms.size(),
		"frame_median_ms":frame_ms[frame_ms.size()/2], "frame_p95_ms":frame_ms[int(frame_ms.size()*0.95)],
		"frame_max_ms":frame_ms.back(), "process_median_ms":process_ms[process_ms.size()/2],
		"physics_median_ms":physics_ms[physics_ms.size()/2],
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	report.track_id = track_id
	report.shadows = shadows[stage]
	report.lamps_enabled = lamp_modes[stage]
	report.lamp_count = game.find_children("*","OmniLight3D",true,false).size()
	report.vehicle = VehicleCatalog.selected
	report.frame_p99_ms = frame_ms[int(frame_ms.size()*0.99)]
	report.over_25_ms = frame_ms.filter(func(value: float) -> bool: return value > 25.0).size()
	report.over_33_ms = frame_ms.filter(func(value: float) -> bool: return value > 33.34).size()
	report.simulated_seconds = game.get("sim").state.tick / 120.0
	report.wall_seconds = elapsed
	report.driven_metres = driven_metres
	report.completed_laps = (game.get("track_session") as TrackSession).completed_laps
	report.touch_stress = touch_stress
	report.touch_draws = (game.get("hud") as PlaygroundHUD).touch.draw_count
	var art_draws: int = 0
	for art: TouchControlArt in (game.get("hud") as PlaygroundHUD).touch.artwork: art_draws += art.draw_count
	report.artwork_draws = art_draws
	speeds.sort()
	report.speed_median_kph = speeds[speeds.size()/2]
	report.speed_max_kph = speeds.back()
	report.tyre_impact = tyre_impact
	report.peak_moving_tyres = peak_moving_tyres
	report.collisions = game.get("sim").state.collision_count
	for key: String in costs:
		costs[key].sort()
		report[key+"_median_ms"] = costs[key][costs[key].size()/2]
		report[key+"_p99_ms"] = costs[key][int(costs[key].size()*0.99)]
	reports.append(report)
	print("MOBILE_PROBE ", JSON.stringify(report))
	if record_samples: report.slow_frames = slow_frames.duplicate()
	var output := FileAccess.open("user://mobile_probe_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(reports,"\t"))
	output.close()
	stage += 1
	if stage == scales.size():
		game.set("profile_enabled",false)
		get_viewport().scaling_3d_scale = original_scale
		(game.get("biome_light") as DirectionalLight3D).shadow_enabled = original_shadows
		game.call("toggle_pause")
		var file := FileAccess.open("user://mobile_probe_results.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(reports, "\t"))
		file.close()
		queue_free()
		return
	elapsed = 0.0
	frame_ms.clear()
	process_ms.clear()
	physics_ms.clear()
	speeds.clear()
	for key: String in costs: costs[key].clear()
	slow_frames.clear()
	game.call("restart")
	driven_metres = 0.0
	last_position = game.get("sim").state.position
	if record_samples:
		game.set("attempt_practice",true)
		(game.get("track_session") as TrackSession).target_laps = 10000
	_configure_stage()
	print("MOBILE_PROBE_START scale=", scales[stage], " batch=",batches[stage])

func _configure_stage() -> void:
	var previous: CarVisual = game.get("car")
	if previous.batch_parts != batches[stage]:
		var replacement := CarVisual.new()
		replacement.vehicle_id = previous.vehicle_id
		replacement.batch_parts = batches[stage]
		previous.get_parent().add_child(replacement)
		game.set("car",replacement)
		previous.queue_free()
	get_viewport().scaling_3d_scale = scales[stage]
	(game.get("biome_light") as DirectionalLight3D).shadow_enabled = shadows[stage]
	for lamp: OmniLight3D in game.find_children("*","OmniLight3D",true,false): lamp.visible = lamp_modes[stage]

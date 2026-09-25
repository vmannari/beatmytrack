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
var costs: Dictionary = {"sim":[],"rules":[],"ai":[],"present":[],"particles":[],"trails":[],"telemetry":[],"weather":[],"car":[],"props":[],"camera":[],"hud":[]}
var feature_stages: Array = []
var surface_probe = preload("res://diagnostics/surface_material_probe.gd").new()
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
var trail_modes: Array[bool] = [true,true,true]
var compare_trails: bool = false
var probe_track: NativeTrack
var compare_particles: bool = false
var particle_modes: Array[bool] = [true,true,true]
var winter_stress: bool = false
var winter_reset_cycle: int = -1
var snow_chip_frames: int = 0
var snow_powder_frames: int = 0

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
	winter_stress = config is Dictionary and config.get("winter_stress",false)
	touch_stress = config is Dictionary and config.get("touch_stress",false)
	if config is Dictionary and config.get("compare_lights",false):
		scales = [0.667,0.667,0.667]
		shadows = [true,true,true]
		lamp_modes = [true,false,true]
	compare_trails = config is Dictionary and config.get("compare_trails",false)
	if compare_trails:
		scales = [0.667,0.667,0.667]
		shadows = [true,true,true]
		trail_modes = [false,true,false]
	if config is Dictionary and config.has("render_scale"):
		for index: int in range(scales.size()): scales[index] = clampf(float(config.render_scale),0.5,1.0)
	compare_particles = config is Dictionary and config.get("compare_particles",false)
	if compare_particles:
		scales = [0.667,0.667,0.667]
		shadows = [true,true,true]
		particle_modes = [true,false,true]
	alternate_controls = config is Dictionary and config.get("alternate_controls",false)
	# Build the actual racing HUD too: the editor practice UI hides its cards.
	app.call("_start_race", track, not record_samples)
	probe_track = track
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
	surface_probe.collect(game.get("track_ground"))
	if config is Dictionary and config.get("feature_profile",false):
		feature_stages = config.get("features",["baseline","shadows","particles","trails","hud","weather","half_scale","baseline"])
		scales.clear()
		batches.clear()
		shadows.clear()
		lamp_modes.clear()
		trail_modes.clear()
		particle_modes.clear()
		for feature: String in feature_stages:
			scales.append(0.5 if feature == "half_scale" else original_scale)
			batches.append(true)
			shadows.append(original_shadows and feature != "shadows")
			lamp_modes.append(true)
			trail_modes.append(false)
			particle_modes.append(feature != "particles")
	_configure_stage()
	last_position = game.get("sim").state.position
	last_usec = Time.get_ticks_usec()
	set_process(true)
	print("MOBILE_PROBE_START scale=", scales[stage])

func _process(_delta: float) -> void:
	if winter_stress: _winter_excursion()
	if compare_trails and not trail_modes[stage]: (game.get("trails") as SkidTrails).clear()
	if touch_stress:
		var touch: TouchControls = (game.get("hud") as PlaygroundHUD).touch
		var active: Array[int] = [0,3]
		if alternate_controls:
			active = [int(elapsed*4.0)%2,2 if int(elapsed)%5 == 0 else 3]
		for index: int in range(4):
			if index not in active and touch.driver.touches.has(900+index):
				var release := InputEventScreenTouch.new()
				release.index = 900+index
				touch._input(release)
		for index: int in active:
			var held: bool = touch.driver.touches.has(900+index)
			var event: InputEvent = InputEventScreenDrag.new() if held else InputEventScreenTouch.new()
			event.index = 900+index
			if not held: event.pressed = true
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
		var snow: SandDust = game.get("sand_dust")
		if snow.visible:
			if snow.snow_chips.any(func(emitter: GPUParticles3D) -> bool: return emitter.emitting): snow_chip_frames += 1
			if snow.snow_powder.any(func(emitter: GPUParticles3D) -> bool: return emitter.emitting): snow_powder_frames += 1
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
	report.disabled_feature = feature_stages[stage] if not feature_stages.is_empty() else "legacy_probe"
	report.timing_schema = 2
	report.surface_materials_changed = surface_probe.changed_count
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
	report.trails_saturated = trail_modes[stage]
	report.particles_enabled = particle_modes[stage]
	report.winter_stress = winter_stress
	report.snow_chip_frames = snow_chip_frames
	report.snow_powder_frames = snow_powder_frames
	report.snow_bank_bursts = (game.get("sand_dust") as SandDust).snow_burst_count
	report.trail_instances = (game.get("trails") as SkidTrails).instances.visible_instance_count
	report.peak_moving_tyres = peak_moving_tyres
	report.collisions = game.get("sim").state.collision_count
	for key: String in costs:
		costs[key].sort()
		report[key+"_median_ms"] = costs[key][costs[key].size()/2]
		report[key+"_p99_ms"] = costs[key][int(costs[key].size()*0.99)]
		var total: float = 0.0
		for value: float in costs[key]: total += value
		report[key+"_mean_ms"] = total / costs[key].size()
	reports.append(report)
	print("MOBILE_PROBE ", JSON.stringify(report))
	if record_samples: report.slow_frames = slow_frames.duplicate()
	var output := FileAccess.open("user://mobile_probe_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(reports,"\t"))
	output.close()
	stage += 1
	if stage == scales.size():
		TouchControls.SteeringHaptics.diagnostic_synchronous = false
		surface_probe.restore()
		_set_particles_enabled(true)
		(game.get("trails") as SkidTrails).visible = true
		(game.get("hud") as PlaygroundHUD).visible = true
		if game.get("storm_weather") != null: game.get("storm_weather").visible = true
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
	winter_reset_cycle = -1
	snow_chip_frames = 0
	snow_powder_frames = 0
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
	if not feature_stages.is_empty():
		var feature: String = feature_stages[stage]
		TouchControls.SteeringHaptics.diagnostic_synchronous = feature == "haptics_sync"
		(game.get("hud") as PlaygroundHUD).touch.haptic_strength = 0.0 if feature == "haptics_off" else TouchControls.SteeringHaptics.AMPLITUDE
		(game.get("car") as CarVisual).set_night_headlights(probe_track.metadata.get("theme","pine") == "night_city" and feature != "headlights")
		surface_probe.apply(feature)
		game.set("profile_skip_telemetry",feature == "telemetry")
		_set_particles_enabled(feature != "particles")
		(game.get("trails") as SkidTrails).visible = feature != "trails"
		(game.get("hud") as PlaygroundHUD).visible = feature != "hud"
		if game.get("storm_weather") != null: game.get("storm_weather").visible = feature != "weather"
	if compare_particles: _set_particles_enabled(particle_modes[stage])
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
	if compare_trails:
		var trails: SkidTrails = game.get("trails")
		trails.clear()
		if trail_modes[stage]:
			var count: int = probe_track.route.size()
			for index: int in range(trails.CAPACITY):
				var route_index: int = floori(index/4.0)%count
				var point: Vector2 = probe_track.route[route_index]
				var next: Vector2 = probe_track.route[(route_index+1)%count]
				var tangent: Vector2 = (next-point).normalized()
				var side: float = -0.72 if index%2 == 0 else 0.72
				var offset: Vector2 = tangent.orthogonal()*side
				var a: Vector3 = VisualGeometry.world(point+offset)+Vector3(0,0.029,0)
				var b: Vector3 = VisualGeometry.world(next+offset)+Vector3(0,0.029,0)
				trails._mark(a,b,0.0,0,0.58)

func _set_particles_enabled(enabled: bool) -> void:
	var effect: Node3D = game.get("sand_dust")
	effect.visible = enabled
	for emitter: GPUParticles3D in effect.get_children():
		emitter.speed_scale = 1.0 if enabled else 0.0


func _winter_excursion() -> void:
	# Explicit debug-only workload: real physics drives across banks every six seconds.
	# Reset between excursions so it cannot become a stationary off-map benchmark.
	var cycle: int = int(elapsed/6.0)
	if cycle == winter_reset_cycle: return
	winter_reset_cycle = cycle
	game.set("ai_enabled",false)
	game.set("countdown_ticks",0)
	var index: int = (cycle*17)%probe_track.route.size()
	var point: Vector2 = probe_track.route[index]
	var tangent: Vector2 = (probe_track.route[(index+1)%probe_track.route.size()]-point).normalized()
	var travel: Vector2 = (tangent+tangent.orthogonal()*0.8).normalized()
	var sim: VehicleSimulation = game.get("sim")
	var tick: int = sim.state.tick
	sim.reset(point,atan2(tangent.x,tangent.y))
	sim.state.tick = tick
	sim.state.velocity = travel*22.0
	sim.state.route_index = index
	game.set("previous_position",point)
	game.set("previous_heading",sim.state.heading)
	last_position = point
	var driver: DriverInput = game.get("driver")
	for touch: int in [900,901,902,903,999]: driver.release_touch(touch)
	driver.set_touch(999,&"accelerate")
	(game.get("camera") as FollowCamera).follow(point,Vector2.ZERO,sim.state.heading,0.0,true)
	# Preserve burst count but prevent a teleport from sweeping across the entire track.
	(game.get("sand_dust") as SandDust).snow_previous_valid = false
	(game.get("sand_dust") as SandDust).snow_in_bank = false

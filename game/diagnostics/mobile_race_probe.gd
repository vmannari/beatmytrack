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
var bridge_upper_review: bool = false
var bridge_along_review: float = -1.0
var visual_only: bool = false
var dust_parity: RefCounted
var readiness_path: String = ""
var original_dust_materials: Dictionary = {}
var original_particle_shadows: Dictionary = {}
var original_msaa: int
var original_scale: float
var last_usec: int = 0
var batches: Array[bool] = [true,true,true]
var shadows: Array[bool] = [true,true,true]
var sample_seconds: float = 20.0
var costs: Dictionary = {"sim":[],"rules":[],"ai":[],"present":[],"particles":[],"trails":[],"telemetry":[],"weather":[],"car":[],"props":[],"camera":[],"hud":[],"audio":[],"contact":[],"music":[],"water":[],"history":[]}
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
var original_music_output: bool = true
var original_presentation_water: bool = true
var paused_frames: int = 0
var screen_keep_saved: bool = false
var screen_keep_original: bool = false

func _ready() -> void:
	set_process(false)
	call_deferred("_start")

func _start() -> void:
	original_music_output = GameSoundtrack.instance().output_enabled
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://mobile_probe.json"))
	if config is Dictionary and config.get("compare_batches",false):
		scales = [0.667,0.667,0.667]
		batches = [true,false,true]
	var app: Node = get_parent()
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	if config is Dictionary and (config.has("track_id") or config.has("document_path")):
		track_id = str(config.get("track_id","diagnostic_document"))
		var document: Dictionary = TrackLibrary.new().import_document(str(config.document_path)) if config.has("document_path") else TrackLibrary.new().load_document(track_id)
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
	# Local diagnostic tracks use the authorized practice launch path. Ordinary
	# Race now requires a published track; a probe must never request a ticket
	# or write last-track preferences/competitive records just to benchmark it.
	await app.call("_start_race", track, true, true)
	probe_track = track
	game = app.get("game")
	if not is_instance_valid(game):
		push_error("Device probe could not start its local practice scene")
		queue_free()
		return
	if OS.has_feature("mobile"):
		screen_keep_original = DisplayServer.screen_is_kept_on()
		screen_keep_saved = true
		DisplayServer.screen_set_keep_on(true)
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
		# Match every restart's standing/countdown phase before the timed window.
		game.set("countdown_ticks",360)
		# Exercise the real timed-route validator without saving an AI personal best.
		game.set("editor_test",false)
		(game.get("hud") as PlaygroundHUD).editor_test = false
		(game.get("hud") as PlaygroundHUD).title.text = "Race"
		game.set("attempt_practice",true)
		(game.get("track_session") as TrackSession).target_laps = 10000
	original_msaa = get_viewport().msaa_3d
	original_scale = get_viewport().scaling_3d_scale
	original_presentation_water = bool(game.get("_presentation_has_water"))
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
			scales.append(0.667 if feature == "previous" else (0.4 if feature == "render_40" else (0.5 if feature == "half_scale" else original_scale)))
			batches.append(true)
			shadows.append(original_shadows and feature not in ["shadows","msaa_2x_shadows"])
			lamp_modes.append(true)
			trail_modes.append(false)
			particle_modes.append(feature != "particles")
	bridge_upper_review = config is Dictionary and config.get("bridge_upper",false)
	bridge_along_review = float(config.get("bridge_along",-1.0)) if config is Dictionary else -1.0
	visual_only = config is Dictionary and config.get("bridge_review",false)
	readiness_path = str(config.get("state_path","")) if config is Dictionary else ""
	if config.get("dust_parity_review",false):
		visual_only = true
		touch_stress = false
		dust_parity = preload("res://diagnostics/dust_parity_review.gd").new()
		await dust_parity.prepare(game,probe_track)
	_configure_stage()
	if visual_only and dust_parity==null: _bridge_review_pose()
	if not readiness_path.is_empty():
		var ready_file := FileAccess.open(readiness_path,FileAccess.WRITE)
		ready_file.store_string(JSON.stringify({"stage":stage,"ready":true}))
	last_position = game.get("sim").state.position
	last_usec = Time.get_ticks_usec()
	set_process(true)
	print("MOBILE_PROBE_START scale=", scales[stage])

func _process(_delta: float) -> void:
	if visual_only and dust_parity==null: (game.get("sand_dust") as SandDust).sample(game.get("sim").state,DriveFrame.new(),probe_track,game.get("bridge_presentation"))
	if dust_parity!=null:
		game.set("paused",false)
		game.get("hud").pause_menu.hide()
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
		if bool(game.get("paused")): paused_frames += 1
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
	report.visual_only = visual_only
	if visual_only:
		report.bridge_along = bridge_along_review
		report.bridge_upper = bridge_upper_review
	report.bridge_clipping = (game.get("sand_dust") as SandDust).bridge_clipping_enabled
	report.deck_cloud_emitters = (game.get("sand_dust") as SandDust).deck_dust_emitters.size()
	report.dust_presentation = SandDust.PRESENTATION_VERSION
	if dust_parity!=null:
		report.car_materials = dust_parity.material_report()
		report.dust_parity_pixels = dust_parity.capture_stats(str(feature_stages[stage]))
	report.dust_height_occlusion = (game.get("sand_dust") as SandDust).height_occlusion_enabled
	report.trail_bridge_clipping = (game.get("trails") as SkidTrails).bridge_clipping_enabled
	report.dust_cast_shadow = game.get("sand_dust").dust_emitters[0].cast_shadow
	if report.deck_cloud_emitters>0:
		var deck: GPUParticles3D = (game.get("sand_dust") as SandDust).deck_dust_emitters[0]
		report.deck_birth_height = (deck.draw_pass_1.surface_get_material(0) as ShaderMaterial).get_shader_parameter("dust_birth_height_available")
		report.deck_birth_process = deck.process_material is ShaderMaterial
	report.paused_frames = paused_frames
	report.dust_billowing = (game.get("sand_dust").dust_emitters[0].draw_pass_1.surface_get_material(0) as ShaderMaterial).get_shader_parameter("billowing")
	report.dust_texture_present = (game.get("sand_dust").dust_emitters[0].draw_pass_1.surface_get_material(0) as ShaderMaterial).get_shader_parameter("dust_texture") is Texture2D
	report.msaa_actual = get_viewport().msaa_3d
	report.world_fxaa = game.get("mobile_world_aa")!=null and game.get("mobile_world_aa").visible
	report.adapter = RenderingServer.get_video_adapter_name()
	report.renderer = RenderingServer.get_current_rendering_method()
	report.rendering_driver = RenderingServer.get_current_rendering_driver_name()
	report.scale_actual = get_viewport().scaling_3d_scale
	report.viewport_pixels = [get_window().size.x,get_window().size.y]
	report.world_pixels = int(get_window().size.x*get_window().size.y*get_viewport().scaling_3d_scale*get_viewport().scaling_3d_scale)
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
		_configure_audio("baseline")
		_configure_dust_depth("baseline")
		game.set("_presentation_has_water",original_presentation_water)
		TouchControls.SteeringHaptics.diagnostic_synchronous = false
		surface_probe.restore()
		_set_particles_enabled(true)
		game.call("set_contact_lighting_enabled",true)
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
	paused_frames = 0
	process_ms.clear()
	physics_ms.clear()
	speeds.clear()
	for key: String in costs: costs[key].clear()
	slow_frames.clear()
	if dust_parity==null: game.call("restart")
	driven_metres = 0.0
	last_position = game.get("sim").state.position
	if record_samples:
		game.set("attempt_practice",true)
		(game.get("track_session") as TrackSession).target_laps = 10000
	_configure_stage()
	if visual_only and dust_parity==null: _bridge_review_pose()
	if not readiness_path.is_empty():
		var ready_file := FileAccess.open(readiness_path,FileAccess.WRITE)
		ready_file.store_string(JSON.stringify({"stage":stage,"ready":true}))
	print("MOBILE_PROBE_START scale=", scales[stage], " batch=",batches[stage])

func _configure_stage() -> void:
	if not feature_stages.is_empty():
		var feature: String = feature_stages[stage]
		_configure_audio(feature)
		_configure_dust_depth(feature)
		# Same-build comparison of former pixel load and always-sampled water.
		game.set("_presentation_has_water",original_presentation_water or feature == "previous")
		game.call("set_contact_lighting_enabled",feature not in ["contact_lighting","msaa_2x_contact_lighting"])
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
	if dust_parity!=null:
		game.get("sand_dust").hide()
		dust_parity.select(str(feature_stages[stage]))

func _configure_audio(feature: String) -> void:
	# Explicit unscored debug comparisons; every stage restores normal playback.
	var race_audio: VehicleAudio = game.get("vehicle_audio")
	var vehicle_enabled: bool = feature not in ["vehicle_audio","audio"]
	race_audio.active = vehicle_enabled
	for player: AudioStreamPlayer in race_audio.get_children():
		player.stream_paused = not vehicle_enabled
	var soundtrack: GameSoundtrack = GameSoundtrack.instance()
	soundtrack.output_enabled = original_music_output and feature not in ["music","audio"]
	if not soundtrack.output_enabled:
		for player: AudioStreamPlayer in soundtrack.get_children(): player.stop()
	elif soundtrack.is_race_owner(game) and not soundtrack.race_player.playing:
		soundtrack.race_player.play()


func _set_particles_enabled(enabled: bool) -> void:
	var effect: Node3D = game.get("sand_dust")
	effect.visible = enabled
	for emitter: GPUParticles3D in effect.get_children():
		emitter.speed_scale = 1.0 if enabled else 0.0


func _exit_tree() -> void:
	if screen_keep_saved: DisplayServer.screen_set_keep_on(screen_keep_original)


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

func _configure_dust_depth(feature: String) -> void:
	get_viewport().msaa_3d = original_msaa
	if feature=="msaa_off": get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if feature=="msaa_4x": get_viewport().msaa_3d = Viewport.MSAA_4X
	if feature.begins_with("msaa_2x"): get_viewport().msaa_3d = Viewport.MSAA_2X

	for node: Node3D in get_tree().get_nodes_in_group("contact_lighting"):
		if game.is_ancestor_of(node) and node.name.begins_with("BridgeUnderShadow"):
			node.visible = feature not in ["msaa_2x_bridge_shadows","msaa_2x_contact_lighting"]
	for emitter: GPUParticles3D in (game.get("sand_dust") as SandDust).dust_emitters+(game.get("sand_dust") as SandDust).tyre_emitters:
		if not original_particle_shadows.has(emitter): original_particle_shadows[emitter] = emitter.cast_shadow
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if feature=="msaa_2x_particle_shadows" else original_particle_shadows[emitter]

		if not original_dust_materials.has(emitter): original_dust_materials[emitter] = emitter.draw_pass_1.surface_get_material(0)
		var original: ShaderMaterial = original_dust_materials[emitter]
		var active: ShaderMaterial = emitter.draw_pass_1.surface_get_material(0)
		if active!=original:
			# Profiles can update the selected diagnostic material after startup.
			# Retain those shipping size/lifetime/texture values when restoring it.
			for uniform: Dictionary in active.shader.get_shader_uniform_list():
				var value: Variant = active.get_shader_parameter(uniform.name)
				if value!=null: original.set_shader_parameter(uniform.name,value)
		var chosen: ShaderMaterial = original
		if feature in ["msaa_2x_fragment_depth","msaa_2x_vertex_depth","msaa_2x_no_fade","msaa_2x_late_depth"]:
			var code: String = original.shader.code
			if feature=="msaa_2x_fragment_depth": code = code.replace("VERTEX.z-scene.z/scene.w","(FRAGCOORD.z-depth)*2.0/PROJECTION_MATRIX[2][2]")
			if feature=="msaa_2x_no_fade": code = code.replace("alpha *= smoothstep(0.0,intersection_fade,VERTEX.z-scene.z/scene.w);","alpha *= 1.0;")
			if feature=="msaa_2x_vertex_depth":
				code = code.replace("varying vec2 cloud_uv;","varying vec2 cloud_uv;\nvarying highp float particle_view_z;")
				code = code.replace("void fragment() {","void fragment() {")
				code = code.replace("MODEL_MATRIX[3]);","MODEL_MATRIX[3]);\nparticle_view_z = (MODELVIEW_MATRIX*vec4(VERTEX,1.0)).z;")
				code = code.replace("VERTEX.z-scene.z/scene.w","particle_view_z-scene.z/scene.w")
			if feature=="msaa_2x_late_depth": code = code.replace("ALPHA = COLOR.a * alpha;","ALPHA = COLOR.a * alpha;\nDEPTH = FRAGCOORD.z;")
			var shader := Shader.new()
			shader.code = code
			chosen = original.duplicate()
			chosen.shader = shader
			for uniform: Dictionary in original.shader.get_shader_uniform_list():
				var value: Variant = original.get_shader_parameter(uniform.name)
				if value!=null: chosen.set_shader_parameter(uniform.name,value)
		emitter.draw_pass_1.surface_set_material(0,chosen)
	(game.get("sand_dust") as SandDust).bridge_clipping_enabled = feature!="bridge_clip_off"
	(game.get("sand_dust") as SandDust).height_occlusion_enabled = feature!="dust_height_depth_off"
	(game.get("trails") as SkidTrails).bridge_clipping_enabled = feature!="bridge_trails_off"

func _bridge_review_pose() -> void:
	if probe_track.creator_bridges.is_empty():
		push_error("Bridge review requires a creator bridge")
		return
	game.set_physics_process(false)
	game.set("ai_enabled",false)
	game.set("countdown_ticks",0)
	game.get("race_cues").reset()
	var span: Dictionary = probe_track.creator_bridges[0]
	var along: float = float(span.length)*0.5 if bridge_along_review<0.0 else clampf(bridge_along_review,0.0,float(span.length))
	var point: Vector2 = Vector2(float(span.position[0]),float(span.position[1]))+Vector2(along,0).rotated(deg_to_rad(float(span.heading)))
	var state: VehicleState = game.get("sim").state
	state.position = point
	state.heading = PI*0.5-deg_to_rad(float(span.heading)) if bridge_upper_review else deg_to_rad(float(span.heading))
	state.velocity = state.forward()*12.0
	state.track_elevated = bridge_upper_review
	game.set("previous_position",point)
	game.set("previous_heading",state.heading)
	(game.get("camera") as FollowCamera).speed_zoom_enabled = false
	(game.get("camera") as FollowCamera).follow(point,Vector2.ZERO,state.heading,0.0,true)
	# Actual tread geometry on both tyre lines exposes underpass/deck overlap.
	# These fixed-position marks exist only in this unsaved debug review.
	var trails: SkidTrails = game.get("trails")
	trails.clear()
	trails._bind_bridges(probe_track)
	trails.desert_sand = str(probe_track.metadata.get("theme",""))=="desert"
	for side: float in [-1.0,1.0]:
		for index: int in range(-40,40):
			var a: Vector2 = point+state.forward()*(index*0.4)+state.right()*(side*trails.track_width*0.5)
			var b: Vector2 = a+state.forward()*0.4
			var a_height: float = CreatorBridges.height(span,a) if bridge_upper_review else 0.0
			var b_height: float = CreatorBridges.height(span,b) if bridge_upper_review else 0.0
			trails._mark(VisualGeometry.world(a)+Vector3.UP*(a_height+0.028),VisualGeometry.world(b)+Vector3.UP*(b_height+0.028),0.0,2,0.85)

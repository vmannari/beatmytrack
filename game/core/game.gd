extends Node
## Composition and lifecycle; canonical dynamics live in VehicleSimulation.

const SandDustEffect = preload("res://vehicle/sand_dust.gd")
const ImpactCracksEffect = preload("res://camera/impact_cracks.gd")

signal exit_requested
signal race_completed
signal retry_requested
signal edit_here_requested(position: Vector2)
signal practice_lap_completed

var practice_validation: TrackSession
var practice_validation_eligible: bool = true

var storm_weather: StormWeather
var weather_layer: CanvasLayer
var biome_light: DirectionalLight3D
var biome_environment: Environment
var initial_track: NativeTrack
var production_mode: bool = false
var editor_test: bool = false
var attempt_practice: bool = false
var countdown_ticks: int = 0
var countdown_label: Label
var race_cues: Control
var finish_sim: VehicleSimulation
var finish_ticks: int = 0
var rating_records: LocalRecords
var finish_rating_pending: bool = false
const FINISH_TICKS: int = 216

const PROFILE_PATHS: Array[String] = HandlingSelection.PROFILE_PATHS
var profile_index: int = HandlingSelection.index
var resume_after_handling: bool = false
var vehicle_id: String = VehicleCatalog.selected
var handling: HandlingConfig
var sim: VehicleSimulation
var yard := PlaygroundData.new()
var driver := DriverInput.new()
var frame := DriveFrame.new()
var recorder := HandlingRecorder.new()
var car: CarVisual
var contact_shadow: MeshInstance3D
var cloud_shadow: MeshInstance3D
var cloud_elapsed: float = 0.0
var contact_lighting_enabled: bool = true
var camera: FollowCamera
var impact_cracks: Control
var trails: SkidTrails
var sand_dust: SandDustEffect
var tire_audio: TireAudio
var music: DynamicMusicController
var hud: PlaygroundHUD
var paused: bool = false
var previous_position: Vector2
var previous_heading: float = 0.0
var demo_capture: bool = false
var capture_path: String = ""
var track_index: int = -1
var TRACK_NAMES: Array[String] = BuiltinTracks.ids()
var native_track: NativeTrack
var lap_telemetry := LapTelemetry.new()
var track_session: TrackSession
var track_ground: Node3D
var track_debug: TrackDebug
var ai_enabled: bool = false
var route_driver := RouteDriver.new()
var overview: bool = false
var capture_tick: int = 0
var bridge_presentation: BridgePresentation
var checkpoint_marker: CheckpointMarker
var profile_enabled: bool = false
var profile_sim_us: int = 0
var profile_rules_us: int = 0
var profile_ai_us: int = 0
var profile_present_us: int = 0
var profile_particles_us: int = 0
var profile_trails_us: int = 0
var profile_telemetry_us: int = 0
var profile_weather_us: int = 0
var profile_car_us: int = 0
var profile_props_us: int = 0
var profile_camera_us: int = 0
var profile_hud_us: int = 0
var profile_skip_telemetry: bool = false
var _render_viewport: Viewport
var _base_render_scale: float = 1.0


func _ready() -> void:
	_render_viewport = get_viewport()
	_base_render_scale = _render_viewport.scaling_3d_scale
	if Engine.physics_ticks_per_second != VehicleSimulation.TICK_RATE:
		push_error("Project physics rate must match the canonical 120 Hz step.")
		get_tree().quit(1)
		return
	handling = VehicleCatalog.config(vehicle_id, profile_index)
	sim = VehicleSimulation.new(handling)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			track_index = TRACK_NAMES.find(argument.trim_prefix("--track="))
		if argument == "--overview": overview = true
		if argument == "--ai": ai_enabled = true
		if argument.begins_with("--capture-tick="): capture_tick = int(argument.trim_prefix("--capture-tick="))
	if track_index >= 0:
		native_track = NativeTrack.read("res://resources/tracks/" + TRACK_NAMES[track_index] + ".json")
		yard = native_track
	if initial_track != null:
		native_track = initial_track
		yard = native_track
	var world: Node3D = $World
	_build_ground(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -35, 0)
	light.light_color = Color("fff1d8")
	light.light_energy = 1.0
	light.shadow_enabled = true
	# One stable shadow projection suits the compact overhead view.
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 65.0
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("647158")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bac8ce")
	environment.environment.ambient_light_energy = 0.35
	world.add_child(environment)
	biome_light = light
	biome_environment = environment.environment
	TrackTheme.apply_lighting(str(native_track.metadata.get("theme","pine")) if native_track != null else "pine",environment.environment,light)
	_update_weather()
	checkpoint_marker = CheckpointMarker.new()
	world.add_child(checkpoint_marker)
	car = CarVisual.new()
	car.vehicle_id = vehicle_id
	world.add_child(car)
	contact_shadow = ContactShading.car_shadow(world)
	car.set_night_headlights(native_track != null and native_track.metadata.get("theme","pine") == "night_city")
	trails = SkidTrails.new()
	trails.wheelbase = handling.wheelbase
	trails.track_width = handling.track_width
	world.add_child(trails)
	sand_dust = SandDustEffect.new()
	sand_dust.wheelbase = handling.wheelbase
	sand_dust.track_width = handling.track_width
	sand_dust.collision_radius = handling.collision_radius
	world.add_child(sand_dust)
	tire_audio = TireAudio.new()
	add_child(tire_audio)
	music = DynamicMusicController.new()
	add_child(music)
	camera = FollowCamera.new()
	world.add_child(camera)
	camera.current = true
	_update_cloud_shadows()
	hud = PlaygroundHUD.new()
	hud.production_mode = production_mode
	hud.editor_test = editor_test
	hud.config = handling
	hud.driver = driver
	add_child(hud)
	impact_cracks = ImpactCracksEffect.new()
	add_child(impact_cracks)
	hud.restart_requested.connect(restart)
	hud.pause_requested.connect(toggle_pause)
	hud.profile_requested.connect(select_profile)
	hud.handling_menu_opened.connect(_open_handling_menu)
	hud.handling_menu_closed.connect(_close_handling_menu)
	hud.handling_edited.connect(restart)
	hud.record_requested.connect(toggle_recording)
	hud.track_requested.connect(cycle_track)
	hud.exit_requested.connect(func() -> void: exit_requested.emit())
	hud.edit_here_requested.connect(_edit_here)
	track_debug = TrackDebug.new()
	var debug_layer := CanvasLayer.new()
	debug_layer.layer = 5
	add_child(debug_layer)
	debug_layer.add_child(track_debug)
	countdown_label = Label.new()
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	countdown_label.offset_left = -160
	countdown_label.offset_right = 160
	countdown_label.offset_top = -170
	countdown_label.offset_bottom = -70
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_override("font", RaceHUDStyle.DISPLAY)
	countdown_label.add_theme_color_override("font_color", RaceHUDStyle.GOLD)
	countdown_label.add_theme_font_size_override("font_size",72)
	countdown_label.add_theme_color_override("font_outline_color",Color("172129"))
	countdown_label.add_theme_constant_override("outline_size",12)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_layer.add_child(countdown_label)
	race_cues = preload("res://ui/race_cues.gd").new()
	debug_layer.add_child(race_cues)
	restart()
	print("PLAYGROUND_READY")
	if OS.is_debug_build():
		for argument: String in OS.get_cmdline_user_args():
			if argument == "--demo":
				demo_capture = true
			if argument.begins_with("--capture="):
				capture_path = argument.trim_prefix("--capture=")
		if not capture_path.is_empty() and not demo_capture and capture_tick == 0:
			_capture_frame()


func _physics_process(_delta: float) -> void:
	if sim == null or paused:
		return
	if finish_sim != null:
		_advance_finish()
		return
	if countdown_ticks > 0:
		race_cues.show_start(countdown_ticks, 0)
		countdown_label.text = ""
		countdown_ticks -= 1
		return
	race_cues.show_start(0, sim.state.tick) if production_mode and not editor_test else race_cues.reset()
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	var velocity_before_step: Vector2 = sim.state.velocity
	var collisions_before_step: int = sim.state.collision_count
	frame = driver.sample()
	var profile_start: int = Time.get_ticks_usec() if profile_enabled else 0
	if ai_enabled and native_track != null:
		frame = route_driver.sample(sim.state, native_track, handling)
	if profile_enabled:
		profile_ai_us += Time.get_ticks_usec() - profile_start
		profile_start = Time.get_ticks_usec()
	if demo_capture:
		frame = DriveFrame.sample(0.7 if sim.state.tick > 190 else 0.0, 1.0, 0.0)
	sim.step(frame, yard)
	if sim.state.collision_count > collisions_before_step:
		var resolved_impact: Vector2 = sim.state.velocity - velocity_before_step
		camera.add_collision_impact(resolved_impact)
		impact_cracks.show_impact(resolved_impact)
	var roughness: float = native_track.off_road_rumble(sim.state) if native_track != null else 0.0
	var off_track_rumble: float = smoothstep(3.0, 22.0, sim.state.velocity.length()) * roughness
	camera.set_off_track_rumble(off_track_rumble)
	if profile_enabled:
		profile_sim_us += Time.get_ticks_usec() - profile_start
		profile_start = Time.get_ticks_usec()
	if native_track != null and editor_test:
		_advance_practice_validation(previous_position,sim.state.position,sim.state.route_index)
	if native_track != null and not editor_test:
		track_session.advance(native_track, previous_position, sim.state.position, sim.state.route_index)
		if profile_enabled:
			profile_rules_us += Time.get_ticks_usec() - profile_start
			profile_start = Time.get_ticks_usec()
		if not (profile_enabled and profile_skip_telemetry):
			lap_telemetry.observe_incidents(track_session, native_track, sim.state, handling)
			lap_telemetry.observe(track_session, native_track, sim.state.position, sim.state.velocity.length(), attempt_practice)
		if profile_enabled: profile_telemetry_us += Time.get_ticks_usec() - profile_start
		if production_mode and track_session.finished:
			_begin_finish()
	profile_start = Time.get_ticks_usec() if profile_enabled else 0
	if trails.visible: trails.sample(sim.state, frame, bridge_presentation, native_track)
	if profile_enabled: profile_trails_us += Time.get_ticks_usec() - profile_start
	var particle_start: int = Time.get_ticks_usec() if profile_enabled else 0
	if sand_dust.visible: sand_dust.sample(sim.state, frame, native_track, bridge_presentation)
	if profile_enabled: profile_particles_us += Time.get_ticks_usec() - particle_start
	recorder.append(frame, sim.state)
	if recorder.active and recorder.frames.size() >= HandlingRecorder.LIMIT:
		_save_recording()
	if demo_capture and sim.state.tick == 400:
		demo_capture = false
		paused = true
		_capture_frame()
	if capture_tick > 0 and sim.state.tick == capture_tick and not capture_path.is_empty():
		paused = true
		_capture_frame()


func _begin_finish() -> void:
	race_cues.reset()
	# A separate simulation coasts visually; scored state and telemetry stay at the line.
	finish_sim = VehicleSimulation.new(handling)
	for property: Dictionary in sim.state.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = sim.state.get(property.name)
			finish_sim.state.set(property.name, value.duplicate(true) if value is Array or value is Dictionary else value)
	finish_ticks = 0
	driver.clear()
	hud.touch.enabled = false
	race_cues.show_finish(0.0)
	finish_rating_pending = rating_records != null and not editor_test and not attempt_practice and int(rating_records.settings.get("track_ratings",{}).get(native_track.identity,0)) == 0
	if finish_rating_pending:
		race_cues.prepare_rating(rating_records,native_track.identity,_complete_finish)


func _advance_finish() -> void:
	previous_position = finish_sim.state.position
	previous_heading = finish_sim.state.heading
	# Retain steering briefly, then release it while gently braking through real collisions.
	var steering: float = finish_sim.state.steering * 0.97
	frame = DriveFrame.sample(steering, 0.0, 0.22)
	finish_sim.step(frame, yard)
	trails.sample(finish_sim.state, frame, bridge_presentation, native_track)
	sand_dust.sample(finish_sim.state, frame, native_track, bridge_presentation)
	finish_ticks += 1
	race_cues.show_finish(minf(float(finish_ticks) / FINISH_TICKS,0.75) if finish_rating_pending else float(finish_ticks) / FINISH_TICKS)
	if finish_rating_pending and finish_ticks >= 90: race_cues.show_rating()
	if finish_ticks >= FINISH_TICKS and not finish_rating_pending:
		_complete_finish()


func _complete_finish() -> void:
	if paused: return
	paused = true
	race_cues.reveal_results()
	race_completed.emit()


func _process(delta: float) -> void:
	if sim == null:
		return
	var presented: VehicleSimulation = finish_sim if finish_sim != null else sim
	if music != null and track_session != null:
		music.present(presented.state,track_session,delta,paused or countdown_ticks > 0)
	var profile_start: int = Time.get_ticks_usec() if profile_enabled else 0
	if storm_weather != null and storm_weather.visible: storm_weather.advance(delta,paused)
	if cloud_shadow != null and not paused:
		cloud_elapsed += delta
		(cloud_shadow.material_override as ShaderMaterial).set_shader_parameter("elapsed",cloud_elapsed)
	if profile_enabled: profile_weather_us += Time.get_ticks_usec() - profile_start
	profile_start = Time.get_ticks_usec() if profile_enabled else 0
	var section_start: int = profile_start
	var weight: float = Engine.get_physics_interpolation_fraction() if not paused else 1.0
	var point: Vector2 = previous_position.lerp(presented.state.position, weight)
	var heading: float = lerp_angle(previous_heading, presented.state.heading, weight)
	var water_depth: float = native_track.water_depth(point) if native_track != null else 0.0
	car.present(point, heading, presented.state, frame)
	tire_audio.present(presented.state, delta, paused or countdown_ticks > 0)
	car.rotation.x = 0.0
	if native_track != null:
		var axle: Vector2 = Vector2(sin(heading), cos(heading)) * handling.wheelbase * 0.5
		var front: float = bridge_presentation.height_at(point + axle, presented.state.route_index,1 if presented.state.track_elevated else 0)
		var rear: float = bridge_presentation.height_at(point - axle, presented.state.route_index,1 if presented.state.track_elevated else 0)
		car.position.y = (front + rear) * 0.5
		car.rotation.x = atan2(front - rear, handling.wheelbase)
		car.position.y += presented.state.jump_height if presented.state.jump_height > 0.0 else (0.0 if presented.state.track_elevated else TrackHazards.ramp_height(point,native_track.hazard_objects))
		if presented.state.jump_height > 0.0: car.rotation.x = atan2(presented.state.jump_velocity,maxf(5.0,presented.state.velocity.length()))
		elif not presented.state.track_elevated:
			car.position.y -= water_depth
			car.rotation.x += TrackHazards.ramp_pitch(point,axle.normalized(),native_track.hazard_objects)
	car.rotation.z = 0.0
	car.present_ramp(presented.state,car.position.y,car.rotation.x,native_track != null and presented.state.jump_height == 0.0 and presented.state.roll_ticks == 0 and water_depth == 0.0)
	car.present_suspension(presented.state, car.rotation.x, water_depth == 0.0 and car.ramp_lift <= 0.005)
	if presented.state.jump_height == 0.0:
		car.position.y += presented.state.kerb_offset.x
		car.rotation.x += presented.state.kerb_offset.y
		car.rotation.z = presented.state.kerb_offset.z
	car.present_roll(presented.state, weight)
	ContactShading.present_car(contact_shadow,car,presented.state,point,heading,native_track,bridge_presentation)
	if not contact_lighting_enabled: contact_shadow.hide()
	if profile_enabled:
		profile_car_us += Time.get_ticks_usec() - section_start
		section_start = Time.get_ticks_usec()
	if track_ground is NativeTrackVisual:
		track_ground.update_tyres(presented.state,native_track.tyre_origins)
		track_ground.update_light_props(presented.state)
	if profile_enabled:
		profile_props_us += Time.get_ticks_usec() - section_start
		section_start = Time.get_ticks_usec()
	camera.follow(point, presented.state.velocity, heading, delta)
	if profile_enabled:
		profile_camera_us += Time.get_ticks_usec() - section_start
		section_start = Time.get_ticks_usec()
	hud.set_track(native_track)
	hud.update_values(presented.state, frame, delta, paused, recorder.active)
	track_debug.visible = overview and native_track != null
	if native_track != null:
		track_debug.track = native_track
		track_debug.state = presented.state
		if track_debug.visible: track_debug.queue_redraw()
		var progress_text: String = "FINISH" if track_session.next_checkpoint == track_session.checkpoint_count() else "CP %d/%d" % [track_session.next_checkpoint + 1, track_session.checkpoint_count()]
		var status_text: String = "PAUSED" if paused else ("FINISHED - R retry" if track_session.finished else ("AI practice" if ai_enabled else "practice"))
		if editor_test:
			hud.title.text = "Practice (untimed)"
			hud.message_label.text = "Paused — tap Resume to continue" if paused else ""
		elif production_mode:
			hud.title.text = str(native_track.metadata.get("title", native_track.metadata.get("name", native_track.identity.replace("_"," ").to_upper())))
			hud.show_session(track_session)
			hud.shortcut_penalty_label.text = ""
			hud.shortcut_notice_label.text = "Missed checkpoint"
			hud.shortcut_notice_label.visible = track_session.missed_checkpoint >= 0
			checkpoint_marker.present(track_session,native_track,bridge_presentation)
			hud.message_label.text = "PAUSED  /  Resume to continue" if paused and not track_session.finished else ("Practice run" if attempt_practice else "")
		else:
			hud.message_label.text = "%s | Lap %d/%d | %s | %.2fs | %s | F4 overview F5 track F9 AI" % [native_track.identity, mini(track_session.target_laps, track_session.completed_laps + 1), track_session.target_laps, progress_text, track_session.elapsed_ticks / 120.0, status_text]
	if profile_enabled: profile_present_us += Time.get_ticks_usec() - profile_start
	if profile_enabled: profile_hud_us += Time.get_ticks_usec() - section_start


func restart() -> void:
	recorder.active = false
	driver.clear()
	frame = DriveFrame.new()
	paused = false
	attempt_practice = editor_test
	countdown_ticks = 360 if production_mode and not editor_test else 0
	countdown_label.text = ""
	finish_sim = null
	finish_ticks = 0
	finish_rating_pending = false
	race_cues.reset()
	if countdown_ticks > 0: race_cues.show_start(countdown_ticks, 0)
	sim.reset(yard.spawn, yard.spawn_heading)
	if production_mode and not editor_test and native_track != null:
		# Leave room for the whole car before the stripe; retain starts already farther back.
		var distance_to_line: float = (sim.state.position - native_track.finish_center).dot(native_track.finish_forward)
		sim.state.position -= native_track.finish_forward * maxf(0.0, distance_to_line + 3.0)
	track_session = TrackSession.new()
	if music != null: music.start(native_track)
	practice_validation = TrackSession.new(120,1)
	practice_validation_eligible = true
	checkpoint_marker.previous_gate = -2
	checkpoint_marker.visible = false
	lap_telemetry = LapTelemetry.new()
	lap_telemetry.begin(sim.state.position)
	hud.title.text = "CIRCUIT / 01  ·  " + (native_track.identity.replace("_"," ").to_upper() if native_track != null else "HANDLING YARD")
	if native_track != null:
		sim.state.route_index = native_track.nearest_route(sim.state.position)
		sim.state.track_elevated = native_track.elevated_at(sim.state.position, sim.state.route_index)
		if CreatorBridges.at_any(native_track.creator_bridges,sim.state.position):
			sim.state.track_elevated = CreatorBridges.initial_layer(native_track.creator_bridges,sim.state.position,sim.state.heading)
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	trails.clear()
	camera.follow(sim.state.position, Vector2.ZERO, sim.state.heading, 0.0, true)
	impact_cracks.clear_effect()
	hud.touch.enabled = true
	hud.message_label.text = "" if editor_test else "Brake before the circle. Lift and countersteer. F5: handling test tracks."
	hud.title.text = "Practice (untimed)" if editor_test else hud.title.text


func _advance_practice_validation(from: Vector2, to: Vector2, route_index: int) -> void:
	if ai_enabled or demo_capture: practice_validation_eligible = false
	if not practice_validation_eligible or practice_validation.finished: return
	practice_validation.advance(native_track,from,to,route_index)
	if practice_validation.finished: practice_lap_completed.emit()

func select_profile(index: int) -> void:
	profile_index = clampi(index, 0, PROFILE_PATHS.size() - 1)
	HandlingSelection.index = profile_index
	handling = VehicleCatalog.config(vehicle_id, profile_index)
	sim.config = handling
	hud.show_config(handling)
	restart()


func _open_handling_menu() -> void:
	resume_after_handling = not paused
	if resume_after_handling:
		toggle_pause()


func _close_handling_menu() -> void:
	if resume_after_handling and paused:
		toggle_pause()
	resume_after_handling = false


func toggle_pause() -> void:
	if production_mode and not editor_test and track_session.finished: return
	paused = not paused
	driver.clear()
	frame = DriveFrame.new()
	hud.touch.enabled = not paused
	if recorder.active:
		_save_recording()
	hud.message_label.text = "PAUSED · press Esc or Pause to resume" if paused else "Resumed. Inputs released."


func toggle_recording() -> void:
	if editor_test or not OS.is_debug_build():
		return
	if recorder.active:
		_save_recording()
	else:
		restart()
		recorder.start(sim, yard)


func _save_recording() -> void:
	var error: Error = recorder.save(sim.state)
	hud.message_label.text = "Saved user://handling_capture.json" if error == OK else "Capture failed: " + error_string(error)
	if error == OK:
		print("HANDLING_CAPTURE: " + ProjectSettings.globalize_path("user://handling_capture.json"))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if production_mode and not editor_test and track_session.finished and event.is_action_pressed("restart"):
		retry_requested.emit()
		return
	if event.is_action_pressed("restart"):
		restart()
	elif event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("debug_hud"):
		hud.debug_enabled = not hud.debug_enabled
	elif OS.is_debug_build() and not production_mode and event is InputEventKey:
		match event.physical_keycode:
			KEY_1: select_profile(0)
			KEY_2: select_profile(1)
			KEY_3: select_profile(2)
			KEY_4: select_profile(3)
			KEY_5: select_profile(4)
			KEY_6: select_profile(5)
			KEY_F2: hud.toggle_tuning()
			KEY_F3: toggle_recording()
			KEY_F6: select_profile(profile_index)
			KEY_F4: overview = not overview
			KEY_F7: track_debug.detail = (track_debug.detail + 1) % 3
			KEY_F5: cycle_track()
			KEY_F9:
				ai_enabled = not ai_enabled
				restart()


func _unhandled_input(event: InputEvent) -> void:
	if race_cues != null and race_cues.rating_confirming: return
	if finish_sim == null or paused or finish_ticks < 30: return
	if finish_rating_pending and finish_ticks < 90: return
	var continue_pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if continue_pressed:
		_complete_finish()
		get_viewport().set_input_as_handled()


func _edit_here() -> void:
	if not editor_test:
		return
	driver.clear()
	frame = DriveFrame.new()
	hud.touch.enabled = false
	paused = true
	edit_here_requested.emit(sim.state.position)


func _build_ground(world: Node3D) -> void:
	if _render_viewport != null:
		var theme: String = str(native_track.metadata.get("theme","pine")) if native_track != null else "pine"
		_render_viewport.scaling_3d_scale = render_scale_for(theme,_base_render_scale,OS.has_feature("mobile"))
	if native_track != null:
		var visual := NativeTrackVisual.new()
		bridge_presentation = BridgePresentation.new(native_track)
		world.add_child(visual)
		visual.build(native_track, bridge_presentation)
		track_ground = visual
	else:
		bridge_presentation = null
		var visual := PlaygroundVisual.new()
		world.add_child(visual)
		visual.build(yard)
		track_ground = visual


static func render_scale_for(theme: String, base_scale: float, mobile: bool) -> float:
	# Point-lit night scenes need extra fill-rate headroom; Canvas UI stays native.
	return minf(base_scale,0.55) if mobile and theme == "night_city" else base_scale


func _exit_tree() -> void:
	if is_instance_valid(_render_viewport):
		_render_viewport.scaling_3d_scale = _base_render_scale


func cycle_track() -> void:
	track_index = (track_index + 1) % (TRACK_NAMES.size() + 1)
	track_ground.queue_free()
	native_track = NativeTrack.read("res://resources/tracks/" + TRACK_NAMES[track_index] + ".json") if track_index < TRACK_NAMES.size() else null
	yard = native_track if native_track != null else PlaygroundData.new()
	_build_ground($World)
	_update_weather()
	restart()


func _notification(what: int) -> void:
	if sim != null and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if not paused:
			toggle_pause()


func _capture_frame() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Screenshot capture needs a graphical display.")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var error: Error = screenshot.save_png(capture_path)
	if error != OK:
		push_error("Screenshot save failed: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("CAPTURE_SAVED: " + capture_path)
	get_tree().quit()


func _update_weather() -> void:
	_update_cloud_shadows()
	if weather_layer != null:
		remove_child(weather_layer)
		weather_layer.queue_free()
		weather_layer = null
		storm_weather = null
	TrackTheme.apply_lighting(str(native_track.metadata.get("theme","pine")) if native_track != null else "pine",biome_environment,biome_light)
	if native_track == null or native_track.metadata.get("theme","pine") != "storm": return
	weather_layer = CanvasLayer.new()
	weather_layer.layer = 0
	add_child(weather_layer)
	storm_weather = StormWeather.new()
	storm_weather.name = "StormWeather"
	storm_weather.light = biome_light
	weather_layer.add_child(storm_weather)


func _update_cloud_shadows() -> void:
	if camera == null: return
	var grass: bool = native_track != null and str(native_track.metadata.get("theme","pine")) == "pine"
	if grass and cloud_shadow == null:
		cloud_elapsed = 0.0
		cloud_shadow = ContactShading.cloud_shadow(camera)
	elif not grass and cloud_shadow != null:
		cloud_shadow.get_parent().remove_child(cloud_shadow)
		cloud_shadow.queue_free()
		cloud_shadow = null


func set_contact_lighting_enabled(enabled: bool) -> void:
	# Diagnostic comparison only; normal races always enable the visual kit.
	contact_lighting_enabled = enabled
	for effect: Node3D in get_tree().get_nodes_in_group("contact_lighting"):
		if is_ancestor_of(effect): effect.visible = enabled

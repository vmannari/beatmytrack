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
var night_ambience: NightAmbience
var grass_birds: GrassBirds
var grass_nature: GrassNature
var desert_ambience: DesertAmbience
var desert_rattlesnake: DesertRattlesnake
var winter_wind: WinterWind
var winter_snow_wind: WinterSnowWind
var weather_layer: CanvasLayer
var mobile_world_aa: CanvasLayer
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
var cloud_rating: Node
var preference_records: LocalRecords
var online_frames: Array = []
var online_rewinds: Array = []
var race_proof = preload("res://backend/race_proof.gd").new()
var resume_client: Node
var resume_ticket_id: String = ""
var resume_credits: Node
var rewind_history := RewindHistory.new()
var rewind_panel: CanvasLayer
var rewind_origin: Dictionary = {}
var rewind_choices: Array[Dictionary] = []
var rewind_selected: int = 0
var rewind_was_paused: bool = false
var rewind_return := RewindReturn.new()
var rewind_ghosts: Node3D
var personal_ghost: PersonalGhost
var ghost_mode: String = "lap"
var ghost_run := PersonalGhostRun.new()
var ghost_store: LocalGhosts
var ghost_bests: Dictionary = {}
var music_personal_ghosts: Dictionary = {}
var finish_rating_pending: bool = false
const FINISH_TICKS: int = 216

const PROFILE_PATHS: Array[String] = HandlingSelection.PROFILE_PATHS
var profile_index: int = HandlingSelection.ORIGINAL_PLUS_INDEX
var resume_after_handling: bool = false
var vehicle_id: String = VehicleCatalog.selected
var handling: HandlingConfig
var sim: VehicleSimulation
var yard := PlaygroundData.new()
var driver := DriverInput.new()
var launch_early: bool = false
var launch_countdown_seen: bool = false
var frame := DriveFrame.new()
var recorder := HandlingRecorder.new()
var car: CarVisual
var car_weathering := VehicleWeathering.new()
var condition_save_elapsed: float = 0.0
var contact_shadow: MeshInstance3D
var cloud_shadow: MeshInstance3D
var cloud_elapsed: float = 0.0
var contact_lighting_enabled: bool = true
var camera: FollowCamera
var impact_cracks: Control
var trails: SkidTrails
var sand_dust: SandDustEffect
var vehicle_audio: VehicleAudio
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
var profile_audio_us: int = 0
var profile_contact_us: int = 0
var profile_music_us: int = 0
var profile_water_us: int = 0
var profile_history_us: int = 0
var profile_condition_us: int = 0
var profile_weathering_us: int = 0
var profile_physics_total_us: int = 0
var profile_process_total_us: int = 0
var condition_save_count: int = 0
var hitch_diagnostics_enabled: bool = true
var hitch_diagnostics: Node
var profile_skip_telemetry: bool = false
var _render_viewport: Viewport
var _base_msaa: Viewport.MSAA = Viewport.MSAA_DISABLED
var _base_render_scale: float = 1.0
var _presentation_has_water: bool = false
const MOBILE_WORLD_PIXEL_BUDGET: float = 1500000.0


func _ready() -> void:
	_render_viewport = get_viewport()
	_base_msaa = _render_viewport.msaa_3d
	if preload("res://track/mobile_world_aa.gd").required(OS.has_feature("mobile"),RenderingServer.get_current_rendering_method(),RenderingServer.get_video_adapter_name()):
		# Adreno's implicit MSAA depth copy loses opaque surfaces and corrupts
		# soft particles/contact shadows. Preserve AA after the world instead.
		_render_viewport.msaa_3d = Viewport.MSAA_DISABLED
		mobile_world_aa = preload("res://track/mobile_world_aa.gd").new()
		add_child(mobile_world_aa)
	_base_render_scale = _render_viewport.scaling_3d_scale
	_render_viewport.size_changed.connect(_refresh_render_scale)
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
	car.simple_model = preference_records != null and bool(preference_records.settings.get("simple_car_models",false))
	if preference_records != null:
		car.livery = VehicleLivery.for_car(preference_records.settings, vehicle_id)
		car.customisation = VehicleCustomisation.for_car(preference_records.settings, vehicle_id)
	world.add_child(car)
	if production_mode and not editor_test and native_track != null and preference_records != null:
		personal_ghost = PersonalGhost.new()
		world.add_child(personal_ghost)
		personal_ghost.configure(car)
	contact_shadow = ContactShading.car_shadow(world)
	car.set_night_headlights(native_track != null and native_track.metadata.get("theme","pine") == "night_city")
	car_weathering.configure(car, str(native_track.metadata.get("theme", "pine")) if native_track != null else "pine", handling)
	car_weathering.restore(VehicleCondition.read(preference_records, vehicle_id))
	trails = SkidTrails.new()
	trails.wheelbase = handling.wheelbase
	trails.track_width = handling.track_width
	world.add_child(trails)
	sand_dust = SandDustEffect.new()
	sand_dust.wheelbase = handling.wheelbase
	sand_dust.track_width = handling.track_width
	sand_dust.collision_radius = handling.collision_radius
	world.add_child(sand_dust)
	if native_track != null and native_track.metadata.get("theme", "pine") == "winter":
		sand_dust.configure_snow_surface(track_ground)
	vehicle_audio = VehicleAudio.new()
	add_child(vehicle_audio)
	vehicle_audio.configure(vehicle_id,handling,car)
	camera = FollowCamera.new()
	if preference_records != null:
		camera.set_mode(str(preference_records.settings.get("camera_mode", "overhead")))
		camera.speed_zoom_enabled = bool(preference_records.settings.get("camera_speed_zoom", true))
		camera.speed_zoom_strength = float(preference_records.settings.get("camera_speed_zoom_strength", CameraProfile.DEFAULT_SPEED_ZOOM_STRENGTH))
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
	hud.restart_requested.connect(func() -> void:
		if production_mode and not editor_test: retry_requested.emit()
		else: restart())
	hud.rewind_requested.connect(open_rewind)
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
	countdown_label.add_theme_color_override("font_color", RaceHUDStyle.TEXT)
	countdown_label.add_theme_font_size_override("font_size",26)
	countdown_label.add_theme_color_override("font_outline_color",Color("172129"))
	countdown_label.add_theme_constant_override("outline_size",0)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var launch_notice: Control = preload("res://ui/launch_notice.gd").new()
	debug_layer.add_child(launch_notice)
	launch_notice.add_child(countdown_label)
	launch_notice.label = countdown_label
	race_cues = preload("res://ui/race_cues.gd").new()
	debug_layer.add_child(race_cues)
	resume_credits = preload("res://platform/resume_credits.gd").new()
	resume_credits.client = resume_client
	resume_credits.show_ads = OS.is_debug_build() and preference_records != null and bool(preference_records.settings.get("development_show_ads", false))
	add_child(resume_credits)
	restart()
	if hitch_diagnostics_enabled:
		hitch_diagnostics = preload("res://diagnostics/race_hitch_monitor.gd").new()
		hitch_diagnostics.game = self
		add_child(hitch_diagnostics)
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
	var started: int = Time.get_ticks_usec() if profile_enabled else 0
	_advance_physics(_delta)
	if profile_enabled: profile_physics_total_us += Time.get_ticks_usec() - started

func _advance_physics(_delta: float) -> void:
	if sim == null or paused:
		return
	if finish_sim != null:
		_advance_finish()
		return
	if countdown_ticks > 0:
		frame = driver.sample()
		launch_countdown_seen = true
		launch_early = launch_early or frame.throttle > 0
		race_cues.show_start(countdown_ticks, 0)
		countdown_label.text = ""
		countdown_ticks -= 1
		if countdown_ticks == 0: race_cues.show_start(0, 0)
		return
	if not rewind_return.step_due(): return
	race_cues.show_start(0, sim.state.tick) if production_mode and not editor_test else race_cues.reset()
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	var layer_before_step: int = int(sim.state.track_elevated)
	frame = driver.sample()
	var profile_start: int = Time.get_ticks_usec() if profile_enabled else 0
	if ai_enabled and native_track != null:
		frame = route_driver.sample(sim.state, native_track, handling)
	if profile_enabled:
		profile_ai_us += Time.get_ticks_usec() - profile_start
		profile_start = Time.get_ticks_usec()
	if demo_capture:
		frame = DriveFrame.sample(0.7 if sim.state.tick > 190 else 0.0, 1.0, 0.0)
	if online_frames.is_empty() and sim.state.tick == 0 and launch_countdown_seen and production_mode and not editor_test:
		frame.launch_start = 2 if launch_early else 1
		LaunchStart.initialize(sim.state,frame.launch_start)
		if not rewind_history.entries.is_empty() and int(rewind_history.entries[0].tick) == 0:
			rewind_history.entries[0].state = RewindHistory.properties(sim.state)
	if production_mode and (not editor_test or not practice_validation.finished) and online_frames.size() < 216000: online_frames.append(frame.packed())
	vehicle_audio.begin_physics_feedback()
	var incoming_contact_velocity: Vector2 = sim.state.velocity
	sim.step(frame, yard)
	var contact_start: int = Time.get_ticks_usec() if profile_enabled else 0
	vehicle_audio.resolved_contact(sim.state,native_track,incoming_contact_velocity,previous_position,previous_heading)
	if profile_enabled: profile_contact_us += Time.get_ticks_usec() - contact_start
	if production_mode and not editor_test and sim.state.tick < 180:
		countdown_label.text = sim.state.launch_result.to_upper()
		countdown_label.modulate.a = 1.0 - smoothstep(120.0,180.0,float(sim.state.tick))
	elif not countdown_label.text.is_empty(): countdown_label.text = ""
	if sim.state.collision_impulse != Vector2.ZERO:
		var resolved_impact: Vector2 = sim.state.collision_impulse
		camera.add_collision_impact(resolved_impact)
		car.add_collision_impact(sim.state,resolved_impact)
		impact_cracks.show_impact(resolved_impact)
		GameSoundtrack.instance().notify_collision(self,resolved_impact.length())
	if sim.state.scrape_strength > 0.0:
		car.add_scrape(sim.state)
		vehicle_audio.scrape(sim.state.scrape_strength,sim.state.scrape_speed)
	var roughness: float = native_track.off_road_rumble(sim.state) if native_track != null else 0.0
	var off_track_rumble: float = smoothstep(3.0, 22.0, sim.state.velocity.length()) * roughness
	camera.set_off_track_rumble(off_track_rumble)
	if profile_enabled:
		profile_sim_us += Time.get_ticks_usec() - profile_start
		profile_start = Time.get_ticks_usec()
	if native_track != null and editor_test:
		_advance_practice_validation(previous_position,sim.state.position,sim.state.route_index,layer_before_step)
	if native_track != null and not editor_test:
		track_session.advance(native_track, previous_position, sim.state.position, sim.state.route_index,sim.state.track_elevated,layer_before_step)
		if production_mode: race_proof.capture(sim.state,track_session)
		if profile_enabled:
			profile_rules_us += Time.get_ticks_usec() - profile_start
			profile_start = Time.get_ticks_usec()
		if not (profile_enabled and profile_skip_telemetry):
			lap_telemetry.observe_incidents(track_session, native_track, sim.state, handling)
			lap_telemetry.observe(track_session, native_track, sim.state.position, sim.state.velocity.length(), attempt_practice)
		if profile_enabled: profile_telemetry_us += Time.get_ticks_usec() - profile_start
		var history_start: int = Time.get_ticks_usec() if profile_enabled else 0
		if production_mode: rewind_history.capture(sim.state,track_session,false,lap_telemetry,impact_cracks.side_damage)
		if ghost_store != null: ghost_run.capture(sim.state,track_session,native_track,bridge_presentation,handling)
		if profile_enabled: profile_history_us += Time.get_ticks_usec() - history_start
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
	car_weathering.present(sim.state, native_track, false)
	_save_condition()
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
	if is_instance_valid(cloud_rating) and not editor_test and not attempt_practice:
		finish_rating_pending = cloud_rating.should_prompt()
	if finish_rating_pending:
		race_cues.prepare_rating(rating_records,native_track.identity,_complete_finish,cloud_rating)


func _advance_finish() -> void:
	# A late prefetch may still offer its unrated track during the short coast.
	if not finish_rating_pending and is_instance_valid(cloud_rating) and not editor_test and not attempt_practice and cloud_rating.should_prompt():
		finish_rating_pending = true
		race_cues.prepare_rating(rating_records,native_track.identity,_complete_finish,cloud_rating)
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
	_save_condition()
	paused = true
	if is_instance_valid(cloud_rating): cloud_rating.abandon()
	race_cues.reveal_results()
	race_completed.emit()


func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec() if profile_enabled else 0
	_present_frame(delta)
	if profile_enabled: profile_process_total_us += Time.get_ticks_usec() - started

func _present_frame(delta: float) -> void:
	if sim == null:
		return
	var presented: VehicleSimulation = finish_sim if finish_sim != null else sim
	var profile_start: int = Time.get_ticks_usec() if profile_enabled else 0
	if storm_weather != null and storm_weather.visible: storm_weather.advance(delta,paused,finish_sim != null)
	if night_ambience != null: night_ambience.present(delta,paused,finish_sim != null)
	if grass_birds != null: grass_birds.present(delta,paused,finish_sim != null)
	if grass_nature != null: grass_nature.present(delta,paused,finish_sim != null)
	if desert_ambience != null: desert_ambience.present(delta,paused,finish_sim != null)
	if desert_rattlesnake != null: desert_rattlesnake.present(delta,paused,finish_sim != null)
	if winter_wind != null: winter_wind.present(delta,paused,finish_sim != null)
	if sand_dust != null: sand_dust.set_water_paused(paused)
	if cloud_shadow != null and not paused:
		cloud_elapsed += delta
		(cloud_shadow.material_override as ShaderMaterial).set_shader_parameter("elapsed",cloud_elapsed)
	if profile_enabled: profile_weather_us += Time.get_ticks_usec() - profile_start
	profile_start = Time.get_ticks_usec() if profile_enabled else 0
	var section_start: int = profile_start
	var weight: float = Engine.get_physics_interpolation_fraction() if not paused else 1.0
	if not paused and finish_sim == null: weight = rewind_return.interpolation(weight)
	var point: Vector2 = previous_position.lerp(presented.state.position, weight)
	if winter_snow_wind != null: winter_snow_wind.present(delta, point, winter_wind.strength, paused, finish_sim != null)
	var heading: float = lerp_angle(previous_heading, presented.state.heading, weight)
	_present_personal_ghost(weight)
	var water_start: int = Time.get_ticks_usec() if profile_enabled else 0
	var water_depth: float = _presentation_water_depth(point)
	if profile_enabled: profile_water_us += Time.get_ticks_usec() - water_start
	car.present(point, heading, presented.state, frame)
	var weathering_start: int = Time.get_ticks_usec() if profile_enabled else 0
	car_weathering.present(presented.state, native_track, paused or countdown_ticks > 0 or finish_sim != null)
	if finish_sim != null and not paused: car_weathering.melt(delta)
	if profile_enabled: profile_weathering_us += Time.get_ticks_usec() - weathering_start
	condition_save_elapsed += delta
	if condition_save_elapsed >= 5.0:
		_save_condition()
	car.set_headlight_bridge_occlusion(not presented.state.track_elevated)
	var audio_start: int = Time.get_ticks_usec() if profile_enabled else 0
	vehicle_audio.present(presented.state,frame,native_track,delta,paused,countdown_ticks>0)
	if profile_enabled: profile_audio_us += Time.get_ticks_usec() - audio_start
	var music_start: int = Time.get_ticks_usec() if profile_enabled else 0
	GameSoundtrack.instance().present_race(self,sim.state,native_track,handling,track_session,paused,countdown_ticks>0,finish_sim!=null,{"personal":music_personal_ghosts,"rival":ghost_bests.get("race",{}) if bool(get_meta("soundtrack_rivalry",false)) else {}})
	if profile_enabled: profile_music_us += Time.get_ticks_usec() - music_start
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
	var body_rumble: float = 0.0
	if native_track != null:
		body_rumble = native_track.off_road_rumble(presented.state) * smoothstep(3.0,22.0,presented.state.velocity.length())
	var kerb_contacts: Vector4 = native_track.kerb_heights(presented.state,handling) if native_track != null else Vector4.ZERO
	var bump_track: bool = native_track != null and not native_track.speed_bump_objects.is_empty()
	var bump_contacts: Vector4 = SpeedBumps.contacts(point,heading,handling,native_track.speed_bump_objects) if bump_track and not presented.state.track_elevated and presented.state.jump_height == 0.0 and presented.state.roll_ticks == 0 else Vector4.ZERO
	var bump_pose := Vector3((bump_contacts.x+bump_contacts.y+bump_contacts.z+bump_contacts.w)*0.25,
		atan2((bump_contacts.x+bump_contacts.y-bump_contacts.z-bump_contacts.w)*0.5,handling.wheelbase),
		atan2((bump_contacts.y+bump_contacts.w-bump_contacts.x-bump_contacts.z)*0.5,handling.track_width))
	car.present_suspension(presented.state, car.rotation.x, water_depth == 0.0 and car.ramp_lift <= 0.005, body_rumble, kerb_contacts,bump_contacts,bump_track,bump_pose)
	car.position.y += bump_pose.x
	car.rotation.x += bump_pose.y
	car.rotation.z += bump_pose.z
	if presented.state.jump_height == 0.0:
		car.position.y += presented.state.kerb_offset.x
		car.rotation.x += presented.state.kerb_offset.y
		car.rotation.z += presented.state.kerb_offset.z
	car.present_roll(presented.state, weight)
	ContactShading.present_car(contact_shadow,car,presented.state,point,heading,native_track,bridge_presentation)
	if not contact_lighting_enabled: contact_shadow.hide()
	if profile_enabled:
		profile_car_us += Time.get_ticks_usec() - section_start
		section_start = Time.get_ticks_usec()
	if native_track != null:
		track_ground.update_tyres(presented.state,native_track.tyre_origins)
		track_ground.update_light_props(presented.state)
	if profile_enabled:
		profile_props_us += Time.get_ticks_usec() - section_start
		section_start = Time.get_ticks_usec()
	camera.follow(point, presented.state.velocity, heading, rewind_return.visual_delta(delta) if not paused else delta)
	if profile_enabled:
		profile_camera_us += Time.get_ticks_usec() - section_start
		section_start = Time.get_ticks_usec()
	if hud.rewind_button != null:
		hud.rewind_button.disabled = countdown_ticks > 0 or finish_sim != null or sim.state.tick < RewindHistory.STRIDE or online_rewinds.size() >= 3 or rewind_return.remaining > 0
		hud.rewind_button.race_remaining = maxi(0,3-online_rewinds.size())
		hud.rewind_button.queue_redraw()
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
			checkpoint_marker.present(track_session,native_track,bridge_presentation)
			hud.checkpoint_notice.present(checkpoint_marker,camera,camera.unproject_position(car.global_position))
			hud.message_label.text = "PAUSED  /  Resume to continue" if paused and not track_session.finished else ("Practice run" if attempt_practice else "")
		else:
			hud.message_label.text = "%s | Lap %d/%d | %s | %.2fs | %s | F4 overview F5 track F9 AI" % [native_track.identity, mini(track_session.target_laps, track_session.completed_laps + 1), track_session.target_laps, progress_text, track_session.elapsed_ticks / 120.0, status_text]
	if profile_enabled: profile_present_us += Time.get_ticks_usec() - profile_start
	if profile_enabled: profile_hud_us += Time.get_ticks_usec() - section_start


func restart() -> void:
	if is_instance_valid(rewind_panel): return
	online_frames.clear()
	launch_early = false
	launch_countdown_seen = false
	countdown_label.modulate.a = 1.0
	online_rewinds.clear()
	rewind_return.reset()
	rewind_history = RewindHistory.new()
	if resume_credits != null: resume_credits.begin(resume_ticket_id)
	recorder.active = false
	driver.clear()
	frame = DriveFrame.new()
	paused = false
	if hud != null and hud.pause_menu != null: hud.pause_menu.hide()
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
	if vehicle_audio != null: vehicle_audio.reset()
	_save_condition()
	car_weathering.last_tick = -1
	if grass_birds != null: grass_birds.reset()
	if grass_nature != null: grass_nature.reset()
	if desert_ambience != null: desert_ambience.reset()
	if desert_rattlesnake != null: desert_rattlesnake.reset()
	if winter_wind != null: winter_wind.reset()
	if winter_snow_wind != null: winter_snow_wind.reset()
	if preference_records != null: GameSoundtrack.instance().apply_settings(preference_records.settings)
	GameSoundtrack.instance().begin_race(self,str(native_track.metadata.get("theme","pine")) if native_track != null else "pine",sim.state)
	practice_validation = TrackSession.new(120,1)
	practice_validation_eligible = true
	checkpoint_marker.previous_gate = -2
	checkpoint_marker.visible = false
	hud.checkpoint_notice.clear()
	lap_telemetry = LapTelemetry.new()
	lap_telemetry.begin(sim.state.position)
	hud.title.text = "CIRCUIT / 01  ·  " + (native_track.identity.replace("_"," ").to_upper() if native_track != null else "HANDLING YARD")
	if native_track != null:
		sim.state.route_index = native_track.nearest_route(sim.state.position)
		sim.state.track_elevated = native_track.elevated_at(sim.state.position, sim.state.route_index)
		if CreatorBridges.at_any(native_track.creator_bridges,sim.state.position):
			sim.state.track_elevated = CreatorBridges.initial_layer(native_track.creator_bridges,sim.state.position,sim.state.heading)
	if production_mode and not editor_test and native_track != null:
		track_session._configure(native_track)
		rewind_history.capture(sim.state,track_session,true,lap_telemetry)
	ghost_run = PersonalGhostRun.new()
	race_proof = preload("res://backend/race_proof.gd").new()
	if production_mode and native_track != null: race_proof.capture(sim.state,practice_validation if editor_test else track_session,true)
	ghost_store = null
	ghost_bests = {}
	music_personal_ghosts = {}
	if personal_ghost != null and preference_records != null:
		ghost_mode = str(preference_records.settings.get("ghost_mode", "lap"))
		ghost_store = LocalGhosts.new(preference_records.path)
		var ghost_key: String = preference_records.key_for(native_track,handling)
		ghost_bests = ghost_store.load_best(ghost_key,preference_records.records.get(ghost_key,{}))
		music_personal_ghosts = ghost_bests.duplicate()
		ghost_run.capture(sim.state,track_session,native_track,bridge_presentation,handling,true)
		personal_ghost.hide()
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	trails.clear()
	camera.follow(sim.state.position, Vector2.ZERO, sim.state.heading, 0.0, true)
	impact_cracks.clear_effect()
	hud.touch.enabled = true
	hud.message_label.text = "" if editor_test else "Brake before the circle. Lift and countersteer. F5: handling test tracks."
	sand_dust.clear()
	hud.title.text = "Practice (untimed)" if editor_test else hud.title.text
	_refresh_resume_hud()


func _advance_practice_validation(from: Vector2, to: Vector2, route_index: int, previous_layer: int = -1) -> void:
	if ai_enabled or demo_capture: practice_validation_eligible = false
	if not practice_validation_eligible or practice_validation.finished: return
	practice_validation.advance(native_track,from,to,route_index,sim.state.track_elevated,previous_layer)
	race_proof.capture(sim.state,practice_validation)
	if practice_validation.finished: practice_lap_completed.emit()

func select_profile(index: int) -> void:
	if production_mode:
		return
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
	if is_instance_valid(rewind_panel): return
	if production_mode and not editor_test and track_session.finished: return
	if not paused: hud.pause_menu.capture_race()
	paused = not paused
	if sand_dust != null: sand_dust.set_water_paused(paused)
	hud.pause_menu.visible = paused
	if paused: hud.pause_menu.show_main()
	driver.clear()
	frame = DriveFrame.new()
	hud.touch.enabled = not paused
	if recorder.active:
		_save_recording()
	hud.message_label.text = "PAUSED · press Esc or Resume to continue" if paused else "Resumed. Inputs released."


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
	if is_instance_valid(rewind_panel):
		if event.is_action_pressed("pause"): cancel_rewind()
		return
	if event is InputEventKey and event.physical_keycode == KEY_C:
		var next: int = (CameraProfile.MODES.find(camera.mode) + 1) % CameraProfile.MODES.size()
		set_camera_mode(CameraProfile.MODES[next])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode == KEY_BACKSPACE:
		open_rewind()
		return
	if event.is_action_pressed("restart"):
		if production_mode and not editor_test: retry_requested.emit()
		else: restart()
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


func set_ghost_mode(value: String) -> Error:
	if value not in PersonalGhostRun.MODES: return ERR_INVALID_PARAMETER
	ghost_mode = value
	if preference_records == null: return OK
	preference_records.settings.ghost_mode = value
	return preference_records.save_records()


func ghost_description() -> String:
	var index: int = PersonalGhostRun.MODES.find(ghost_mode)
	var description: String = PersonalGhostRun.DESCRIPTIONS[index]
	if ghost_mode != "off" and not ghost_bests.has(ghost_mode):
		description += " No recording yet. Match or improve your best in a completed race."
	return description


func _present_personal_ghost(weight: float) -> void:
	if personal_ghost == null: return
	if countdown_ticks > 0 or finish_sim != null or is_instance_valid(rewind_panel) or ghost_mode == "off":
		personal_ghost.hide()
		return
	var tick: float = float(track_session.elapsed_ticks)
	if not paused: tick = maxf(0.0,tick - 1.0 + weight)
	if ghost_mode == "lap":
		# Boundary ticks reset exactly at the player's accepted finish crossing.
		tick = maxf(0.0,tick - track_session.lap_start_time * VehicleSimulation.TICK_RATE)
	personal_ghost.present(PersonalGhostRun.sample(ghost_bests.get(ghost_mode,{}),tick))


func save_personal_ghost() -> Error:
	if ghost_store == null or not track_session.finished or attempt_practice or editor_test: return OK
	var key: String = preference_records.key_for(native_track,handling)
	return ghost_store.save_run(key,preference_records.records.get(key,{}),ghost_run)


func set_camera_mode(value: String) -> Error:
	camera.set_mode(value)
	var presented: VehicleSimulation = finish_sim if finish_sim != null else sim
	camera.follow(presented.state.position, presented.state.velocity, presented.state.heading, 0.0, true)
	if preference_records == null: return OK
	preference_records.settings.camera_mode = camera.mode
	return preference_records.save_records()


func set_camera_speed_zoom(enabled: bool) -> Error:
	camera.speed_zoom_enabled = enabled
	if preference_records == null: return OK
	preference_records.settings.camera_speed_zoom = enabled
	return preference_records.save_records()


func set_camera_speed_zoom_strength(value: float, save_preference: bool = true) -> Error:
	camera.speed_zoom_strength = value
	if preference_records == null or not save_preference: return OK
	preference_records.settings.camera_speed_zoom_strength = camera.speed_zoom_strength
	return preference_records.save_records()


func _unhandled_input(event: InputEvent) -> void:
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
	_presentation_has_water = native_track != null and (native_track.cells.has(3) or native_track.cells.has(6))
	_refresh_render_scale()
	if native_track != null:
		var visual := NativeTrackVisual.new()
		visual.cache_race_world = production_mode and not editor_test
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


func _refresh_render_scale() -> void:
	if not is_instance_valid(_render_viewport): return
	var theme: String = str(native_track.metadata.get("theme","pine")) if native_track != null else "pine"
	var pixels: Vector2i = _render_viewport.get_window().size
	var scale: float = render_scale_for(theme,_base_render_scale,OS.has_feature("mobile"),pixels)
	if not is_equal_approx(_render_viewport.scaling_3d_scale,scale): _render_viewport.scaling_3d_scale = scale


func _presentation_water_depth(point: Vector2) -> float:
	return native_track.water_depth(point) if native_track != null and _presentation_has_water else 0.0


static func render_scale_for(theme: String, base_scale: float, mobile: bool, pixels: Vector2i = Vector2i.ZERO) -> float:
	# Point-lit night scenes need extra fill-rate headroom; Canvas UI stays native.
	var scale: float = minf(base_scale,0.55) if mobile and theme == "night_city" else base_scale
	# A percentage alone lets large tablets render several times the phone budget.
	# Bound only the 3D buffer; neither projection nor the native Canvas is resized.
	if mobile and pixels.x > 0 and pixels.y > 0:
		scale = minf(scale,sqrt(MOBILE_WORLD_PIXEL_BUDGET/(float(pixels.x)*float(pixels.y))))
	return scale


func _save_condition() -> void:
	var started: int = Time.get_ticks_usec() if profile_enabled else 0
	condition_save_elapsed = 0.0
	if preference_records != null and car != null:
		condition_save_count += 1
		var error: Error = VehicleCondition.save(preference_records, vehicle_id, car_weathering.snapshot())
		if error != OK: push_warning("Local car condition save failed: " + error_string(error))
	if profile_enabled: profile_condition_us += Time.get_ticks_usec() - started

func _exit_tree() -> void:
	_save_condition()
	if is_instance_valid(cloud_rating): cloud_rating.abandon()
	GameSoundtrack.instance().leave_race(self)
	if is_instance_valid(_render_viewport):
		if _render_viewport.size_changed.is_connected(_refresh_render_scale): _render_viewport.size_changed.disconnect(_refresh_render_scale)
		_render_viewport.msaa_3d = _base_msaa
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
		_save_condition()
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
	var weather_theme: String = str(native_track.metadata.get("theme","pine")) if native_track != null else "pine"
	if car != null and car_weathering.theme != weather_theme:
		car_weathering.configure(car, weather_theme, handling)
	if night_ambience == null:
		night_ambience = NightAmbience.new()
		add_child(night_ambience)
	night_ambience.configure(weather_theme)
	if grass_birds == null:
		grass_birds = GrassBirds.new()
		add_child(grass_birds)
	grass_birds.configure(weather_theme)
	if grass_nature == null:
		grass_nature = GrassNature.new()
		add_child(grass_nature)
	grass_nature.configure(weather_theme)
	if desert_ambience == null:
		desert_ambience = DesertAmbience.new()
		add_child(desert_ambience)
	desert_ambience.configure(weather_theme)
	if desert_rattlesnake == null:
		desert_rattlesnake = DesertRattlesnake.new()
		add_child(desert_rattlesnake)
	desert_rattlesnake.configure(weather_theme)
	if winter_wind == null:
		winter_wind = WinterWind.new()
		add_child(winter_wind)
	winter_wind.configure(weather_theme)
	if winter_snow_wind != null:
		winter_snow_wind.get_parent().remove_child(winter_snow_wind)
		winter_snow_wind.queue_free()
		winter_snow_wind = null
	if weather_theme == "winter":
		winter_snow_wind = WinterSnowWind.new()
		$World.add_child(winter_snow_wind)
		winter_snow_wind.configure(native_track, track_ground)
		if sand_dust != null: sand_dust.configure_snow_surface(track_ground)
	if weather_theme not in ["storm", "winter"]: return
	weather_layer = CanvasLayer.new()
	weather_layer.layer = 0
	add_child(weather_layer)
	if weather_theme == "winter":
		weather_layer.add_child(preload("res://camera/winter_frost.gd").new())
		return
	storm_weather = StormWeather.new()
	storm_weather.name = "StormWeather"
	storm_weather.light = biome_light
	weather_layer.add_child(storm_weather)


func _update_cloud_shadows() -> void:
	if camera == null: return
	var theme: String = str(native_track.metadata.get("theme","pine")) if native_track != null else ""
	var sunlit: bool = theme in ["pine", "desert"]
	if sunlit and cloud_shadow == null:
		cloud_elapsed = 0.0
		cloud_shadow = ContactShading.cloud_shadow(camera)
	if sunlit:
		# Desert shares the warm sun veil, with clear skies rather than grass clouds.
		(cloud_shadow.material_override as ShaderMaterial).set_shader_parameter("cloud_coverage", 0.0 if theme == "desert" else 1.0)
	elif cloud_shadow != null:
		cloud_shadow.get_parent().remove_child(cloud_shadow)
		cloud_shadow.queue_free()
		cloud_shadow = null


func set_contact_lighting_enabled(enabled: bool) -> void:
	# Diagnostic comparison only; normal races always enable the visual kit.
	contact_lighting_enabled = enabled
	for effect: Node3D in get_tree().get_nodes_in_group("contact_lighting"):
		if is_ancestor_of(effect): effect.visible = enabled


func open_rewind() -> void:
	if hud != null and hud.pause_menu.visible: return
	if not production_mode or editor_test or is_instance_valid(rewind_panel) or countdown_ticks > 0 or finish_sim != null or track_session.finished or online_rewinds.size() >= 3 or rewind_return.remaining > 0: return
	rewind_choices = rewind_history.choices(sim.state.tick)
	if rewind_choices.is_empty(): return
	rewind_was_paused = paused
	paused = true
	driver.clear()
	frame = DriveFrame.new()
	hud.touch.enabled = false
	hud.hide()
	trails.hide()
	sand_dust.hide()
	rewind_origin = {"state":RewindHistory.properties(sim.state),"session":RewindHistory.properties(track_session,true),"glass_damage":impact_cracks.side_damage}
	rewind_panel = preload("res://ui/rewind_panel.gd").new()
	add_child(rewind_panel)
	rewind_panel.selected.connect(preview_rewind)
	rewind_panel.cancelled.connect(cancel_rewind)
	rewind_panel.confirmed.connect(confirm_rewind)
	rewind_panel.configure(rewind_choices,sim.state.tick,camera,native_track)
	rewind_ghosts = preload("res://vehicle/rewind_ghosts.gd").new()
	add_child(rewind_ghosts)
	var markers: Array[Dictionary] = rewind_choices.duplicate()
	markers.append({"tick":sim.state.tick,"state":rewind_origin.state})
	rewind_ghosts.configure(car,native_track,bridge_presentation,markers,sim.state.tick)
	rewind_selected = rewind_choices.size()
	rewind_panel.select_index(rewind_selected)
	preview_rewind(rewind_selected)
	var panel: CanvasLayer = rewind_panel
	var result: Dictionary = await resume_credits.refresh()
	if not is_instance_valid(panel) or panel != rewind_panel: return
	if result.ok: panel.show_balance(result.data,online_rewinds.size())
	else:
		panel.status.text = "Could not check resumes: "+str(result.get("error","Connection unavailable"))+". Cancel and retry."

func preview_rewind(index: int) -> void:
	if not is_instance_valid(rewind_panel) or resume_credits.busy: return
	rewind_selected = clampi(index,0,rewind_choices.size())
	rewind_panel.select_index(rewind_selected)
	var live: bool = rewind_selected == rewind_choices.size()
	var item: Dictionary = rewind_origin if live else rewind_choices[rewind_selected]
	RewindHistory.restore(sim.state,item.state)
	RewindHistory.restore(track_session,item.session)
	impact_cracks.restore_damage(item.glass_damage)
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	camera.follow(sim.state.position,sim.state.velocity,sim.state.heading,0.0,true)
	rewind_ghosts.present(rewind_selected)
	rewind_panel.show_moment(sim.state,track_session,rewind_ghosts.labels,rewind_ghosts.world(item.state),live)

func cancel_rewind() -> void:
	if not is_instance_valid(rewind_panel) or resume_credits.busy: return
	if not resume_credits.pending.is_empty():
		exit_requested.emit()
		return
	RewindHistory.restore(sim.state,rewind_origin.state)
	RewindHistory.restore(track_session,rewind_origin.session)
	impact_cracks.restore_damage(rewind_origin.glass_damage)
	_close_rewind(rewind_was_paused)

func confirm_rewind() -> void:
	if not is_instance_valid(rewind_panel) or resume_credits.busy or rewind_selected >= rewind_choices.size(): return
	var target: Dictionary = rewind_choices[rewind_selected]
	var from_tick: int = int(rewind_origin.state.tick)
	rewind_panel.set_busy(true)
	rewind_panel.status.text = "Confirming resume…"
	var result: Dictionary = await resume_credits.consume(from_tick,int(target.tick),online_frames.size())
	if not is_instance_valid(rewind_panel): return
	if not result.ok:
		rewind_panel.set_busy(false)
		rewind_panel.status.text = str(result.get("error","Connection unavailable"))
		if not resume_credits.pending.is_empty():
			rewind_panel.lock_pending()
			rewind_panel.cancel.text = "Leave race"
			var recoverable: bool = resume_client != null and resume_client.get("_capabilities") is Dictionary and bool(resume_client.get("_capabilities").get("resume_recovery",false))
			rewind_panel.status.text += " Retry, or leave to close this attempt and recover an unconfirmed credit." if recoverable else " Retry to resolve the pending resume, or leave. It may already be spent."
		return
	online_rewinds.append({"receipt_id":str(result.data.receipt_id),"input_offset":online_frames.size(),"from_tick":from_tick,"to_tick":int(target.tick)})
	RewindHistory.restore(sim.state,target.state)
	RewindHistory.restore(track_session,target.session)
	RewindHistory.restore(lap_telemetry,target.telemetry)
	rewind_history.branch(int(target.tick))
	ghost_run.branch(int(target.tick))
	race_proof.branch(int(target.tick),track_session)
	race_proof.capture(sim.state,track_session,true)
	if ghost_store != null: ghost_run.capture(sim.state,track_session,native_track,bridge_presentation,handling,true)
	trails.clear()
	sand_dust.clear()
	impact_cracks.restore_damage(target.glass_damage)
	car.last_tick = -1
	car.ramp_tick = -1
	car.wheel_last_tick = -1
	car.suspension = Vector3.ZERO
	car.suspension_speed = Vector3.ZERO
	checkpoint_marker.previous_gate = -2
	if vehicle_audio != null: vehicle_audio.reset()
	_close_rewind(false,true)
	_refresh_resume_hud()

func _refresh_resume_hud() -> void:
	if hud == null or hud.rewind_button == null or resume_credits == null:
		return
	var credits: Node = resume_credits
	var result: Dictionary = await credits.refresh()
	if not is_instance_valid(credits) or credits != resume_credits or hud == null or hud.rewind_button == null:
		return
	if result.ok:
		hud.rewind_button.show_resource(result.data,online_rewinds.size())

func _close_rewind(stay_paused: bool, resumed: bool = false) -> void:
	if is_instance_valid(rewind_ghosts):
		remove_child(rewind_ghosts)
		rewind_ghosts.queue_free()
		rewind_ghosts = null
	if resumed: rewind_return.resume()
	elif not stay_paused: rewind_return.cancel()
	remove_child(rewind_panel)
	rewind_panel.queue_free()
	rewind_panel = null
	rewind_origin = {}
	rewind_choices.clear()
	previous_position = sim.state.position
	previous_heading = sim.state.heading
	camera.follow(sim.state.position,sim.state.velocity,sim.state.heading,0.0,true)
	driver.clear()
	frame = DriveFrame.new()
	paused = stay_paused
	hud.show()
	hud.touch.enabled = not paused
	trails.show()
	sand_dust.show()

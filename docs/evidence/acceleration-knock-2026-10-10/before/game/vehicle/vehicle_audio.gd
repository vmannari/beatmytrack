class_name VehicleAudio
extends Node
## Recorded local sound bank. All state is presentation-only and scoped to this race.
const BANK: String = "res://assets/audio/vehicles/"
const IMPACTS: Array[String] = ["impact_0","impact_1","impact_2"]
const BODY_CLIPS: Array[String] = ["impact_0","impact_1","impact_2","chassis"]
const GRIT: Array[String] = ["grit_0","grit_1","grit_2"]
const GRIT_SPACING: Array[float] = [4.2,6.6,5.1,3.7]
var model := VehicleAudioModel.new()
var surface_model := SurfaceAudioModel.new()
var engine_load: Array[AudioStreamPlayer] = []
var engine_coast: Array[AudioStreamPlayer] = []
var layers: Dictionary = {}
var events: Array[AudioStreamPlayer] = []
var debris_events: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var levels: Dictionary = {}
var active: bool = false
var impact_cooldown: float = 0.0
var chassis_cooldown: float = 0.0
var event_index: int = 0
var impact_index: int = 0
var last_tick: int = -1
var last_jump: float = 0.0
var last_jump_velocity: float = 0.0
var was_silent: bool = true
var event_count: int = 0
var engine_envelope: float = 0.0
var grit_distance: float = 0.0
var grit_cooldown: float = 0.0
var grit_count: int = 0
var pending_scrape: float = 0.0
var pending_scrape_speed: float = 0.0
var debris_index: int = 0
var impact_count: int = 0
var countdown_active: bool = false
var sand_frequency: float = 0.94
var contact_enabled: bool = false
var visible_contact := VisibleContactAudio.new()
var use_windows_impacts: bool = true
var windows_impacts := WindowsImpactAudio.new()
var collision_trace_enabled: bool = false
var last_impact_route: String = "none"

func _ready() -> void:
	name = "VehicleAudio"
	collision_trace_enabled = OS.is_debug_build() and OS.get_cmdline_user_args().has("--collision-audio-trace")
	for i: int in range(3):
		engine_load.append(_player("EngineLoad%d"%i,"Engine"))
		engine_coast.append(_player("EngineCoast%d"%i,"Engine"))
	for layer: String in ["tire","road","loose","grass","wind","water","sand","sand_roll","sand_debris","scrape"]:
		var player: AudioStreamPlayer = _player(layer.capitalize(),"Tires" if layer in ["tire","road","loose","grass","water"] else "Vehicle")
		layers[layer] = player
		# Reuse the cleared coarse friction recording at a restrained level.
		player.stream = _stream("loose" if layer == "scrape" else layer,true)
		levels[layer] = 0.0
	for i: int in range(4): events.append(_player("BodyEvent%d"%i,"Vehicle"))
	# Debris cannot steal a collision voice or truncate its settling tail.
	for i: int in range(2): debris_events.append(_player("DebrisEvent%d"%i,"Vehicle"))
	for clip: String in IMPACTS+GRIT+ ["chassis"]: _stream(clip,false)
	if use_windows_impacts:
		var impact_samples: Array[AudioStreamWAV] = []
		for clip: String in BODY_CLIPS: impact_samples.append(_stream(clip,false))
		windows_impacts.configure(impact_samples)

func _exit_tree() -> void:
	windows_impacts.close()

func _player(label: String, target_bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.bus = target_bus
	player.volume_linear = 0.0
	add_child(player)
	return player

func _stream(clip: String, looping: bool) -> AudioStreamWAV:
	if streams.has(clip): return streams[clip] as AudioStreamWAV
	var source: AudioStreamWAV = load(BANK+clip+".wav") as AudioStreamWAV
	var sample: AudioStreamWAV = PcmAudioLoop.prepare(source) if looping else source.duplicate() as AudioStreamWAV
	streams[clip] = sample
	return sample

func configure(id: String, config: HandlingConfig, car: Node3D = null) -> void:
	model.configure(id,config.maximum_speed)
	surface_model.configure(config)
	if car!=null: visible_contact.configure(car)
	else: visible_contact.outline = PackedVector2Array()
	# Only the selected vehicle's six engine loops are retained by this race.
	for i: int in range(3):
		engine_load[i].stream = _stream(model.vehicle_id+"_%d_load"%i,true)
		engine_coast[i].stream = _stream(model.vehicle_id+"_%d_coast"%i,true)
	reset()

func reset() -> void:
	windows_impacts.reset()
	model.reset()
	surface_model.reset()
	impact_cooldown = 0.0
	countdown_active = false
	contact_enabled = false
	visible_contact.reset()
	sand_frequency = 0.94
	chassis_cooldown = 0.0
	event_index = 0
	impact_index = 0
	impact_count = 0
	debris_index = 0
	event_count = 0
	engine_envelope = 0.0
	grit_distance = 0.0
	grit_cooldown = 0.0
	grit_count = 0
	pending_scrape = 0.0
	pending_scrape_speed = 0.0
	last_tick = -1
	last_jump = 0.0
	last_jump_velocity = 0.0
	was_silent = true
	active = true
	for i: int in range(3):
		for player: AudioStreamPlayer in [engine_load[i],engine_coast[i]]:
			player.stop()
			player.volume_linear = 0.0
			player.stream_paused = false
			# All recorded orders represent one engine. Start even muted voices
			# at that engine's idle frequency, rather than their native bank RPM.
			player.pitch_scale = model.rpm/model.anchors[i]
			player.play()
	for layer: String in layers:
		var player: AudioStreamPlayer = layers[layer]
		player.stop()
		player.volume_linear = 0.0
		player.stream_paused = false
		levels[layer] = 0.0
		player.play()
	for player: AudioStreamPlayer in events+debris_events: player.stop()

func begin_physics_feedback() -> void:
	# Caller passed live pause/countdown/rewind gates and is taking a real tick.
	# Avoid suppression by the previous render's paused/countdown latch.
	contact_enabled = active

func resolved_contact(state: VehicleState, track: NativeTrack, incoming: Vector2) -> void:
	if not active or not contact_enabled: return
	var requested_us: int = int(Time.get_unix_time_from_system()*1000000.0) if collision_trace_enabled else 0
	var count_before: int = impact_count
	var cooldown_before: float = impact_cooldown
	var visual_impulse: Vector2 = visible_contact.sample(state,track,incoming)
	if state.collision_impulse!=Vector2.ZERO:
		if not visible_contact.duplicate_physical(state.collision_impulse):
			var before: int = impact_count
			collision(state.collision_impulse)
			visible_contact.sounded = visible_contact.touching and impact_count>before
			if visible_contact.sounded and visible_contact.normal==Vector2.ZERO:
				visible_contact.normal = state.collision_impulse.normalized()
	elif visual_impulse!=Vector2.ZERO:
		var before: int = impact_count
		collision(visual_impulse)
		visible_contact.sounded = impact_count>before
	if collision_trace_enabled and (state.collision_impulse!=Vector2.ZERO or visual_impulse!=Vector2.ZERO):
		var started: bool = impact_count>count_before
		var trace: Dictionary = {"unix_us":requested_us,"tick":state.tick,"car":model.vehicle_id,"track":str(track.metadata.get("title",track.identity)) if track!=null else "physics_playground","source":"canonical" if state.collision_impulse!=Vector2.ZERO else "visible_contact","speed_mps":incoming.length(),"position":[state.position.x,state.position.y],"canonical_impulse":state.collision_impulse.length(),"visible_impulse":visual_impulse.length(),"played":started,"route":last_impact_route if started else "suppressed","cooldown_before":cooldown_before,"outline_points":visible_contact.outline.size(),"touching":visible_contact.touching,"normal":[visible_contact.normal.x,visible_contact.normal.y],"native":windows_impacts.stats(),"fps":Engine.get_frames_per_second(),"last_presented_tick":last_tick,"driver":AudioServer.get_driver_name(),"device":AudioServer.output_device,"vehicle_gain":db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Impacts")))}
		_emit_collision_trace.call_deferred(trace)

func _emit_collision_trace(trace: Dictionary) -> void:
	# Print after the physics callback. The development launcher retains stdout;
	# no diagnostic file/network write occurs in the canonical simulation step.
	print("COLLISION_AUDIO_TRACE: ",JSON.stringify(trace))

func collision(impulse: Vector2) -> void:
	# Game calls this directly after its canonical step resolves a contact.
	# Start playback here; render/presentation work must not delay the attack.
	var strength: float = impulse.length()
	if not active or not contact_enabled or strength<=1.2 or impact_cooldown>0.0: return
	var severity: float = smoothstep(1.2,22.0,strength)
	impact_index = 0 if strength<5.0 else (1 if strength<13.0 else 2)
	_event(IMPACTS[impact_index],lerpf(0.18,0.9,severity),[1.04,0.96,1.01,0.92][impact_count%4])
	impact_count += 1
	impact_cooldown = lerpf(0.12,0.23,severity)

func scrape(strength: float, speed: float) -> void:
	if active and not was_silent:
		pending_scrape = maxf(pending_scrape,clampf(strength,0.0,1.0))
		pending_scrape_speed = maxf(pending_scrape_speed,speed)

func _event(clip: String, amplitude: float, pitch: float = 1.0, debris: bool = false) -> void:
	var slot: int = event_index
	var player: AudioStreamPlayer = debris_events[debris_index] if debris else events[event_index]
	if not debris: windows_impacts.stop_voice(slot)
	if debris: debris_index = (debris_index+1)%debris_events.size()
	else: event_index = (event_index+1)%events.size()
	player.stream = _stream(clip,false)
	player.bus = "Impacts" if clip in IMPACTS else "Vehicle"
	player.stream_paused = false
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(maxf(0.0001,amplitude))
	var native_played: bool = clip in BODY_CLIPS and windows_impacts.play(BODY_CLIPS.find(clip),amplitude,pitch,slot)
	if clip in IMPACTS and collision_trace_enabled: last_impact_route = "windows_raw" if native_played else "godot"
	if native_played:
		player.stop() # One playback path per event; no delayed second copy.
	else: player.play()
	event_count += 1

func present(state: VehicleState, frame: DriveFrame, track: NativeTrack, delta: float, silent: bool, countdown: bool = false) -> void:
	if not active: return
	if last_tick>state.tick: reset() # Restored rewind state cannot replay impact/landing events.
	countdown_active = countdown
	windows_impacts.sync_output(silent or countdown)
	contact_enabled = not silent and not countdown
	for player: AudioStreamPlayer in engine_load+engine_coast+events+debris_events: player.stream_paused = silent
	for layer: String in layers: (layers[layer] as AudioStreamPlayer).stream_paused = silent
	if silent:
		pending_scrape = 0.0
		pending_scrape_speed = 0.0
		levels.scrape = 0.0
		(layers.scrape as AudioStreamPlayer).volume_linear = 0.0
		last_tick = state.tick
		last_jump = state.jump_height
		last_jump_velocity = state.jump_velocity
		was_silent = true
		surface_model.has_speed = false
		return
	var dt: float = minf(maxf(delta,0.0),0.1)
	var changed: bool = model.advance(state,frame,dt)
	if changed and not countdown and not was_silent: _event("chassis",0.12,1.32)
	var weights: Vector3 = EngineAudioBlend.rpm_gains(model.weights())
	var load_blend: float = clampf(model.load_amount,0.08,1.0)
	var load_gains: Vector2 = EngineAudioBlend.load_gains(load_blend)
	var engine_level: float = lerpf(0.31,0.72,load_blend)
	if model.shift_remaining>0.0: engine_level *= 0.56
	engine_envelope = lerpf(engine_envelope,engine_level,1.0-exp(-dt*22.0))
	for i: int in range(3):
		# Muted banks must track the same engine too: clipping their rate would
		# let their phase diverge before they reenter the audible blend.
		var pitch: float = model.rpm/model.anchors[i]
		engine_load[i].pitch_scale = pitch
		engine_coast[i].pitch_scale = pitch
		engine_load[i].volume_db = linear_to_db(maxf(0.0001,weights[i]*load_gains.x*engine_envelope))
		engine_coast[i].volume_db = linear_to_db(maxf(0.0001,weights[i]*load_gains.y*engine_envelope))
	var speed: float = state.velocity.length()
	var grounded: bool = state.jump_height<=0.0 and state.roll_ticks==0 and not countdown
	_layer("scrape",pending_scrape*0.10,0.62+clampf(pending_scrape_speed/46.0,0.0,1.0)*0.26,dt,not grounded or was_silent)
	pending_scrape = 0.0
	pending_scrape_speed = 0.0
	var rolling: float = smoothstep(0.4,22.0,speed) if grounded else 0.0
	var movement: float = smoothstep(0.35,3.0,speed) if grounded else 0.0
	var theme: String = str(track.metadata.get("theme","pine")) if track != null else "pine"
	var desert: bool = theme=="desert"
	surface_model.sample(state,frame,track,dt,grounded)
	var sand_contact: bool = surface_model.sand>0.0
	# Modest speed-driven spectral motion; pedal/acceleration change intensity.
	sand_frequency = lerpf(sand_frequency,0.94+clampf(speed/46.0,0.0,1.0)*0.14,1.0-exp(-dt*8.0))
	# Keep terrain below the engine, including lift-off when the engine quiets.
	var desert_gain: float = 0.16+load_blend*0.12
	var scrub: float = TireAudio.scrub_amount(state) if not countdown else 0.0
	var asphalt: float = scrub*surface_model.pavement*(1.0-clampf(surface_model.water,0.0,1.0)) if theme!="winter" and not desert else 0.0
	# Desert replaces all tire/rolling beds immediately, including transition tails.
	var tires_silent: bool = not grounded or desert
	_layer("tire",asphalt*0.62,0.88+clampf(speed/46.0,0,1)*0.24,dt,tires_silent or surface_model.pavement==0.0 or surface_model.water>=1.0)
	# Owner deferred wet-asphalt rolling; no wet loop or dry-road replacement.
	_layer("road",rolling*0.13*surface_model.pavement,0.78+clampf(speed/46.0,0.0,1.0)*0.46,dt,tires_silent or theme=="storm" or surface_model.pavement==0.0 or speed<=0.4)
	_layer("loose",movement*(0.10+rolling*0.25+scrub*0.15)*surface_model.gravel,0.82+clampf(speed/46.0,0,1)*0.28,dt,tires_silent or surface_model.gravel==0.0 or movement==0.0)
	_layer("grass",movement*(0.12+rolling*0.30+scrub*0.14+surface_model.drive*0.08)*surface_model.grass,0.85+clampf(speed/46.0,0,1)*0.25,dt,tires_silent or surface_model.grass==0.0 or movement==0.0)
	_layer("sand_roll",movement*(0.12+rolling*0.32)*surface_model.sand*(desert_gain if desert else 1.0),sand_frequency*0.90 if desert else 0.72+clampf(speed/46.0,0,1)*0.38,dt,not sand_contact or movement==0.0)
	_layer("sand",movement*(0.10+rolling*0.24+scrub*0.24+surface_model.drive*0.22)*surface_model.sand*(0.40*desert_gain if desert else 1.0),sand_frequency if desert else 0.86+clampf(speed/46.0,0,1)*0.20+surface_model.drive*0.06,dt,not sand_contact or movement==0.0)
	_layer("sand_debris",movement*(0.12+rolling*0.30+scrub*0.16+surface_model.drive*0.24)*surface_model.sand*desert_gain,sand_frequency,dt,not desert or not sand_contact or movement==0.0)
	# Fine sand/stone contacts merge into a steady noise bed in Desert.
	# Do not punctuate it with the former distance-spaced pebble one-shots.
	if desert:
		for player: AudioStreamPlayer in debris_events:
			if player.playing: player.stop()
	_present_grit(speed,rolling,scrub,dt,not desert and (sand_contact or surface_model.gravel>0.0))
	_layer("water",rolling*0.36*surface_model.water,0.9+clampf(speed/46.0,0,1)*0.2,dt,not grounded or surface_model.water==0.0 or speed<=0.4)
	_layer("wind",smoothstep(10.0,46.0,speed)*0.14,1.0,dt,false)
	impact_cooldown = maxf(0,impact_cooldown-dt)
	chassis_cooldown = maxf(0,chassis_cooldown-dt)
	if not was_silent and not countdown:
		if last_jump>0.0 and state.jump_height<=0.0 and last_jump_velocity< -0.5:
			_event("chassis",lerpf(0.15,0.55,clampf(-last_jump_velocity/10.0,0,1)),0.76)
		elif chassis_cooldown==0.0 and speed>4.0 and state.jump_height<=0.0 and absf(state.kerb_velocity.x)>0.18:
			_event("chassis",clampf(absf(state.kerb_velocity.x)*0.08,0.04,0.17),0.93)
			chassis_cooldown = 0.22
	last_tick = state.tick
	last_jump = state.jump_height
	last_jump_velocity = state.jump_velocity
	was_silent = false

func _present_grit(speed: float, rolling: float, slip: float, delta: float, on_sand: bool) -> void:
	if not on_sand or speed<3.0:
		grit_distance = 0.0
		grit_cooldown = 0.0
		return
	if was_silent: return
	grit_cooldown = maxf(0.0,grit_cooldown-delta)
	var contact: float = clampf(surface_model.sand+surface_model.gravel,0.0,1.0)
	grit_distance += speed*delta*(0.45+rolling*0.55)*(1.0+slip*0.9+surface_model.drive*0.65)*contact
	var spacing: float = GRIT_SPACING[grit_count%GRIT_SPACING.size()]
	if grit_cooldown==0.0 and grit_distance>=spacing:
		var variation: int = grit_count%GRIT.size()
		_event(GRIT[variation],(0.10+rolling*0.17+slip*0.10+surface_model.drive*0.14)*contact*[0.86,1.0,0.92][variation],[1.07,0.94,1.15][variation],true)
		grit_count += 1
		grit_distance = minf(grit_distance-spacing,1.0)
		grit_cooldown = 0.12 # Bounded foley; no unbounded catch-up burst after a slow frame.

func _layer(key: String, desired: float, pitch: float, delta: float, immediate_silence: bool) -> void:
	levels[key] = 0.0 if immediate_silence else lerpf(float(levels[key]),desired,1.0-exp(-delta*14.0))
	var player: AudioStreamPlayer = layers[key]
	player.volume_linear = maxf(0.0,float(levels[key]))
	player.pitch_scale = pitch

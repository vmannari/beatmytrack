class_name VehicleAudio
extends Node
## Recorded local sound bank. All state is presentation-only and scoped to this race.
const BANK: String = "res://assets/audio/vehicles/"
const IMPACTS: Array[String] = ["impact_0","impact_1","impact_2"]
const GRIT: Array[String] = ["grit_0","grit_1","grit_2"]
const GRIT_SPACING: Array[float] = [4.2,6.6,5.1,3.7]
var model := VehicleAudioModel.new()
var engine_load: Array[AudioStreamPlayer] = []
var engine_coast: Array[AudioStreamPlayer] = []
var layers: Dictionary = {}
var events: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var levels: Dictionary = {}
var active: bool = false
var pending_impact: float = 0.0
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

func _ready() -> void:
	name = "VehicleAudio"
	for i: int in range(3):
		engine_load.append(_player("EngineLoad%d"%i,"Engine"))
		engine_coast.append(_player("EngineCoast%d"%i,"Engine"))
	for layer: String in ["tire","road","loose","grass","wind","water","sand"]:
		var player: AudioStreamPlayer = _player(layer.capitalize(),"Tires" if layer in ["tire","road","loose","grass","water"] else "Vehicle")
		layers[layer] = player
		player.stream = _stream(layer,true)
		levels[layer] = 0.0
	for i: int in range(4): events.append(_player("BodyEvent%d"%i,"Vehicle"))
	for clip: String in IMPACTS+GRIT+ ["chassis"]: _stream(clip,false)

func _player(label: String, target_bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.bus = target_bus
	player.volume_linear = 0.0
	add_child(player)
	return player

func _stream(clip: String, looping: bool) -> AudioStreamWAV:
	if streams.has(clip): return streams[clip] as AudioStreamWAV
	var sample: AudioStreamWAV = (load(BANK+clip+".wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	if looping:
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sample.loop_begin = 0
		sample.loop_end = sample.data.size()/2 # Bank is authored mono, 16-bit PCM.
	streams[clip] = sample
	return sample

func configure(id: String, config: HandlingConfig) -> void:
	model.configure(id,config.maximum_speed)
	# Only the selected vehicle's six engine loops are retained by this race.
	for i: int in range(3):
		engine_load[i].stream = _stream(model.vehicle_id+"_%d_load"%i,true)
		engine_coast[i].stream = _stream(model.vehicle_id+"_%d_coast"%i,true)
	reset()

func reset() -> void:
	model.reset()
	pending_impact = 0.0
	impact_cooldown = 0.0
	chassis_cooldown = 0.0
	event_index = 0
	impact_index = 0
	event_count = 0
	engine_envelope = 0.0
	grit_distance = 0.0
	grit_cooldown = 0.0
	grit_count = 0
	last_tick = -1
	last_jump = 0.0
	last_jump_velocity = 0.0
	was_silent = true
	active = true
	for player: AudioStreamPlayer in engine_load+engine_coast:
		player.stop()
		player.volume_linear = 0.0
		player.stream_paused = false
		player.play()
	for layer: String in layers:
		var player: AudioStreamPlayer = layers[layer]
		player.stop()
		player.volume_linear = 0.0
		player.stream_paused = false
		levels[layer] = 0.0
		player.play()
	for player: AudioStreamPlayer in events: player.stop()

func collision(impulse: Vector2) -> void:
	if active and not was_silent: pending_impact = maxf(pending_impact,impulse.length())

func _event(clip: String, amplitude: float, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = events[event_index]
	event_index = (event_index+1)%events.size()
	player.stream = _stream(clip,false)
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(maxf(0.0001,amplitude))
	player.play()
	event_count += 1

func present(state: VehicleState, frame: DriveFrame, track: NativeTrack, delta: float, silent: bool, countdown: bool = false) -> void:
	if not active: return
	if last_tick>state.tick: reset() # Restored rewind state cannot replay impact/landing events.
	for player: AudioStreamPlayer in engine_load+engine_coast+events: player.stream_paused = silent
	for layer: String in layers: (layers[layer] as AudioStreamPlayer).stream_paused = silent
	if silent:
		pending_impact = 0.0
		last_tick = state.tick
		last_jump = state.jump_height
		last_jump_velocity = state.jump_velocity
		was_silent = true
		return
	var dt: float = minf(maxf(delta,0.0),0.1)
	var changed: bool = model.advance(state,frame,dt)
	if changed and not countdown and not was_silent: _event("chassis",0.12,1.32)
	var weights: Vector3 = model.weights()
	var load_blend: float = clampf(model.load_amount,0.08,1.0)
	var engine_level: float = lerpf(0.31,0.72,load_blend)
	if model.shift_remaining>0.0: engine_level *= 0.56
	engine_envelope = lerpf(engine_envelope,engine_level,1.0-exp(-dt*22.0))
	for i: int in range(3):
		var pitch: float = clampf(model.rpm/model.anchors[i],0.55,1.85)
		engine_load[i].pitch_scale = pitch
		engine_coast[i].pitch_scale = pitch
		engine_load[i].volume_db = linear_to_db(maxf(0.0001,weights[i]*sqrt(load_blend)*engine_envelope))
		engine_coast[i].volume_db = linear_to_db(maxf(0.0001,weights[i]*sqrt(1.0-load_blend)*engine_envelope*0.84))
	var speed: float = state.velocity.length()
	var grounded: bool = state.jump_height<=0.0 and state.roll_ticks==0 and not countdown
	var rolling: float = smoothstep(0.8,25.0,speed) if grounded else 0.0
	var surface: int = track.cell_at(state.position,state.track_elevated) if track != null else 0
	var theme: String = str(track.metadata.get("theme","pine")) if track != null else "pine"
	var desert: bool = theme=="desert"
	var sand_contact: bool = desert and surface in [0,1,2,5] and grounded
	var loose: bool = surface in [1,2,5,7] or (surface==0 and theme=="desert")
	var water: bool = surface in [3,6] or state.tire_water>0.05
	var scrub: float = TireAudio.scrub_amount(state) if not countdown else 0.0
	var asphalt: float = scrub if not loose and not water and theme!="winter" and not desert else 0.0
	# Desert replaces all tire/rolling beds immediately, including transition tails.
	var tires_silent: bool = not grounded or desert
	_layer("tire",asphalt*0.62,0.88+clampf(speed/46.0,0,1)*0.24,dt,tires_silent)
	_layer("road",rolling*0.13 if not loose else 0.0,0.78+clampf(speed/46.0,0,1)*0.46,dt,tires_silent)
	_layer("loose",rolling*(0.23+scrub*0.22) if loose and surface!=1 else 0.0,0.78+clampf(speed/46.0,0,1)*0.5,dt,tires_silent)
	_layer("grass",rolling*(0.25+scrub*0.18) if surface==1 else 0.0,0.8+clampf(speed/46.0,0,1)*0.4,dt,tires_silent)
	_layer("sand",rolling*(0.28+scrub*0.38)*(1.2 if surface in [1,2] else 1.0) if sand_contact else 0.0,0.88+clampf(speed/46.0,0,1)*0.32,dt,not sand_contact)
	_present_grit(speed,rolling,scrub,dt,sand_contact)
	_layer("water",rolling*0.36 if water or theme=="storm" else 0.0,0.9+clampf(speed/46.0,0,1)*0.2,dt,state.jump_height>0.0)
	_layer("wind",smoothstep(10.0,46.0,speed)*0.14,1.0,dt,false)
	impact_cooldown = maxf(0,impact_cooldown-dt)
	chassis_cooldown = maxf(0,chassis_cooldown-dt)
	if pending_impact>1.2 and impact_cooldown==0.0 and not was_silent:
		_event(IMPACTS[impact_index],lerpf(0.16,0.9,smoothstep(1.2,22,pending_impact)),1.02-float(impact_index)*0.065)
		impact_index = (impact_index+1)%IMPACTS.size()
		impact_cooldown = 0.14
	pending_impact = 0.0
	if not was_silent and not countdown:
		if last_jump>0.0 and state.jump_height<=0.0 and last_jump_velocity< -0.5:
			_event("impact_1",lerpf(0.15,0.55,clampf(-last_jump_velocity/10.0,0,1)),0.8)
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
	grit_distance += speed*delta*(0.45+rolling*0.55)*(1.0+slip*0.9)
	var spacing: float = GRIT_SPACING[grit_count%GRIT_SPACING.size()]
	if grit_cooldown==0.0 and grit_distance>=spacing:
		var variation: int = grit_count%GRIT.size()
		_event(GRIT[variation],(0.10+rolling*0.14+slip*0.10)*[0.86,1.0,0.92][variation],[1.07,0.94,1.15][variation])
		grit_count += 1
		grit_distance = minf(grit_distance-spacing,1.0)
		grit_cooldown = 0.12 # Bounded foley; no unbounded catch-up burst after a slow frame.

func _layer(key: String, desired: float, pitch: float, delta: float, immediate_silence: bool) -> void:
	levels[key] = 0.0 if immediate_silence else lerpf(float(levels[key]),desired,1.0-exp(-delta*14.0))
	var player: AudioStreamPlayer = layers[key]
	player.volume_linear = maxf(0.0,float(levels[key]))
	player.pitch_scale = pitch

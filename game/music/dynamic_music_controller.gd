class_name DynamicMusicController
extends Node
@export var profile: MusicProfile = preload("res://music/grass.tres")
var analyzer := TrackMusicAnalyzer.new()
var trajectory := TrajectoryMusicAnalyzer.new()
var clock := BeatClock.new()
var state := Vector3(0.5,0.1,0.5)
var target := Vector3(0.5,0.1,0.5)
var distance: float = 0.0
var speed: float = 0.0
var lookahead_distance: float = 0.0
var controller_us: int = 0
var telemetry: Dictionary = {}
var player: AudioStreamPlayer
var stream: AudioStream
var overlay: Control
var track: NativeTrack
var cooldown: float = 0.0
var debug_enabled: bool = false
var context: int = 0
var available: bool = false
var manual: bool = false

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
	var bus: int = AudioServer.get_bus_index("Music")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count-1
		AudioServer.set_bus_name(bus,"Music")
	player.bus = "Music"
	player.volume_db = profile.volume_db
	available = ClassDB.class_exists("BMTMusicStream")
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	overlay = preload("res://music/music_debug.gd").new()
	overlay.controller = self
	layer.add_child(overlay)
	overlay.visible = false

func start(value: NativeTrack) -> void:
	if value != track:
		track = value
		if track != null: analyzer.build(track,profile)
	state = Vector3(0.5,0.1,0.5); target = state; context = 0
	player.stop()
	# The MVP deliberately has only Grass; other biomes wait for ear acceptance.
	if not available or (track != null and track.metadata.get("theme","pine") != "pine"): return
	stream = ClassDB.instantiate("BMTMusicStream") as AudioStream
	stream.call("configure",analyzer.seed_value,profile.bpm)
	stream.call("set_preset",profile.brightness,profile.metallicity,profile.decay,profile.stereo_width)
	stream.call("set_state",state.x,state.y,state.z,4 if track != null else 0)
	player.stream = stream
	player.play()

static func smooth(current: Vector3, desired: Vector3, delta: float, seconds: float) -> Vector3:
	return current.lerp(desired,1.0-exp(-maxf(delta,0.0)/maxf(seconds,0.001)))

func present(vehicle: VehicleState, session: TrackSession, delta: float, paused: bool) -> void:
	if track == null or not player.playing: return
	var begin: int = Time.get_ticks_usec()
	context = (1 if session.completed_laps>=session.target_laps-1 else 0) | (2 if session.finished else 0) | (4 if paused else 0)
	cooldown -= delta
	if cooldown <= 0.0 and not paused:
		cooldown = 0.1
		distance = track.route_progress(vehicle.position,vehicle.route_index)
		speed = vehicle.velocity.length()
		# Reverse travel looks behind; it cannot demand a forward corner release.
		var tangent: Vector2 = track._race_route_point(distance+1.0)-track._race_route_point(distance-1.0)
		var direction: float = 1.0 if vehicle.velocity.dot(tangent) >= 0 else -1.0
		lookahead_distance = speed*profile.lookahead_seconds*direction
		target = analyzer.sample(distance).lerp(analyzer.sample(distance+lookahead_distance),profile.lookahead_weight)
		# Inspect the intervening corridor too: a fast car can otherwise leap over
		# an entire narrow hairpin between current and future samples.
		for ahead: int in range(1,7):
			var corridor: Vector3 = analyzer.sample(distance+lookahead_distance*ahead/6.0)
			target.y = maxf(target.y,corridor.y*0.85)
		var risk: float = trajectory.analyze(vehicle,track,analyzer,profile.lookahead_seconds)
		target.x = clampf(target.x*0.8+0.2*smoothstep(2.0,32.0,speed),0.0,1.0)
		if session.completed_laps == 0: target.x *= 0.9
		target.y = clampf(target.y+risk*profile.trajectory_influence,0.0,1.0)
		if context&1:
			target.x = maxf(target.x,0.8)
			var progress: float = fposmod(distance-track.route_progress(track.finish_center),analyzer.length)/analyzer.length
			if progress > 0.8: target.z = maxf(target.z,0.85)
	update_audio(delta if not paused else 0.0)
	controller_us = Time.get_ticks_usec()-begin

func update_audio(delta: float) -> void:
	if stream == null or not player.playing: return
	state = smooth(state,target,delta,profile.smoothing_seconds)
	stream.call("set_state",state.x,state.y,state.z,context)
	var playback: AudioStreamPlayback = player.get_stream_playback()
	if playback != null:
		telemetry = playback.call("telemetry")
		clock.beat_position = float(telemetry.get("beat_position",0.0))
		clock.bpm = profile.bpm
	if debug_enabled: overlay.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		debug_enabled = not debug_enabled
		overlay.visible = debug_enabled
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		player.volume_db = -80.0 if player.volume_db > -70.0 else profile.volume_db

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and stream != null:
		stream.call("set_state",state.x,state.y,state.z,context|4)

func _exit_tree() -> void:
	if player != null:
		player.stop()
		player.stream = null
	stream = null

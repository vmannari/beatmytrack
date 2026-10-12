class_name DesertRattlesnake
extends Node
## Occasional recorded rattles, independent of the continuous wind and simulation.
const CLIPS: Array[AudioStreamWAV] = [
	preload("res://assets/audio/ambience/desert_rattle_a.wav"),
	preload("res://assets/audio/ambience/desert_rattle_b.wav"),
]
const MIN_GAP: float = 12.0
const MAX_GAP: float = 24.0
const MIN_LEVEL: float = 0.28
const MAX_LEVEL: float = 0.38
const FINISH_FADE: float = 0.3
var rng := RandomNumberGenerator.new()
var player: AudioStreamPlayer
var enabled: bool = false
var suspended: bool = false
var output_enabled: bool = DisplayServer.get_name() != "headless"
var variant: int = -1
var wait_seconds: float = 0.0
var remaining: float = 0.0
var elapsed: float = 0.0
var gain: float = 0.0
var level: float = 0.0
var calls_started: int = 0
var source_offset: float = 0.0
var duration: float = 0.0
var rhythm_times := PackedFloat32Array()
var rhythm_levels := PackedFloat32Array()

func _init() -> void: rng.randomize()

func configure(theme: String) -> void:
	enabled = theme == "desert"
	if enabled and player == null:
		player = AudioStreamPlayer.new()
		player.name = "Rattlesnake"
		player.bus = "Vehicle"
		player.volume_linear = 0.0
		add_child(player)
	reset()

func reset() -> void:
	if player != null:
		player.stop()
		player.stream_paused = suspended
		player.volume_linear = 0.0
	remaining = 0.0
	elapsed = 0.0
	gain = 0.0
	source_offset = 0.0
	duration = 0.0
	rhythm_times.clear()
	rhythm_levels.clear()
	if enabled: wait_seconds = rng.randf_range(4.0, 10.0)

func present(delta: float, paused: bool, finished: bool) -> void:
	if not enabled or player == null: return
	player.stream_paused = paused or suspended
	if paused or suspended or not is_finite(delta) or delta <= 0.0: return
	var step: float = minf(delta, 0.25)
	if finished:
		gain = move_toward(gain, 0.0, MAX_LEVEL * step / FINISH_FADE)
		player.volume_linear = gain
		if gain <= 0.0:
			player.stop()
			remaining = 0.0
		return
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - step)
		elapsed += step
		gain = level * _rhythm_gain() * minf(smoothstep(0.0, 0.08, elapsed), smoothstep(0.0, 0.18, remaining))
		player.volume_linear = gain
		if remaining <= 0.0: player.stop()
		return
	wait_seconds -= step
	if wait_seconds > 0.0: return
	variant = rng.randi_range(0, CLIPS.size() - 1) if variant < 0 else 1 - variant
	player.stream = CLIPS[variant]
	player.pitch_scale = rng.randf_range(0.97, 1.03)
	level = rng.randf_range(MIN_LEVEL, MAX_LEVEL)
	# Choose a fresh portion of the recording, then shape its soft, uneven pulses.
	# The recorded fine-grained buzz stays intact; no PCM is generated at runtime.
	var source_span: float = rng.randf_range(1.35, minf(3.25, player.stream.get_length() - 0.15))
	source_offset = rng.randf_range(0.05, player.stream.get_length() - source_span - 0.05)
	duration = source_span / player.pitch_scale
	remaining = duration
	rhythm_times = PackedFloat32Array([0.0])
	rhythm_levels = PackedFloat32Array([rng.randf_range(0.8, 1.0)])
	var pulse_time: float = rng.randf_range(0.12, 0.45)
	var quiet: bool = true
	while pulse_time < duration:
		rhythm_times.append(pulse_time)
		rhythm_levels.append(rng.randf_range(0.38, 0.65) if quiet else rng.randf_range(0.8, 1.0))
		quiet = not quiet
		pulse_time += rng.randf_range(0.12, 0.45)
	rhythm_times.append(duration)
	rhythm_levels.append(rng.randf_range(0.65, 1.0))
	elapsed = 0.0
	gain = 0.0
	wait_seconds = rng.randf_range(MIN_GAP, MAX_GAP)
	player.volume_linear = 0.0
	calls_started += 1
	if output_enabled: player.play(source_offset)

func _rhythm_gain() -> float:
	for index: int in range(1, rhythm_times.size()):
		if elapsed > rhythm_times[index]: continue
		var blend: float = smoothstep(rhythm_times[index - 1], rhythm_times[index], elapsed)
		return lerpf(rhythm_levels[index - 1], rhythm_levels[index], blend)
	return rhythm_levels[-1] if not rhythm_levels.is_empty() else 1.0

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		suspended = true
		if player != null: player.stream_paused = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]: suspended = false

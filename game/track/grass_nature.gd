class_name GrassNature
extends Node
## Subtle insect bed and sparse leaf rustles; independent presentation-only RNG.
const INSECT_MIN: float = 0.035
const INSECT_MAX: float = 0.075
const LEAF_MIN: float = 0.09
const LEAF_MAX: float = 0.15
const FADE_SECONDS: float = 0.5
var rng := RandomNumberGenerator.new()
var insects: AudioStreamPlayer
var leaves: AudioStreamPlayer
var enabled: bool = false
var suspended: bool = false
var output_enabled: bool = DisplayServer.get_name() != "headless"
var insect_gain: float = 0.0
var insect_target: float = 0.0
var insect_offset: float = 0.0
var drift_wait: float = 0.0
var leaf_gain: float = 0.0
var leaf_level: float = 0.0
var leaf_wait: float = 0.0
var leaf_remaining: float = 0.0
var leaf_elapsed: float = 0.0
var rustles_started: int = 0


func _init() -> void:
	rng.randomize()


func configure(theme: String) -> void:
	enabled = theme == "pine"
	if enabled and insects == null:
		insects = _voice("GrassInsects")
		insects.stream = PcmAudioLoop.prepare(preload("res://assets/audio/ambience/night_cicadas.wav"))
		leaves = _voice("GrassLeaves")
		leaves.stream = preload("res://assets/audio/ambience/grass_leaves.wav")
	reset()


func _voice(label: String) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.name = label
	voice.bus = "Vehicle"
	voice.volume_linear = 0.0
	add_child(voice)
	return voice


func reset() -> void:
	for voice: AudioStreamPlayer in [insects, leaves]:
		if voice == null: continue
		voice.stop()
		voice.stream_paused = suspended
		voice.volume_linear = 0.0
	insect_gain = 0.0
	leaf_gain = 0.0
	leaf_remaining = 0.0
	leaf_elapsed = 0.0
	if not enabled: return
	insect_offset = rng.randf_range(0.0, 39.9)
	insect_target = rng.randf_range(INSECT_MIN, INSECT_MAX)
	drift_wait = rng.randf_range(6.0, 15.0)
	leaf_wait = rng.randf_range(4.0, 10.0)


func present(delta: float, paused: bool, finished: bool) -> void:
	if not enabled or insects == null: return
	for voice: AudioStreamPlayer in [insects, leaves]: voice.stream_paused = paused or suspended
	if paused or suspended or not is_finite(delta) or delta <= 0.0: return
	var step: float = minf(delta, 0.25)
	if finished:
		insect_gain = move_toward(insect_gain, 0.0, INSECT_MAX * step / FADE_SECONDS)
		leaf_gain = move_toward(leaf_gain, 0.0, LEAF_MAX * step / FADE_SECONDS)
		insects.volume_linear = insect_gain
		leaves.volume_linear = leaf_gain
		if insect_gain <= 0.0: insects.stop()
		if leaf_gain <= 0.0:
			leaves.stop()
			leaf_remaining = 0.0
		return
	drift_wait -= step
	if drift_wait <= 0.0:
		insect_target = rng.randf_range(INSECT_MIN, INSECT_MAX)
		drift_wait = rng.randf_range(6.0, 15.0)
	# Slow opening fade and later swells keep this beneath the birds.
	insect_gain = move_toward(insect_gain, insect_target, step * 0.025)
	insects.volume_linear = insect_gain
	if not insects.playing and output_enabled: insects.play(insect_offset)
	if leaf_remaining > 0.0:
		leaf_remaining = maxf(0.0, leaf_remaining - step)
		leaf_elapsed += step
		leaf_gain = leaf_level * minf(smoothstep(0.0, 0.25, leaf_elapsed), smoothstep(0.0, 0.45, leaf_remaining))
		leaves.volume_linear = leaf_gain
		if leaf_remaining <= 0.0: leaves.stop()
		return
	leaf_wait -= step
	if leaf_wait > 0.0: return
	leaves.pitch_scale = rng.randf_range(0.90, 1.02)
	leaf_level = rng.randf_range(LEAF_MIN, LEAF_MAX)
	leaf_elapsed = 0.0
	leaf_gain = 0.0
	leaves.volume_linear = 0.0
	leaf_remaining = leaves.stream.get_length() / leaves.pitch_scale
	leaf_wait = rng.randf_range(8.0, 20.0)
	rustles_started += 1
	if output_enabled: leaves.play()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		suspended = true
		for voice: AudioStreamPlayer in [insects, leaves]:
			if voice != null: voice.stream_paused = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		suspended = false

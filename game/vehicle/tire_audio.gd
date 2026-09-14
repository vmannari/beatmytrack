class_name TireAudio
extends AudioStreamPlayer
## Original synthesized scrub, presentation only; never writes simulation state.
var loudness: float = 0.0

func _ready() -> void:
	stream = make_scrub()
	volume_db = -80.0
	play()

static func scrub_amount(state: VehicleState) -> float:
	if state.jump_height > 0.0:
		return 0.0
	return smoothstep(0.055, 0.32, absf(state.slip_angle())) * smoothstep(3.0, 12.0, state.velocity.length())

func present(state: VehicleState, delta: float, silent: bool) -> void:
	if silent or state.jump_height > 0.0 or state.velocity.length() < 3.0:
		loudness = 0.0
	else:
		loudness = lerpf(loudness, scrub_amount(state), 1.0 - exp(-12.0 * delta))
	volume_db = linear_to_db(maxf(0.0001, loudness * 0.075))
	pitch_scale = 0.85 + 0.3 * clampf(state.velocity.length() / 46.0, 0.0, 1.0)

static func make_scrub() -> AudioStreamWAV:
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 22050
	sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sample.loop_end = 11025
	var bytes := PackedByteArray()
	bytes.resize(sample.loop_end * 2)
	var noise_state: int = 317
	var filtered: float = 0.0
	for index: int in range(sample.loop_end):
		noise_state = (noise_state * 1664525 + 1013904223) & 0xffffffff
		var noise: float = float(noise_state) / 4294967295.0 * 2.0 - 1.0
		filtered = lerpf(filtered, noise, 0.28)
		var phase: float = TAU * float(index) / sample.mix_rate
		var envelope: float = minf(1.0, minf(index / 128.0, (sample.loop_end - 1 - index) / 128.0))
		var value: float = (filtered * 0.75 + sin(phase * 920.0) * 0.12 + sin(phase * 1380.0) * 0.06) * envelope
		bytes.encode_s16(index * 2, roundi(value * 26000.0))
	sample.data = bytes
	return sample

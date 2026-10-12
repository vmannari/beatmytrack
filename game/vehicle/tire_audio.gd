class_name TireAudio
extends AudioStreamPlayer
## Slip feedback contract retained for handling diagnostics. The race mix uses VehicleAudio.
var loudness: float = 0.0

func _ready() -> void:
	stream = make_scrub()
	bus = "Tires"
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
	return PcmAudioLoop.prepare(preload("res://assets/audio/vehicles/tire.wav"))

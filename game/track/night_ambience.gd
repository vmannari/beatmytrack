class_name NightAmbience
extends Node
## One recorded ambience voice, owned by the race and outside simulation.
const LEVEL: float = 0.4
const FADE_SECONDS: float = 0.75
var player: AudioStreamPlayer
var enabled: bool = false
var suspended: bool = false
var gain: float = 0.0


func configure(theme: String) -> void:
	enabled = theme == "night_city"
	if not enabled:
		gain = 0.0
		if player != null:
			player.stop()
			player.volume_linear = 0.0
		return
	if player != null: return
	player = AudioStreamPlayer.new()
	player.name = "Cicadas"
	player.bus = "Vehicle"
	player.volume_linear = 0.0
	var stream: AudioStreamWAV = PcmAudioLoop.prepare(preload("res://assets/audio/ambience/night_cicadas.wav"))
	player.stream = stream
	add_child(player)


func present(delta: float, paused: bool, finished: bool) -> void:
	if player == null or not enabled: return
	player.stream_paused = paused or suspended
	if paused or suspended: return
	gain = move_toward(gain, 0.0 if finished else LEVEL, LEVEL * delta / FADE_SECONDS)
	player.volume_linear = gain
	if gain <= 0.0:
		player.stop()
	elif not player.playing and DisplayServer.get_name() != "headless":
		player.play()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		suspended = true
		if player != null: player.stream_paused = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		suspended = false

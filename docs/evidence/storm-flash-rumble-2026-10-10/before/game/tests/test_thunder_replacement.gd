extends SceneTree
## Each cue gets a fresh clap; prior tails fade out with two bounded voices.
const OUT: String = "res://../docs/evidence/short-thunder-2026-10-10"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	var graphical: bool = DisplayServer.get_name()!="headless"
	var weather := StormWeather.new()
	root.add_child(weather)
	weather.until_lightning = 9999
	var one: AudioStreamPlayer = weather.thunder_audio
	var two: AudioStreamPlayer = weather.thunder_tail_audio
	check(absf(one.stream.get_length()-6.0)<.001,"short six-second thunder asset")
	var sample: AudioStreamWAV = one.stream
	var pcm: PackedByteArray = sample.data
	check(pcm.decode_s16(pcm.size()-2)==0,"cosine release ends at zero")
	var voices: int = 0
	for child: Node in weather.get_children():
		if child is AudioStreamPlayer: voices += 1
	check(voices==3,"one rain voice and exactly two thunder voices")
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	if graphical:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		AudioServer.add_bus_effect(0,record)
		record.set_recording_active(true)
	weather.until_thunder = .001
	weather.advance(.01,false)
	check(weather.thunder_count==1 and weather.thunder_audio==two and weather.thunder_audio.playing,"first scheduled cue starts a fresh voice")
	if graphical: await create_timer(.65).timeout
	weather.until_thunder = .001
	weather.advance(.01,false)
	check(weather.thunder_count==2 and weather.thunder_audio==one and weather.thunder_tail_audio==two,"new cue starts independently of the old tail")
	check(weather.thunder_audio.get_playback_position()<.15,"new cue restarts at its clap")
	check(weather.thunder_tail_gain==StormWeather.THUNDER_LEVEL,"previous voice begins its replacement fade")
	var frozen: float = weather.thunder_tail_gain
	weather.advance(.1,true)
	check(weather.thunder_tail_gain==frozen and weather.thunder_audio.stream_paused and weather.thunder_tail_audio.stream_paused,"pause freezes both cue and replacement fade")
	weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	weather.advance(.1,false)
	check(weather.thunder_tail_gain==frozen,"background focus freezes replacement fade")
	weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	weather.advance(.05,false)
	check(weather.thunder_tail_gain>0 and weather.thunder_tail_gain<frozen,"old rumble fades while new cue remains full strength")
	weather.advance(.20,false)
	check(weather.thunder_tail_gain==0 and not weather.thunder_tail_audio.playing,"previous rumble stops after a short fade")
	for cue: int in range(4):
		weather.until_thunder = .001
		weather.advance(.01,false)
		check(weather.thunder_audio in [one,two] and weather.thunder_tail_audio in [one,two] and weather.thunder_audio!=weather.thunder_tail_audio,"rapid cue reuses bounded independent voices")
		check(weather.thunder_audio.get_playback_position()<.15,"every rapid cue restarts at the clap")
		if graphical: await create_timer(.15).timeout
	weather.advance(.25,false)
	check(weather.thunder_count==6 and weather.thunder_tail_gain==0 and not weather.thunder_tail_audio.playing,"latest cue survives and accumulated tails are cleared")
	if graphical:
		await create_timer(1.5).timeout
		record.set_recording_active(false)
		check(record.get_recording().save_to_wav(OUT.path_join("rapid-cues.wav"))==OK,"native rapid-replacement audio saved")
		AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	weather.free()
	weather = null
	one = null
	two = null
	sample = null
	pcm = PackedByteArray()
	record = null
	await create_timer(.15).timeout
	print("THUNDER_REPLACEMENT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)

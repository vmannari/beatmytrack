extends SceneTree
## Same live event pool, pitch, Vehicle compressor and Master limiter for each cut.
const OUT: String = "res://../docs/evidence/original-snow-impact-2026-10-23/audition"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	var output: String = OUT
	var before_file: String = "res://../docs/evidence/original-snow-impact-2026-10-23/before/game/assets/audio/vehicles/snow_hit.wav"
	var variants: String = "res://../build/original-snow-impact-2026-10-23/variants"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
		elif argument.begins_with("--before-file="): before_file = argument.trim_prefix("--before-file=")
		elif argument.begins_with("--variants-dir="): variants = argument.trim_prefix("--variants-dir=")
	check(DisplayServer.get_name()!="headless","audition uses the real desktop mixer")
	if failures:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var world: GameSoundtrack = GameSoundtrack.instance()
	world.begin_race(root,"winter",VehicleState.new())
	world.apply_settings({"vehicle_volume":1.0})
	var audio := VehicleAudio.new()
	audio.use_windows_impacts = false # Record the tone; separate tests verify RAW events.
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0,record)
	world.windows_output.sync_output()
	for variant: String in ["before","packed","powder","bank"]:
		var path: String = before_file if variant=="before" else variants.path_join(variant+".wav")
		var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
		check(stream!=null and stream.mix_rate==44100 and not stream.stereo,"valid mono entry: "+variant)
		if stream==null: continue
		audio.reset()
		audio.streams.snow_hit = stream
		await create_timer(.15).timeout
		record.set_recording_active(true)
		await create_timer(.15).timeout
		audio._event("snow_hit",.65,.90)
		await create_timer(.7).timeout
		record.set_recording_active(false)
		var capture: AudioStreamWAV = record.get_recording()
		check(capture!=null and capture.save_to_wav(output.path_join(variant+".wav"))==OK,"native mastered event saved: "+variant)
		check(audio.event_count==1 and not audio.events[0].playing,"one bounded event completes naturally: "+variant)
	for index: int in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0,index)==record:
			AudioServer.remove_bus_effect(0,index)
			break
	audio.free()
	await create_timer(.15).timeout
	print("ORIGINAL_SNOW_CAPTURE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

extends SceneTree
## Every biome stays music-free during race/practice lifecycle; effects/menu survive.
const OUT: String = "res://../docs/evidence/biome-music-off-2026-10-10"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	var world: GameSoundtrack = GameSoundtrack.instance()
	var graphical: bool = DisplayServer.get_name()!="headless"
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	var bus: int = AudioServer.get_bus_index("Music")
	if graphical:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		AudioServer.add_bus_effect(bus,record)
	world.apply_settings({})
	for theme: String in TrackTheme.IDS:
		world.show_menu()
		world._process(1.0)
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
		game.initial_track.metadata.theme = theme
		root.add_child(game)
		game.set_physics_process(false)
		game.set_process(false)
		game.countdown_ticks = 0
		game.sim.state.velocity = game.sim.state.forward()*20
		check(world.mode=="race" and world.synced==null and world.race_player.stream==null,"no score resources: "+theme)
		check(not world.menu_player.playing and not world.race_player.playing,"menu stops immediately at biome entry: "+theme)
		world.play_musical_event("breath")
		check(not world.event_player.playing,"no musical breath during driving: "+theme)
		if graphical: await create_timer(.20).timeout
		if graphical: record.set_recording_active(true)
		for tick: int in range(30):
			if graphical: await process_frame
			game.paused = tick>=15 and tick<20
			game.frame = DriveFrame.sample(0,.7,0)
			world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			if game.storm_weather!=null: game.storm_weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			game._process(.016)
			world._process(.016)
		check(not world.race_player.playing and world.race_target==0.0,"driving/pause/resume stay music-free: "+theme)
		check(game.vehicle_audio.active and game.vehicle_audio.engine_load[0].stream!=null,"vehicle audio remains active: "+theme)
		if theme=="storm": check(game.storm_weather.rain_gain>0 and game.storm_weather.thunder_audio.stream!=null,"rain and thunder remain installed")
		if theme=="night_city": check(game.night_ambience.enabled,"night cicadas remain enabled")
		if graphical:
			record.set_recording_active(false)
			var sample: AudioStreamWAV = record.get_recording()
			check(sample.save_to_wav(OUT.path_join(theme+"-music.wav"))==OK,"native Music-bus capture: "+theme)
			var pcm: PackedByteArray = sample.data
			var peak: int = 0
			for offset: int in range(0,pcm.size(),2): peak = maxi(peak,absi(pcm.decode_s16(offset)))
			check(peak==0,"all race music PCM exactly silent: "+theme)
		game.restart()
		check(world.synced==null and world.race_player.stream==null and not world.menu_player.playing,"retry cannot reload music: "+theme)
		game._begin_finish()
		game.paused = false
		game._process(.1)
		check(world.mode=="race" and not world.menu_player.playing,"finish coast has no menu music: "+theme)
		world.results_feedback(0.0,false)
		check(world.mode=="menu" and world.menu_target==1.0,"actual summary restores menu music: "+theme)
		game.free()
		world.event_player.stop()
		await create_timer(.15).timeout
	if graphical: AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	world.menu_player.stop()
	print("BIOME_MUSIC_OFF: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)

extends SceneTree
func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var showroom := CarShowroom.new()
	showroom.garage_mode = true
	showroom.size = Vector2(1280,620)
	root.add_child(showroom)
	showroom.set_process(false)
	var music: GameSoundtrack = GameSoundtrack.instance()
	music.output_enabled = true
	music.show_menu()
	await process_frame
	# Force one stable logical state for a deterministic callback-count probe.
	music.menu_player.stream_paused = false
	var bus: int = AudioServer.get_bus_index("Music")
	for muted: bool in [false,true]:
		AudioServer.set_bus_mute(bus,muted)
		var before: int = showroom.render_requests
		var started: int = Time.get_ticks_usec()
		for index: int in range(120): showroom._process(1.0/60.0)
		print("GARAGE_RENDER ",JSON.stringify({"muted":muted,"callbacks":120,"render_requests":showroom.render_requests-before,"callback_ms":(Time.get_ticks_usec()-started)/1000.0,"record_station":showroom.record_station!=null,"vinyl":showroom.record_vinyl!=null,"music_playing":music.menu_player.playing,"reflection_views":showroom.reflections.views.size()}))
	AudioServer.set_bus_mute(bus,false)
	showroom.free()
	await process_frame
	quit()

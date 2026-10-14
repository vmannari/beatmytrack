extends SceneTree
## Explicit unscored desktop diagnostic, with no records/account/upload adapters.
func _initialize() -> void: run.call_deferred()

func quantiles(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p50":values[values.size()/2],"p95":values[mini(values.size()-1,floori(values.size()*0.95))],"p99":values[mini(values.size()-1,floori(values.size()*0.99))],"max":values[-1]}

func run() -> void:
	root.size = Vector2i(1600,900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var document: Dictionary = TrackLibrary.new().load_document("track_3e26605a8a90165e")
	assert(not document.is_empty())
	var track: NativeTrack = TrackCompiler.compile(document)
	var topology: Dictionary = RoadPieces.prepare_endpoints(document.pieces)
	var phases: Dictionary = preload("res://track/desert_road_union.gd").phases(document.pieces,topology)
	for i: int in range(document.pieces.size()):
		print("DESERT_CONNECTION ",i," ends=",RoadPieces._matches(topology,i,0),"/",RoadPieces._matches(topology,i,1)," phase=",phases[i])
	var race: Node = load("res://core/game.tscn").instantiate()
	race.initial_track = track
	race.production_mode = true
	race.attempt_practice = true
	race.ai_enabled = true
	root.add_child(race)
	race.countdown_ticks = 0
	race.race_cues.hide()
	assert(race.preference_records == null and race.rating_records == null)
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec()-start < 3000000:
		if race.paused: race.toggle_pause()
		await process_frame
	var frames: Array[float] = []
	var gpu: Array[float] = []
	start = Time.get_ticks_usec()
	var previous: int = start
	var initial_tick: int = race.sim.state.tick
	var initial_position: Vector2 = race.sim.state.position
	while Time.get_ticks_usec()-start < 8000000:
		if race.paused: race.toggle_pause()
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		previous = now
	var ticks: int = race.sim.state.tick-initial_tick
	assert(ticks >= int(8.0*VehicleSimulation.TICK_RATE*0.95))
	var report: Dictionary = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"viewport":[1600,900],"warmup_seconds":3,"measured_seconds":8,"samples":frames.size(),"ticks":ticks,"movement_m":initial_position.distance_to(race.sim.state.position),"frame_ms":quantiles(frames),"gpu_ms":quantiles(gpu),"road_reference":str(NativeTrackVisual.desert_road_reference),"bank_sections":race.track_ground.get_meta("desert_bank_sections",0),"chips":race.track_ground.get_meta("desert_clod_count",0),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"note":"Unscored real driving with original dense dust; desktop smoke sample, not phone/thermal or old-new comparison."}
	var folder: String = "res://../docs/evidence/desert-reference-2026-10-12/performance/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	FileAccess.open(folder+"desktop.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"driving.png")
	print("DESERT_REFERENCE_PROFILE: ",JSON.stringify(report))
	race.queue_free()
	await process_frame
	quit()

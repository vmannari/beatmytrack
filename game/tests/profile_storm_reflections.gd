extends SceneTree
## Controlled desktop rendering A/B: same paused scene, no simulation/random flash.
const WARMUP: int = 90
const SAMPLES: int = 300

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var track_id: String = "track_acf29166cceaaa42"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track="): track_id = argument.trim_prefix("--track=")
	var document: Dictionary = TrackLibrary.new().load_document(track_id)
	if document.is_empty():
		push_error("Missing profile track: "+track_id)
		quit(1)
		return
	document.theme = "storm"
	var race: Node = load("res://core/game.tscn").instantiate()
	race.initial_track = TrackCompiler.compile(document)
	race.production_mode = true
	root.size = Vector2i(1280,720)
	root.add_child(race)
	race.paused = true
	(race.race_cues as Control).hide()
	var environment: Environment = race.biome_environment
	var sky: Sky = environment.sky
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var results: Array[Dictionary] = []
	print("REFLECTION_PROFILE_DEVICE ",RenderingServer.get_video_adapter_name()," renderer=",RenderingServer.get_current_rendering_method())
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		# Alternate order to expose warm-up/clock drift, rather than assume it away.
		for mode: String in ["off","on","on","off","off","on"]:
			environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if mode == "on" else Environment.REFLECTION_SOURCE_DISABLED
			environment.background_mode = Environment.BG_SKY if mode == "on" else Environment.BG_COLOR
			environment.sky = sky if mode == "on" else null
			for frame: int in range(WARMUP): await RenderingServer.frame_post_draw
			var wall: Array[float] = []
			var gpu: Array[float] = []
			var cpu: Array[float] = []
			var previous: int = Time.get_ticks_usec()
			for frame: int in range(SAMPLES):
				await RenderingServer.frame_post_draw
				var now: int = Time.get_ticks_usec()
				wall.append(float(now-previous)/1000.0)
				previous = now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			var result: Dictionary = {"resolution":str(resolution),"mode":mode,"frames":SAMPLES,
				"wall_ms":_stats(wall),"gpu_ms":_stats(gpu),"render_cpu_ms":_stats(cpu),
				"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
			results.append(result)
			print("REFLECTION_PROFILE ",JSON.stringify(result))
	var output := FileAccess.open("res://../build/storm-reflection-profile.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"track":track_id,"warmup_frames":WARMUP,"results":results},"\t"))
	output.close()
	race.queue_free()
	await process_frame
	await process_frame
	quit()

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[int(values.size()*0.95)],"max":values[-1]}

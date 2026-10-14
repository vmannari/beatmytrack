extends "res://tests/test_winter_environment.gd"
## Explicit local, unscored performance diagnostic; no menu/account/upload path.
const PROFILE_DIR: String = "res://../docs/evidence/winter-performance-2026-10-11"
var bank_meshes: Array[MeshInstance3D] = []
var originals: Array[Dictionary] = []
var reports: Array[Dictionary] = []

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var track: NativeTrack = make_track()
	var tag: String = "fixture"
	var duration: float = 5.0
	var resolutions: Array[Vector2i] = [Vector2i(1920,1080),Vector2i(3840,2160)]
	var modes: Array[String] = ["full","no_wind","no_banks","flat_world","no_shadows","full_repeat"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--document="):
			var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--document=")))
			document.theme = "winter"
			track = TrackCompiler.compile(document)
			if tag == "fixture": tag = document.id
		if argument.begins_with("--native="):
			track = NativeTrack.read(argument.trim_prefix("--native="))
			track.metadata.theme = "winter"
			tag = "native"
		if argument.begins_with("--tag="): tag = argument.trim_prefix("--tag=")
		if argument.begins_with("--seconds="): duration = float(argument.trim_prefix("--seconds="))
		if argument == "--4k": resolutions = [Vector2i(3840,2160)]
		if argument.begins_with("--modes="): modes.assign(argument.trim_prefix("--modes=").split(","))
	set_meta("profile_tag",tag)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	game.attempt_practice = true
	game.ai_enabled = true
	game.profile_enabled = true
	root.add_child(game)
	for i: int in range(10): await process_frame
	for node: Node in game.track_ground.find_children("*","MeshInstance3D",true,false):
		var material: Material = node.material_override
		if material is ShaderMaterial and material.shader.code.contains("smooth_road_bank"):
			bank_meshes.append(node)
			print("WINTER_BANK_BUFFER: vertices=",node.mesh.surface_get_array_len(0)," indices=",node.mesh.surface_get_array_index_len(0))
		if material != null:
			var flat := StandardMaterial3D.new()
			flat.albedo_color = Color(0.65,0.72,0.80)
			flat.roughness = 1.0
			originals.append({"node":node,"original":material,"flat":flat})
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROFILE_DIR))
	for resolution: Vector2i in resolutions:
		root.size = resolution
		for mode: String in modes:
			game.restart()
			game.countdown_ticks = 0
			game.track_session.target_laps = 10000
			game.attempt_practice = true
			game.race_cues.hide()
			game.winter_snow_wind.visible = mode != "no_wind"
			for mesh: MeshInstance3D in bank_meshes: mesh.visible = mode != "no_banks"
			for entry: Dictionary in originals: entry.node.material_override = entry.flat if mode == "flat_world" else entry.original
			game.biome_light.shadow_enabled = mode != "no_shadows"
			await sample(game,viewport,mode,1.0,false)
			var report: Dictionary = await sample(game,viewport,mode,duration,true)
			reports.append(report)
			print("WINTER_DESKTOP_STAGE: ",JSON.stringify({"mode":mode,"viewport":report.viewport,"frame_ms":report.frame_ms,"gpu_ms":report.gpu_ms,"draws":report.draws,"primitives":report.primitives,"ticks":report.ticks}))
			if mode == "full_repeat": root.get_texture().get_image().save_png(PROFILE_DIR+"/"+str(resolution.x)+"-"+RenderingServer.get_current_rendering_method()+".png")
			write_report(track)
	for entry: Dictionary in originals: entry.node.material_override = entry.original
	game.queue_free()
	await process_frame
	print("WINTER_DESKTOP_PROFILE_DONE")
	quit()

func sample(game: Node, viewport: RID, mode: String, seconds: float, measured: bool) -> Dictionary:
	var frames: Array[float] = []
	var gpu: Array[float] = []
	var render_cpu: Array[float] = []
	var process_cpu: Array[float] = []
	var physics_cpu: Array[float] = []
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var counters: Dictionary = {}
	for name: String in ["sim","rules","ai","present","particles","trails","telemetry","weather","car","props","camera","hud","audio","contact","music","water","history"]:
		counters[name] = game.get("profile_"+name+"_us")
	var initial_tick: int = game.sim.state.tick
	var initial_position: Vector2 = game.sim.state.position
	while Time.get_ticks_usec()-start < seconds*1000000.0:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if measured:
			frames.append(float(now-previous)/1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			process_cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			physics_cpu.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		previous = now
	if not measured: return {}
	var costs: Dictionary = {}
	for name: String in counters: costs[name+"_ms_per_frame"] = float(int(game.get("profile_"+name+"_us"))-int(counters[name]))/frames.size()/1000.0
	return {"mode":mode,"viewport":[root.size.x,root.size.y],"render_scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"samples":frames.size(),"frame_ms":quantiles(frames),"gpu_ms":quantiles(gpu),"render_cpu_ms":quantiles(render_cpu),"process_cpu_ms":quantiles(process_cpu),"physics_cpu_ms":quantiles(physics_cpu),"costs":costs,"ticks":game.sim.state.tick-initial_tick,"movement_m":initial_position.distance_to(game.sim.state.position),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}

func quantiles(values: Array[float]) -> Dictionary:
	values.sort()
	var over_budget: int = 0
	for value: float in values: if value > 16.667: over_budget += 1
	return {"p50":values[values.size()/2],"p95":values[mini(values.size()-1,floori(values.size()*0.95))],"p99":values[mini(values.size()-1,floori(values.size()*0.99))],"max":values[-1],"over_16ms":over_budget}

func write_report(track: NativeTrack) -> void:
	var file := FileAccess.open(PROFILE_DIR+"/desktop-"+str(get_meta("profile_tag"))+"-"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"visual_version":NativeTrackVisual.VERSION,"device":RenderingServer.get_video_adapter_name(),"track_hash":track.content_hash,"vsync":"disabled","diagnostic":"real unscored AI driving; flat_world also removes material masks, so is a broad shader-cost bound","stages":reports},"\t"))

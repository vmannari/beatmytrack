extends "res://tests/test_winter_snow_wind.gd"
## Read-only, unscored attribution diagnostic. Removal modes are cost bounds,
## never proposed graphics settings. Each mode retains the same frozen camera.
var folder: String = "res://../build/winter-render-audit-2026-10-14"
var seconds: float = 1.5
var themes: Array[String] = ["winter", "pine", "desert"]
var modes: Array[String] = ["full", "no_wind", "flat_banks", "flat_terrain", "flat_roads", "no_frost", "no_shadows", "no_car", "flat_world", "full"]
var resolutions: Array[Vector2i] = [Vector2i(1920,1080), Vector2i(3840,2160)]
var view: int = 0
var entries: Array[Dictionary] = []
var report: Dictionary = {}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=")
		if argument.begins_with("--seconds="): seconds = float(argument.trim_prefix("--seconds="))
		if argument.begins_with("--themes="): themes.assign(argument.trim_prefix("--themes=").split(","))
		if argument.begins_with("--modes="): modes.assign(argument.trim_prefix("--modes=").split(","))
		if argument.begins_with("--view="): view = int(argument.trim_prefix("--view="))
		if argument == "--1080p": resolutions = [Vector2i(1920,1080)]
		if argument == "--4k": resolutions = [Vector2i(3840,2160)]
	folder += "/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	report = {"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"visual_version":NativeTrackVisual.VERSION,"note":"Frozen same-route native scenes, fixed camera/light/time within each biome; uncapped desktop GPU cost bounds, not phone FPS. Flat materials remove surface shading and masking; geometry and camera stay fixed. Wind uses a fixed active event. Captures/readbacks outside timing windows. Shared host may have other applications running.","themes":{}}
	var document: Dictionary = make_track().metadata.creator_document.duplicate(true)
	for theme: String in themes:
		document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.production_mode = true
		game.attempt_practice = true
		root.add_child(game)
		for i: int in range(10): await process_frame
		check(game.preference_records == null and game.rating_records == null,"no persistent records adapters")
		game.paused = true
		game.attempt_practice = true
		game.set_process(false)
		game.set_physics_process(false)
		game.set_process_input(false)
		game.set_process_unhandled_input(false)
		game.race_cues.hide()
		game.hud.hide()
		game.hud.pause_menu.hide()
		# Nested CanvasLayers have independent visibility. Focus loss during
		# startup can open the pause canvas before the diagnostic freezes.
		for layer: Node in game.find_children("*","CanvasLayer",true,false):
			if layer != game.weather_layer: (layer as CanvasLayer).hide()
		game.sand_dust.hide()
		game.trails.hide()
		var wind: WinterSnowWind = game.winter_snow_wind
		var focus: Vector2 = track.route[clampi(view * track.route.size() / 3, 0, track.route.size()-1)]
		if wind != null:
			wind.elapsed = 5.0
			wind.travel = 95.0
			wind.intensity = 0.45
			wind.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
			wind.present(0.0, focus, 1.0, false, false)
		entries.clear()
		var inventory: Dictionary = {}
		for node: Node in game.track_ground.find_children("*","MeshInstance3D",true,false):
			var material: Material = node.material_override
			if material == null or node.mesh == null: continue
			var role: String = "other"
			if material is ShaderMaterial:
				var code: String = (material as ShaderMaterial).shader.code
				if code.contains("smooth_road_bank"): role = "banks"
				elif code.contains("uniform sampler2D surface_low"): role = "terrain"
				elif code.contains("uniform sampler2D verge_blend_mask"): role = "roads"
				elif code.contains("uniform bool winter_bridge_width_data"): role = "roads"
			var flat := StandardMaterial3D.new()
			flat.albedo_color = Color(0.65,0.72,0.80)
			flat.roughness = 1.0
			flat.cull_mode = BaseMaterial3D.CULL_DISABLED
			flat.render_priority = material.render_priority
			entries.append({"node":node,"original":material,"flat":flat,"role":role})
			if not inventory.has(role): inventory[role] = {"nodes":0,"triangles":0}
			inventory[role].nodes += 1
			if node.mesh is ArrayMesh:
				for surface: int in range(node.mesh.get_surface_count()):
					var indices: int = node.mesh.surface_get_array_index_len(surface)
					inventory[role].triangles += (indices if indices > 0 else node.mesh.surface_get_array_len(surface)) / 3
			else:
				inventory[role].triangles += node.mesh.get_faces().size() / 3
		var snapshot: Array = game.sim.state.snapshot().duplicate(true)
		var saved_condition: Dictionary = game.car_weathering.snapshot()
		var stages: Array[Dictionary] = []
		var default_shadow: bool = game.biome_light.shadow_enabled
		var frost: Node = game.find_child("WinterFrost",true,false)
		if view != 0:
			game.car.position.x = focus.x
			game.car.position.z = -focus.y
			game.car.force_update_transform()
			if wind != null: wind._sync_surfaces()
		game.camera.follow(focus,Vector2.ZERO,0.0,0.0,true)
		for resolution: Vector2i in resolutions:
			root.size = resolution
			for mode: String in modes:
				if mode == "weathered_car":
					if theme == "winter":
						game.car_weathering.snow_amount = 0.45
						game.car_weathering.slow_snow_amount = 0.15
					else:
						game.car_weathering.dirt_amount = 0.45
						game.car_weathering.slow_dirt_amount = 0.15
					game.car_weathering._update_finish()
				elif game.car_weathering.installed:
					game.car_weathering.restore(saved_condition)
				for entry: Dictionary in entries:
					entry.node.material_override = entry.flat if mode == "flat_world" or mode == "flat_" + str(entry.role) else entry.original
				game.biome_light.shadow_enabled = default_shadow and mode != "no_shadows"
				game.car.visible = mode != "no_car"
				if frost != null: frost.visible = mode != "no_frost"
				if wind != null: wind.visible = mode != "no_wind"
				await measure(viewport,0.6)
				var stage: Dictionary = await measure(viewport,seconds)
				stage["mode"] = mode
				stages.append(stage)
				print("WINTER_RENDER_AUDIT_STAGE: ",theme," ",JSON.stringify(stage))
				if mode in ["full","no_wind","weathered_car"]: root.get_texture().get_image().save_png(folder+"/"+theme+"-"+str(resolution.x)+"-"+mode+".png")
				check(game.sim.state.snapshot() == snapshot,"frozen diagnostic leaves canonical state unchanged")
				check(not game.hud.visible and not game.hud.pause_menu.visible and not game.race_cues.visible,"diagnostic has no HUD or pause/countdown cover")
				report.themes[theme] = {"content_hash":track.content_hash,"view":view,"focus":[focus.x,focus.y],"inventory":inventory,"wind_materials":wind.surface_materials.size() if wind != null else 0,"wind_bindings":wind.surface_bindings.size() if wind != null else 0,"stages":stages}
				FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		for entry: Dictionary in entries: entry.node.material_override = entry.original
		game.queue_free()
		await process_frame
	print("WINTER_RENDER_AUDIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func measure(viewport: RID, duration: float) -> Dictionary:
	var frames: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	while Time.get_ticks_usec()-start < duration*1000000.0:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		previous = now
	return {"samples":frames.size(),"frame_ms":quantiles(frames),"gpu_ms":quantiles(gpu),"render_cpu_ms":quantiles(cpu),"viewport":[root.size.x,root.size.y],"scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}

func quantiles(values: Array[float]) -> Dictionary:
	values.sort()
	return {"p50":values[values.size()/2],"p95":values[mini(values.size()-1,floori(values.size()*0.95))],"max":values[-1]}

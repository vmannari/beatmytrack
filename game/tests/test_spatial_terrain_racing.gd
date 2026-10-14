extends "res://tests/test_winter_snow_wind.gd"
## Same-instance pixel/work comparison. No account, records, simulation or uploads.
var folder: String = "res://../build/spatial-terrain-2026-10-13"
var terrain_entries: Array[Dictionary] = []
var chunk_entries: Array[Dictionary] = []
var report: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)

func compare(a: Image, b: Image) -> Dictionary:
	var left: PackedByteArray = a.get_data()
	var right: PackedByteArray = b.get_data()
	var changed: int = 0
	var maximum: int = 0
	var examples: Array = []
	for pixel: int in range(a.get_width()*a.get_height()):
		var different: bool = false
		for channel: int in range(3):
			var delta: int = absi(int(left[pixel*4+channel])-int(right[pixel*4+channel]))
			maximum = maxi(maximum,delta)
			if delta > 2 and examples.size() < 12: examples.append([pixel%a.get_width(),pixel/a.get_width(),channel,delta])
			different = different or delta > 0
		if different: changed += 1
	return {"changed":changed,"max_delta":maximum,"examples":examples}

func settle() -> void:
	for frame: int in range(10): await RenderingServer.frame_post_draw

func capture_frame(tag: String) -> Image:
	await create_timer(0.3).timeout
	await settle()
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	if not tag.is_empty(): image.save_png(folder.path_join(tag+".png"))
	return image

func prepare_terrain(visual: NativeTrackVisual) -> void:
	var seen: Dictionary = {}
	for node: Node in visual.get_children():
		if not node is MeshInstance3D: continue
		var material: ShaderMaterial = node.material_override as ShaderMaterial
		if material == null or material.get_shader_parameter("surface_low") == null: continue
		if seen.has(material.get_instance_id()): continue
		seen[material.get_instance_id()] = true
		var dynamic: ShaderMaterial = material.get_meta("surface_dynamic_material")
		var base_source: String = dynamic.shader.code
		var before: String = FileAccess.get_file_as_string("res://tests/fixtures/spatial_terrain_before/terrain.gdshaderinc")
		var old_shader := Shader.new()
		old_shader.code = base_source.replace('#include "res://track/terrain.gdshaderinc"',before)
		material.shader = old_shader
		SurfaceShaderVariants.specialize(material)
		var original_shader: Shader = material.shader
		var low: Image = material.get_shader_parameter("surface_low").get_image()
		var high: Image = material.get_shader_parameter("surface_high").get_image()
		var packed: bool = material.get_shader_parameter("terrain_packed") == true
		var slots: Vector4i = material.get_shader_parameter("terrain_slots")
		var kinds := PackedByteArray()
		kinds.resize(low.get_width()*low.get_height())
		for y: int in range(low.get_height()):
			for x: int in range(low.get_width()):
				var a: Color = low.get_pixel(x,y)
				var b: Color = high.get_pixel(x,y)
				for channel: int in range(4):
					if a[channel] > 0.5: kinds[y*low.get_width()+x] = slots[channel] if packed else channel
					if not packed and b[channel] > 0.5: kinds[y*low.get_width()+x] = channel+4
		var regions: Dictionary = TerrainUniformRegions.build(kinds,low.get_width(),low.get_height(),slots if packed else Vector4i(-1,-1,-1,-1))
		var original_high: Texture2D = material.get_shader_parameter("surface_high")
		var original_low: Texture2D = material.get_shader_parameter("surface_low")
		var high_present: bool = material.get_shader_parameter("terrain_high_present") == true
		TerrainUniformRegions.bind(material,high,regions,high_present)
		material.shader = dynamic.shader
		SurfaceShaderVariants.specialize(material)
		terrain_entries.append({"material":material,"before":original_shader,"after":material.shader,"high_before":original_high,"high_after":material.get_shader_parameter("surface_high"),"low_before":original_low,"low_after":material.get_shader_parameter("surface_low"),"enabled":material.get_shader_parameter("terrain_uniform_enabled"),"eligible":regions.eligible,"cells":regions.cells})

func prepare_chunks(visual: NativeTrackVisual) -> void:
	for node: Node in visual.get_children():
		if not node is MeshInstance3D: continue
		var material: Material = node.material_override
		var eligible: bool = material is BaseMaterial3D and material.vertex_color_use_as_albedo
		eligible = eligible or node.name in ["LowCover","DesertLowCover"]
		if material is ShaderMaterial:
			eligible = eligible or (visual.theme_id == "winter" and material.shader.code.contains("smooth_road_bank"))
			eligible = eligible or (visual.theme_id == "desert" and material.get_shader_parameter("gravel") == true)
		if not eligible: continue
		visual.remove_child(node)
		var chunks: Array[MeshInstance3D] = SpatialMeshChunks.add(visual,node,true,true)
		if chunks.size() <= 1: continue
		var before: int = node.mesh.surface_get_array_index_len(0)
		if before == 0: before = node.mesh.surface_get_array_len(0)
		var after: int = 0
		for chunk: MeshInstance3D in chunks: after += chunk.mesh.surface_get_array_index_len(0)
		check(before == after,"chunked mesh retains every triangle")
		chunk_entries.append({"original":node,"chunks":chunks,"parent":visual})

func mode(mask: bool, chunks: bool) -> void:
	for entry: Dictionary in terrain_entries:
		entry.material.shader = entry.after if mask else entry.before
		entry.material.set_shader_parameter("surface_high",entry.high_after if mask else entry.high_before)
		entry.material.set_shader_parameter("surface_low",entry.low_after if mask else entry.low_before)
		entry.material.set_shader_parameter("terrain_uniform_enabled",mask and entry.enabled)
	for entry: Dictionary in chunk_entries:
		entry.original.call("set_spatial_draws_enabled",chunks)
		if chunks: entry.original.call("_process",0.2)

func sample(seconds: float) -> Dictionary:
	await settle()
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	var start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec()-start < seconds*1000000.0:
		await process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	gpu.sort(); cpu.sort(); draws.sort(); primitives.sort()
	return {"gpu_ms":gpu[gpu.size()/2],"render_cpu_ms":cpu[cpu.size()/2],"draws":draws[draws.size()/2],"primitives":primitives[primitives.size()/2],"samples":gpu.size()}

func run() -> void:
	var themes: Array[String] = ["pine","desert","winter","storm","night_city"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--themes="): themes.assign(argument.trim_prefix("--themes=").split(","))
	folder = folder.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1600,900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	var template: Dictionary = make_track().metadata.creator_document.duplicate(true)
	report = {"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"kit":NativeTrackVisual.VERSION,"themes":{},"note":"Frozen same-instance scenery/banks/terrain fixture; component work/timing, not phone FPS. Archived pre-task terrain include, approved current lighting/artwork, no race/account/records adapters."}
	for theme: String in themes:
		var document: Dictionary = template.duplicate(true)
		document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		var original_cells: PackedInt32Array = track.cells.duplicate()
		var world := Node3D.new()
		root.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.shadow_enabled = true
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = 65.0
		world.add_child(light)
		TrackTheme.apply_lighting(theme,environment.environment,light)
		var visual := NativeTrackVisual.new()
		visual.partition_static_meshes = false
		visual.uniform_terrain_regions = false
		visual.cache_road_meshes = false
		visual.persist_road_meshes = false
		world.add_child(visual)
		await visual.build(track,BridgePresentation.new(track))
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 46
		world.add_child(camera)
		terrain_entries.clear(); chunk_entries.clear()
		prepare_terrain(visual)
		prepare_chunks(visual)
		await create_timer(1.0).timeout
		var proofs: Array[Dictionary] = []
		for view: int in range(3):
			var point: Vector2 = track.route[view*track.route.size()/3]
			camera.position = VisualGeometry.world(point)+Vector3(0,36,27)
			camera.look_at(VisualGeometry.world(point))
			mode(false,false)
			var before: Image = await capture_frame(theme+"-"+str(view)+"-before")
			for stage: Vector2i in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				mode(stage.x != 0,stage.y != 0)
				var after: Image = await capture_frame(theme+"-"+str(view)+"-"+str(stage.x)+str(stage.y))
				var proof: Dictionary = compare(before,after)
				proof.stage = [stage.x,stage.y]
				proof.view = view
				proofs.append(proof)
				check(proof.max_delta <= 2,theme+" exact artwork within 2/255 for "+str(stage))
				print("SPATIAL_TERRAIN_PIXELS ",theme," ",proof)
			mode(false,false)
			check(compare(before,await capture_frame("")).changed == 0,theme+" baseline restoration is stable")
		var stages: Array[Dictionary] = []
		for setting: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1)]:
			mode(setting.x != 0,setting.y != 0)
			var value: Dictionary = await sample(0.6)
			value.mode = [setting.x,setting.y]
			stages.append(value)
			print("SPATIAL_TERRAIN_STAGE ",theme," ",value)
		var eligible: int = 0
		var cells: int = 0
		for entry: Dictionary in terrain_entries: eligible += entry.eligible; cells += entry.cells
		check(track.cells == original_cells,theme+" canonical cells unchanged")
		report.themes[theme] = {"uniform_cells":eligible,"cells":cells,"chunked_roles":chunk_entries.size(),"proofs":proofs,"stages":stages}
		FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		mode(false,false)
		for entry: Dictionary in chunk_entries:
			for part: MeshInstance3D in entry.chunks: part.free()
		world.queue_free()
		await process_frame
	print("SPATIAL_TERRAIN_RACING ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

extends SceneTree
## Regional CPU results against the independent uncached builder, plus real
## upload scheduling, rendered equivalence and selection/navigation fences.
const ROADS = preload("res://editor/road_preparation.gd")
const SECTIONS = preload("res://editor/road_sections.gd")
var checks: int = 0
var failures: int = 0
var observations: Array = []
var frozen_wind_shaders: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func fixture(theme: String) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank(); doc.theme = theme; doc.id = "editor_sections_"+theme
	var straight: Dictionary = RoadPieces.create("straight",Vector2(-24,-16),0.0,6.0); straight.length = 16.0
	var crossing: Dictionary = RoadPieces.create("straight",Vector2(-16,-24),90.0,6.0); crossing.length = 18.0
	var neighbour: Dictionary = RoadPieces.create("curve",Vector2(-8,-16),0.0,6.0); neighbour.radius = 8.0
	var distant: Dictionary = RoadPieces.create("straight",Vector2(60,60),0.0,6.0); distant.length = 12.0
	doc.pieces = [straight,crossing,neighbour,distant]
	return doc

func clear_packets() -> void:
	ROADS.guard.lock(); ROADS.entries.clear(); ROADS.bytes = 0; ROADS.guard.unlock()

func packet(track: NativeTrack) -> Dictionary:
	var job = preload("res://editor/work_job.gd").start(ROADS.run.bind(track),self)
	while not job.done: await process_frame
	check(job.result is Dictionary and not job.result.get("parts",[]).is_empty(),"worker completes CPU road packet")
	return job.result

func uncached(track: NativeTrack) -> Array:
	var builder := NativeTrackVisual.new()
	builder.theme_id = track.metadata.theme; builder.colors = TrackTheme.palette(builder.theme_id)
	builder._capture_road_arrays = true; builder.cache_road_meshes = false; builder.persist_road_meshes = false
	await builder._build_creator_roads(track)
	if builder.theme_id == "desert":
		var relief = preload("res://track/desert_road_relief.gd").new(track)
		for part: Dictionary in builder._prepared_road_parts:
			if part.role != "road": continue
			part.arrays = relief.prepare_arrays(Callable(),[ROADS.unpack_intermediate(part.arrays,true)],Transform3D.IDENTITY,true)[0]
	var result: Array = builder._prepared_road_parts; builder.free(); return result

func triangles(parts: Array) -> Dictionary:
	var result: Dictionary = {}
	for part: Dictionary in parts:
		# Compare final engine encoding too, including packed normals/colours.
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.arrays)
		var arrays: Array = mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		for first: int in range(0,count,3):
			var triangle: Array = [part.role,part.get("arguments",[])]
			for cursor: int in range(first,first+3):
				var i: int = indices[cursor] if not indices.is_empty() else cursor
				for channel: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]: triangle.append(arrays[channel][i] if arrays[channel] != null else null)
			var key: String = SECTIONS.digest(triangle); result[key] = int(result.get(key,0))+1
	return result

func cpu(theme: String) -> void:
	var doc: Dictionary = fixture(theme)
	var track: NativeTrack = TrackCompiler.compile(doc)
	clear_packets()
	var first: Dictionary = await packet(track)
	var expected: Array = await uncached(track)
	check(triangles(first.parts) == triangles(expected),theme+" regional geometry equals original uncached triangles and attributes")
	var old_keys: Dictionary = {}
	for part: Dictionary in first.parts: old_keys[part.mesh_key] = true
	doc.pieces[0].width = 7.0
	track = TrackCompiler.compile(doc)
	var began: int = Time.get_ticks_usec()
	clear_packets()
	var edited: Dictionary = await packet(track)
	var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
	var reused: int = 0
	for part: Dictionary in edited.parts:
		if old_keys.has(part.mesh_key): reused += 1
	check(reused > 0,theme+" distant mesh sections survive local road edit")
	check(edited.section_hits > 0,theme+" local edit reuses CPU sections")
	check(int(edited.reused.get("piece",0)) > 0 and int(edited.rebuilt.get("piece",0)) < doc.pieces.size(),theme+" local edit rebuilds fewer than all road sections")
	check(triangles(edited.parts) == triangles(await uncached(track)),theme+" crossing/join edit equals independent fresh geometry")
	check(ROADS.bytes+ROADS.section_bytes+ROADS.gpu_bytes <= ROADS.BUDGET,theme+" total CPU and GPU cache stays bounded")
	for part: Dictionary in edited.parts: check(part.arrays[Mesh.ARRAY_VERTEX].size() <= SECTIONS.UPLOAD_VERTICES,theme+" uploads have bounded vertex counts")
	observations.append({"theme":theme,"edit_ms":elapsed,"hits":edited.section_hits,"misses":edited.section_misses,"reused_meshes":reused,"parts":edited.parts.size(),"reused":edited.reused,"rebuilt":edited.rebuilt})
	print("EDITOR_SECTIONS ",JSON.stringify(observations.back()))
	# Inserting a distant piece reindexes every existing piece. Cache identity
	# follows geometry; current crossing ownership and phase indices are rebound.
	var inserted: Dictionary = RoadPieces.create("straight",Vector2(-75,65),0.0,6.0); inserted.length = 8.0
	doc.pieces.push_front(inserted); track = TrackCompiler.compile(doc); clear_packets()
	var reordered: Dictionary = await packet(track)
	check(int(reordered.reused.get("piece",0)) > 0,theme+" distant insertion retains section identities")
	check(triangles(reordered.parts) == triangles(await uncached(track)),theme+" reordered sections retain exact crossing ownership and decoration limits")
	if theme == "desert":
		doc.pieces[1].length = 18.0; track = TrackCompiler.compile(doc); clear_packets()
		var phases: Dictionary = await packet(track)
		check(triangles(phases.parts) == triangles(await uncached(track)),"connected Desert UV phase changes invalidate dependent sections")
	# Obsolete workers must not poison a later build with partial geometry.
	doc.pieces[1].width = 8.0; track = TrackCompiler.compile(doc); clear_packets()
	var calls: Dictionary = {"count":0}
	var aborted: Dictionary = ROADS.run(func() -> bool:
		calls.count += 1; return calls.count >= 6,track)
	check(aborted.get("parts",[]).is_empty(),theme+" mid-build cancellation discards partial packet")
	clear_packets()
	var resumed: Dictionary = await packet(track)
	check(triangles(resumed.parts) == triangles(await uncached(track)),theme+" cancelled work cannot populate stale section results")

func rendered(theme: String) -> void:
	var world := EditorWorld.new(); world.theme_id = theme; root.add_child(world)
	world.size = Vector2(960,640)
	var canvas := EditorCanvas.new(); canvas.document = fixture(theme); root.add_child(canvas); canvas.size = Vector2(960,640)
	world.follow_canvas(canvas)
	var track: NativeTrack = TrackCompiler.compile(canvas.document)
	world.show_track(track)
	while world._building: await process_frame
	check(not canvas.preparing,"editor input opens after material preparation")
	check(DisplayServer.get_name() == "headless" or world.materials_warmed > 0,"renderer draws representative biome materials before editing")
	check(world.visual.road_uploads > 0,"actual editor installs section meshes")
	check(world.visual.install_yields > 0,"actual installation spans multiple frames")
	check(world.visual.install_peak_vertices <= NativeTrackVisual.INSTALL_VERTEX_BUDGET,"actual scene installation respects its shared per-frame vertex budget")
	var warm_kind: String = "egypt_column" if theme == "desert" else "igloo" if theme == "winter" else "container"
	world.warm_prop(warm_kind,1.0,ContainerPaint.DEFAULT)
	while world._prop_job != null or not world._prop_request.is_empty(): await process_frame
	var previous_meshes: int = CreatorPropVisual.meshes.size()
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	CreatorPropVisual.append(tool,world.visual,warm_kind,Vector3.ZERO,1.0,0.0,-1.0,ContainerPaint.DEFAULT)
	check(CreatorPropVisual.meshes.size() == previous_meshes,"selected prop placement consumes the prepared model")
	check(CreatorPropVisual.cache_bytes <= CreatorPropVisual.CACHE_BUDGET,"prop cache remains bounded")
	if DisplayServer.get_name() != "headless":
		world.visual.process_mode = Node.PROCESS_MODE_DISABLED
		freeze_wind(world.visual)
		world.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var reference := NativeTrackVisual.new(); reference.process_mode = Node.PROCESS_MODE_DISABLED; reference.editor_preview = true; reference.cache_road_meshes = false; reference.persist_road_meshes = false; reference.prepare_editor_roads = false; reference.hide()
		world.world.add_child(reference); await reference.build(track,BridgePresentation.new(track),true)
		freeze_wind(reference)
		await settle_pipelines(world,world.visual,reference)
		world.visual.show(); reference.hide()
		for frame: int in range(5): await RenderingServer.frame_post_draw
		var actual: Image = world.viewport.get_texture().get_image()
		world.visual.hide(); reference.show()
		for frame: int in range(5): await RenderingServer.frame_post_draw
		var expected: Image = world.viewport.get_texture().get_image()
		check(actual.get_data() == expected.get_data(),theme+" sectioned editor pixels equal original uncached geometry")
		var folder: String = ProjectSettings.globalize_path("res://../build/editor-improvements/"+RenderingServer.get_current_rendering_method())
		DirAccess.make_dir_recursive_absolute(folder); actual.save_png(folder+"/"+theme+"-sections.png"); expected.save_png(folder+"/"+theme+"-uncached.png")
	world.warm_prop(warm_kind,1.0,"#8b4134")
	for frame: int in range(4):
		if world._prop_job != null: break
		await process_frame
	world.warm_prop("rock")
	world.queue_free(); canvas.queue_free(); await process_frame
	while not preload("res://editor/work_job.gd").pending.is_empty(): await process_frame
	check(preload("res://editor/work_job.gd").pending.is_empty(),"leaving reaps selection preparation workers")

func freeze_wind(source: Node) -> void:
	# The pinned build has no RenderingServer shader-time override. Hold the
	# original grass-wind expression at one common time for static comparisons.
	for node: Node in source.find_children("*","GeometryInstance3D",true,false):
		var material: ShaderMaterial = node.material_override as ShaderMaterial
		if material == null or not material.shader.code.contains("TIME"): continue
		var fixed: ShaderMaterial = material.duplicate()
		var code: String = material.shader.code.replace("TIME","0.0")
		if not frozen_wind_shaders.has(code):
			var shader := Shader.new(); shader.code = code; frozen_wind_shaders[code] = shader
		fixed.shader = frozen_wind_shaders[code]
		node.material_override = fixed

func settle_pipelines(world: EditorWorld, current: NativeTrackVisual, original: NativeTrackVisual) -> void:
	# Both static scenes must have submitted their pipelines before comparing.
	# Mobile may replace an ubershader with its optimized specialization later.
	var quiet: int = 0
	var previous: float = -1.0
	for round: int in range(30):
		for scene: NativeTrackVisual in [current,original]:
			current.visible = scene == current; original.visible = scene == original
			for frame: int in range(2): await RenderingServer.frame_post_draw
		var count: float = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		quiet = quiet+1 if count == previous else 0; previous = count
		if round >= 4 and quiet >= 4: break
	check(quiet >= 4,"renderer pipeline counters settle before exact static comparisons")

func prop_triangles(source: Node3D) -> Dictionary:
	var parts: Array = []
	for child: Node in source.find_children("*","MeshInstance3D",true,false):
		if child.is_in_group("contact_lighting"): continue
		for surface: int in range(child.mesh.get_surface_count()):
			parts.append({"role":"prop","arrays":child.mesh.surface_get_arrays(surface)})
	return triangles(parts)

func large_props() -> void:
	var track := NativeTrack.new()
	var objects: Array = []
	for i: int in range(8): objects.append({"kind":"container","position":[-12.0+(i%4)*7.0,-8.0+(i/4)*8.0],"rotation":0.0,"color":ContainerPaint.DEFAULT})
	track.metadata = {"theme":"pine","creator_document":{"objects":objects},"scenery_objects":[]}
	var original := NativeTrackVisual.new(); original.theme_id = "pine"; original.colors = TrackTheme.palette("pine")
	var current := NativeTrackVisual.new(); current.theme_id = "pine"; current.colors = original.colors
	root.add_child(original); root.add_child(current)
	await original._build_placed_objects(track)
	await current.refresh_editor_objects(track,false,true)
	check(prop_triangles(original) == prop_triangles(current),"large sliced prop uploads retain every original triangle and attribute")
	check(current.editor_objects.install_peak_vertices <= NativeTrackVisual.INSTALL_VERTEX_BUDGET,"large prop uploads respect the shared per-frame budget")
	original.free(); current.free()

func reserve_installs(visual: NativeTrackVisual, observation: Dictionary) -> void:
	for i: int in range(2):
		if not await visual._budget_install(SECTIONS.UPLOAD_VERTICES): break
		var frame: int = Engine.get_process_frames()
		observation.frames[frame] = int(observation.frames.get(frame,0))+SECTIONS.UPLOAD_VERTICES
	observation.done += 1

func concurrent_installs() -> void:
	var visual := NativeTrackVisual.new(); visual._menu_slices = true; root.add_child(visual)
	var observation: Dictionary = {"frames":{},"done":0}
	for i: int in range(3): reserve_installs(visual,observation)
	while observation.done < 3: await process_frame
	check(observation.frames.size() >= 3,"concurrent scene installers share frame capacity")
	for vertices: int in observation.frames.values(): check(vertices <= NativeTrackVisual.INSTALL_VERTEX_BUDGET,"concurrent installers cannot reset another installer's frame budget")
	visual.free()

func run() -> void:
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	if "--fallback" in OS.get_cmdline_user_args():
		preload("res://track/geometry_acceleration.gd").enabled = false
		preload("res://track/geometry_acceleration.gd").roads_enabled = false
	root.size = Vector2i(960,640)
	for theme: String in TrackTheme.IDS:
		if "--pine" in OS.get_cmdline_user_args() and theme != "pine": continue
		if "--desert" in OS.get_cmdline_user_args() and theme != "desert": continue
		if "--winter" in OS.get_cmdline_user_args() and theme != "winter": continue
		await cpu(theme)
	for theme: String in TrackTheme.IDS:
		if "--pine" in OS.get_cmdline_user_args() and theme != "pine": continue
		if "--desert" in OS.get_cmdline_user_args() and theme != "desert": continue
		if "--winter" in OS.get_cmdline_user_args() and theme != "winter": continue
		await rendered(theme)
	await large_props()
	await concurrent_installs()
	var folder: String = ProjectSettings.globalize_path("res://../build/editor-improvements")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder+"/"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name()+("-fallback" if "--fallback" in OS.get_cmdline_user_args() else "")+"-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t")); file.close()
	print("EDITOR_PREPARATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

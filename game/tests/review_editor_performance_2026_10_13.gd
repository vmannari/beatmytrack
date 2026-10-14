extends SceneTree
## Review observations only. Uses disposable workspace storage and real editor paths.

var evidence: String
var observations: Array[Dictionary] = []
var app: Node
var failures: int = 0

class ReadCountingLibrary extends TrackLibrary:
	var reads: int = 0
	func _read(path: String) -> Dictionary:
		reads += 1
		return super._read(path)

class StageVisual extends NativeTrackVisual:
	var stages: Dictionary = {}
	func _build_terrain(track: NativeTrack) -> void:
		var began: int = Time.get_ticks_usec()
		await super._build_terrain(track)
		stages["terrain_ms"] = (Time.get_ticks_usec()-began)/1000.0
	func _build_creator_roads(track: NativeTrack) -> void:
		var began: int = Time.get_ticks_usec()
		await super._build_creator_roads(track)
		stages["roads_ms"] = (Time.get_ticks_usec()-began)/1000.0
	func _build_barriers(track: NativeTrack) -> void:
		var began: int = Time.get_ticks_usec()
		await super._build_barriers(track)
		stages["barriers_ms"] = (Time.get_ticks_usec()-began)/1000.0
	func refresh_editor_objects(track: NativeTrack, refresh_cover: bool = true, sliced: bool = false) -> void:
		var began: int = Time.get_ticks_usec()
		await super.refresh_editor_objects(track,refresh_cover,sliced)
		stages["objects_and_cover_ms"] = (Time.get_ticks_usec()-began)/1000.0

func _initialize() -> void:
	call_deferred("run")

func observe(label: String, values: Dictionary) -> void:
	values["operation"] = label
	observations.append(values)
	print("EDITOR_REVIEW_20261013 ", JSON.stringify(values))

func require(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func measure(label: String, action: Callable, count: int = 5) -> void:
	var samples: Array[float] = []
	for index: int in range(count):
		var began: int = Time.get_ticks_usec()
		action.call()
		samples.append((Time.get_ticks_usec()-began)/1000.0)
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	observe(label,{"samples_ms":samples,"median_ms":ordered[ordered.size()/2],"max_ms":ordered[-1]})

func circuit(count: int) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "review_%d" % count
	doc.name = "Performance review %d" % count
	var position := Vector2(-47,-36)
	var heading: float = 0.0
	for side: int in range(2):
		for index: int in range((count-2)/2):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,6)
			piece.length = 94.0/float((count-2)/2)
			doc.pieces.append(piece)
			position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,6)
		turn.radius = 36.0
		doc.pieces.append(turn)
		var pose: Dictionary = RoadPieces.end_pose(turn)
		position = pose.position
		heading = pose.heading
	var result: Dictionary = RoadPieces.route_from_pieces(doc)
	require(result.ok,"connected circuit is valid")
	return result.document

func props(count: int, kind: String) -> Array:
	var result: Array = []
	for index: int in range(count):
		result.append({"kind":kind,"position":[-42.0+(index%12)*7.0,-26.0+(index/12)*7.0],"rotation":float(index%4)*90.0})
	return result

func persistence(doc: Dictionary, label: String) -> void:
	var library := ReadCountingLibrary.new(evidence.path_join("storage_"+label))
	require(library.save_document(doc) == OK,"first local write succeeds")
	library.reads = 0
	measure(label+"_save_original",func() -> void: require(library.save_document(doc) == OK,"repeated local write succeeds"))
	observe(label+"_save_reads",{"direct_library_read_calls_per_save":float(library.reads)/5.0,"json_bytes":JSON.stringify(doc,"\t",true).to_utf8_buffer().size()})
	measure(label+"_save_wip",func() -> void: require(library.save_wip(doc) == OK,"WIP write succeeds"))
	measure(label+"_load",func() -> void: require(not library.load_document(doc.id).is_empty(),"local read succeeds"))
	var expected: Dictionary = JSON.parse_string(JSON.stringify(doc,"\t",true))
	require(library.load_document(doc.id) == expected,"durable content matches serialized numeric representation")

func authored_batch(kind: String, count: int) -> void:
	var target := NativeTrack.new()
	target.metadata = {"creator_document":{"objects":props(count,kind)},"scenery_objects":[]}
	target.tyre_origins = LooseTyres.positions(target.metadata.creator_document)
	var samples: Array[float] = []
	var nodes: int = 0
	var triangles: int = 0
	for repeat: int in range(3):
		var visual := NativeTrackVisual.new()
		visual.theme_id = "pine"
		visual.colors = TrackTheme.palette("pine")
		visual.editor_preview = true
		root.add_child(visual)
		var began: int = Time.get_ticks_usec()
		await visual.refresh_editor_objects(target,false,false)
		samples.append((Time.get_ticks_usec()-began)/1000.0)
		nodes = visual.find_children("*","MeshInstance3D",true,false).size()+visual.find_children("*","MultiMeshInstance3D",true,false).size()
		triangles = 0
		for node: Node in visual.find_children("*","MeshInstance3D",true,false):
			for surface: int in range(node.mesh.get_surface_count()):
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
		visual.free()
		await process_frame
	observe("authored_batch",{"kind":kind,"objects":count,"samples_ms":samples,"mesh_nodes":nodes,"mesh_triangles_excluding_multimesh":triangles})

func settle(label: String) -> void:
	var began: int = Time.get_ticks_usec()
	var deadline: int = Time.get_ticks_msec()+60000
	var frames: Array[float] = []
	while (app.editor_preview_thread != null or app.editor_world._building) and Time.get_ticks_msec()<deadline:
		var frame_start: int = Time.get_ticks_usec()
		await process_frame
		frames.append((Time.get_ticks_usec()-frame_start)/1000.0)
	var completed: bool = app.editor_preview_thread == null and not app.editor_world._building
	require(completed,"editor settles before deadline")
	frames.sort()
	observe(label,{"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"completed":completed,"frame_count":frames.size(),"p95_interval_ms":frames[mini(frames.size()-1,floori(frames.size()*0.95))] if not frames.is_empty() else 0.0,"max_interval_ms":frames[-1] if not frames.is_empty() else 0.0})
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func generation(doc: Dictionary, theme_id: String) -> void:
	var source: Dictionary = doc.duplicate(true)
	source.theme = theme_id
	var cache: Dictionary = {"enabled":true}
	var track: NativeTrack
	for repeat: int in range(3):
		source.name = "Compile review %d" % repeat
		var began: int = Time.get_ticks_usec()
		track = TrackCompiler.compile(source,cache)
		require(track != null,"compile fixture succeeds")
		observe("compile",{"theme":theme_id,"repeat":repeat,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"cells":track.cells.size(),"raster_reused":repeat > 0})
	var visual := StageVisual.new()
	visual.editor_preview = true
	visual.visible = false
	visual.cache_road_meshes = false
	root.add_child(visual)
	var began: int = Time.get_ticks_usec()
	await visual.build(track,BridgePresentation.new(track),true)
	visual.stages["theme"] = theme_id
	visual.stages["elapsed_ms"] = (Time.get_ticks_usec()-began)/1000.0
	observe("sliced_geometry_build",visual.stages)
	visual.free()
	await process_frame

func draw_measurements() -> void:
	if DisplayServer.get_name() == "headless": return
	var viewport_rid: RID = app.editor_world.viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	for frame: int in range(90):
		app.canvas.pan += Vector2(0.25,0)
		app.canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		if frame >= 30:
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
	cpu.sort()
	gpu.sort()
	observe("editor_pan_render",{"frames":gpu.size(),"cpu_median_ms":cpu[cpu.size()/2],"gpu_median_ms":gpu[gpu.size()/2],"gpu_p95_ms":gpu[floori(gpu.size()*0.95)],"scope":"editor 3D subviewport only; excludes canvas and main viewport; RTX3090 desktop"})

func run() -> void:
	var evidence_root: String = ProjectSettings.globalize_path("res://").path_join("../build/editor-review-2026-10-13").simplify_path()
	evidence = evidence_root.path_join(TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	observe("environment",{"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"fixture_storage":evidence})
	var large: Dictionary = circuit(96)
	var painted: Dictionary = large.duplicate(true)
	painted.id = "review_painted"
	for stroke: int in range(32):
		var points: Array = []
		for index: int in range(512): points.append([-100.0+index*0.39,-100.0+stroke*6.0])
		painted.paint.append({"surface":2,"width":2.0,"shape":"round","points":points})
	require(TrackDocument.validate(painted,false).is_empty(),"maximum paint point fixture is valid")
	for fixture: Dictionary in [{"label":"small","doc":circuit(4)},{"label":"large","doc":large},{"label":"painted_16384","doc":painted}]:
		var doc: Dictionary = fixture.doc
		var label: String = fixture.label
		measure(label+"_validate",func() -> void: TrackDocument.validate(doc))
		measure(label+"_fingerprint",func() -> void: TrackLibrary.draft_fingerprint(doc))
		measure(label+"_route_data",func() -> void: TrackDocument.route_data(doc))
		measure(label+"_route_from_pieces",func() -> void: RoadPieces.route_from_pieces(doc))
		measure(label+"_joins",func() -> void: RoadPieces.joins(doc.pieces))
		if label != "painted_16384": persistence(doc,label)
	# The point-count contract permits more pretty-printed bytes than storage.
	var oversized := TrackLibrary.new(evidence.path_join("oversized"))
	var oversized_result: Error = oversized.save_document(painted)
	observe("painted_16384_storage_limit",{"save_error":oversized_result,"message":oversized.last_error,"pretty_json_bytes":JSON.stringify(painted,"\t",true).to_utf8_buffer().size(),"compact_json_bytes":JSON.stringify(painted,"",true).to_utf8_buffer().size()})
	require(oversized_result == ERR_INVALID_DATA,"oversized write is rejected honestly")
	var savable_paint: Dictionary = painted.duplicate(true)
	savable_paint.id = "review_savable_paint"
	savable_paint.paint = savable_paint.paint.slice(0,16)
	persistence(savable_paint,"painted_8192")
	var listing := TrackLibrary.new(evidence.path_join("listing"))
	for count: int in [16,64,128]:
		for index: int in range(count):
			var path: String = listing.directory.path_join("draft_%03d.json" % index)
			if FileAccess.file_exists(path): continue
			var copy: Dictionary = large.duplicate(true)
			copy.id = "draft_%03d" % index
			require(listing.save_document(copy) == OK,"listing fixture writes")
			require(listing.save_wip(copy) == OK,"listing WIP fixture writes")
		measure("editable_entries_%d_saved_and_wip" % count,func() -> void: require(listing.editable_entries().size() == count,"listing deduplicates versions"),3)
	for kind: String in ["tyre_stack","tree","container"]:
		for count: int in [1,24,95]: await authored_batch(kind,count)
	for biome: String in ["pine","desert","winter"]: await generation(large,biome)
	var folder: String = evidence.path_join("app_storage")
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder+"/records.json")
	app.cloud_root_override = folder+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	large.objects = props(24,"container")
	app.document = large.duplicate(true)
	app.editor_view.clear()
	var began: int = Time.get_ticks_usec()
	app.call("_show_screen","create")
	observe("large_editor_open_handler",{"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0})
	await settle("large_editor_open_settle")
	for kind: String in ["tyre_stack","tree","water"]:
		var previous: NativeTrackVisual = app.editor_world.visual
		var before: NativeTrack = app.canvas.native_preview
		app.canvas.mode = "place"
		app.canvas.stamp_kind = kind
		began = Time.get_ticks_usec()
		app.canvas._place(app.canvas.to_screen(Vector2(0,5)))
		observe("placement_handler",{"kind":kind,"existing_objects":app.document.objects.size()-1,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0})
		await settle("placement_"+kind+"_settle")
		var after: NativeTrack = app.canvas.native_preview
		observe("placement_reuse",{"kind":kind,"same_visual":previous == app.editor_world.visual,"same_cells":before.cells == after.cells,"same_extent":before.half_extent == after.half_extent,"same_deck":before.deck_cells == after.deck_cells,"same_ground":app.editor_world._same_ground(before,after)})
	# A second Save of an unchanged document follows the real UI path as well.
	for repeat: int in range(2):
		began = Time.get_ticks_usec()
		require(app.call("_save_track_now"),"explicit editor Save succeeds")
		observe("explicit_editor_save",{"repeat":repeat,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0})
		for dialog: Node in app.root_ui.find_children("*","AcceptDialog",true,false): dialog.queue_free()
		await settle("explicit_editor_save_settle")
	await draw_measurements()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence.path_join("editor.png"))
	app.queue_free()
	await process_frame
	var output := FileAccess.open(evidence.path_join("observations.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures":failures,"observations":observations},"\t"))
	output.close()
	var latest := FileAccess.open(evidence_root.path_join("latest.json"),FileAccess.WRITE)
	latest.store_string(JSON.stringify({"evidence":evidence,"failures":failures},"\t"))
	latest.close()
	print("EDITOR_REVIEW_COMPLETED failures=",failures)
	quit(1 if failures else 0)

extends SceneTree
const PREPARATION = preload("res://editor/road_preparation.gd")
const CACHE = preload("res://persistence/document_read_cache.gd")
var checks: int = 0
var failures: int = 0
var evidence: String
var metrics: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func metric(name: String, started: int) -> void:
	var entry: Dictionary = {"operation":name,"ms":(Time.get_ticks_usec()-started)/1000.0}
	metrics.append(entry); print("EDITOR_LOADING_ROADS ",JSON.stringify(entry))

func circuit(count: int = 96) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "loading_roads"; doc.name = "Loading roads"
	var position := Vector2(-47,-36); var heading: float = 0.0
	for side: int in range(2):
		for index: int in range((count-2)/2):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,6)
			piece.length = 94.0/float((count-2)/2); doc.pieces.append(piece); position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,6); turn.radius = 36.0; doc.pieces.append(turn)
		var pose: Dictionary = RoadPieces.end_pose(turn); position = pose.position; heading = pose.heading
	return RoadPieces.route_from_pieces(doc).document

func mesh_digest(visual: Node3D) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	for node: Node in visual.get_children():
		if not node is MeshInstance3D: continue
		context.update(var_to_bytes(node.mesh.surface_get_arrays(0)))
	return context.finish().hex_encode()

func roads(theme_id: String) -> void:
	var doc: Dictionary = circuit(); doc.theme = theme_id
	var track: NativeTrack = TrackCompiler.compile(doc)
	track.editor_overlay_mask = CreatorPreviewMasks.overlay(track,doc.paint)
	track.editor_road_mask = CreatorPreviewMasks.road(track)
	var original := NativeTrackVisual.new(); original.theme_id = theme_id; original.colors = TrackTheme.palette(theme_id)
	original.editor_preview = true
	original.cache_road_meshes = false; original.persist_road_meshes = false; original.prepare_editor_roads = false
	var current := NativeTrackVisual.new(); current.theme_id = theme_id; current.colors = original.colors
	original.name = "OriginalRoads"; current.name = "PreparedRoads"
	current.cache_road_meshes = false; current.persist_road_meshes = false; current.editor_preview = true
	var viewport := SubViewport.new(); viewport.size = Vector2i(1280,720); viewport.own_world_3d = true
	viewport.name = "RoadViewport"
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var stage := Node3D.new(); viewport.add_child(stage); stage.add_child(original); stage.add_child(current)
	stage.name = "RoadStage"
	var began: int = Time.get_ticks_usec(); await original._build_creator_roads(track); metric(theme_id+"_original_generation",began)
	var thread := Thread.new(); began = Time.get_ticks_usec(); thread.start(PREPARATION.prepare.bind(track,true))
	var slowest: float = 0.0
	while thread.is_alive():
		var frame: int = Time.get_ticks_usec(); await process_frame; slowest = maxf(slowest,(Time.get_ticks_usec()-frame)/1000.0)
	track.editor_roads = thread.wait_to_finish(); metric(theme_id+"_worker_generation",began)
	metrics.append({"operation":theme_id+"_maximum_worker_frame_interval","ms":slowest})
	print("EDITOR_ROAD_WORKER maximum_frame_interval_ms=",slowest)
	check(not track.editor_roads.parts.is_empty(),theme_id+" worker supplies CPU-only mesh arrays")
	began = Time.get_ticks_usec(); await current._build_creator_roads(track); metric(theme_id+"_main_publication",began)
	check(mesh_digest(original) == mesh_digest(current),theme_id+" original/worker mesh arrays match exactly")
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 120
	camera.name = "RoadCamera"
	stage.add_child(camera); camera.look_at_from_position(Vector3(0,150,-95),Vector3.ZERO); camera.current = true
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-58,-35,0); light.shadow_enabled = true; stage.add_child(light)
	light.name = "RoadLight"
	var ambient := WorldEnvironment.new(); ambient.environment = Environment.new()
	ambient.name = "RoadEnvironment"
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; ambient.environment.ambient_light_energy = 0.45
	stage.add_child(ambient)
	if DisplayServer.get_name() != "headless":
		current.hide(); original.show(); for frame: int in range(5): await RenderingServer.frame_post_draw
		var a: Image = viewport.get_texture().get_image()
		original.hide(); current.show(); for frame: int in range(5): await RenderingServer.frame_post_draw
		var b: Image = viewport.get_texture().get_image()
		a.save_png(evidence+"/"+theme_id+"-original.png"); b.save_png(evidence+"/"+theme_id+"-worker.png")
		check(a.get_data() == b.get_data(),theme_id+" actual paired road pixels are exact")
	# Geometry is independent of metadata and non-road object edits, but masks are live.
	var changed: Dictionary = doc.duplicate(true); changed.name = "Renamed road"; changed.objects.append({"kind":"tyre_stack","position":[0,0],"rotation":0.0})
	var other: NativeTrack = TrackCompiler.compile(changed)
	check(PREPARATION.key_for(track) == PREPARATION.key_for(other),theme_id+" metadata/tyre edits retain road geometry identity")
	current._remember_road_meshes([track.content_hash,NativeTrackVisual.VERSION,theme_id,current.colors,true],0,track,PREPARATION.key_for(track))
	other.editor_overlay_mask = CreatorPreviewMasks.overlay(other,changed.paint); other.editor_road_mask = CreatorPreviewMasks.road(other)
	other.editor_roads = PREPARATION.prepare(other)
	var retained := NativeTrackVisual.new(); retained.name = "ReusedRoads"; retained.editor_preview = true; retained.theme_id = theme_id; retained.colors = current.colors; retained.persist_road_meshes = false
	stage.add_child(retained)
	began = Time.get_ticks_usec(); await retained._build_creator_roads(other); metric(theme_id+"_unchanged_geometry_reuse",began)
	check(mesh_digest(retained) == mesh_digest(current),theme_id+" reused road attributes stay exact after metadata/tyre edits")
	check(retained.get_child(0).mesh == current.get_child(0).mesh,theme_id+" unchanged geometry reuses the actual mesh resource")
	check(PREPARATION.bytes+PREPARATION.gpu_bytes <= PREPARATION.BUDGET,theme_id+" prepared CPU/GPU cache shares the original byte budget")
	var painted: Dictionary = changed.duplicate(true)
	painted.paint.append({"surface":2,"width":4.0,"shape":"round","points":[[0.0,-28.0]]})
	var painted_track: NativeTrack = TrackCompiler.compile(painted)
	painted_track.editor_overlay_mask = CreatorPreviewMasks.overlay(painted_track,painted.paint)
	painted_track.editor_road_mask = CreatorPreviewMasks.road(painted_track)
	check(PREPARATION.key_for(painted_track) == PREPARATION.key_for(track),theme_id+" off-road paint retains geometry while changing its overlay")
	check(painted_track.editor_overlay_mask.get_data() != track.editor_overlay_mask.get_data(),theme_id+" paint fixture changes the live mask")
	painted_track.editor_roads = PREPARATION.prepare(painted_track)
	var masked := NativeTrackVisual.new(); masked.name = "MaskedReusedRoads"; masked.editor_preview = true; masked.theme_id = theme_id; masked.colors = current.colors; masked.persist_road_meshes = false
	stage.add_child(masked); await masked._build_creator_roads(painted_track)
	check(masked.get_child(0).mesh == retained.get_child(0).mesh,theme_id+" off-road painting reuses the actual road mesh")
	for child: Node in masked.get_children():
		var material: ShaderMaterial = child.material_override
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			if uniform.name == "overlay_mask": check(material.get_shader_parameter("overlay_mask").get_image().get_data() == painted_track.editor_overlay_mask.get_data(),theme_id+" reused material binds the latest overlay")
	var fresh := NativeTrackVisual.new(); fresh.name = "FreshPaintedRoads"; fresh.editor_preview = true; fresh.prepare_editor_roads = false; fresh.cache_road_meshes = false; fresh.persist_road_meshes = false; fresh.theme_id = theme_id; fresh.colors = current.colors
	stage.add_child(fresh); await fresh._build_creator_roads(painted_track)
	check(mesh_digest(fresh) == mesh_digest(masked),theme_id+" fresh and reused painted roads retain exact attributes")
	if DisplayServer.get_name() != "headless":
		original.hide(); current.hide(); retained.hide(); masked.hide(); fresh.show()
		for frame: int in range(5): await RenderingServer.frame_post_draw
		var painted_a: Image = viewport.get_texture().get_image()
		fresh.hide(); masked.show()
		for frame: int in range(5): await RenderingServer.frame_post_draw
		var painted_b: Image = viewport.get_texture().get_image()
		painted_a.save_png(evidence+"/"+theme_id+"-paint-fresh.png"); painted_b.save_png(evidence+"/"+theme_id+"-paint-reused.png")
		check(painted_a.get_data() == painted_b.get_data(),theme_id+" reused materials match actual freshly painted pixels")
	changed.pieces[0].width += 1.0
	check(PREPARATION.key_for(track) != PREPARATION.key_for(TrackCompiler.compile(changed)),theme_id+" geometry edits invalidate preparation")
	viewport.queue_free(); await process_frame

func listing() -> void:
	var library := TrackLibrary.new(evidence+"/library")
	var source: Dictionary = circuit()
	for index: int in range(128):
		var doc: Dictionary = source.duplicate(true); doc.id = "draft_%03d" % index; doc.name = "Draft %03d" % index
		check(library.save_document(doc) == OK and library.save_wip(doc) == OK,"listing fixture saves "+str(index))
	for repeat: int in range(3):
		var began: int = Time.get_ticks_usec(); var entries: Array = library.editable_entries(true); metric("summary_list_128_"+str(repeat),began)
		check(entries.size() == 128 and not entries[0].document.has("paint"),"summary listing deduplicates versions without retaining full maps")
	var browser = preload("res://ui/draft_browser.gd").new(); browser.library = library
	var began: int = Time.get_ticks_usec(); root.add_child(browser); metric("browser_open_handler",began)
	var deadline: int = Time.get_ticks_msec()+30000
	while browser.scanning and Time.get_ticks_msec()<deadline: await process_frame
	check(not browser.scanning and browser.entries.size()==128,"browser asynchronously presents actual drafts")
	check(browser.find_child("ContinueEditing",true,false)!=null,"selected draft actions remain usable")
	var first: Dictionary = library.load_document("draft_000"); first.name = "External same-sized change"
	var file := FileAccess.open(library.directory+"/draft_000.json",FileAccess.WRITE); file.store_string(JSON.stringify(first,"\t",true)); file.close()
	check(library.load_document("draft_000").name == first.name,"file-content verification invalidates stale cached parsing")
	var copy: Dictionary = library.load_document("draft_000"); copy.objects.clear(); copy.name = "Mutated returned value"
	check(library.load_document("draft_000").name == first.name,"decoded cache results own independent mutable values")
	check(library.save_document(first) == OK,"recovery fixture creates a real previous committed backup")
	file = FileAccess.open(library.directory+"/draft_000.json",FileAccess.WRITE); file.store_string("{invalid}"); file.close()
	check(not library.load_document("draft_000").is_empty(),"corrupt primary still recovers the valid backup")
	check(CACHE.bytes <= CACHE.BUDGET,"read cache retains its byte budget")
	browser._load_entries(); began = Time.get_ticks_usec(); browser.queue_free(); await process_frame; metric("leave_pending_scan",began)

func run() -> void:
	root.size = Vector2i(1280,720)
	evidence = ProjectSettings.globalize_path("res://").path_join("../build/editor-loading-roads-2026-10-13").simplify_path().path_join(RenderingServer.get_current_rendering_method()+"-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(evidence)
	await listing()
	for biome: String in ["pine","desert","winter","night_city"]: await roads(biome)
	var file := FileAccess.open(evidence+"/results.json",FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	print("EDITOR_LOADING_ROADS_TESTS: %d checks, %d failures; evidence=%s" % [checks,failures,evidence])
	quit(1 if failures else 0)

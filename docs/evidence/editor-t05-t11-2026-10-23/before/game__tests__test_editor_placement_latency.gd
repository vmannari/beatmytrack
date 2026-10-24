extends SceneTree
## Actual editing callbacks, disposable storage, and independent compiler checks.
var app: Node
var checks: int = 0
var failures: int = 0
var baseline: bool
var evidence: String
var observations: Array = []
class EditorApp extends "res://core/app.gd":
	func _ready() -> void:
		capture_path = "editor-test"
		super._ready()
	func _prepare_garage_covered() -> void: pass
	func _capture() -> void: pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func settle(label: String, began: int) -> void:
	var slowest: float = 0.0
	var deadline: int = Time.get_ticks_msec()+60000
	# Deferred compilation and the ordered WIP writer can outlive a fast retained
	# scene update. Wait for the actual document and durable write as well.
	while Time.get_ticks_msec()<deadline:
		var preview: NativeTrack = app.canvas.native_preview
		var exact_document: bool = preview != null and preview.metadata.get("creator_document",{}) == app.document
		if exact_document and not app.canvas.preparing and app.editor_preview_thread == null and not app.editor_world._building and not app.editor_writes.unsettled(app.library,str(app.document.id)): break
		var frame: int = Time.get_ticks_usec()
		await process_frame
		slowest = maxf(slowest,(Time.get_ticks_usec()-frame)/1000.0)
	check(not app.canvas.preparing and app.editor_preview_thread == null and not app.editor_world._building and not app.editor_writes.unsettled(app.library,str(app.document.id)),label+" completes")
	var metric: Dictionary = {"operation":label,"settle_ms":(Time.get_ticks_usec()-began)/1000.0,"max_frame_ms":slowest}
	observations.append(metric); print("PLACEMENT_LATENCY ",JSON.stringify(metric))

func fixture(theme: String) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "latency_"+theme; doc.theme = theme
	var position := Vector2(-42,-26)
	var heading: float = 0.0
	for side: int in range(2):
		for i: int in range(11):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,6)
			piece.length = 84.0/11.0; doc.pieces.append(piece)
			position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,6)
		turn.radius = 26.0; doc.pieces.append(turn)
		var pose: Dictionary = RoadPieces.end_pose(turn)
		position = pose.position; heading = pose.heading
	return RoadPieces.route_from_pieces(doc).document

func exact(label: String) -> void:
	var independent: NativeTrack = TrackCompiler.compile(app.document)
	check(independent != null,label+" valid document")
	if independent == null: return
	var preview: NativeTrack = app.canvas.native_preview
	check(preview.content_hash == independent.content_hash and preview.cells == independent.cells and preview.deck_cells == independent.deck_cells,label+" exact collision and identity")
	var saved: Dictionary = app.library.load_wip(app.document.id)
	var expected: Dictionary = JSON.parse_string(JSON.stringify(app.document))
	if saved != expected:
		var changed: Array = []
		for key: String in expected:
			if saved.get(key) != expected[key]: changed.append(key)
		print("WIP_DIFFERENCE ",label," fields=",changed," queued=",app.editor_writes.unsettled(app.library,str(app.document.id))," status=",app.editor_status.text)
	check(saved == expected,label+" durable WIP")

func geometry(node: Node, owner_visual: NativeTrackVisual) -> Array:
	if node in [owner_visual.editor_objects,owner_visual.editor_cover,owner_visual.editor_scenery]: return []
	var result: Array = []
	if node is MeshInstance3D:
		var surfaces: Array = []
		for i: int in range(node.mesh.get_surface_count()): surfaces.append(node.mesh.surface_get_arrays(i))
		result.append([node.transform,surfaces])
	for child: Node in node.get_children(): result.append_array(geometry(child,owner_visual))
	return result

func reference(theme: String) -> void:
	var world: EditorWorld = app.editor_world
	var retained: NativeTrackVisual = world.visual
	var rebuilt := NativeTrackVisual.new()
	rebuilt.editor_preview = true; rebuilt.visible = false
	world.world.add_child(rebuilt)
	await rebuilt.build(app.canvas.native_preview,BridgePresentation.new(app.canvas.native_preview),true)
	check(geometry(retained,retained) == geometry(rebuilt,rebuilt),theme+" retained ground arrays equal a complete fresh build")
	if DisplayServer.get_name() != "headless":
		world.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		for frame: int in range(3): await RenderingServer.frame_post_draw
		var actual: Image = world.viewport.get_texture().get_image()
		retained.hide(); rebuilt.show()
		for frame: int in range(3): await RenderingServer.frame_post_draw
		var expected: Image = world.viewport.get_texture().get_image()
		check(actual.get_data() == expected.get_data(),theme+" retained scene pixels equal complete fresh build")
		actual.save_png(evidence+"/"+theme+"-retained.png"); expected.save_png(evidence+"/"+theme+"-fresh.png")
		retained.show(); rebuilt.hide(); world.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	rebuilt.free()

func deformation() -> void:
	var track: NativeTrack = TrackCompiler.compile(fixture("desert"))
	var original = preload("res://tests/fixtures/desert_relief_before_editor_latency.gd").new(track)
	var current = preload("res://track/desert_road_relief.gd").new(track)
	check(original.field == current.field,"original Desert relief field remains exact")
	var plane := PlaneMesh.new(); plane.size = Vector2(55,55)
	var cube := BoxMesh.new(); cube.size = Vector3(8,2,5)
	for source: Mesh in [plane,cube]:
		var pose := Transform3D(Basis(Vector3.UP,0.23),Vector3(3,0,8))
		var expected: Mesh = original.deform(source,pose,source == plane)
		var actual: Mesh = current.deform(source,pose,source == plane)
		check(expected.surface_get_arrays(0) == actual.surface_get_arrays(0),"refactored relief matches frozen original mesh streams")
		var worker = preload("res://track/desert_road_relief.gd").new()
		worker.track = track; worker.field = current.field; worker.bounds = current.bounds
		var job = preload("res://editor/work_job.gd").start(worker.prepare_arrays.bind([source.surface_get_arrays(0)],pose,source == plane),self)
		while not job.done: await process_frame
		var uploaded := ArrayMesh.new(); uploaded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,job.result[0])
		check(expected.surface_get_arrays(0) == uploaded.surface_get_arrays(0),"worker relief matches frozen original mesh streams")

func supersession() -> void:
	for i: int in range(5):
		app.call("_choose_object","tyre_stack")
		app.canvas._place(app.canvas.to_screen(Vector2(-20+i*6,12)))
	app.call("_undo"); app.call("_redo"); app.call("_undo")
	await settle("rapid_placement_history",Time.get_ticks_usec()); exact("rapid placement history")
	check(app.editor_compiled_cache.size() <= 3 and app.editor_world._visual_cache.size() <= 2,"history caches retain their entry bounds")
	check(app.editor_world.visual_cache_bytes <= EditorWorld.VISUAL_CACHE_BUDGET,"visual history retains its byte bound")
	check(app.editor_raster_cache.get("auxiliary_bytes",0) <= 8*1024*1024,"auxiliary preparation retains its byte bound")
	var previous: NativeTrackVisual = app.editor_world.visual
	app.call("_choose_object","rock")
	app.canvas._place(app.canvas.to_screen(Vector2(-20,-26)))
	await settle("solid_on_road",Time.get_ticks_usec()); exact("solid on road")
	check(app.editor_world.visual != previous,"solid replacing a real road cell rebuilds affected ground")
	await reference("solid-on-road")
	# Leave while a fresh Desert road/relief worker owns a candidate scene.
	app.canvas = null; app.editor_view.clear(); app.document = fixture("desert")
	app.document.pieces[0].width = 7.0
	app.call("_show_screen","create")
	var deadline: int = Time.get_ticks_msec()+20000
	while not app.editor_world._building and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_world._building,"departure exercise reaches active scenery preparation")
	for frame: int in range(4): await process_frame
	app.call("_show_screen","home")
	deadline = Time.get_ticks_msec()+20000
	while not preload("res://editor/work_job.gd").pending.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(app.screen == "home" and preload("res://editor/work_job.gd").pending.is_empty(),"leaving cancels and reaps obsolete scene workers")

func run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	preload("res://track/geometry_acceleration.gd").roads_enabled = not "--scalar-roads" in OS.get_cmdline_user_args() and not "--scalar-desert" in OS.get_cmdline_user_args()
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/editor-placement-2026-10-18/"+("baseline" if baseline else "final")+"-"+DisplayServer.get_name()+"-"+str(ProjectSettings.get_setting("rendering/renderer/rendering_method")))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): evidence = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	if not baseline: await deformation()
	app = EditorApp.new()
	app.library = TrackLibrary.new(evidence+"/storage")
	app.records = LocalRecords.new(evidence+"/storage/records.json")
	app.cloud_root_override = evidence+"/storage/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	# The fixture omits Garage startup; keep its profile-rebuild guard inactive.
	app.startup_complete = false
	for theme: String in ["pine","desert","winter","storm","night_city"]:
		if "--pine" in OS.get_cmdline_user_args() and theme != "pine": continue
		if ("--desert" in OS.get_cmdline_user_args() or "--scalar-desert" in OS.get_cmdline_user_args()) and theme != "desert": continue
		app.canvas = null; app.editor_view.clear(); app.document = fixture(theme)
		var began: int = Time.get_ticks_usec()
		app.call("_show_screen","create")
		await settle(theme+"_open",began)
		var kinds: Array = ["rock","egypt_column","flag","water"] if theme == "desert" else ["tree","igloo","tyre_stack","water"] if theme == "winter" else ["broadleaf","container","tyre_stack","water"] if theme == "night_city" else ["tree","container","tyre_stack","water"]
		for kind: String in kinds:
			var previous: NativeTrackVisual = app.editor_world.visual
			app.call("_choose_object",kind)
			var objects_before: int = app.document.objects.size()
			began = Time.get_ticks_usec()
			app.canvas._place(app.canvas.to_screen(Vector2(-18+app.document.objects.size()*10,0)))
			check(app.document.objects.size() == objects_before+1,theme+" "+kind+" real placement accepted")
			print("PLACEMENT_HANDLER ",theme,"/",kind," ms=",(Time.get_ticks_usec()-began)/1000.0)
			await settle(theme+"_"+kind,began)
			print("PLACEMENT_RETAINED ",theme,"/",kind," ",app.editor_world.visual == previous)
			if not baseline and kind != "water": check(app.editor_world.visual == previous,theme+" "+kind+" retains ground scene")
			exact(theme+" "+kind)
			if kind == kinds[2] and not baseline: await reference(theme)
		app.call("_undo"); await settle(theme+"_undo",Time.get_ticks_usec()); exact(theme+" undo")
		app.call("_redo"); await settle(theme+"_redo",Time.get_ticks_usec()); exact(theme+" redo")
		app.canvas.ghost = RoadPieces.create("straight",Vector2(-15,-8),90,6)
		app.canvas.ghost.length = 18.0
		began = Time.get_ticks_usec(); app.canvas.confirm_piece()
		print("ROAD_HANDLER ",theme," ms=",(Time.get_ticks_usec()-began)/1000.0)
		await settle(theme+"_road",began)
		exact(theme+" road")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(evidence+"/"+theme+".png")
	if not baseline: await supersession()
	app.queue_free(); await process_frame
	var output := FileAccess.open(evidence+"/report.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t")); output.close()
	print("PLACEMENT_LATENCY_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

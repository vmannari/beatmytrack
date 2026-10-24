extends SceneTree
## Audit instrumentation only. No game source edits, owner files or publication.
const ROADS = preload("res://editor/road_preparation.gd")
const ACCEL = preload("res://track/geometry_acceleration.gd")
var out: String
var app: Node
var rows: Array = []
var failures: Array = []
var mode: String

func _initialize() -> void: run.call_deferred()

func record(label: String, value: Dictionary) -> void:
	value["operation"] = label; rows.append(value)
	print("AUDIT ",JSON.stringify(value))
	var file := FileAccess.open(out+"/results-"+mode+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"failures":failures},"\t")); file.close()

func require(ok: bool, label: String) -> void:
	if not ok: failures.append(label); print("AUDIT_CHECK_FAILED ",label)

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted: Array = values.duplicate(); sorted.sort()
	var total: float = 0.0
	for value: float in values: total += value
	return {"n":values.size(),"mean_ms":total/values.size(),"median_ms":sorted[sorted.size()/2],"p95_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*0.95)-1)],"p99_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*0.99)-1)],"max_ms":sorted[-1]}

func measure(label: String, action: Callable, count: int = 11) -> void:
	var samples: Array = []
	for index: int in range(count):
		var began: int = Time.get_ticks_usec(); action.call(); samples.append((Time.get_ticks_usec()-began)/1000.0)
	var value: Dictionary = stats(samples); value.samples_ms = samples; record(label,value)

func circuit(count: int) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "audit_%d" % count; doc.name = "Audit circuit %d" % count
	var position := Vector2(-47,-36); var heading: float = 0.0
	for side: int in range(2):
		for index: int in range((count-2)/2):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,8.0); piece.length = 94.0/float((count-2)/2)
			doc.pieces.append(piece); position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,8.0); turn.radius = 36.0; doc.pieces.append(turn)
		var pose: Dictionary = RoadPieces.end_pose(turn); position = pose.position; heading = pose.heading
	var routed: Dictionary = RoadPieces.route_from_pieces(doc); require(routed.ok,"fixture closed %d" % count)
	doc = routed.document; doc["start_line"] = {"position":[0.0,-36.0],"heading":0.0}
	return doc

func objects(count: int) -> Array:
	var result: Array = []
	for index: int in range(count): result.append({"kind":"container","position":[-42.0+(index%12)*7.0,-26.0+(index/12)*7.0],"rotation":0.0})
	return result

func painted() -> Dictionary:
	var doc: Dictionary = circuit(96); doc.id = "audit_paint"
	for stroke: int in range(32):
		var points: Array = []
		for index: int in range(512): points.append([-100.0+index*0.39,-100.0+stroke*6.0])
		doc.paint.append({"surface":2,"width":2.0,"shape":"round","points":points})
	return doc

func memory() -> Dictionary:
	return {"static_bytes":OS.get_static_memory_usage(),"static_peak_bytes":OS.get_static_memory_peak_usage(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"render_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"render_texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"render_buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)}

func settle(label: String) -> void:
	var began: int = Time.get_ticks_usec(); var frames: Array = []
	var deadline: int = Time.get_ticks_msec()+90000
	while (app.editor_preview_thread != null or app.editor_world._building or app.canvas.preparing) and Time.get_ticks_msec()<deadline:
		var start: int = Time.get_ticks_usec(); await process_frame; frames.append((Time.get_ticks_usec()-start)/1000.0)
	var complete: bool = app.editor_preview_thread == null and not app.editor_world._building and not app.canvas.preparing
	require(complete,"settled "+label)
	var value: Dictionary = {"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"frame_intervals":stats(frames),"completed":complete,"memory":memory(),"road_cache_cpu":ROADS.bytes,"road_cache_gpu":ROADS.gpu_bytes,"road_cache_sections":ROADS.section_bytes}
	if complete and app.canvas.native_preview != null:
		value.cells = app.canvas.native_preview.cells.size(); value.visual_nodes = app.editor_world.visual.find_children("*","",true,false).size()
	record(label,value)
	await process_frame

func show(doc: Dictionary, label: String) -> void:
	app.canvas = null; app.document = doc.duplicate(true); app.editor_view.clear(); app.editor_pending_tools.clear(); app.history.clear(); app.redo_history.clear()
	var began: int = Time.get_ticks_usec(); app._show_screen("create")
	record(label+"_handler",{"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0})
	await settle(label+"_settle")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+mode+"-"+label+".png")

func render_frames(label: String, count: int = 120) -> void:
	var frames: Array = []; var cpu: Array = []; var gpu: Array = []; var draws: Array = []; var primitives: Array = []
	var rid: RID = app.editor_world.viewport.get_viewport_rid()
	if DisplayServer.get_name() != "headless": RenderingServer.viewport_set_measure_render_time(rid,true)
	for index: int in range(count):
		var began: int = Time.get_ticks_usec(); app.canvas.pan += Vector2(0.5,0.0); app.canvas.queue_redraw()
		await process_frame
		frames.append((Time.get_ticks_usec()-began)/1000.0)
		if DisplayServer.get_name() != "headless":
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid)); gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			draws.append(RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
			primitives.append(RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
	var value: Dictionary = {"frame_intervals":stats(frames),"subviewport_cpu":stats(cpu),"subviewport_gpu":stats(gpu),"subviewport_draw_calls":draws,"subviewport_primitives":primitives,"memory":memory()}
	record(label,value)

func drag_road(width: bool) -> void:
	app._editor_category("road"); var canvas: EditorCanvas = app.canvas
	canvas.selected_piece = 0; canvas.snap_enabled = false
	var piece: Dictionary = app.document.pieces[0]
	var start: Vector2 = canvas.to_screen(canvas._geometry_handle(piece,"width")) if width else canvas.to_screen(RoadPieces.samples(piece)[1])
	canvas._begin(start,-1)
	# Explicit body target removes handle-priority ambiguity in short sections.
	if not width: canvas.endpoint_drag = -1; canvas.geometry_drag = ""; canvas.drag_origin = Vector2(piece.position[0],piece.position[1]); canvas.dragging = true
	var handlers: Array = []; var frames: Array = []; var cycles: Array = []
	for index: int in range(120):
		var cycle: int = Time.get_ticks_usec()
		var began: int = Time.get_ticks_usec(); canvas._move(start+Vector2(0.0,12.0*sin(float(index)/12.0)))
		handlers.append((Time.get_ticks_usec()-began)/1000.0)
		began = Time.get_ticks_usec(); await process_frame; frames.append((Time.get_ticks_usec()-began)/1000.0); cycles.append((Time.get_ticks_usec()-cycle)/1000.0)
	var label: String = "width_drag" if width else "road_body_drag"
	record(label,{"handlers":stats(handlers),"frame_intervals":stats(frames),"input_cycle":stats(cycles),"worker_during_drag":app.editor_preview_thread != null,"history_steps":app.history.size(),"changed":canvas.changed_in_gesture,"geometry_handle":canvas.geometry_drag})
	var began: int = Time.get_ticks_usec(); canvas._end(-1); record(label+"_release",{"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0})
	await settle(label+"_settle")

func drag_object() -> void:
	app._editor_category("objects"); var canvas: EditorCanvas = app.canvas; canvas.mode = "objects"; canvas.selected_object = 0
	var start: Vector2 = canvas.to_screen(Vector2(app.document.objects[0].position[0],app.document.objects[0].position[1]))
	canvas._begin(start,-1)
	var visual_id: int = app.editor_world.visual.get_instance_id(); var handlers: Array = []; var frames: Array = []; var cycles: Array = []
	for index: int in range(120):
		var cycle: int = Time.get_ticks_usec()
		var began: int = Time.get_ticks_usec(); canvas._move(start+Vector2(float(index%40)*2.0,0.0)); handlers.append((Time.get_ticks_usec()-began)/1000.0)
		began = Time.get_ticks_usec(); await process_frame; frames.append((Time.get_ticks_usec()-began)/1000.0); cycles.append((Time.get_ticks_usec()-cycle)/1000.0)
	record("object_drag",{"handlers":stats(handlers),"frame_intervals":stats(frames),"input_cycle":stats(cycles),"visual_retained":app.editor_world.visual.get_instance_id() == visual_id,"native_position":canvas.native_preview.metadata.creator_document.objects[0].position,"authored_position":app.document.objects[0].position})
	await capture("object-during-drag")
	var began: int = Time.get_ticks_usec(); canvas._end(-1); record("object_release",{"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0})
	await settle("object_release_settle")

func layout(label: String) -> void:
	for frame: int in range(4): await process_frame
	var collisions: Array = []; var buttons: Array = []
	for node: Node in app.root_ui.find_children("*","Button",true,false):
		if not node.is_visible_in_tree() or node is Window: continue
		var rect: Rect2 = node.get_global_rect()
		buttons.append({"name":node.name,"text":node.text,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	for i: int in range(buttons.size()):
		for j: int in range(i+1,buttons.size()):
			var a: Array = buttons[i].rect; var b: Array = buttons[j].rect
			if Rect2(a[0],a[1],a[2],a[3]).intersection(Rect2(b[0],b[1],b[2],b[3])).get_area()>8.0: collisions.append([buttons[i].name,buttons[j].name])
	var visible: Rect2 = root.get_visible_rect()
	record(label,{"window_pixels":[root.size.x,root.size.y],"logical_viewport":[visible.size.x,visible.size.y],"buttons":buttons,"button_rect_intersections":collisions})
	await capture(label)

func run() -> void:
	mode = "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
	out = ProjectSettings.globalize_path("res://../docs/evidence/track-editor-audit-2026-10-23").simplify_path()
	DirAccess.make_dir_recursive_absolute(out)
	record("environment",{"engine":Engine.get_version_info().string,"mode":mode,"native_geometry":ACCEL.available(),"user_data":OS.get_user_data_dir(),"gpu":RenderingServer.get_video_adapter_name(),"scope":"desktop debug engine; local synthetic fixtures; no human or physical device study"})
	for count: int in [4,24,96]:
		var doc: Dictionary = circuit(count); record("fixture_%d" % count,{"errors":TrackDocument.validate(doc),"keys":doc.keys()}); require(TrackDocument.validate(doc).is_empty(),"fixture validates")
		if not TrackDocument.validate(doc).is_empty(): quit(2); return
		measure("validate_%d" % count,func() -> void: TrackDocument.validate(doc))
		measure("route_%d" % count,func() -> void: RoadPieces.route_from_pieces(doc))
		measure("topology_%d" % count,func() -> void: RoadPieces.prepare_endpoints(doc.pieces))
		measure("fingerprint_%d" % count,func() -> void: TrackLibrary.draft_fingerprint(doc))
		var cache: Dictionary = {"enabled":true}
		measure("compile_cold_%d" % count,func() -> void: require(TrackCompiler.compile(doc,cache)!=null,"compile"),1)
		measure("compile_warm_%d" % count,func() -> void: TrackCompiler.compile(doc,cache),5)
	var paint: Dictionary = painted(); require(TrackDocument.validate(paint).is_empty(),"paint validates")
	measure("validate_paint_16384",func() -> void: TrackDocument.validate(paint),5)
	measure("snapshot_paint_16384",func() -> void: paint.duplicate(true),5)
	measure("fingerprint_paint_16384",func() -> void: TrackLibrary.draft_fingerprint(paint),5)
	var library := TrackLibrary.new(out+"/fixtures-"+mode)
	measure("save_wip_paint_16384",func() -> void: require(library.save_wip(paint)==OK,"paint save"),5)
	record("paint_document_size",{"compact_bytes":JSON.stringify(paint,"",true).to_utf8_buffer().size(),"binary_bytes":var_to_bytes(paint).size()})
	root.size = Vector2i(1280,720)
	app = load("res://core/app.tscn").instantiate(); app.library = library; app.records = LocalRecords.new(out+"/fixtures-"+mode+"/records.json"); app.cloud_root_override = out+"/fixtures-"+mode+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for count: int in [4,24,96]:
		var doc: Dictionary = circuit(count); doc.objects = objects(0 if count == 4 else 24 if count == 24 else 95)
		await show(doc,"open_%d" % count)
		await render_frames("pan_%d" % count,120)
	await layout("road-1280")
	await drag_road(false); await drag_road(true)
	await drag_object()
	# Restore a closed road before testing the actual local create-drive-edit loop.
	await show(circuit(24),"test_fixture")
	for repeat: int in range(3):
		var began: int = Time.get_ticks_usec(); await app._test_document()
		record("test_enter_%d" % repeat,{"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"started":is_instance_valid(app.game),"memory":memory()})
		if is_instance_valid(app.game):
			app.game.set_physics_process(false); began = Time.get_ticks_usec(); app._leave_race()
			record("test_exit_%d" % repeat,{"handler_ms":(Time.get_ticks_usec()-began)/1000.0}); await settle("test_exit_settle_%d" % repeat)
		else: failures.append("practice did not start")
	await show(circuit(24),"undo_fixture")
	app.canvas.selected_piece = 0
	measure("width_button_commit_24",func() -> void: app._change_piece("width",0.5),4)
	await settle("width_button_settle")
	measure("undo_24",func() -> void: app._undo(),4); measure("redo_24",func() -> void: app._redo(),4); await settle("history_settle")
	app._editor_category("paint"); app.canvas.paint_mode = "free"; app.canvas.paint_points = [[-100.0,90.0],[0.0,90.0],[100.0,90.0]]; app.canvas.brush_width = 40.0
	var began: int = Time.get_ticks_usec(); app.canvas.confirm_paint(); record("large_paint_commit",{"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0}); await settle("large_paint_settle")
	for size: Vector2i in [Vector2i(960,540),Vector2i(844,390)]:
		root.size = size; await process_frame; await process_frame; app._editor_category("road"); await layout("road-%d" % size.x)
		app._editor_category("objects"); await process_frame; await layout("objects-%d" % size.x)
	root.size = Vector2i(1280,720)
	await show(TrackDocument.create_blank(),"add_fixture")
	var adds: Array = []
	for index: int in range(20):
		app.canvas.choose_piece("straight"); app.canvas.ghost = RoadPieces.create("straight",Vector2(-40+index*2,-20),0.0,8.0); app.canvas.ghost.length = 2.0
		began = Time.get_ticks_usec(); app.canvas.confirm_piece(); adds.append((Time.get_ticks_usec()-began)/1000.0); await process_frame
	record("add_20",{"handlers":stats(adds),"pieces":app.document.pieces.size()}); await settle("add_20_settle")
	record("final",{"failures":failures,"memory":memory()})
	app.queue_free(); await process_frame; await process_frame
	record("after_app_free",{"memory":memory()})
	quit(1 if not failures.is_empty() else 0)

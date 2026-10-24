extends SceneTree
const BEFORE = preload("res://tests/fixtures/editor_t01_t04_before/canvas.gd")
const ROADS = preload("res://editor/road_preparation.gd")
const UPDATE = preload("res://editor/road_update.gd")
const PREPARED = preload("res://editor/prepared_track_cache.gd")
const APP_SCENE = preload("res://core/app.tscn")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var out: String = ""
var app: Node

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func record(label: String, values: Dictionary) -> void:
	values.operation = label; rows.append(values); print("EDITOR_T01_T04 ",JSON.stringify(values))
	if not out.is_empty():
		var mode: String = "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
		var file := FileAccess.open(out+"/results-"+mode+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))

func circuit(count: int = 24) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "editor_t01_t04"; doc.name = "Editor performance regression"
	var position := Vector2(-47,-36); var heading: float = 0.0
	for side: int in range(2):
		for i: int in range((count-2)/2):
			var piece: Dictionary = RoadPieces.create("straight",position,heading,8.0); piece.length = 94.0/float((count-2)/2)
			doc.pieces.append(piece); position = RoadPieces.end_pose(piece).position
		var turn: Dictionary = RoadPieces.create("hairpin",position,heading,8.0); turn.radius = 36.0; doc.pieces.append(turn)
		var end: Dictionary = RoadPieces.end_pose(turn); position = end.position; heading = end.heading
	doc = RoadPieces.route_from_pieces(doc).document
	doc["start_line"] = {"position":[0.0,-36.0],"heading":0.0}
	return doc

func packet(track: NativeTrack, previous: NativeTrack = null) -> Dictionary:
	var began: int = Time.get_ticks_usec()
	var job = preload("res://editor/road_preparation_job.gd").start(track,self,true,previous)
	while not job.done: await process_frame
	var result: Dictionary = job.result
	record("road_packet",{"ms":(Time.get_ticks_usec()-began)/1000.0,"partial":result.has("dirty_tiles"),"parts":result.get("parts",[]).size(),"reused":result.get("reused",{}),"rebuilt":result.get("rebuilt",{}),"section_bytes":ROADS.section_bytes,"gpu_cache_bytes":ROADS.gpu_bytes})
	return result

func part_keys(packet_value: Dictionary, excluded: Dictionary = {}) -> Array:
	var result: Array = []
	for part: Dictionary in packet_value.parts:
		if not excluded.has(part.tile): result.append(part.mesh_key)
	result.sort(); return result

func stats(values: Array) -> Dictionary:
	var sorted: Array = values.duplicate(); sorted.sort()
	var total: float = 0.0
	for value: float in values: total += value
	return {"mean_ms":total/values.size(),"p95_ms":sorted[ceili(sorted.size()*0.95)-1],"p99_ms":sorted[ceili(sorted.size()*0.99)-1],"max_ms":sorted[-1]}

func drag_preview() -> void:
	var canvas: EditorCanvas = app.canvas
	var before: Dictionary = app.document.duplicate(true)
	var history_count: int = app.history.size()
	canvas.mode = "road"; canvas.selected_piece = 47
	var start: Vector2 = canvas.geometry_controls(app.document.pieces[47]).width
	canvas._begin(start,0)
	check(canvas.geometry_drag == "width","synthetic touch grabs the real width control")
	var handlers: Array = []; var frames: Array = []
	for i: int in range(120):
		var began: int = Time.get_ticks_usec()
		canvas._move(start+Vector2(sin(i*0.13)*8.0,0))
		handlers.append((Time.get_ticks_usec()-began)/1000.0)
		if DisplayServer.get_name() == "headless": await process_frame
		else: await RenderingServer.frame_post_draw
		frames.append((Time.get_ticks_usec()-began)/1000.0)
	canvas._rollback_navigation_edit(); canvas.cancel_gesture()
	check(app.document == before and app.history.size() == history_count,"interrupted continuous manipulation restores the draft and grouped undo history")
	record("drag_width_preview_120",{"handler":stats(handlers),"synthetic_event_to_frame":stats(frames),"renderer":DisplayServer.get_name(),"scope":"script-dispatched touch and planning overlay; not physical touch latency or final geometry completion"})

func geometry() -> void:
	var wide: Dictionary = TrackDocument.create_blank(); wide.theme = "storm"
	var first: Dictionary = RoadPieces.create("straight",Vector2.ZERO,0.0,6.0)
	var taper: Dictionary = RoadPieces.create("taper",RoadPieces.end_pose(first).position,170.0,20.0); taper.narrow_width = 6.0
	wide.pieces = [first,taper]
	var a := NativeTrack.new(); a.cell_size = 0.5; a.metadata = {"creator_document":wide}
	var wider: Dictionary = wide.duplicate(true); wider.pieces[0].width = 20.0
	var b := NativeTrack.new(); b.cell_size = 0.5; b.metadata = {"creator_document":wider}
	var dirty: Dictionary = UPDATE.plan(a,b)
	var topology: Dictionary = RoadPieces.prepare_endpoints(wider.pieces)
	for index: int in range(2):
		for point: Vector2 in RoadPieces.section_outline(wider.pieces,index,0.0,topology):
			for offset: Vector2 in [Vector2.ZERO,Vector2(8,0),Vector2(-8,0),Vector2(0,8),Vector2(0,-8)]:
				var probe: Vector2 = point+offset
				check(dirty.tiles.has(Vector2i(floori(probe.x/UPDATE.TILE),floori(-probe.y/UPDATE.TILE))),"wide reversed joins and cosmetic reach are fully dirty")
	for theme: String in ["pine","storm","night_city"]:
		var doc: Dictionary = circuit(); doc.theme = theme
		var before: NativeTrack = TrackCompiler.compile(doc)
		var original: Dictionary = await packet(before)
		doc.pieces[0].width = 10.0
		var after: NativeTrack = TrackCompiler.compile(doc)
		check(not UPDATE.plan(before,after).is_empty(),theme+" local width uses dirty tiles")
		var patch: Dictionary = await packet(after,before)
		var full: Dictionary = await packet(after)
		var composite: Array = part_keys(original,patch.get("dirty_tiles",{}))+part_keys(patch); composite.sort()
		check(composite == part_keys(full),theme+" patched road meshes equal a full fresh planning build")
		check(part_keys(original,patch.dirty_tiles).size() > 0,theme+" retains distant road tiles")
		check(int(patch.get("reused",{}).get("piece",0)) > 0,theme+" reuses unchanged piece work")
		check(ROADS.bytes+ROADS.section_bytes+ROADS.gpu_bytes <= ROADS.BUDGET,theme+" road LRU stays within its existing budget")
		for kind: String in ["body","delete","add"]:
			var changed: Dictionary = doc.duplicate(true)
			if kind == "body": changed.pieces[0].position[1] -= 3.0
			elif kind == "delete": changed.pieces.remove_at(0)
			else: changed.pieces.append(RoadPieces.create("curve",Vector2(-80,0),0.0,8.0))
			var target: NativeTrack = TrackCompiler.compile(changed)
			var local: Dictionary = await packet(target,after)
			var reference: Dictionary = await packet(target)
			var merged: Array = part_keys(full,local.dirty_tiles)+part_keys(local); merged.sort()
			check(merged == part_keys(reference),theme+" "+kind+" has exact tile parity")
	for theme: String in ["desert","winter"]:
		var doc: Dictionary = circuit(); doc.theme = theme
		var before: NativeTrack = TrackCompiler.compile(doc); doc.pieces[0].width = 10.0
		check(UPDATE.plan(before,TrackCompiler.compile(doc)).is_empty(),theme+" retains full component preparation")
	var doc: Dictionary = circuit(); var base: NativeTrack = TrackCompiler.compile(doc)
	doc.paint.append({"surface":2,"width":4.0,"points":[[0,0],[10,0]],"shape":"round"})
	check(UPDATE.plan(base,TrackCompiler.compile(doc)).is_empty(),"paint changes use full road preparation")
	var job = preload("res://editor/work_job.gd").start(func(_cancel: Callable) -> Dictionary: return ROADS.run_editor(func() -> bool: return true,base,base),self)
	while not job.done: await process_frame
	check(job.result.is_empty(),"cancelled preparation never returns a partial road packet")
	ROADS.prepare(base,true)
	var occupied: int = ROADS.bytes+ROADS.gpu_bytes
	NativeTrackVisual.reserve_editor_sections()
	record("cache_reservation",{"final_packets_and_gpu_before":occupied,"after":ROADS.bytes+ROADS.gpu_bytes,"section_bytes":ROADS.section_bytes})
	check(ROADS.bytes+ROADS.gpu_bytes <= ROADS.BUDGET/2,"return to editing reserves section space even after a final CPU packet")

func handles() -> void:
	var old = BEFORE.new(); var current := EditorCanvas.new()
	root.add_child(old); root.add_child(current)
	for kind: String in ["straight","taper","curve","hairpin","s_bend","bridge"]:
		var doc: Dictionary = circuit(96); var piece: Dictionary = RoadPieces.create(kind,Vector2(0,0),35.0,8.0)
		doc.pieces.append(piece)
		for target: Control in [old,current]:
			target.document = doc; target.size = Vector2(1280,720); target.selected_piece = doc.pieces.size()-1
		for view: int in range(4):
			for target: Control in [old,current]: target.pan = Vector2(view*17,-view*9); target.zoom = 0.5+view*0.75
			check(old.geometry_controls(piece) == current.geometry_controls(piece),kind+" handle positions match original at view "+str(view))
		var began: int = Time.get_ticks_usec()
		for i: int in range(100): old.geometry_controls(piece)
		var original_ms: float = (Time.get_ticks_usec()-began)/1000.0
		began = Time.get_ticks_usec()
		for i: int in range(100): current.geometry_controls(piece)
		record("handles_"+kind,{"before_100_ms":original_ms,"after_100_ms":(Time.get_ticks_usec()-began)/1000.0,"counts":current.preparation_counts.duplicate()})
		began = Time.get_ticks_usec()
		for i: int in range(100):
			var changed: Dictionary = piece.duplicate(true); changed.heading += i*0.001
			current.geometry_controls(changed)
		record("handles_changing_"+kind,{"after_100_ms":(Time.get_ticks_usec()-began)/1000.0})
		current.geometry_controls(piece)
		var count: int = int(current.preparation_counts.get("handle_geometry",0))
		current.pan += Vector2.ONE; current.geometry_controls(piece)
		check(current.preparation_counts.handle_geometry == count,kind+" pan reuses world handle geometry")
	old.queue_free(); current.queue_free(); await process_frame

func settle() -> void:
	var until: int = Time.get_ticks_msec()+60000
	while (app.editor_commits.unsettled() or app.editor_writes.unsettled(app.library,str(app.document.get("id",""))) or app.editor_preview_thread != null or app.editor_world._building or app.canvas.preparing) and Time.get_ticks_msec() < until: await process_frame
	check(app.editor_preview_thread == null and not app.editor_world._building and not app.canvas.preparing,"editor finishes preparation")
	await process_frame

func show(doc: Dictionary) -> void:
	app.canvas = null; app.document = doc; app.editor_pending_tools.clear(); app.editor_view.clear(); app.history.clear(); app.redo_history.clear()
	app._show_screen("create"); await settle()

func app_loop() -> void:
	var directory: String = "user://editor_t01_t04_"+TrackLibrary.unique_id()
	app = APP_SCENE.instantiate()
	app.library = TrackLibrary.new(directory); app.records = LocalRecords.new(directory+"/records.json"); root.add_child(app)
	while not app.startup_complete: await process_frame
	await show(circuit(96))
	var visual: NativeTrackVisual = app.editor_world.visual
	var retained: Dictionary = {}
	for child: Node in visual.get_children():
		if child.has_meta("editor_road_tile"): retained[child.get_instance_id()] = child.get_meta("editor_road_tile")
	app._remember(); app.document.pieces[0].width = 10.0
	var began: int = Time.get_ticks_usec(); app._save_draft(true); await settle()
	var kept: int = 0
	for child: Node in visual.get_children():
		if retained.has(child.get_instance_id()): kept += 1
	record("96_width_settle",{"ms":(Time.get_ticks_usec()-began)/1000.0,"retained_nodes":kept,"previous_road_nodes":retained.size(),"uploads":visual.road_uploads,"reuses":visual.road_reuses})
	check(app.editor_world.visual == visual and kept > 0 and kept < retained.size(),"local road edit retains the scene and untouched road nodes while replacing affected tiles")
	await drag_preview()
	app.canvas.zoom_by(1.25); app.canvas.selected_piece = 4; app.canvas.mode = "road"
	var editor: Control = app.root_ui; var canvas: EditorCanvas = app.canvas
	var view: Array = [canvas.zoom,canvas.pan,canvas.selected_piece,canvas.mode]
	var history: Array = app.history.duplicate(true)
	canvas.active_pointer = 7; app._test_document()
	check(app.game == null and app.root_ui == editor and editor.visible,"Test waits for an active canvas gesture to finish")
	canvas.active_pointer = -99
	for cycle: int in range(2):
		began = Time.get_ticks_usec(); app._test_document()
		var until: int = Time.get_ticks_msec()+60000
		while (app.game == null or is_instance_valid(app.race_loading)) and Time.get_ticks_msec() < until: await process_frame
		check(app.game != null and not is_instance_valid(app.race_loading),"practice starts in bounded time")
		record("practice_enter_"+str(cycle),{"ms":(Time.get_ticks_usec()-began)/1000.0})
		check(app.root_ui == editor and editor.process_mode == Node.PROCESS_MODE_DISABLED,"practice suspends original editor")
		check(app.cloud_ticket.is_empty() and app.game.editor_test and app.game.attempt_practice,"practice never opens a public race ticket")
		check(app.game.native_track != canvas.native_preview and app.game.native_track.metadata.creator_document == app.document,"practice uses an isolated copy of the exact preview")
		began = Time.get_ticks_usec(); app._leave_race()
		record("practice_return_"+str(cycle),{"ms":(Time.get_ticks_usec()-began)/1000.0})
		check(app.root_ui == editor and app.canvas == canvas and app.editor_world.visual == visual,"practice returns to identical editor nodes")
		check([canvas.zoom,canvas.pan,canvas.selected_piece,canvas.mode] == view and app.history == history,"practice preserves view, tool, selection and undo history")
		check(editor.visible and editor.process_mode != Node.PROCESS_MODE_DISABLED,"return restores editor processing and visibility")
		await process_frame
	var prepared: NativeTrack = canvas.native_preview
	check(TrackLifecycle.prepared_test_matches(app.document,prepared),"exact preview is eligible for reuse")
	var changed: Dictionary = app.document.duplicate(true); changed.pieces[0].width += 0.5
	check(not TrackLifecycle.prepared_test_matches(changed,prepared),"changed draft rejects an old preview")
	var copy: NativeTrack = PREPARED.copy_track(prepared)
	check(PREPARED.fields(copy) == PREPARED.fields(prepared),"practice copy preserves every canonical field")
	copy.metadata["isolated"] = true; copy.spawn += Vector2.ONE
	check(not prepared.metadata.has("isolated") and copy.spawn != prepared.spawn,"practice owns mutable metadata and spawn")
	copy.content_hash += "stale"
	check(not TrackLifecycle.prepared_test_matches(app.document,copy),"a different compiled build identity cannot reuse the preview")
	var context: Dictionary = {"root":app.root_ui.get_instance_id(),"navigation":app._navigation_generation,"mode":app.root_ui.process_mode}
	app._practice_editor_context = context.duplicate(); app._practice_editor_context.navigation -= 1
	check(not app._resume_practice_editor(),"navigation change rejects a suspended editor")
	app._practice_editor_context = context.duplicate(); var scope: String = app.test_scope_snapshot; app.test_scope_snapshot += "other"
	check(not app._resume_practice_editor(),"owner change rejects a suspended editor"); app.test_scope_snapshot = scope
	var vehicle: String = app.test_vehicle_snapshot; app.test_vehicle_snapshot = "other"
	check(not app._resume_practice_editor(),"vehicle change rejects a suspended editor"); app.test_vehicle_snapshot = vehicle
	app._practice_editor_context = {}
	app._undo(); await settle()
	check(app.document.pieces[0].width == 8.0 and app.editor_world.visual == visual,"undo restores the previous road in the retained scene")
	app._redo(); await settle()
	check(app.document.pieces[0].width == 10.0 and app.editor_world.visual == visual,"redo restores dependent road geometry in the retained scene")
	var superseded: Dictionary = app.document.duplicate(true); superseded.pieces[10].width = 9.0
	app.editor_world.show_track(TrackCompiler.compile(superseded)); app.editor_world.show_track(prepared)
	await settle()
	check(app.editor_world._visual_track == prepared,"a superseded geometry transaction cannot replace the current track")
	var dense: Dictionary = circuit(96)
	for i: int in range(95): dense.objects.append({"kind":"shed","position":[-42.0+(i%12)*7.0,-26.0+(i/12)*7.0],"rotation":0.0})
	check(TrackDocument.validate(dense,false).is_empty(),"dense proxy fixture stays inside current admission budgets")
	await show(dense); await detail_views()
	var winter: Dictionary = TrackDocument.create_blank(); winter.theme = "winter"
	winter.pieces = [RoadPieces.create("straight",Vector2(-24,-16),0.0,6.0),RoadPieces.create("curve",Vector2(0,-16),0.0,6.0)]
	await show(winter)
	var winter_visual: NativeTrackVisual = app.editor_world.visual
	check(winter_visual.has_meta("winter_smooth_sections"),"Winter asphalt records its smooth bank preparation")
	app.document.surface = "dirt"; app._save_draft(true); await settle()
	check(app.editor_world.visual == winter_visual and not winter_visual.has_meta("winter_smooth_sections"),"retained Winter surface change removes obsolete dependent bank metadata")
	app.queue_free(); await process_frame

func detail_views() -> void:
	var world: EditorWorld = app.editor_world; var detail: RefCounted = world._detail
	detail.enabled = false
	for i: int in range(3): await process_frame
	await render_sample("dense_full")
	detail.enabled = true
	for i: int in range(3): await process_frame
	check(detail.reduced and not world.sunlight.shadow_enabled,"dense overview reduces detail and shadows")
	await render_sample("dense_overview")
	app.canvas.selected_object = 40
	for i: int in range(3): await process_frame
	check(detail._members.values().any(func(indices: Array) -> bool: return indices.has(40)),"overview identifies the selected object's full geometry")
	for key: String in detail._members:
		if not detail._members[key].has(40): continue
		for node: GeometryInstance3D in world.visual.editor_objects._editor_authored_batches.groups[key].nodes:
			check(node.visible,"selected object's original batch remains visible in overview")
	app.canvas.zoom = 10.0/maxf(0.01,minf(app.canvas.size.x/110.0,app.canvas.size.y/90.0))
	await create_timer(0.25).timeout
	for i: int in range(3): await process_frame
	check(not detail.reduced and world.sunlight.shadow_enabled,"settled close view restores original meshes and shadows")
	for group: Dictionary in world.visual.editor_objects._editor_authored_batches.groups.values():
		for node: GeometryInstance3D in group.nodes: check(node.visible,"full view restores authored batch visibility")
	if DisplayServer.get_name() != "headless" and not out.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/"+RenderingServer.get_current_rendering_method()+"-dense-close.png")

func render_sample(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var rid: RID = app.editor_world.viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	var draws: Array = []; var primitives: Array = []; var cpu: Array = []; var gpu: Array = []
	for i: int in range(8):
		app.editor_world.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	for i: int in range(12):
		app.editor_world.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		draws.append(RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		primitives.append(RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid)); gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	record(label,{"draws":draws,"primitives":primitives,"cpu_ms":cpu,"gpu_ms":gpu})
	if not out.is_empty(): root.get_texture().get_image().save_png(out+"/"+RenderingServer.get_current_rendering_method()+"-"+label+".png")

func run() -> void:
	root.size = Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--editor-evidence="): out = arg.trim_prefix("--editor-evidence=")
	await geometry(); await handles(); await app_loop()
	record("complete",{"checks":checks,"failures":failures,"static_bytes":OS.get_static_memory_usage()})
	# Let the unrelated menu decoder release while AudioServer still has frames
	# to mix; an immediate Dummy-driver shutdown otherwise reports its playback.
	GameSoundtrack.instance().queue_free()
	for i: int in range(3): await process_frame
	print("EDITOR_T01_T04_TESTS: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)

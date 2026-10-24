extends "audit.gd"
## Isolated complexity, memory, and biome probes, separate from main run.
func run() -> void:
	mode = ("headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method())+"-detail"
	out = ProjectSettings.globalize_path("res://../docs/evidence/track-editor-audit-2026-10-23").simplify_path()
	record("environment",{"engine":Engine.get_version_info().string,"processor":OS.get_processor_name(),"logical_processors":OS.get_processor_count(),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"native_geometry":ACCEL.available()})
	var doc: Dictionary = circuit(96)
	var canvas := EditorCanvas.new(); canvas.document = doc; canvas.size = Vector2(1280,720); canvas.fit()
	for kind: String in ["straight","curve","s_bend","hairpin","bridge","spline"]:
		var piece: Dictionary = RoadPieces.create(kind,Vector2(-24,0),0.0,8.0)
		measure("geometry_controls_"+kind,func() -> void: canvas.geometry_controls(piece),21)
		measure("piece_validate_"+kind,func() -> void: RoadPieces.validate(piece),21)
		if kind == "spline": measure("spline_preview_changed",func() -> void:
			piece.point_widths[2] = float(piece.point_widths[2])+0.01; piece.width = float(piece.point_widths.max()); canvas._spline_preview(piece),11)
	var source: Dictionary = painted(); canvas.document = source
	measure("begin_touch_max_paint",func() -> void: canvas._begin(Vector2(1000,500),-1); canvas.cancel_gesture(),11)
	var before: Dictionary = memory(); var history: Array = []
	for index: int in range(40): history.append(source.duplicate(true))
	record("history_40_max_paint",{"before":before,"after":memory(),"binary_snapshot_bytes":var_to_bytes(source).size(),"snapshot_count":history.size()})
	history.clear(); canvas.free()
	measure("compile_max_paint",func() -> void: require(TrackCompiler.compile(source)!=null,"max paint compiles"),3)
	# Endpoint buckets intentionally crowded: worst case differs from a normal loop.
	var crowded: Array = []
	for index: int in range(96): crowded.append(RoadPieces.create("straight",Vector2.ZERO,0.0,8.0))
	measure("topology_crowded_96",func() -> void: RoadPieces.prepare_endpoints(crowded),11)
	root.size = Vector2i(1280,720)
	app = load("res://core/app.tscn").instantiate(); app.library = TrackLibrary.new(out+"/detail-fixtures-"+mode); app.records = LocalRecords.new(out+"/detail-fixtures-"+mode+"/records.json"); app.cloud_root_override = out+"/detail-fixtures-"+mode+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for theme: String in ["pine","desert","winter","storm","night_city"]:
		var themed: Dictionary = TrackDocument.create_blank(); themed.id = "audit_"+theme; themed.theme = theme
		var position := Vector2(-20,-16); var heading: float = 0.0
		for side: int in range(2):
			var straight: Dictionary = RoadPieces.create("straight",position,heading,8.0); straight.length = 40.0; themed.pieces.append(straight); position = RoadPieces.end_pose(straight).position
			var bend: Dictionary = RoadPieces.create("hairpin",position,heading,8.0); bend.radius = 16.0; themed.pieces.append(bend)
			var pose: Dictionary = RoadPieces.end_pose(bend); position = pose.position; heading = pose.heading
		themed = RoadPieces.route_from_pieces(themed).document; themed["start_line"] = {"position":[0.0,-16.0],"heading":0.0}
		await show(themed,"biome_open_"+theme); await render_frames("biome_pan_"+theme,120)
		await capture(theme)
	app.queue_free(); await process_frame; await process_frame
	record("final",{"failures":failures,"memory":memory()})
	quit(1 if not failures.is_empty() else 0)

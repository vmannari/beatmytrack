extends SceneTree

var checks: int = 0
var failures: int = 0
var evidence: String = "res://../docs/evidence/editor-start-line-2026-10-22/before"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func markings(track: NativeTrack, editor: bool) -> int:
	var visual := NativeTrackVisual.new()
	visual.editor_preview = editor
	visual.theme_id = track.metadata.theme
	visual.colors = TrackTheme.palette(visual.theme_id)
	visual._build_finish(track)
	var count: int = visual.get_child_count()
	visual.free()
	return count

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	evidence = ProjectSettings.globalize_path(evidence)
	DirAccess.make_dir_recursive_absolute(evidence)
	for theme: String in TrackTheme.IDS:
		var blank: Dictionary = TrackDocument.create_blank()
		blank.theme = theme
		var untouched: Dictionary = blank.duplicate(true)
		var track: NativeTrack = TrackCompiler.compile(blank)
		check(track != null,theme+" blank compiles")
		if track == null: continue
		check(markings(track,true) == 0,theme+" blank editor has no fallback starting line")
		check(markings(track,false) == 2,theme+" race retains fallback starting line")
		check(blank == untouched,theme+" rendering preserves draft document")
		var piece: Dictionary = RoadPieces.create("straight",Vector2(-45,-12),0.0)
		piece.length = 30.0
		blank.pieces.append(piece)
		check(markings(TrackCompiler.compile(blank),true) == 0,theme+" incomplete road editor has no unplaced starting line")
		blank["start_line"] = {"position":[-30.0,-12.0],"heading":0.0}
		check(markings(TrackCompiler.compile(blank),true) == 2,theme+" explicitly placed starting line stays visible")
		var layout: Dictionary = TrackDocument.create_default()
		layout.theme = theme
		check(markings(TrackCompiler.compile(layout),true) == 2,theme+" existing layout keeps its starting line")
	var native: NativeTrack = NativeTrack.read("res://resources/tracks/"+BuiltinTracks.ids()[0]+".json")
	var remix: Dictionary = TrackDocument.from_builtin(native)
	check(markings(TrackCompiler.compile(remix),true) == 2,"existing base-track remix keeps its starting line")
	root.size = Vector2i(1280,720)
	var folder: String = "user://editor_start_line_probe"
	var app: Node = load("res://core/app.tscn").instantiate()
	app.set("library",TrackLibrary.new(folder))
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app)
	while not app.get("startup_complete"): await process_frame
	app.set("document",TrackDocument.create_blank())
	app.set("editor_view",{})
	app.call("_show_screen","create")
	await process_frame
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec() < deadline:
		var editor: EditorWorld = app.get("editor_world")
		if app.get("editor_preview_thread") == null and is_instance_valid(editor) and not editor._building and editor.visual != null: break
		await process_frame
	var editor: EditorWorld = app.get("editor_world")
	check(is_instance_valid(editor) and editor.visual != null and not editor._building,"actual blank editor finishes preparation")
	if is_instance_valid(editor) and editor.visual != null:
		var lines: int = 0
		for node: Node in editor.visual.get_children():
			if str(node.name).begins_with("WornAsphaltFinish"): lines += 1
		check(lines == 0,"actual new editor contains no painted starting line")
		if DisplayServer.get_name() != "headless":
			for frame: int in range(4): await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(evidence+"/blank-editor.png") == OK,"native editor screenshot saved")
	app.queue_free()
	await process_frame
	var file := FileAccess.open(evidence+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name()},"\t"))
	file.close()
	print("EDITOR_START_LINE_PROBE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

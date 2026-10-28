extends SceneTree
## Selected-piece material persistence, canonical surfaces and real editor UI.
const OUTPUT: String = "res://../docs/evidence/road-piece-materials-2026-10-27"
var output: String = OUTPUT
var checks: int = 0
var failures: int = 0
var app: Node
var observations: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func circuit(theme: String) -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = theme
	doc["automatic_scenery"] = false
	doc["start_line"] = {"position":[-20.0,-20.0],"heading":0.0}
	doc.pieces = []
	var position := Vector2(-30,-20)
	var heading: float = 0.0
	for i: int in range(8):
		var piece: Dictionary = RoadPieces.create("straight" if i%2 == 0 else "curve",position,heading)
		piece.length = 40.0 if i in [0,4] else 20.0 if i%2 == 0 else 0.0
		piece.radius = 10.0
		doc.pieces.append(piece)
		var end: Dictionary = RoadPieces.end_pose(piece)
		position = end.position; heading = end.heading
	var generated: Dictionary = RoadPieces.route_from_pieces(doc)
	check(generated.ok,theme+" closed road fixture: "+str(generated.errors))
	return generated.document if generated.ok else doc

func sample(image: Image, track: NativeTrack, point: Vector2) -> Color:
	return image.get_pixel(floori((point.x+track.half_extent.x)/track.cell_size),floori((track.half_extent.y-point.y)/track.cell_size))

func domain() -> void:
	for theme: String in ["pine","storm"]:
		var doc: Dictionary = circuit(theme)
		var old: NativeTrack = TrackCompiler.compile(doc)
		check(old != null and old.cell_at(Vector2(-10,-20)) == 0,theme+" original asphalt")
		doc.pieces[0].surface = "gravel"
		check(TrackDocument.validate(JSON.parse_string(JSON.stringify(doc))).is_empty(),theme+" material survives strict JSON import")
		var cache: Dictionary = {"enabled":true}
		var track: NativeTrack = TrackCompiler.compile(doc,cache)
		check(track != null,theme+" mixed road compiles")
		if track == null: continue
		check(track.cell_at(Vector2(-10,-20)) == 2 and track.cell_at(Vector2(20,0)) == 0,theme+" only selected piece uses loose surface")
		check(track.cell_at(Vector2(9,-20)) == 2 and track.cell_at(Vector2(11,-20)) == 0,theme+" driving materials meet at the joined mouth")
		check(old.content_hash != track.content_hash,theme+" material changes content identity")
		var request := FileAccess.open(output+"/"+theme+"-request.json",FileAccess.WRITE)
		request.store_string(JSON.stringify({"operation":"track","document":doc})); request.close()
		observations.append({"theme":theme,"content_hash":track.content_hash})
		var state := VehicleState.new(); state.position = Vector2(-10,-20)
		check(track.surface_factors(state) == Vector2(0.8,2.0),theme+" gravel uses existing deterministic loose traction")
		var image: Image = CreatorPreviewMasks.road(track)
		check(sample(image,track,Vector2(-10,-20)).g > 0.9 and sample(image,track,Vector2(20,0)).g < 0.1,theme+" rendered material mask agrees with selected and unselected road")
		check(sample(image,track,Vector2(9,-20)).g > 0.6 and sample(image,track,Vector2(9,-20)).g < 0.95 and sample(image,track,Vector2(11,-20)).g > 0.05 and sample(image,track,Vector2(11,-20)).g < 0.4,theme+" material seam blends gradually across the joined mouth")
		check(sample(image,track,Vector2(-10,-25.15)).g > 0.5,theme+" smooth gravel rim retains gravel")
		check(preload("res://track/road_surface_height.gd").new(track).ground(Vector2(-10,-20)) == 0.05,theme+" gravel roadbed remains aligned")
		doc.pieces[0].surface = "asphalt"
		var reset: NativeTrack = TrackCompiler.compile(doc,cache)
		check(reset.cell_at(Vector2(-10,-20)) == 0,theme+" cached compile returns selected piece to asphalt")
		check(reset.cells == old.cells and reset.deck_cells == old.deck_cells,theme+" asphalt restoration preserves original grid")
		doc.pieces[0].surface = "gravel"
		doc.pieces[1].surface = "gravel"
		check(not RoadKerbs.creator_segments(doc).any(func(segment: Dictionary) -> bool: return segment.piece == 1),theme+" gravel bend has no asphalt kerbs")
		doc.surface = "dirt"; doc.pieces[0].surface = "asphalt"
		var reverse: NativeTrack = TrackCompiler.compile(doc,cache)
		check(reverse.cell_at(Vector2(-10,-20)) == 0 and reverse.cell_at(Vector2(20,0)) == 2,theme+" per-piece asphalt overrides a legacy dirt default")
		for invalid: Variant in ["sand","water",2,null,{},[]]:
			doc.pieces[0].surface = invalid
			check(not TrackDocument.validate(doc).is_empty(),theme+" rejects unapproved material "+str(invalid))
		for kind: String in RoadPieces.KINDS:
			if kind == "bridge": continue
			var single: Dictionary = TrackDocument.create_blank(); single.theme = theme; single["automatic_scenery"] = false
			var piece: Dictionary = RoadPieces.create(kind,Vector2(-30,-10)); piece.surface = "gravel"
			single.pieces = [piece]
			var compiled: NativeTrack = TrackCompiler.compile(single)
			var points: PackedVector2Array = RoadPieces.samples(piece)
			var center: Vector2 = points[points.size()/2]
			check(compiled != null and compiled.cell_at(center) == 2,theme+" gravel driving surface for "+kind)
			check(compiled != null and sample(CreatorPreviewMasks.road(compiled),compiled,center).g > 0.9,theme+" gravel render mask for "+kind)
	var doc: Dictionary = circuit("pine")
	var a: Dictionary = RoadPieces.create("bridge",Vector2(-20,0)); a.length = 40; a.surface = "gravel"
	var b: Dictionary = RoadPieces.create("straight",Vector2(0,-20),90); b.length = 40
	doc.pieces = [a,b]
	var bridge: NativeTrack = TrackCompiler.compile(doc)
	check(bridge != null and bridge.cell_at(Vector2.ZERO,true) == 2 and bridge.cell_at(Vector2.ZERO,false) == 0,"gravel bridge preserves asphalt road below")
	check(bridge.cell_at(Vector2(-19,0),false) == 2,"gravel ramp approach matches deck")
	var world := Node3D.new(); root.add_child(world)
	CreatorBridgeVisual.build(world,bridge.creator_bridges,"pine")
	var mesh: MeshInstance3D = world.get_node("BridgeAsphalt")
	check(mesh.material_override.get_meta("surface_dynamic_material",mesh.material_override).get_shader_parameter("piece_materials") == true,"bridge material enables selected surfaces")
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_TEX_UV2][0].y > 0.9,"bridge top carries gravel material independently of ground mask")
	world.free()

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		if app.editor_preview_thread == null and not app.editor_commits.unsettled() and not app.canvas.preparing and not app.editor_world._building: break
		await process_frame
	app._flush_editor_writes()
	check(Time.get_ticks_msec() < deadline,"editor settles after material change")
	await process_frame

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i: int in range(5): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+RenderingServer.get_current_rendering_method()+"-"+label+".png") == OK,label+" screenshot")

func editor() -> void:
	var fixture: String = ProjectSettings.globalize_path("res://../build/road-piece-materials-2026-10-27/fixture-"+str(OS.get_process_id()))
	app = preload("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(fixture+"/tracks"); app.library.owner_name = "Material test"
	app.records = LocalRecords.new(fixture+"/records.json")
	app.cloud_root_override = fixture+"/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.online.client.configure("")
	for theme: String in ["pine","storm"]:
		app.document = circuit(theme); app.editor_view = {}
		app._show_screen("create")
		await settle()
		app._editor_category("road"); app.canvas.selected_piece = 0; app._build_editor_tools()
		var button: Button = app.editor_context.get_node("RoadMaterial_gravel")
		check(button != null and not button.button_pressed,theme+" selected road exposes Gravel")
		var before: Dictionary = app.document.duplicate(true)
		button.pressed.emit()
		check(app.document.pieces[0].surface == "gravel" and app.document.pieces[1] == before.pieces[1],theme+" real button changes only selected piece")
		await settle()
		var saved: Dictionary = app.library.load_wip(app.document.id)
		check(saved.get("pieces",[]).size() == 8 and saved.pieces[0].surface == "gravel",theme+" actual draft persists material")
		check(app.editor_context.get_node("RoadMaterial_gravel").button_pressed,theme+" current material is selected")
		var history_size: int = app.history.size()
		app.editor_context.get_node("RoadMaterial_gravel").set_pressed_no_signal(false)
		app.editor_context.get_node("RoadMaterial_gravel").pressed.emit()
		check(app.history.size() == history_size and app.editor_context.get_node("RoadMaterial_gravel").button_pressed,theme+" choosing current material retains selection without an undo entry")
		await shot(theme+"-gravel")
		app._undo(); await settle()
		check(not app.document.pieces[0].has("surface"),theme+" undo restores inherited asphalt")
		app._redo(); await settle()
		check(app.document.pieces[0].surface == "gravel",theme+" redo restores gravel")
		app._editor_category("road"); app.canvas.selected_piece = 0; app._build_editor_tools()
		app.editor_context.get_node("RoadMaterial_asphalt").pressed.emit()
		await settle()
		check(RoadPieces.material(app.document.pieces[0],app.document) == "asphalt",theme+" real Asphalt button restores road")
		app.canvas.choose_piece("curve")
		app.editor_context.get_node("RoadMaterial_gravel").pressed.emit()
		check(app.canvas.ghost.surface == "gravel" and app.document.pieces.size() == 8,theme+" unplaced piece changes without changing saved road")
		app.canvas.ghost.clear()
		app.canvas.selected_piece = -1; app._build_editor_tools()
		check(app.editor_context.find_child("RoadMaterial_gravel",false,false) == null,theme+" no material action without a piece")
		app._editor_category("road"); app.canvas.selected_piece = 0; app._build_editor_tools()
		app.editor_context.get_node("RoadMaterial_gravel").pressed.emit(); await settle()
		app._flush_editor_writes()
		observations.append({"theme":theme,"material":app.document.pieces[0].surface,"saved":app.library.load_wip(app.document.id).pieces[0].surface})
		for width: int in [960,1280]:
			root.size = Vector2i(width,720); await process_frame; app._build_editor_tools(); await process_frame
			var choice: Control = app.editor_context.get_node("RoadMaterial_gravel")
			check(choice.get_global_rect().size.y >= 44,"material button retains touch height at "+str(width))
			await shot(theme+"-"+str(width))
		app.test_button.pressed.emit()
		var deadline: int = Time.get_ticks_msec()+90000
		while Time.get_ticks_msec() < deadline and (not is_instance_valid(app.game) or not app.game.preparation_complete or is_instance_valid(app.race_loading)): await process_frame
		check(is_instance_valid(app.game) and app.game.preparation_complete,theme+" actual Test drive opens")
		if is_instance_valid(app.game):
			app.game.paused = true
			check(app.game.native_track.cell_at(Vector2(-10,-20)) == 2 and app.game.native_track.cell_at(Vector2(20,0)) == 0,theme+" Test drive keeps selected gravel and neighboring asphalt")
			await shot(theme+"-test-drive")
			app._leave_race(); await settle()
	for theme: String in ["desert","winter","night_city"]:
		app.document.theme = theme; app.canvas.selected_piece = 0; app._build_editor_tools()
		check(app.editor_context.find_child("RoadMaterial_gravel",false,false) == null,theme+" material choices reserved for Grass and Storm")
	app.queue_free(); await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	domain()
	if "--domain-only" not in OS.get_cmdline_user_args(): await editor()
	var file := FileAccess.open(output+"/result-"+RenderingServer.get_current_rendering_method()+("-headless" if DisplayServer.get_name() == "headless" else "")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t")); file.close()
	print("ROAD_PIECE_MATERIALS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

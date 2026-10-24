extends SceneTree

var checks: int = 0
var failures: int = 0
var app: Node
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func button(node: Node, title: String) -> Button:
	if node is Button and (node.text == title or node.text.ends_with("\n"+title)): return node
	for child: Node in node.get_children():
		var found: Button = button(child,title)
		if found != null: return found
	return null

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720)
	var folder: String = "user://retirement_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder+"/records.json")
	records.settings["last_track"] = "slicks_freeway_test"
	records.settings["favorites"] = ["slicks_1way_test"]
	check(records.save_records() == OK,"existing preferences saved for retirement regression")
	app = load("res://core/app.tscn").instantiate()
	app.set("records",records)
	app.set("library",TrackLibrary.new(folder))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.online.client.configure("")
	check(app.get("selected_track").identity == "starter_circuit","removed last-track selection falls back to original starter")
	check(BuiltinTracks.ids() == ["starter_circuit"],"playable catalog contains no retired collection")
	for filename: String in DirAccess.open("res://resources/tracks").get_files():
		check(not filename.begins_with("slicks_"),"runtime resource directory excludes legacy tracks")
	var retired: Dictionary = TrackDocument.create_default()
	retired.base_track = "slicks_freeway_test"
	check(not TrackDocument.validate(retired).is_empty(),"retired native bases are unsupported")
	var legacy_path: String = folder+"/retired.json"
	var file := FileAccess.open(legacy_path,FileAccess.WRITE)
	retired.id = "retired"
	file.store_string(JSON.stringify(retired)); file.close()
	check((app.get("library") as TrackLibrary).load_document("retired").is_empty() and FileAccess.file_exists(legacy_path),"unsupported saved remix is preserved on disk")
	app.call("_show_screen","tracks")
	await process_frame
	for frame: int in range(8): await process_frame
	var browser: TrackBrowser = app.get("root_ui").find_child("TrackBrowser",true,false)
	while browser.loading: await process_frame
	check(browser.matches.is_empty(),"isolated cloud-only Race has no publications and excludes the retired local remix")
	check(button(app.get("root_ui"),"Delete track") == null,"bundled starter cannot be deleted as a user track")
	await screenshot("library")
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "automatic_route"
	var position := Vector2(-28,-18)
	var heading: float = 0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	app.set("document",doc)
	app.set("editor_view",{})
	app.call("_show_screen","create")
	await process_frame
	app.call("_editor_category","road")
	var canvas: EditorCanvas = app.get("canvas")
	for label: String in ["Move","Add bend","Set start","Lay road along route","Sharp","Smooth"]:
		check(button(app.get("root_ui"),label) == null,"manual route option absent: "+label)
	var auto: Button = button(app.get("root_ui"),"Auto waypoints")
	check(auto == null and button(app.get("root_ui"),"Waypoints") == null,"route menu is removed; placement is implicit")
	var expected: Dictionary = RoadPieces.route_from_pieces(doc)
	var before: Dictionary = doc.duplicate(true)
	app.call("_save_draft")
	check(doc.points == expected.document.points and doc.pieces == before.pieces,"automatic placement exactly traces roads without altering geometry")
	check((app.get("history") as Array).size() == 0,"derived route does not add a separate undo step")
	check((app.get("library") as TrackLibrary).load_wip(doc.id).points == JSON.parse_string(JSON.stringify(doc.points)),"automatic route is autosaved")
	var placed: Dictionary = doc.duplicate(true)
	var point: Vector2 = canvas.to_screen(Vector2(doc.points[0][0],doc.points[0][1]))
	canvas.mode = "pan"
	canvas._begin(point,-1); canvas._move(point+Vector2(35,25)); canvas._end(-1)
	check(doc == placed and canvas.selected == -1,"dragging generated waypoints only navigates")
	var key := InputEventKey.new()
	key.pressed = true; key.keycode = KEY_DELETE
	app.call("_unhandled_key_input",key)
	check(doc == placed,"Delete cannot remove automatic waypoints")
	app.call("_remember")
	doc.pieces[0].width = 12.0
	app.call("_save_draft")
	var changed: Dictionary = doc.duplicate(true)
	app.call("_undo")
	check(app.get("document") == placed,"undo restores road geometry and its derived route together")
	app.call("_redo")
	check(app.get("document") == changed,"redo restores road geometry and regenerated route")
	canvas = app.get("canvas")
	canvas.fit()
	await screenshot("automatic-waypoints")
	var open_doc: Dictionary = placed.duplicate(true)
	open_doc.pieces.pop_back()
	app.set("document",open_doc)
	app.set("editor_view",{})
	app.call("_show_screen","create")
	await process_frame
	app.call("_editor_category","road")
	var unchanged: Dictionary = open_doc.duplicate(true)
	app.call("_save_draft")
	check(app.get("document") == unchanged,"incomplete roads leave existing waypoints intact")
	check(not RoadPieces.joins(open_doc.pieces).is_empty(),"incomplete loop retains actionable open-road issues")
	app.queue_free()
	await process_frame
	for name: String in DirAccess.open(folder).get_files(): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("EDITOR_RETIREMENT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func screenshot(stage: String) -> void:
	if not capture: return
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../build/retirement-"+stage+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"capture saved: "+stage)

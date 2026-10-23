extends SceneTree
## Real Compact profiles, seated pedestal, Winter authoring and native review.
const BASE: String = "res://../docs/evidence/ice-compact-2026-10-19"
const SCULPTURE = preload("res://track/prop_ice_compact.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func mesh() -> ArrayMesh:
	var kit := NativeTrackVisual.new(); kit.theme_id = "winter"
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	check(CreatorPropVisual.append(tool,kit,"ice_compact",Vector3.ZERO,1.0,0.0),"sculpture uses the shared shipping builder")
	kit.free(); return tool.commit()

func has_point(vertices: PackedVector3Array, point: Vector3) -> bool:
	for p: Vector3 in vertices:
		if p.distance_squared_to(point) < 0.00000001: return true
	return false

func run() -> void:
	for biome: String in TrackTheme.IDS:
		var entries: Array = CreatorCatalog.filtered("Props","",[],biome)
		check(entries.any(func(asset: Array) -> bool: return asset[0] == "ice_compact") == (biome == "winter"),biome+" exposes the sculpture only in Winter Props")
		var recent: Array[String] = ["ice_compact"]
		check(CreatorCatalog.filtered("Recent","",recent,biome).is_empty() == (biome != "winter"),biome+" Recent follows sculpture availability")
	check(CreatorCatalog.filtered("Props","compact",[],"winter").size() == 1,"Compact search finds the new asset")
	check("ice_compact" in CreatorObjects.KINDS and "ice_compact" not in PropWinterCraft.BREAKABLE,"large pedestal sculpture is a static solid prop")
	var model: ArrayMesh = mesh(); var arrays: Array = model.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var valid: bool = vertices.size() > 0 and normals.size() == vertices.size()
	var collapsed: int = 0; var reversed_faces: int = 0; var ice: int = 0; var snow: int = 0
	for i: int in range(vertices.size()):
		valid = valid and vertices[i].is_finite() and normals[i].is_finite() and normals[i].length() > 0.9
		if colors[i].a > 0.35 and colors[i].a < 0.5: ice += 1
		if colors[i].a > 0.5 and colors[i].a < 0.7: snow += 1
	for i: int in range(0,vertices.size(),3):
		var cross_product: Vector3 = (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
		if cross_product.length_squared() < 1e-16: collapsed += 1
		if -cross_product.dot(normals[i]+normals[i+1]+normals[i+2]) < -0.000001: reversed_faces += 1
	check(valid and collapsed == 0,"sculpture has finite unit normals and no collapsed faces")
	check(reversed_faces == 0,"all carved surfaces agree with their shading normals")
	check(vertices.size()/3 < 10000,"complete car and pedestal retain the established prop triangle ceiling")
	check(ice > snow and snow > 0,"ice car and snow-covered pedestal have distinct material tags")
	var bounds: AABB = model.get_aabb()
	check(bounds.position.x >= -1.7 and bounds.end.x <= 1.7 and bounds.position.z >= -2.9 and bounds.end.z <= 2.9,"sculpture fits its complete authored footprint")
	check(has_point(vertices,CompactCoachwork.hood_point(0,0.5)+Vector3.UP*SCULPTURE.LIFT),"sculpture uses the actual stock Compact hood profile")
	check(has_point(vertices,CompactCoachwork.roof_point(0,0.5)+Vector3.UP*SCULPTURE.LIFT),"sculpture uses the actual stock Compact roof profile")
	check(has_point(vertices,CompactCoachwork.front_face_point(0.5,3.0/7.0)+Vector3.UP*SCULPTURE.LIFT),"sculpture uses the actual stock Compact nose profile")
	check(absf(SCULPTURE.LIFT-1.10) < 0.006,"tyres are seated in the pedestal cap rather than floating")
	check(mesh().surface_get_arrays(0) == arrays,"cached construction retains every model channel")
	var kit := NativeTrackVisual.new(); kit.theme_id = "winter"
	var placed := SurfaceTool.new(); placed.begin(Mesh.PRIMITIVE_TRIANGLES)
	CreatorPropVisual.append(placed,kit,"ice_compact",Vector3(7,1,-8),1.4,0.7); kit.free()
	var transformed: PackedVector3Array = placed.commit_to_arrays()[Mesh.ARRAY_VERTEX]
	var exact_transform: bool = transformed.size() == vertices.size()
	for i: int in range(vertices.size()): exact_transform = exact_transform and transformed[i].distance_to(Vector3(7,1,-8)+(vertices[i]*1.4).rotated(Vector3.UP,0.7)) < 0.00001
	check(exact_transform,"cached statue and pedestal preserve placement, scale and rotation together")
	var object: Dictionary = {"kind":"ice_compact","position":[0,0],"rotation":0}
	check(CreatorObjects.surface("ice_compact") == 4 and CreatorObjects.solid_contains(object,Vector2.ZERO),"pedestal compiles as a solid obstacle")
	check(CreatorObjects.solid_contains(object,Vector2(1.5,0)) and not CreatorObjects.solid_contains(object,Vector2(1.63,2.77)),"solid footprint follows the rounded pedestal, excluding empty corners")
	var doc: Dictionary = TrackDocument.create_default(); doc.theme = "winter"; doc.objects = [object]
	doc.paint = [{"surface":0,"width":20.0,"shape":"square","points":[[0,0]]}]
	check(TrackDocument.validate(doc).is_empty(),"new sculpture validates in the original saved document format")
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null and track.cell_at(Vector2.ZERO) == 4,"actual compiled track includes the pedestal contacts")
	check(track.cell_at(Vector2(1.63,2.77)) == 0,"compiled contacts exclude the empty pedestal corner")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(doc))
	check(TrackDocument.validate(saved).is_empty() and TrackCompiler.compile(saved).content_hash == track.content_hash,"JSON save/reload retains the new object's compiled identity")
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/schemas/creator-track-v5.schema.json"))
	check("ice_compact" in schema.properties.objects.items.properties.kind["enum"],"published document schema explicitly supports the new kind")
	check(CreatorPropVisual.cache_bytes <= CreatorPropVisual.CACHE_BUDGET,"existing shared cache byte budget remains")
	await legacy_models()
	print("ICE_COMPACT_METRICS: ",JSON.stringify({"triangles":vertices.size()/3,"bounds":str(bounds),"ice_vertices":ice,"snow_vertices":snow}))
	if DisplayServer.get_name() != "headless": await captures()
	print("ICE_COMPACT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func legacy_models() -> void:
	var old := GDScript.new()
	old.source_code = FileAccess.get_file_as_string(BASE+"/before/game/track/prop_winter_craft.gd.txt").replace("\r\n","\n").replace("class_name PropWinterCraft\n","")
	check(old.reload() == OK,"preserved Winter builder loads")
	for kind: String in ["igloo","snow_castle","snowman","snow_lantern","ice_lantern"]:
		var a := SurfaceTool.new(); a.begin(Mesh.PRIMITIVE_TRIANGLES)
		var b := SurfaceTool.new(); b.begin(Mesh.PRIMITIVE_TRIANGLES)
		old.append(a,kind,Vector3.ZERO,1,0); PropWinterCraft.append(b,kind,Vector3.ZERO,1,0)
		check(a.commit_to_arrays() == b.commit_to_arrays(),kind+" retains every original mesh channel")

func frames(count: int = 5) -> void:
	for i: int in range(count): await process_frame
	await RenderingServer.frame_post_draw

func folder() -> String:
	var result: String = ProjectSettings.globalize_path(BASE+"/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(result); return result

func captures() -> void:
	var host := Button.new(); root.add_child(host)
	var view: SubViewport = ObjectThumbnail._render_preview(host,"ice_compact","winter")
	view.size = Vector2i(1400,1000); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await frames()
	check(view.get_texture().get_image().save_png(folder()+"/studio.png") == OK,"native full sculpture studio capture")
	var camera: Camera3D = view.get_camera_3d()
	camera.look_at_from_position(Vector3(7,4.2,-10),Vector3(0,1.3,0)); camera.size = 5.5
	await frames(); check(view.get_texture().get_image().save_png(folder()+"/front-detail.png") == OK,"actual Compact face and pedestal capture")
	camera.look_at_from_position(Vector3(-7,5,10),Vector3(0,1.3,0))
	await frames(); check(view.get_texture().get_image().save_png(folder()+"/rear-detail.png") == OK,"actual Compact hatch and carved wheels capture")
	host.queue_free(); await process_frame
	await editor()
	await race()

func editor() -> void:
	var app: Node = load("res://core/app.gd").new()
	var directory: String = "user://ice_compact_"+TrackLibrary.unique_id()
	app.set("library",TrackLibrary.new(directory)); app.set("records",LocalRecords.new(directory+"/records.json")); root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+30000
	while not app.get("startup_complete") and Time.get_ticks_msec() < deadline: await process_frame
	check(app.get("startup_complete"),"actual editor completes covered startup")
	var doc: Dictionary = TrackDocument.create_default(); doc.theme = "winter"
	doc.objects = [{"kind":"ice_compact","position":[-6,0],"rotation":30},{"kind":"snow_castle","position":[4,0],"rotation":0}]
	app.set("document",doc); app.call("_show_screen","create")
	deadline = Time.get_ticks_msec()+40000
	while Time.get_ticks_msec() < deadline:
		var canvas: EditorCanvas = app.get("canvas")
		if canvas != null and canvas.native_preview != null and not app.get("editor_world")._building and app.get("editor_preview_thread") == null: break
		await process_frame
	check(app.get("canvas") != null and app.get("canvas").native_preview != null,"actual Winter editor prepares the rotated sculpture")
	app.call("_editor_category","objects")
	var browser: ObjectBrowser = app.get("object_browser"); browser.category = "Props"; browser.page = 0; browser.refresh(); browser.choose("ice_compact")
	check(browser.current == "ice_compact","actual Winter palette selects the sculpture")
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	await frames(35)
	check(root.get_texture().get_image().save_png(folder()+"/editor-props.png") == OK,"actual Winter palette, thumbnail and saved placement capture")
	check(app.get("canvas").document.objects == doc.objects,"loading the sculpture preserves saved placement and rotation")
	var canvas: EditorCanvas = app.get("canvas")
	var original: Array = canvas.document.objects.duplicate(true)
	canvas._place(Vector2(975,330))
	check(canvas.document.objects.size() == original.size()+1 and canvas.document.objects[-1].kind == "ice_compact","actual editor places the selected sculpture")
	app.call("_undo"); await frames(3)
	check(app.get("document").objects == original,"undo removes only the newly placed sculpture")
	app.call("_redo"); await frames(3)
	check(app.get("document").objects.size() == original.size()+1 and app.get("document").objects[-1].kind == "ice_compact","redo restores the sculpture with its original placement")
	deadline = Time.get_ticks_msec()+5000
	while app.get("editor_writes").unsettled(app.get("library"),str(app.get("document").id)) and Time.get_ticks_msec() < deadline: await process_frame
	var stored: Dictionary = app.get("library").load_wip(str(app.get("document").id))
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(app.get("document")))
	if stored.get("objects",[]) != app.get("document").objects:
		print("ICE_COMPACT_SAVED_OBJECTS: ",JSON.stringify(stored.get("objects",[])))
		print("ICE_COMPACT_EXPECTED_JSON: ",JSON.stringify(serialized.objects))
	check(stored.get("objects",[]) == serialized.objects,"actual local draft saves and reloads the exact JSON sculpture placements")
	app.queue_free(); await frames()

func race() -> void:
	var doc: Dictionary = TrackDocument.create_blank(); doc.theme = "winter"; doc.automatic_scenery = false
	var position := Vector2(-28,-18); var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0; piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece); position = pose.position; heading = pose.heading
	doc = RoadPieces.route_from_pieces(doc).document
	doc.start_line = {"position":[0.0,-18.0],"heading":0.0}
	doc.objects = [{"kind":"ice_compact","position":[35,0],"rotation":25},{"kind":"ice_lantern","position":[34,-6],"rotation":0},{"kind":"tree","position":[23,10],"rotation":0}]
	doc = JSON.parse_string(JSON.stringify(doc))
	check(TrackDocument.validate(doc).is_empty(),"actual Winter race sculpture fixture validates")
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"actual Winter race sculpture fixture compiles")
	if track == null: return
	var cells: PackedInt32Array = track.cells.duplicate(); var identity: String = track.content_hash
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track); game.set("production_mode",true); game.set("vehicle_id","compact")
	root.add_child(game); game.set_physics_process(false); game.set("paused",true); game.get("race_cues").hide()
	game.get("sim").reset(Vector2(45.5,-1),0.3)
	game.call("_process",0.0); game.set_process(false); game.get("hud").get("message_label").hide()
	var snapshot: Array = game.get("sim").state.snapshot()
	var camera: Camera3D = game.get("camera"); camera.size = 24.0
	camera.look_at_from_position(Vector3(48,24,20),Vector3(37,0,0))
	root.size = Vector2i(1600,900); root.content_scale_size = root.size
	await frames(8)
	check(root.get_texture().get_image().save_png(folder()+"/race.png") == OK,"actual sculpture and live Compact in Winter race context")
	check(track.cells == cells and track.content_hash == identity and game.get("sim").state.snapshot() == snapshot,"sculpture rendering preserves the track and canonical car state")
	var world: Node3D = game.get("track_ground")
	check(world.get_node("WinterCraft").mesh.get_surface_count() == 1,"sculpture joins the original single opaque Winter craft surface")
	game.queue_free(); await frames()

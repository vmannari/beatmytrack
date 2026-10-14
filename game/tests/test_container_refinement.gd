extends SceneTree
## Per-object colour, cache isolation, original wear/logo and real editor transactions.
const OUTPUT: String = "res://../docs/evidence/container-refinement-2026-10-12/"
var checks: int = 0
var failures: int = 0
var capture: bool = false
var folder: String
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func obj(color: String = "") -> Dictionary:
	var result: Dictionary = {"kind":"container","position":[0,0],"rotation":0}
	if not color.is_empty(): result["color"] = color
	return result
func doc(object: Dictionary) -> Dictionary:
	var result: Dictionary = TrackDocument.create_default(); result["automatic_scenery"] = false; result.objects = [object]
	return result
func run() -> void:
	capture = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280,720)
	folder = ProjectSettings.globalize_path(OUTPUT+RenderingServer.get_current_rendering_method()); DirAccess.make_dir_recursive_absolute(folder)
	for value: String in [ContainerPaint.DEFAULT,"#000000","#ffffff","#A1b2C3"]: check(ContainerPaint.valid(value),"six-digit opaque paint accepted: "+value)
	for value: Variant in [null,42,"blue","#abc","#12345678","#gg1234","#12345 "]:
		check(not ContainerPaint.valid(value),"unsupported paint rejected")
		check(not TrackDocument.validate(doc(obj(str(value)))).is_empty(),"invalid colour cannot enter a saved track")
	var invalid: Dictionary = obj("#123456"); invalid.kind = "crate"
	check(not TrackDocument.validate(doc(invalid)).is_empty(),"paint property cannot be smuggled onto another object kind")
	check(TrackDocument.validate(doc(obj())).is_empty(),"existing uncoloured containers remain valid")
	var base: NativeTrack = TrackCompiler.compile(doc(obj()))
	var kit := NativeTrackVisual.new()
	var previous_vertices := PackedVector3Array()
	var previous_colors := PackedColorArray()
	for color: String in ContainerPaint.SWATCHES:
		var track: NativeTrack = TrackCompiler.compile(doc(obj(color)))
		check(track != null and track.cells == base.cells and track.deck_cells == base.deck_cells and track.route == base.route and track.kerbs.triangles == base.kerbs.triangles,"colour preserves all canonical prepared geometry: "+color)
		check(track.content_hash != base.content_hash,"painted immutable document has a distinct identity")
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		CreatorPropVisual.append(tool,kit,"container",Vector3.ZERO,1,0,-1,color)
		tool.generate_normals(); var mesh: ArrayMesh = tool.commit()
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		check(mesh.get_aabb().size.x <= 6.022 and mesh.get_aabb().size.z <= 2.52 and mesh.get_aabb().size.y <= 2.62,"model stays within established footprint/height tolerance")
		if not previous_vertices.is_empty(): check(vertices == previous_vertices and colors != previous_colors,"cached variants share dimensions without leaking paint")
		previous_vertices = vertices; previous_colors = colors
		var rust: int = 0
		for pigment: Color in colors:
			if pigment.r > pigment.g*1.12 and pigment.g > pigment.b*1.15: rust += 1
		check(rust > 45,"authored rust pigment remains visible through chosen paint")
	kit.free()
	check(ContainerVisual.GLYPHS.has("B") and ContainerVisual.GLYPHS.has("M") and ContainerVisual.GLYPHS.has("T"),"fixed original BMT CARGO mark is included")
	if capture: await model_captures()
	var records_path: String = "user://container_refinement_"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.gd").new()
	app.set("library",TrackLibrary.new(records_path)); app.set("records",LocalRecords.new(records_path+"/records.json"))
	root.add_child(app); await process_frame
	app.set("document",doc(obj())); app.call("_show_screen","create"); await process_frame; app.call("_editor_category","objects")
	var canvas: EditorCanvas = app.get("canvas"); var browser: ObjectBrowser = app.get("object_browser")
	canvas.mode = "objects"; canvas.selected_object = 0; app.call("_build_editor_tools")
	var picker: ColorPickerButton = app.get("editor_context").find_child("ContainerColour",true,false)
	check(picker != null and not picker.edit_alpha,"selected container has an opaque colour control")
	var count: int = app.get("history").size()
	picker.color = Color("8b4134"); picker.popup_closed.emit(); await process_frame
	check(app.get("document").objects[0].color == "#8b4134" and app.get("history").size() == count+1,"colour close commits one undoable editor transaction")
	app.call("_undo"); await process_frame
	check(not app.get("document").objects[0].has("color"),"undo restores original legacy container paint")
	app.call("_redo"); await process_frame
	check(app.get("document").objects[0].color == "#8b4134","redo restores chosen paint")
	canvas = app.get("canvas"); canvas.selected_object = 0; app.call("_duplicate_object")
	check(app.get("document").objects[-1].color == "#8b4134","copy preserves per-container paint")
	browser = app.get("object_browser"); browser.category = "Props"; browser.choose("container"); browser._activate_asset("container")
	picker = browser.details.find_child("ContainerColour",true,false)
	check(picker != null,"container placement options expose the same colour control")
	picker.color = Color("58705b"); picker.popup_closed.emit(); await process_frame
	canvas = app.get("canvas"); check(canvas.stamp_container_color == "#58705b","palette colour sets the next placement")
	canvas.mode = "place"; canvas._place(canvas.to_screen(Vector2(9,0)))
	check(app.get("document").objects[-1].color == "#58705b","new placement serializes chosen opaque paint")
	var library: TrackLibrary = app.get("library"); var document: Dictionary = app.get("document")
	check(library.save_document(document) == OK and library.load_document(document.id).objects == JSON.parse_string(JSON.stringify(document.objects)),"all container paint choices save and reload exactly")
	if capture:
		canvas.mode = "place"; canvas.selected_object = -1; app.call("_build_editor_tools")
		for frame: int in range(600):
			if app.get("editor_preview_thread") == null and canvas.native_preview != null and not app.get("editor_world")._building: break
			await process_frame
		check(app.get("editor_preview_thread") == null and canvas.native_preview != null and not app.get("editor_world")._building,"palette capture waits for actual prepared track")
		browser = app.get("object_browser"); browser.category = "Props"; browser.choose("container"); await frames(4)
		var entries: Array = CreatorCatalog.filtered(browser.category,"",browser.recent,browser.biome)
		for index: int in range(entries.size()):
			if entries[index][0] == "container": browser.page = index/browser.page_size; break
		browser.refresh(); await frames(20); browser._activate_asset("container")
		check(browser.tiles.get_node_or_null("Asset_container") != null,"chosen-colour container thumbnail is on the visible palette page")
		await shot("container-palette-1280")
		browser.options.hide(); canvas.selected_object = 0; canvas.mode = "objects"; app.call("_build_editor_tools")
		await shot("editor-selected-1280")
		picker = app.get("editor_context").find_child("ContainerColour",true,false); picker.get_popup().popup_centered()
		await shot("colour-picker-1280"); picker.get_popup().hide()
		root.size = Vector2i(960,540); await frames(4)
		canvas = app.get("canvas"); canvas.selected_object = 0; canvas.mode = "objects"; app.call("_build_editor_tools")
		await shot("editor-selected-960")
		picker = app.get("editor_context").find_child("ContainerColour",true,false); picker.get_popup().popup_centered(); await frames(3)
		check(root.get_visible_rect().encloses(Rect2(Vector2(picker.get_popup().position),Vector2(picker.get_popup().size))),"compact colour popup stays inside viewport")
		await shot("colour-picker-960"); picker.get_popup().hide()
	app.queue_free(); await process_frame
	print("CONTAINER_REFINEMENT: %d checks, %d failures; %s" % [checks,failures,folder])
	quit(1 if failures else 0)

func frames(count: int) -> void:
	for i: int in range(count): await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frames(5)
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png") == OK,"capture "+name)
func model_captures() -> void:
	var stage := Node3D.new(); root.add_child(stage)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new(); environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("172831"); environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c6d6df"); environment.environment.ambient_light_energy = 0.40; stage.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-48,-34,0); light.light_color = Color("fff0d9"); light.shadow_enabled = true; stage.add_child(light)
	VisualGeometry.box(stage,Vector3(40,0.1,35),Vector3(0,-0.1,0),VisualGeometry.material(Color("586155")))
	var visual := NativeTrackVisual.new(); stage.add_child(visual)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 5.5; stage.add_child(camera); camera.current = true
	for color: String in [ContainerPaint.DEFAULT,"#8b4134","#b6b6a4"]:
		var track: NativeTrack = TrackCompiler.compile(doc(obj(color)))
		var layer := NativeTrackVisual.new(); stage.add_child(layer); layer._build_placed_objects(track)
		camera.look_at_from_position(Vector3(8,5.5,-10),Vector3(0,1.1,0))
		await shot("container-"+color.trim_prefix("#"))
		if color == ContainerPaint.DEFAULT:
			camera.look_at_from_position(Vector3(-8,4.3,10),Vector3(0,1.1,0)); await shot("opposite-side")
			camera.look_at_from_position(Vector3(10,3.3,-3),Vector3(2,1.3,0)); camera.size = 3.5; await shot("doors-detail"); camera.size = 5.5
		layer.queue_free(); await process_frame
	stage.queue_free(); await process_frame

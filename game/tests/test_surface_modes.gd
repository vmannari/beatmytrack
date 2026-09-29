extends SceneTree
var checks: int = 0
var failures: int = 0
var capture: bool = false
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func tap(canvas: EditorCanvas, p: Vector2) -> void:
	canvas._begin(canvas.to_screen(p),-1)
	canvas._end(-1)
func shot(label: String) -> void:
	if not capture: return
	for frame: int in range(3): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/surfaces-"+label+".png")) == OK,"screenshot "+label)
func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720)
	var app: Node = load("res://core/app.gd").new()
	root.add_child(app)
	await process_frame
	var folder: String = "user://surface_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var library := TrackLibrary.new(folder)
	library.owner_name = "Surface test"
	app.set("library",library)
	var doc: Dictionary = TrackDocument.create_default()
	app.set("document",doc)
	app.set("editor_view",{})
	app.call("_show_screen","create")
	await process_frame
	app.call("_editor_category","paint")
	var canvas: EditorCanvas = app.get("canvas")
	check(app.get("root_ui").find_child("ConfirmPiece",true,false)==null,"bottom-right confirmation removed")
	var toolbar: Control = app.get("surface_toolbar")
	await process_frame
	check(toolbar.visible and root.get_visible_rect().encloses(toolbar.get_global_rect()),"separate placement toolbar visible and inside viewport")
	var palette: Node = app.get("editor_context")
	for child: Node in palette.get_children():
		if child is Button: check(not child.text in ["Road","Oil","Line","Bounded area","Free painting"],"material palette excludes roads oil and placement modes")
	check(toolbar.position.y <= 16,"paint modes share the top control band")
	for choice: String in ["free","area","line"]:
		var mode_button: Button = app.get("root_ui").find_child("PaintMode_"+choice,true,false)
		check(mode_button != null,"segmented mode exists: "+choice)
		mode_button.pressed.emit()
		check(canvas.paint_mode == choice,"segmented button selects "+choice)
	var brush_slider: HSlider = app.get("root_ui").find_child("BrushSizeSlider",true,false)
	brush_slider.value = 7.5
	check(is_equal_approx(canvas.brush_width,7.5),"slider changes actual brush width")
	var bigger: Button = app.get("root_ui").find_child("BrushBigger",true,false)
	bigger.pressed.emit()
	check(is_equal_approx(canvas.brush_width,8.0),"plus adjusts size by half a metre")
	brush_slider.value = 40
	bigger.pressed.emit()
	check(is_equal_approx(canvas.brush_width,40.0),"brush control respects maximum width")
	brush_slider.value = 10.0
	canvas.paint_mode = "line"
	canvas.brush_surface = 2
	canvas.protect_road = false
	for p: Vector2 in [Vector2(-25,15),Vector2(0,30),Vector2(25,15)]: tap(canvas,p)
	check(doc.paint.is_empty(),"point release does not commit a line")
	canvas._begin(canvas.to_screen(Vector2(0,30)),-1)
	canvas._move(canvas.to_screen(Vector2(0,35)))
	canvas._end(-1)
	check(canvas.paint_points.size()==3 and absf(canvas.paint_points[1][1]-35)<0.01,"drag moves a point without adding points")
	app.call("_build_editor_tools")
	await shot("line-preview")
	canvas._begin(canvas.paint_accept_rect().get_center(),-1)
	check(doc.paint.is_empty(),"in-world confirmation waits for release")
	canvas._end(-1)
	check(doc.paint.size()==1 and doc.paint[0].mode=="line","confirm commits exactly one line")
	check(TrackDocument.validate(doc).is_empty(),"line document valid")
	var path: PackedVector2Array = SurfacePaint.contour(doc.paint[0].points,"line")
	check(path.size()>3 and path[0]==Vector2(-25,15) and path[-1]==Vector2(25,15),"smooth line retains endpoints")
	app.call("_undo")
	canvas = app.get("canvas")
	check(canvas.document.paint.is_empty(),"one undo removes confirmed line")
	app.call("_redo")
	canvas = app.get("canvas")
	doc = canvas.document
	check(doc.paint.size()==1,"redo restores line")
	canvas.mode = "paint"
	canvas.paint_mode = "area"
	canvas.brush_surface = 3
	canvas.protect_road = false
	for p: Vector2 in [Vector2(-20,-30),Vector2(20,-30),Vector2(20,0),Vector2(-20,0)]: tap(canvas,p)
	check(doc.paint.size()==1,"area remains a draft until confirmed")
	app.call("_build_editor_tools")
	await shot("area-preview")
	root.size = Vector2i(960,540)
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses((app.get("surface_toolbar") as Control).get_global_rect()),"placement toolbar fits smaller landscape viewport")
	await shot("area-small-landscape")
	root.size = Vector2i(1280,720)
	await process_frame
	await process_frame
	check(Geometry2D.is_point_in_polygon(canvas.to_world(canvas.paint_accept_rect().get_center()),SurfacePaint.contour(canvas.paint_points,"area")),"area confirmation is inside its smooth contour")
	canvas._begin(canvas.paint_accept_rect().get_center(),-1)
	canvas._end(-1)
	check(doc.paint.size()==2,"area confirmed")
	check(TrackDocument.validate(doc).is_empty(),"area document valid")
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"surface document compiles")
	if track == null:
		print("Surface fixture validation: ",TrackDocument.validate(doc))
		app.queue_free()
		quit(1)
		return
	var grid := Vector2i(100,100)
	var cells := PackedInt32Array(); cells.resize(10000); cells.fill(1)
	var roads := cells.duplicate()
	TrackCompiler._paint([doc.paint[1]],cells,grid,Vector2(50,50),1.0,roads)
	check(cells[65*100+50]==3,"bounded area fills interior")
	check(cells[20*100+50]==1,"bounded area leaves outside untouched")
	cells.fill(0); roads.fill(0)
	var protected: Dictionary = doc.paint[1].duplicate(true); protected.protect_road=true
	TrackCompiler._paint([protected],cells,grid,Vector2(50,50),1.0,roads)
	check(cells[65*100+50]==0,"area respects road protection")
	var mask: PackedByteArray = RoadKerbs.exclusion_mask(track,[doc.paint[1]])
	var center: int = floori((track.half_extent.y+15)/track.cell_size)*track.grid_width+floori(track.half_extent.x/track.cell_size)
	check(mask[center]==1,"area suppresses road overlays throughout its interior")
	canvas.show_native(track)
	await shot("confirmed")
	tap(canvas,Vector2(0,0)); canvas.confirm_paint()
	check(doc.paint.size()==2,"incomplete area cannot confirm")
	var draft: Array = canvas.paint_points.duplicate(true)
	var touch := InputEventScreenTouch.new()
	touch.index=0; touch.position=canvas.to_screen(Vector2(40,35)); touch.pressed=true
	canvas._gui_input(touch)
	touch = InputEventScreenTouch.new()
	touch.index=1; touch.position=canvas.to_screen(Vector2(10,0)); touch.pressed=true
	canvas._gui_input(touch)
	touch.pressed=false
	canvas._gui_input(touch)
	check(canvas.paint_points==draft and canvas.paint_handle==-1,"two finger navigation keeps draft and releases its handle")
	canvas.cancel_gesture()
	check(canvas.paint_points.is_empty() and doc.paint.size()==2,"cancel leaves document untouched")
	canvas.paint_mode="free"
	tap(canvas,Vector2(35,0))
	check(doc.paint.size()==3,"free painting still commits on release")
	check(TrackDocument.validate(JSON.parse_string(JSON.stringify(doc))).is_empty(),"JSON roundtrip keeps modes valid")
	var invalid: Dictionary = doc.duplicate(true)
	invalid.paint[1].points = [[-10,-10],[10,10],[-10,10],[10,-10]]
	check(not TrackDocument.validate(invalid).is_empty(),"crossing area is rejected")
	invalid.paint[1].points = [["bad",0],[10,10],[-10,10]]
	check(not TrackDocument.validate(invalid).is_empty(),"malformed coordinates rejected before geometry")
	# Reproduce protected paint meeting the outside of a constructed hairpin.
	var verge_doc: Dictionary = TrackDocument.create_default()
	verge_doc.layout = {}
	verge_doc.pieces = []
	var position := Vector2(-35,-20)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var section: Dictionary = RoadPieces.create(kind,position,heading,10.0)
		section.radius = 20.0
		section.length = 30.0 if kind == "straight" else 0.0
		verge_doc.pieces.append(section)
		var pose: Dictionary = RoadPieces.end_pose(section)
		position = pose.position
		heading = pose.heading
	verge_doc.paint = [{"surface":2,"width":10.0,"shape":"round","mode":"area","points":[[-8,-32],[28,-32],[28,32],[-8,32]],"protect_road":true}]
	var verge_track: NativeTrack = TrackCompiler.compile(verge_doc)
	check(verge_track != null,"protected hairpin paint compiles")
	var visual := NativeTrackVisual.new()
	var overlay: Image = visual._creator_overlay_mask(verge_track,verge_doc.paint)
	var painted_verge: int = 0
	var preserved_road: int = 0
	var natural_grass: int = 0
	var sand_blend_cells: int = 0
	for y: int in range(verge_track.grid_height):
		for x: int in range(verge_track.grid_width):
			var kind: int = verge_track.cells[y*verge_track.grid_width+x]
			var pixel: Color = overlay.get_pixel(x,y)
			if kind == 2 and pixel.b > 0.5: sand_blend_cells += 1
			if kind == 2 and pixel.g < 0.5: painted_verge += 1
			if kind == 0 and pixel.r > 0.5: preserved_road += 1
			if kind == 1 and pixel.g > 0.5: natural_grass += 1
	check(painted_verge == verge_track.cells.count(2) and painted_verge > 0,"paint suppresses all decorative grass and gravel even with Keep road")
	check(sand_blend_cells == painted_verge,"all painted sand supplies decorative blend coverage")
	check(preserved_road == verge_track.cells.count(0) and preserved_road > 0,"Keep road retains every asphalt cell")
	check(natural_grass == verge_track.cells.count(1) and natural_grass > 0,"unpainted grass keeps its verge")
	var unpainted_doc: Dictionary = verge_doc.duplicate(true)
	unpainted_doc.paint = []
	var unpainted_track: NativeTrack = TrackCompiler.compile(unpainted_doc)
	var unpainted_mask: Image = visual._creator_overlay_mask(unpainted_track,[])
	var clipped_unpainted: int = 0
	for y: int in range(unpainted_track.grid_height):
		for x: int in range(unpainted_track.grid_width):
			if unpainted_mask.get_pixel(x,y).g < 0.5 or unpainted_mask.get_pixel(x,y).b > 0.5: clipped_unpainted += 1
	check(clipped_unpainted == 0,"unpainted road skirt and shoulder are never clipped by surface type")
	visual.free()
	app.set("document",verge_doc)
	app.set("editor_view",{})
	app.call("_show_screen","create")
	await process_frame
	app.call("_editor_category","paint")
	canvas = app.get("canvas")
	canvas.zoom_by(1.3,canvas.to_screen(Vector2(0,0)))
	await shot("painted-verge")
	if capture:
		canvas.zoom_by(3.0,canvas.to_screen(Vector2(9,21)))
		await shot("sand-detail")
	app.set("document",unpainted_doc)
	app.set("editor_view",{})
	app.call("_show_screen","create")
	await process_frame
	canvas = app.get("canvas")
	canvas.zoom = 1.0
	canvas.pan = Vector2.ZERO
	canvas.fit()
	await shot("unpainted-road")
	app.call("_editor_category","objects")
	var browser: ObjectBrowser = app.get("object_browser")
	browser.category = "Props"
	browser.page = 0
	browser.refresh()
	check(not CreatorCatalog.family("oil").is_empty() and CreatorCatalog.label("oil")=="Oil spill","oil spill belongs to object catalog")
	browser.choose("oil")
	check(browser.visible and not (app.get("surface_toolbar") as Control).visible,"oil placement stays in Objects")
	canvas = app.get("canvas")
	var old_count: int = canvas.document.objects.size()
	tap(canvas,Vector2(0,-20))
	check(canvas.document.objects.size()==old_count+1 and canvas.document.objects[-1].kind=="oil","object palette places an oil spill")
	await shot("oil-objects")
	app.queue_free()
	await process_frame
	for name: String in DirAccess.open(folder).get_files(): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("SURFACE_MODES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

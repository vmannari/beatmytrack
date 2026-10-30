extends "res://tests/review_track_editor_2026_10_28.gd"
## Actual-App regressions and native evidence for the editor usability pass.
const EDIT = preload("res://editor/object_editing.gd")
const OVERVIEW = preload("res://editor/overview_prop_models.gd")
const SURFACES = preload("res://editor/surface_labels.gd")
var checks: int = 0
var measurements: Dictionary = {}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL: ",message)

func frames(count: int = 4) -> void:
	for index: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func shot(label: String) -> void:
	if DisplayServer.get_name() != "headless": await super.shot(label)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		if app.editor_preview_thread == null and not app.editor_world._building and not app.editor_commits.unsettled() and not app.editor_writes.unsettled(app.library,str(app.document.id)):
			await frames(4)
			if app.editor_preview_thread == null and not app.editor_world._building and not app.editor_commits.unsettled(): return
		await process_frame
	check(false,"editor preparation and recovery writes settle")

func touch(canvas: EditorCanvas, position: Vector2, pressed: bool, cancelled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 9; event.position = position; event.pressed = pressed; event.canceled = cancelled
	canvas._gui_input(event)

func drag(canvas: EditorCanvas, position: Vector2) -> void:
	var event := InputEventScreenDrag.new(); event.index = 9; event.position = position
	canvas._gui_input(event)

func named(value: String) -> Node:
	return app.root_ui.find_child(value,true,false)

func object(kind: String, x: float, y: float) -> Dictionary:
	return {"kind":kind,"position":[x,y],"rotation":0.0}

func picking() -> void:
	var canvas := EditorCanvas.new(); canvas.document = TrackDocument.create_blank(); canvas.mode = "objects"
	canvas.document.objects = [object("cone",0,0),object("cone",4,0)]
	root.add_child(canvas); canvas.size = Vector2(1280,720)
	canvas.zoom = 6.0/minf(canvas.size.x/110.0,canvas.size.y/90.0)
	var point: Vector2 = canvas.to_screen(Vector2.ZERO)
	touch(canvas,point,true); touch(canvas,point,false)
	check(canvas.selected_object == 0,"exact object wins over a later-added neighbour 24 pixels away")
	canvas.document.objects.append(object("cone",0,0))
	touch(canvas,point,true); touch(canvas,point,false)
	check(canvas.selected_object == 2,"coincident ties select the topmost object")
	canvas.cycle_objects(); check(canvas.selected_object == 0,"Next object reaches the other coincident object")
	canvas.object_snap = 0.25
	check(canvas.object_position(Vector2(1.36,2.62)).is_equal_approx(Vector2(1.25,2.5)),"quarter-metre snapping")
	canvas.object_snap = 0
	check(canvas.object_position(Vector2(1.36,2.62)).is_equal_approx(Vector2(1.36,2.62)),"free placement retains precision")
	canvas.object_snap = 1
	check(canvas.object_position(Vector2(1.36,2.62)).is_equal_approx(Vector2(1,3)),"default metre snapping retained")
	var original: Array = [object("crate",106,108),object("cone",108,106)]
	var indices: Array[int] = [0,1]
	var moved: Array = EDIT.moved(original,indices,Vector2(10,10))
	check(moved[0].position == [108.0,110.0] and moved[1].position == [110.0,108.0],"bounded group translation preserves spacing")
	check(original[0].position == [106.0,108.0],"group transforms never mutate their source snapshot")
	var rotated: Array = EDIT.rotated([object("crate",-3,0),object("cone",3,0)],indices,90)
	check(Vector2(rotated[0].position[0],rotated[0].position[1]).is_equal_approx(Vector2(0,-3)),"group rotates around its shared centre")
	check(EDIT.rotated([object("crate",110,110),object("cone",100,110)],indices,45).is_empty(),"out-of-map group rotation is rejected atomically")
	canvas.mode = "place"; canvas.stamp_kind = "crate"; canvas.object_snap = 0.25
	point = canvas.to_screen(Vector2(15.36,12.62))
	touch(canvas,point,true); touch(canvas,point,false)
	check(canvas.document.objects.back().position == [15.25,12.5],"touch placement uses the selected quarter-metre grid")
	canvas.object_snap = 0; point = canvas.to_screen(Vector2(25.36,22.62))
	touch(canvas,point,true); touch(canvas,point,false)
	var free: Array = canvas.document.objects.back().position
	check(Vector2(free[0],free[1]).distance_to(Vector2(25.36,22.62)) < 0.0001,"touch placement supports free precision")
	var dense: Array = []
	point = canvas.to_screen(Vector2.ZERO)
	for index: int in range(1000): dense.append(object("cone",-100+(index%40)*5,-60+(index/40)*5))
	var samples: Array[float] = []
	for index: int in range(60):
		var started: int = Time.get_ticks_usec()
		EDIT.candidates(dense,point,Vector2.ZERO,canvas.to_screen)
		samples.append(float(Time.get_ticks_usec()-started)/1000.0)
	samples.sort()
	measurements.picking_1000_objects_ms = {"median":samples[30],"p95":samples[57],"maximum":samples.back()}
	canvas.queue_free(); await frames(2)

func browser() -> void:
	var browser: ObjectBrowser = app.object_browser
	app._editor_category("objects")
	browser.choose("boulder"); browser.stamp_scale = 1.5; browser.placement = "curve"
	browser._activate_asset("rock")
	check(browser.current == "boulder" and browser.stamp_scale == 1.5 and browser.placement == "curve","opening family Properties preserves variant, size and placement")
	check(browser.options.visible and browser.options.state.kind == "boulder","Properties inspects the chosen variant")
	await frames(3); await shot("03-preserved-boulder-properties")
	browser.options.hide()
	browser._property_edited("kind","rock"); await frames(2)
	check(browser.current == "rock" and browser.stamp_scale == 1.5 and browser.placement == "curve","changing a variant retains size and placement")
	browser._property_edited("kind","boulder"); await frames(2)
	browser.options.hide()
	browser.snap_step = 0.25
	check((named("ObjectSnap") as OptionButton).selected == 1,"restored snap setting matches its visible control")
	(named("ObjectSnap") as OptionButton).item_selected.emit(2)
	check(app.canvas.object_snap == 0,"snap control changes actual placement precision")
	browser.category = "Recent"; browser.refresh(); await frames(2)
	var tile: ObjectThumbnail = browser.tiles.find_child("Asset_rock",true,false) as ObjectThumbnail
	check(tile != null and tile._kind == "boulder","family card previews the selected variant")
	if tile != null: check(tile.custom_minimum_size == Vector2(112,90),"object cards give captions and artwork more room")
	app.canvas.cancel_gesture()

func groups() -> void:
	var doc: Dictionary = circuit(); doc.objects = [object("crate",-12,0),object("cone",0,0),object("barrel",12,0)]
	await show(doc); app._editor_category("objects")
	var canvas: EditorCanvas = app.canvas
	canvas.zoom = 8.0/minf(canvas.size.x/110.0,canvas.size.y/90.0)
	touch(canvas,canvas.to_screen(Vector2(-12,0)),true); touch(canvas,canvas.to_screen(Vector2(-12,0)),false)
	canvas.toggle_multi_select()
	touch(canvas,canvas.to_screen(Vector2.ZERO),true); touch(canvas,canvas.to_screen(Vector2.ZERO),false)
	check(canvas.object_indices() == [0,1],"tap adds an object to a multi-selection")
	var before: Array = app.document.objects.duplicate(true); var count: int = app.history.size()
	var start: Vector2 = canvas.to_screen(Vector2.ZERO)
	touch(canvas,start,true); drag(canvas,canvas.to_screen(Vector2(2,3))); touch(canvas,canvas.to_screen(Vector2(2,3)),false)
	check(app.document.objects[0].position == [-10.0,3.0] and app.document.objects[1].position == [2.0,3.0],"dragging one member moves the selected group")
	check(app.document.objects[2] == before[2] and app.history.size() == count+1,"group drag changes only the group and creates one undo step")
	await settle(); await shot("04-group-selection")
	var moved: Array = app.document.objects.duplicate(true)
	touch(canvas,canvas.to_screen(Vector2(2,3)),true); drag(canvas,canvas.to_screen(Vector2(5,7)))
	touch(canvas,canvas.to_screen(Vector2(5,7)),false,true)
	check(app.document.objects == moved and app.history.size() == count+1 and not canvas.dragging and canvas.active_pointer == -99,"cancelled group drag rolls back and releases capture without a new undo step")
	app._undo(); check(app.document.objects == before,"one Undo restores the complete group")
	app._redo(); check(app.document.objects == moved,"one Redo restores the complete group")
	canvas.multi_select = true; canvas.selected_objects.assign([0,1]); canvas.selected_object = 1
	count = app.history.size(); app._duplicate_object()
	check(app.document.objects.size() == 5 and canvas.object_indices() == [3,4],"Copy duplicates and selects the whole group")
	check(app.history.size() == count+1,"group Copy is one undo step")
	app._delete_selection(); check(app.document.objects == moved,"Delete removes the selected copies together")
	app._undo(); check(app.document.objects.size() == 5,"Undo restores all deleted group members")
	app._redo(); check(app.document.objects == moved,"Redo removes precisely the copied group")
	canvas.multi_select = true; canvas.selected_objects.assign([0,1]); canvas.selected_object = 1
	var separation: float = Vector2(-12,0).length()
	app._set_object_rotation(90)
	var a := Vector2(app.document.objects[0].position[0],app.document.objects[0].position[1])
	var b := Vector2(app.document.objects[1].position[0],app.document.objects[1].position[1])
	check(is_equal_approx(a.distance_to(b),separation) and app.document.objects[0].rotation == 90.0,"group rotation preserves spacing and rotates all members")
	await settle()
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		var saved: Dictionary = app.library.load_wip(app.document.id)
		if JSON.stringify(saved.get("objects",[])) == JSON.stringify(app.document.objects) and not app.editor_commits.unsettled() and not app.editor_writes.unsettled(app.library,str(app.document.id)): break
		await process_frame
	var recovered: Array = app.library.load_wip(app.document.id).get("objects",[])
	measurements.group_recovery = {"saved":recovered,"live":app.document.objects.duplicate(true)}
	print("GROUP_RECOVERY: ",JSON.stringify(measurements.group_recovery))
	check(JSON.stringify(recovered) == JSON.stringify(app.document.objects),"draft recovery stores the complete transformed group at serialization precision")
	app._undo(); canvas.multi_select = true; canvas.selected_objects.assign([0,1]); canvas.selected_object = 1
	touch(canvas,canvas.to_screen(Vector2(2,3)),true); touch(canvas,canvas.to_screen(Vector2(2,3)),false)
	check(canvas.object_indices() == [0],"tapping an existing member removes it from the selection")
	var prior: Dictionary = app.document
	var limited: Dictionary = TrackDocument.create_blank(); limited.id = "limited_group"
	for index: int in range(4095): limited.objects.append(object("tyre_stack",-80+(index%80)*2,-80+(index/80)*2))
	app.document = limited; canvas.document = limited; canvas.multi_select = true; canvas.selected_objects.assign([0,1]); canvas.selected_object = 1
	count = app.history.size(); app._duplicate_object()
	check(app.document.objects.size() == 4095 and app.history.size() == count,"a group exceeding the remaining capacity is rejected without partial copies or history")
	app.document = prior; canvas.document = prior; canvas.multi_select = false; canvas.selected_object = -1

func surface_controls() -> void:
	var doc: Dictionary = circuit(); doc.theme = "winter"
	await show(doc); app._editor_category("paint")
	app.canvas.paint_mode = "area"; app._build_editor_tools(); await frames(3)
	check(named("BrushSizeSlider") == null,"Area omits the irrelevant brush-size control")
	check(named("AreaRemovePoint") != null and (named("AreaRemovePoint") as Button).disabled,"Area exposes disabled Undo point before the first point")
	check((named("AreaConfirm") as Button).disabled,"Area cannot place fewer than three points")
	app.canvas.paint_points = [[-8.0,8.0],[8.0,8.0],[8.0,-8.0]]; app._build_editor_tools(); await frames(3)
	check(not (named("AreaConfirm") as Button).disabled,"three points enable visible Place")
	await shot("05-winter-area-controls")
	(named("AreaRemovePoint") as Button).pressed.emit()
	check(app.canvas.paint_points.size() == 2 and (named("AreaConfirm") as Button).disabled,"Undo point removes one draft vertex and refreshes availability")
	(named("AreaCancel") as Button).pressed.emit()
	check(app.canvas.paint_points.is_empty() and app.document.paint.is_empty(),"Cancel clears only the uncommitted area")
	check(SURFACES.title(1,"winter") == "Snow" and SURFACES.title(2,"winter") == "Packed snow","Winter material labels match the terrain")
	check(SURFACES.glyph(1,"winter") == "terrain_snow" and SURFACES.title(2,"desert") == "Loose sand","biome-specific material symbols and labels")

func overview() -> void:
	var mesh_counts: Dictionary = {}
	for kind: String in ["parked_car","van","car_wreck","barrel","cone","crate","pallet","hut","shed","tree","broadleaf","container"]:
		var mesh: ArrayMesh = OVERVIEW.mesh(kind,OVERVIEW.color(kind,"pine",{"kind":kind}))
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var valid: bool = not vertices.is_empty() and normals.size() == vertices.size()
		for normal: Vector3 in normals:
			if not normal.is_finite() or normal.length() < 0.9: valid = false
		check(valid,"overview "+kind+" has finite lit geometry")
		check(vertices.size() < 3000,"overview "+kind+" remains a bounded simple mesh")
		mesh_counts[kind] = vertices.size()/3
	check(OVERVIEW.color("parked_car","pine",{}) != OVERVIEW.color("crate","pine",{}),"overview objects retain distinct material colours")
	measurements.overview_triangles = mesh_counts
	var doc: Dictionary = circuit(); doc.objects.clear()
	var kinds: Array[String] = ["parked_car","van","car_wreck","barrel","cone","crate","pallet","hut"]
	for index: int in range(32): doc.objects.append(object(kinds[index%8],-35.0+(index%8)*10.0,20.0-(index/8)*13.0))
	await show(doc); app._editor_category("objects")
	app.canvas.zoom = 6.5/minf(app.canvas.size.x/110.0,app.canvas.size.y/90.0); app.canvas.pan = Vector2.ZERO
	await frames(20)
	check(app.editor_world._detail.reduced,"dense distant scene uses the readable overview")
	await shot("06-dense-overview")
	app.canvas.multi_select = true; app.canvas.selected_objects.assign([0,3]); app.canvas.selected_object = 3
	await frames(8)
	check(app.editor_world._detail._selection == [0,3],"overview tracks every selected member for full detail")
	app.canvas.multi_select = false; app.canvas.selected_object = -1
	app.editor_map_panel.show(); await frames(3)
	var toggle: CheckButton = named("EditorDetailedScenery") as CheckButton
	check(toggle != null,"Map exposes Detailed scenery")
	if toggle != null: toggle.button_pressed = true
	app.editor_map_panel.hide(); await frames(20)
	check(not app.editor_world._detail.reduced,"Detailed scenery explicitly restores full models")
	await shot("07-dense-full-detail")
	root.size = Vector2i(960,540); root.content_scale_size = Vector2i(1280,720); await frames(5)
	await shot("08-small-window-objects")
	root.size = Vector2i(1280,720); root.content_scale_size = root.size

func model_study() -> void:
	if DisplayServer.get_name() == "headless": return
	app.root_ui.hide()
	var background := ColorRect.new(); background.color = Color("15262e"); background.size = Vector2(1280,720); root.add_child(background)
	var title := MenuStyle.label("Shared object meshes · production thumbnail renderer",24); title.position = Vector2(24,12); background.add_child(title)
	var tiles: Array[ObjectThumbnail] = []
	var kinds: Array[String] = ["parked_car","van","car_wreck","cliff","barrel","hut"]
	for index: int in range(kinds.size()):
		var tile: ObjectThumbnail = ObjectThumbnail.make(kinds[index],CreatorCatalog.label(kinds[index]),false,func() -> void: pass,"pine") as ObjectThumbnail
		tile.position = Vector2(50+(index%3)*400,64+(index/3)*315); tile.scale = Vector2(3.2,3.2); background.add_child(tile); tiles.append(tile)
	var deadline: int = Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		var pending: bool = false
		for tile: ObjectThumbnail in tiles:
			if tile._image.texture == null or tile._viewport != null: pending = true
		if not pending: break
		await process_frame
	for tile: ObjectThumbnail in tiles: check(tile._image.texture != null and tile._viewport == null,"native model study renders "+tile._kind)
	await frames(5)
	check(root.get_texture().get_image().save_png(folder+"/09-model-study.png") == OK,"native model study saved")
	background.queue_free(); app.root_ui.show(); await frames(3)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	folder = ProjectSettings.globalize_path("res://../docs/evidence/editor-ux-improvements-2026-10-28").simplify_path().path_join("headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	await picking()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder+"/disposable-storage"); app.records = LocalRecords.new(folder+"/disposable-storage/records.json")
	app.cloud_root_override = folder+"/disposable-storage/cloud"; root.add_child(app)
	while not app.startup_complete: await process_frame
	app.library.owner_name = "Editor checks"
	await show(TrackDocument.create_blank())
	check(app.editor_status.visible and not app.editor_guidance.is_empty(),"first-use tool guidance is visible")
	check(named("EditorSaveAction") != null,"Save is directly available in the main toolbar")
	check(not is_instance_valid(app.editor_world.visual.editor_cover) or not app.editor_world.visual.editor_cover.visible,"planning view suppresses decorative ground flecks")
	await shot("01-first-use")
	await show(circuit()); app.canvas.selected_piece = 0; app._build_editor_tools()
	await shot("02-road-handles")
	await browser()
	await groups()
	await surface_controls()
	await overview()
	await model_study()
	measurements["checks"] = checks; measurements["failures"] = failures; measurements["observations"] = observations
	var report := FileAccess.open(folder+"/report.json",FileAccess.WRITE); report.store_string(JSON.stringify(measurements,"\t")); report.close()
	app.queue_free(); GameSoundtrack.instance().queue_free(); await frames(5)
	await create_timer(0.25).timeout
	print("EDITOR_UX_IMPROVEMENTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

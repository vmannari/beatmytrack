extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: "+label)
func run() -> void:
	create_timer(60).timeout.connect(func() -> void: print("FAIL: object test timed out"); quit(1))
	root.size=Vector2i(1280,720)
	var config: HandlingConfig=load("res://resources/balanced.tres")
	var recent: Array[String]=["tyre_stack"]
	check(CreatorCatalog.filtered("Recent","",recent).size()==1,"Recent filters families")
	check(CreatorCatalog.filtered("Nature","boulder",recent).size()==1,"search finds a grouped variant")
	for category: String in CreatorCatalog.CATEGORIES: check(not CreatorCatalog.filtered(category,"",recent).is_empty(),category+" has placeable assets")
	for kind: String in CreatorCatalog.SOFT:
		var doc: Dictionary=TrackDocument.create_blank()
		doc.paint=[{"surface":0,"width":40.0,"shape":"square","points":[[0,0]]}]
		doc.objects=[{"kind":kind,"position":[0,0],"rotation":0}]
		var track: NativeTrack=TrackCompiler.compile(doc)
		check(track!=null and track.cell_at(Vector2.ZERO)==0,kind+" is not baked into an impassable wall")
		var sim:=VehicleSimulation.new(config); sim.reset(Vector2(0,-5)); sim.state.velocity=Vector2(0,10)
		var input:=DriveFrame.new()
		for tick: int in range(100): sim.step(input,track)
		check(float(sim.state.light_props[0][1])>0.5 and sim.state.position.y>1,kind+" moves and lets car pass")
		var replay:=VehicleSimulation.new(config); replay.reset(Vector2(0,-5)); replay.state.velocity=Vector2(0,10)
		for tick: int in range(100):
			var values: Array=JSON.parse_string(JSON.stringify(input.packed()))
			var decoded:=DriveFrame.new(); decoded.steer=values[0]; decoded.throttle=values[1]; decoded.brake=values[2]
			replay.step(decoded,track)
		check(sim.state.snapshot()==replay.state.snapshot(),kind+" JSON inputs replay moving state exactly")
		sim.reset(Vector2(20,20)); sim.step(input,track)
		check(sim.state.light_props[0][0]==0 and sim.state.light_props[0][1]==0,kind+" resets each attempt")
	var trunk: Dictionary={"kind":"tree","position":[0,0],"rotation":0}
	check(CreatorObjects.contains(trunk,Vector2(1,0)) and not CreatorObjects.solid_contains(trunk,Vector2(1,0)),"tree canopy is selectable but only trunk collides")
	var gantry: Dictionary={"kind":"gantry","position":[0,0],"rotation":0}
	check(not CreatorObjects.solid_contains(gantry,Vector2.ZERO) and CreatorObjects.solid_contains(gantry,Vector2(5.7,0)),"gantry supports leave clear passage")
	var folder: String="user://object_browser_"+TrackLibrary.unique_id()
	var app: Node=load("res://core/app.gd").new()
	app.set("library",TrackLibrary.new(folder)); app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app); await process_frame
	var doc: Dictionary=TrackDocument.create_default(); doc.name="Woodland studio"
	for index: int in range(12): doc.objects.append({"kind":["tree","broadleaf","bush","rock","tyre_stack","fence","cone","jump","barrel","crate","parked_car","shed"][index],"position":[-20+(index%6)*8,-8+(index/6)*14],"rotation":15})
	app.set("document",doc); app.call("_show_screen","create")
	await process_frame; await process_frame
	app.call("_editor_category","objects")
	var browser: ObjectBrowser=app.get("object_browser")
	var canvas: EditorCanvas=app.get("canvas")
	check(browser.visible and not (app.get("editor_palette") as Control).visible,"compact object browser replaces road palette")
	browser.choose("tyre_stack")
	var before: int=doc.objects.size()
	canvas._place(canvas.to_screen(Vector2(0,-16)))
	check(doc.objects.size()==before+1 and LooseTyres.positions({"objects":[doc.objects[-1]]}).size()==1,"single mode places exactly one tyre stack")
	app.call("_object_placement","line")
	before=doc.objects.size()
	canvas._begin(canvas.to_screen(Vector2(-10,-17)),-1); canvas._move(canvas.to_screen(Vector2(0,-17))); canvas._end(-1)
	check(doc.objects.size()==before+10,"dragging a line automatically spaces ten stacks")
	app.call("_undo")
	doc=app.get("document"); canvas=app.get("canvas")
	check(doc.objects.size()==before,"one undo removes the complete run")
	app.call("_object_placement","curve")
	before=doc.objects.size()
	canvas._begin(canvas.to_screen(Vector2(-10,-17)),-1)
	canvas._move(canvas.to_screen(Vector2(-5,-17)))
	canvas._move(canvas.to_screen(Vector2(0,-12)))
	canvas._end(-1)
	check(doc.objects.size()>before+5 and doc.objects[-1].rotation>20,"drawn curve changes stack direction along the path")
	before=doc.objects.size()
	canvas._begin(canvas.to_screen(Vector2(0,-20)),-1)
	canvas._move(canvas.to_screen(Vector2(10,-20)))
	canvas.cancel_gesture(); canvas._end(-1)
	check(doc.objects.size()==before,"cancelled line gesture places nothing")
	browser=app.get("object_browser")
	browser.category="Nature"; browser.choose("pebbles")
	var decoration: Dictionary={"kind":"pebbles","position":[0,0],"rotation":0,"scale":2.0}
	var invalid: Dictionary=TrackDocument.create_blank(); invalid.objects=[decoration]
	check(not TrackDocument.validate(invalid).is_empty(),"decorative pebbles cannot be scaled into a large misleading obstacle")
	check(CreatorCatalog.filtered("All","",recent,"future_biome").size()==CreatorCatalog.ASSETS.size(),"unconfigured biome uses shared kit")
	var availability: Dictionary={"test_forest":["tree","rock"]}
	check(CreatorCatalog.filtered("All","",recent,"test_forest",availability).size()==2 and CreatorCatalog.filtered("Props","",recent,"test_forest",availability).is_empty(),"biome family availability filters all browser paths")
	check(TrackDocument.validate(doc).is_empty(),"palette restrictions do not invalidate existing placed kinds")
	var library: TrackLibrary=app.get("library")
	check(library.save_document(doc)==OK and library.load_document(doc.id).objects==JSON.parse_string(JSON.stringify(doc.objects)),"catalogue objects and drawn runs save and reload")
	browser=app.get("object_browser")
	browser.category="Barriers"; browser.choose("tyre_stack"); app.call("_object_placement","curve"); browser.refresh()
	await process_frame; await process_frame
	check(browser.get_global_rect().end.x<=1280 and browser.size.y<170,"browser fits desktop landscape and preserves most world height")
	if "--capture-objects" in OS.get_cmdline_user_args():
		for tick: int in range(5): await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/object-browser.png"))==OK,"object browser screenshot")
		browser.category="Nature"; browser.refresh()
		for tick: int in range(5): await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/object-nature.png"))==OK,"nature screenshot")
	var test_action: Button=app.get("test_button")
	check(root.get_visible_rect().encloses(test_action.get_global_rect()),"Test action stays inside screen")
	check(not CreatorCatalog.family("jump").is_empty(),"Jump is available in Objects")
	browser.choose("jump")
	app.call("_build_editor_tools")
	check(browser.visible and canvas.stamp_kind=="jump","Jump selection keeps Objects browser open")
	check(not browser.options.visible,"object options do not reserve a permanent row")
	var target: Vector2=Vector2(doc.objects[0].position[0],doc.objects[0].position[1])
	canvas.mode="place"; canvas._begin(canvas.to_screen(target),-1)
	canvas._move(canvas.to_screen(target+Vector2(4,0))); canvas._end(-1)
	check(Vector2(doc.objects[0].position[0],doc.objects[0].position[1]).distance_to(target+Vector2(4,0))<0.01,"direct selection also drags the object in one gesture")
	check(canvas.mode=="objects" and canvas.selected_object>=0,"existing objects are selected directly without Select / move")
	app.call("_editor_category","objects")
	browser=app.get("object_browser")
	if "--capture-objects" in OS.get_cmdline_user_args():
		canvas.zoom*=2.2; canvas.pan=Vector2(0,40); canvas.queue_redraw()
		browser.category="Buildings"; browser.refresh()
		for tick: int in range(5): await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/editor-props-detail.png"))==OK,"refined prop detail capture")
		browser.choose("tyre_stack")
		(browser.find_child("ObjectOptions",true,false) as Button).pressed.emit()
		for tick: int in range(4): await RenderingServer.frame_post_draw
		check(browser.options.visible,"variant and mode popover opens")
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/editor-object-options.png"))==OK,"object options capture")
		browser.options.hide()
	root.size=Vector2i(1280,576)
	await process_frame; await process_frame
	check(root.get_visible_rect().encloses(browser.get_global_rect()) and browser.position.y>root.get_visible_rect().size.y*0.4,"wide phone aspect keeps the browser in bounds and world exposed")
	if "--capture-objects" in OS.get_cmdline_user_args():
		for tick: int in range(4): await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/object-wide.png"))==OK,"wide landscape screenshot")
	if "--capture-objects" in OS.get_cmdline_user_args():
		app.call("_editor_category","road")
		for tick: int in range(4): await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/editor-road-toolbar.png"))==OK,"road toolbar capture")
	print("OBJECT_BROWSER_TESTS: %d checks, %d failures" % [checks,failures])
	app.queue_free(); await process_frame
	quit(1 if failures else 0)

extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)
func run() -> void:
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var free: Callable = func(_p: Vector2,_r: float,_e: bool) -> Vector3: return Vector3.ZERO
	var origins := PackedVector2Array([Vector2.ZERO])
	var slide := VehicleState.new()
	slide.position = Vector2(-50,-50)
	slide.loose_tyres = [[0.0,0.0,10.0,0.0,0.0]]
	var stop_tick: int = 0
	for tick: int in range(300):
		LooseTyres.step(slide,origins,free,slide.position,config,VehicleSimulation.STEP)
		if float(slide.loose_tyres[0][2]) == 0.0:
			stop_tick = tick+1; break
	print("TYRE_SLIDE distance=",slide.loose_tyres[0][0]," seconds=",stop_tick*VehicleSimulation.STEP)
	check(float(slide.loose_tyres[0][0])<3.0 and stop_tick<72,"10 m/s tyre stops within 3 m and 0.6 s")
	var impact := VehicleState.new()
	impact.position = Vector2(0,-1.7); impact.velocity = Vector2(0,20)
	LooseTyres.step(impact,origins,free,Vector2(0,-1.8),config,VehicleSimulation.STEP)
	print("TYRE_IMPACT car_before=20 car_after=",impact.velocity.y)
	check(impact.velocity.y<17 and impact.velocity.y>0,"one direct stack impact removes at least 3 m/s without reversing the car")
	await _load_ui()
	print("TYRES_LOAD_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _load_ui() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "user://load_tests_"+TrackLibrary.unique_id()
	var library := TrackLibrary.new(folder)
	var saved: Dictionary = TrackDocument.create_blank()
	saved.id = "saved_curve"; saved.name = "Saved curve"
	var curve: Dictionary = RoadPieces.create("curve",Vector2(-20,-20))
	curve.angle = 120.0
	saved.pieces = [curve]
	check(library.save_document(saved)==OK,"save a track for later editing")
	var draft: Dictionary = saved.duplicate(true)
	draft.id = "unfinished"; draft.name = "Unfinished lap"
	draft.points[1] = draft.points[0].duplicate()
	check(library.save_document(draft)==OK,"incomplete lap remains a loadable draft")
	var app: Node = load("res://core/app.gd").new()
	app.set("library",TrackLibrary.new(folder))
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app)
	await process_frame
	var current: Dictionary = TrackDocument.create_blank()
	current.id = "current"; current.name = "Current work"
	app.set("document",current)
	app.call("_show_screen","create")
	await process_frame
	await process_frame
	var load_button: Button = (app.get("root_ui") as Node).find_child("LoadTrack",true,false)
	check(load_button!=null,"Load is visible directly in the editor")
	load_button.pressed.emit()
	await process_frame
	var dialog: AcceptDialog = (app.get("root_ui") as Node).find_child("LoadTrackDialog",true,false)
	check(dialog!=null and library.load_document("current").name=="Current work","opening Load preserves current work")
	var search: LineEdit = dialog.find_child("LoadSearch",true,false)
	var choices: ItemList = dialog.find_child("SavedDrafts",true,false)
	search.text = "missing"; search.text_changed.emit(search.text)
	check(choices.item_count==0 and dialog.get_ok_button().disabled,"empty search disables Load")
	search.text = "saved curve"; search.text_changed.emit(search.text)
	check(choices.item_count==1 and choices.get_item_metadata(0)=="saved_curve","search locates a persisted track by name")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/load-track-picker.png"))==OK,"load picker screenshot")
	dialog.confirmed.emit()
	await process_frame
	await process_frame
	var canvas: EditorCanvas = app.get("canvas")
	check(app.get("document").id=="saved_curve" and canvas.document.pieces[0].angle==120.0,"Load restores authored geometry with the same track ID")
	check(canvas.selected_piece==-1 and app.get("history").is_empty(),"loaded track starts without the previous document selection or undo history")
	canvas.selected_piece=0
	app.call("_change_piece","width",2.0)
	check(library.load_document("saved_curve").pieces[0].width==12.0,"loaded track can be edited and saved under the same ID")
	(app.get("root_ui") as Node).find_child("LoadTrack",true,false).pressed.emit()
	await process_frame
	dialog=(app.get("root_ui") as Node).find_child("LoadTrackDialog",true,false)
	search=dialog.find_child("LoadSearch",true,false)
	search.text="Unfinished"; search.text_changed.emit(search.text)
	dialog.confirmed.emit()
	await process_frame
	check(app.get("document").id=="unfinished" and not TrackDocument.validate(app.get("document")).is_empty(),"Load also opens unfinished laps for repair")
	canvas=app.get("canvas")
	check(canvas.native_preview!=null and canvas.native_preview.cell_at(Vector2(-38,-12))==1,"unfinished lap displays authored map without a phantom fallback road")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/loaded-track-editor.png"))==OK,"loaded editor screenshot")
	app.queue_free()
	await process_frame
	var directory := DirAccess.open(folder)
	for file: String in directory.get_files(): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)

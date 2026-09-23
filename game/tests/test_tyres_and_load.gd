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
	check(impact.velocity.y<15 and impact.velocity.y>0,"one direct stack impact removes at least 5 m/s without reversing the car")
	var single: VehicleState = _push(1,config,free)
	var pile: VehicleState = _push(6,config,free)
	print("TYRE_PUSH single=",single.loose_tyres[0][1]," pile=",pile.loose_tyres[0][1])
	check(float(single.loose_tyres[0][1])>3.0,"sustained engine force pushes one stack from rest")
	check(float(pile.loose_tyres[0][1])<0.2,"six touching stacks exceed available engine force")
	check(single.snapshot()==_push(1,config,free).snapshot(),"pushing is exactly repeatable")
	check(pile.snapshot()==_push(6,config,free).snapshot(),"pile resistance is exactly repeatable")
	var separated: bool = true
	for index: int in range(5):
		separated = separated and float(pile.loose_tyres[index+1][1])-float(pile.loose_tyres[index][1])>0.99
	check(separated,"stalled stacks remain separate bodies")
	var bridge := VehicleState.new()
	bridge.position = Vector2(0,-1.7); bridge.velocity = Vector2(0,20); bridge.track_elevated = true
	LooseTyres.step(bridge,origins,free,Vector2(0,-1.8),config,VehicleSimulation.STEP)
	check(bridge.velocity.y==20 and bridge.loose_tyres[0][1]==0.0,"overpass car ignores ground tyres")
	var before: float = pile.position.y
	for tick: int in range(120):
		var previous: Vector2 = pile.position
		pile.velocity = Vector2(0,-2)
		pile.position += pile.velocity*VehicleSimulation.STEP
		LooseTyres.step(pile,PackedVector2Array([Vector2.ZERO]),free,previous,config,VehicleSimulation.STEP)
	check(pile.position.y<before-1.9,"car can reverse away from a stalled pile")
	await _load_ui()
	print("TYRES_LOAD_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _push(count: int, config: HandlingConfig, free: Callable) -> VehicleState:
	var state := VehicleState.new()
	state.position = Vector2(0,-config.collision_radius-LooseTyres.RADIUS)
	var origins := PackedVector2Array()
	for index: int in range(count): origins.append(Vector2(0,index))
	for tick: int in range(240):
		var previous: Vector2 = state.position
		state.velocity.y += (config.engine_force-config.rolling_resistance)/config.mass*VehicleSimulation.STEP
		state.position += state.velocity*VehicleSimulation.STEP
		LooseTyres.step(state,origins,free,previous,config,VehicleSimulation.STEP)
	return state

func _load_ui() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "user://load_tests_"+TrackLibrary.unique_id()
	var library := TrackLibrary.new(folder)
	var saved: Dictionary = TrackDocument.create_blank()
	saved.id = "saved_curve"; saved.name = "Forest bend"
	var curve: Dictionary = RoadPieces.create("curve",Vector2(-20,-20))
	curve.angle = 120.0
	saved.pieces = [curve]
	check(library.save_document(saved)==OK,"save track for editing")
	var latest: Dictionary = saved.duplicate(true)
	latest.pieces[0].width = 12.0
	check(library.save_wip(latest)==OK,"save newer autosave")
	for index: int in range(5):
		var draft: Dictionary = saved.duplicate(true)
		draft.id = "draft_%d" % index
		draft.name = ["Desert loop","Midnight works","Winter pass","Storm valley","Empty canvas"][index]
		draft.theme = ["desert","night_city","winter","storm","pine"][index]
		if index == 4: draft.pieces = []
		if index == 3: draft.points[1] = draft.points[0].duplicate()
		check(library.save_wip(draft)==OK,"save autosave-only fixture")
	var entries: Array[Dictionary] = library.editable_entries()
	check(entries.size()==6,"saved original and autosave appear once")
	var matched: Array[Dictionary] = entries.filter(func(item: Dictionary) -> bool: return item.id == "saved_curve")
	check(matched[0].load_id=="wip:saved_curve" and matched[0].document.pieces[0].width==12.0,"newest editable version is the autosave")
	check(entries[0].modified>0,"last saved uses actual file modification time")
	var app: Node = load("res://core/app.gd").new()
	app.set("library",library)
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app)
	await process_frame
	app.call("_new_document")
	await process_frame
	(app.get("root_ui") as Node).find_child("LoadTrack",true,false).pressed.emit()
	await process_frame
	var browser: Node = app.get("root_ui").find_child("DraftBrowser",true,false)
	check(app.get("screen")=="drafts" and browser!=null,"Create Load opens editing gallery")
	check(browser.get("entries").size()==6,"gallery includes autosave-only tracks")
	var gallery: Node = browser.get("gallery")
	check(gallery.find_children("*","TrackTile",true,false).size()==4,"gallery pages four scenic cards")
	for tile: TrackTile in gallery.find_children("*","TrackTile",true,false):
		check(tile.draft_mode and not tile.find_child("ToggleFavorite",false,false).visible,"draft card omits racing favorite action")
	(browser.get("next") as Button).pressed.emit()
	check(gallery.find_children("*","TrackTile",true,false).size()==2,"next page exposes remaining drafts")
	(browser.get("previous") as Button).pressed.emit()
	if "--capture" in OS.get_cmdline_user_args():
		for i: int in range(3): await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/evidence/draft-browser"))
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/evidence/draft-browser/gallery.png"))
	var search: LineEdit = browser.find_child("DraftSearch",true,false)
	search.text="missing"; search.text_changed.emit(search.text)
	check(gallery.find_children("*","TrackTile",true,false).is_empty(),"unmatched search offers no load/delete")
	search.text="Forest bend"; search.text_changed.emit(search.text)
	check(gallery.find_children("*","TrackTile",true,false).size()==1,"name search finds one deduplicated draft")
	check(browser.find_child("PublishDraft",true,false).disabled,"untested selected draft cannot publish")
	var delete_button: Button = browser.find_child("DeleteDraft",true,false)
	check(is_equal_approx(delete_button.size.x,delete_button.size.y),"delete action is square")
	check(browser.find_child("TestDraft",true,false).text=="Test drive","test drive has no additional label")
	browser.find_child("ContinueEditing",true,false).pressed.emit()
	await process_frame
	check(app.get("screen")=="create" and app.get("document").id=="saved_curve","continue editing opens original identity")
	check(app.get("document").pieces[0].width==12.0,"editor restores newer autosave geometry")
	check(app.get("history").is_empty(),"loaded draft does not inherit undo history")
	var canvas: EditorCanvas = app.get("canvas")
	canvas.selected_piece=0
	app.call("_change_piece","width",2.0)
	check(library.load_wip("saved_curve").pieces[0].width==14.0,"continued changes autosave")
	check(library.load_document("saved_curve").pieces[0].width==10.0,"original is preserved until explicit Save")
	app.call("_open_drafts")
	await process_frame
	check(app.get("screen")=="drafts","editor Load uses the same gallery")
	browser = app.get("root_ui").find_child("DraftBrowser",true,false)
	browser.emit_signal("back_requested")
	await process_frame
	check(app.get("screen")=="create" and app.get("document").pieces[0].width==14.0,"Back from editor browser restores work")
	app.call("_open_drafts")
	await process_frame
	app.call("_confirm_delete_draft","saved_curve","Forest bend")
	await process_frame
	var dialog: ConfirmationDialog = app.get("root_ui").find_child("DeleteDraftDialog",true,false)
	dialog.canceled.emit()
	await process_frame
	check(not library.load_document("saved_curve").is_empty(),"cancel deletion retains saved original")
	check(not library.load_wip("saved_curve").is_empty(),"cancel deletion retains autosave")
	app.call("_confirm_delete_draft","saved_curve","Forest bend")
	await process_frame
	dialog = app.get("root_ui").find_child("DeleteDraftDialog",true,false)
	dialog.confirmed.emit()
	await process_frame
	check(library.load_document("saved_curve").is_empty() and library.load_wip("saved_curve").is_empty(),"confirmed deletion removes both versions and recovery copies")
	check(library.editable_entries().size()==5,"deleted draft does not reappear via backup")
	check(app.get("document").is_empty(),"deleting current draft prevents later autosave resurrection")
	check(library.delete_editable("../invalid")==ERR_INVALID_PARAMETER,"deletion rejects path traversal")
	browser = app.get("root_ui").find_child("DraftBrowser",true,false)
	search = browser.find_child("DraftSearch",true,false)
	search.text = "Storm valley"; search.text_changed.emit(search.text)
	browser.find_child("ContinueEditing",true,false).pressed.emit()
	await process_frame
	check(app.get("document").id=="draft_3" and app.get("screen")=="create","unfinished autosave opens for repair")
	canvas = app.get("canvas")
	canvas.ghost = RoadPieces.create("straight",Vector2(200,0))
	app.call("_open_drafts")
	await process_frame
	check(app.get("screen")=="create" and not canvas.ghost.is_empty(),"invalid pending preview blocks leaving editor")
	canvas.ghost.clear()
	await _publication_ui(app,library)
	app.queue_free()
	await process_frame

func _publication_ui(app: Node, library: TrackLibrary) -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "publication_test"
	doc.name = "Tested oval"
	var position := Vector2(-28,-18)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	doc["start_line"] = {"position":[0.0,-18.0],"heading":0.0}
	doc = RoadPieces.route_from_pieces(doc).document
	var save_error: Error = library.save_wip(doc)
	check(save_error==OK,"publication fixture saved: "+library.last_error)
	check(library.publish_document(doc)==ERR_UNAUTHORIZED,"untested publishing rejected at persistence boundary")
	app.call("_show_screen","drafts")
	app.call("_test_saved_draft","wip:publication_test")
	await process_frame
	var game: Node = app.get("game")
	check(game!=null and bool(game.get("editor_test")),"Test drive starts untimed editor practice")
	if game == null: return
	game.set_physics_process(false)
	check(not library.is_tested(app.get("document")),"launching test is not completion")
	app.call("_leave_race")
	await process_frame
	check(app.get("screen")=="drafts" and not library.is_tested(doc),"aborting returns to drafts without tested status")
	app.call("_test_saved_draft","wip:publication_test")
	await process_frame
	game = app.get("game")
	game.set_physics_process(false)
	var track: NativeTrack = game.get("native_track")
	var origin: float = track.route_progress(track.finish_center)
	var from: Vector2 = track._race_route_point(origin-1.0)
	# Deterministic route sweeps exercise actual gate completion and the signal;
	# this verifies workflow, not human driving acceptance.
	for step: int in range(ceili(track.route_length*2.0)+6):
		var to: Vector2 = track._race_route_point(origin+float(step)*0.5)
		game.call("_advance_practice_validation",from,to,track.nearest_route(to))
		from = to
	check(game.get("practice_validation").finished,"one complete ordered lap satisfies practice witness")
	await process_frame
	await process_frame
	doc = library.load_wip("publication_test")
	check(app.get("screen")=="drafts" and app.get("game")==null,"successful draft test returns to selection")
	check(library.is_tested(doc),"completion persists tested snapshot")
	check(TrackLibrary.new(library.directory).is_tested(doc),"tested status survives library reload")
	for child: Node in app.get("root_ui").get_children():
		if child is AcceptDialog: child.hide(); child.queue_free()
	await process_frame
	var browser: Node = app.get("root_ui").find_child("DraftBrowser",true,false)
	var search: LineEdit = browser.find_child("DraftSearch",true,false)
	search.text="Tested oval"; search.text_changed.emit(search.text)
	check(not browser.find_child("PublishDraft",true,false).disabled,"tested selection enables Publish")
	if "--capture" in OS.get_cmdline_user_args():
		for i: int in range(3): await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/evidence/draft-browser/tested.png"))
	var changed: Dictionary = doc.duplicate(true)
	changed.name = "Renamed oval"
	check(library.save_wip(changed)==OK and not library.is_tested(changed),"metadata modification clears tested status")
	check(library.save_wip(doc)==OK and not library.is_tested(doc),"undo to old content does not resurrect cleared test status")
	check(library.mark_tested(doc)==OK,"test receipt can be renewed after a new completion")
	changed = doc.duplicate(true)
	changed.objects.append({"kind":"tree","position":[50.0,50.0],"rotation":0.0,"scale":1.0})
	check(library.save_wip(changed)==OK and not library.is_tested(changed),"object changes invalidate test")
	check(library.save_wip(doc)==OK and library.mark_tested(doc)==OK,"restore completed-test fixture for publishing")
	app.call("_show_screen","drafts")
	app.call("_publish_saved_draft","wip:publication_test")
	await process_frame
	check(library.is_published(doc.id),"Publish persists local lock")
	check(not library.load_document(doc.id).is_empty(),"published track enters local playable library")
	check(library.editable_entries().filter(func(item: Dictionary) -> bool: return item.id==doc.id).is_empty(),"published track removed from draft gallery")
	check(library.save_wip(changed)==ERR_UNAUTHORIZED and library.save_document(changed)==ERR_UNAUTHORIZED,"published lock rejects autosave and original overwrite")
	check(TrackLibrary.new(library.directory).is_published(doc.id),"publication lock survives reload")
	for child: Node in app.get("root_ui").get_children():
		if child is AcceptDialog: child.hide(); child.queue_free()
	await process_frame
	app.call("_load_saved_document",doc.id)
	check(app.get("screen")=="drafts","direct stale load cannot edit published track")

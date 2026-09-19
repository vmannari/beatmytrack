extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func run() -> void:
	root.size=Vector2i(1280,720)
	root.gui_embed_subwindows=true
	var capture: bool = "--capture-delete" in OS.get_cmdline_user_args()
	var folder: String="user://delete_test_"+TrackLibrary.unique_id()
	var library:=TrackLibrary.new(folder)
	var doc: Dictionary=TrackDocument.create_default(); doc.name="Woodland practice"
	check(library.save_document(doc)==OK and library.save_document(doc)==OK,"create primary and backup")
	var other: Dictionary=doc.duplicate(true); other.id="keep_me"
	check(library.save_document(other)==OK,"create unrelated track")
	check(library.delete_document("../keep_me")==ERR_INVALID_PARAMETER,"reject path traversal")
	var app: Node=load("res://core/app.tscn").instantiate()
	var records:=LocalRecords.new(folder+"/records.json")
	records.settings["favorites"]=["creator_my_track","creator_keep_me"]
	records.settings["last_track"]="creator_my_track"
	app.set("library",library); app.set("records",records)
	root.add_child(app); await process_frame
	records.settings["favorites"]=["creator_my_track","creator_keep_me"]
	records.settings["last_track"]="creator_my_track"
	app.set("document",doc); app.call("_open_library","saved")
	var browser: TrackBrowser=app.get("root_ui").find_child("TrackBrowser",true,false)
	while browser.loading: await process_frame
	browser._select(TrackCatalog.local_metadata(doc))
	while browser.selecting: await process_frame
	check(browser.find_child("DeleteUserTrack",true,false)!=null,"saved track has a visible delete action")
	if capture:
		for i: int in range(3): await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/delete-track-library.png"))==OK,"library screenshot")
	(browser.find_child("DeleteUserTrack",true,false) as Button).pressed.emit()
	var dialog: ConfirmationDialog=app.find_child("DeleteTrackDialog",true,false)
	check(dialog!=null and dialog.visible,"delete asks for confirmation")
	check(FileAccess.file_exists(folder+"/my_track.json"),"opening confirmation does not delete")
	if capture:
		for i: int in range(3): await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/delete-track-confirm.png"))==OK,"confirmation screenshot")
	dialog.canceled.emit(); dialog.hide(); await process_frame
	check(not library.load_document("my_track").is_empty(),"cancel preserves saved track")
	app.call("_confirm_delete_track","my_track",doc.name)
	dialog=app.find_child("DeleteTrackDialog",true,false)
	var pending:=FileAccess.open(folder+"/my_track.json.tmp",FileAccess.WRITE); pending.store_string(JSON.stringify(doc)); pending.close()
	dialog.confirmed.emit(); dialog.hide(); await process_frame
	check(library.load_document("my_track").is_empty(),"deleted track cannot recover")
	for suffix: String in [".json",".json.bak",".json.tmp"]: check(not FileAccess.file_exists(folder+"/my_track"+suffix),"removed "+suffix)
	check(not library.load_document("keep_me").is_empty(),"unrelated user track retained")
	check("creator_my_track" not in records.settings.favorites and "creator_keep_me" in records.settings.favorites,"only deleted favorite removed")
	check(records.settings.last_track!="creator_my_track" and app.get("selected_track").identity!="creator_my_track","last and active selections cleared")
	check((app.get("document") as Dictionary).is_empty(),"in-memory editor cannot autosave deleted track")
	browser=app.get("root_ui").find_child("TrackBrowser",true,false)
	while browser.loading: await process_frame
	check(browser.matches.size()==1 and browser.matches[0].local_id=="keep_me","library reindexes after deletion")
	browser._show_detail()
	check(browser.find_child("DeleteUserTrack",true,false)==null,"built-in track has no delete action")
	var draft: Dictionary=doc.duplicate(true); draft.id="unfinished"; draft.points[1]=draft.points[0].duplicate()
	check(library.save_document(draft)==OK,"save unfinished draft")
	browser._select(TrackCatalog.local_metadata(draft))
	while browser.selecting: await process_frame
	check(browser.find_child("DeleteUserTrack",true,false)!=null,"unfinished draft can also be deleted")
	app.queue_free(); await process_frame
	var temp:=DirAccess.open(folder)
	for file: String in temp.get_files(): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)
	print("DELETE_TRACK_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

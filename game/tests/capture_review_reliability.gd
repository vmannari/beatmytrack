extends SceneTree
## Visual acceptance evidence uses only a disposable fixture identity and replay.
var app: Node
var folder: String

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	folder = "user://review_capture_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.online.client.configure("http://127.0.0.1:1")
	app.online.client._access_token = "disposable-fixture"
	app.online.client.player = {"id":"review-fixture", "display_name":"Review fixture"}
	app.cloud.queue_run({"ticket_id":"pending-fixture"},[[0,255,0]])
	app.cloud.queue_run({"ticket_id":"failed-fixture"},[[0,255,0]])
	for job: Dictionary in app.cloud.upload_jobs():
		if job.ticket == "failed-fixture":
			job.failure = "invalid_replay"
			app.cloud._save_job(str(job._path),job)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		app._show_screen("profile")
		await capture("profile",dimensions)
		app.cloud.show_uploads(app.root_ui)
		await capture("uploads",dimensions)
		var dialog: AcceptDialog = app.root_ui.find_child("*",false,false) as AcceptDialog
		for child: Node in app.root_ui.get_children():
			if child is AcceptDialog: dialog = child
		if dialog != null: dialog.hide(); dialog.queue_free()
		await process_frame
	root.size = Vector2i(1280,720)
	app.document = TrackDocument.create_blank()
	app.document.id = "save_dialog_fixture"
	app._show_screen("create")
	app._save_track_explicit()
	var save_dialog: ConfirmationDialog = app.root_ui.find_child("SaveChangesDialog",true,false)
	if save_dialog == null: quit(1); return
	var field: LineEdit = save_dialog.find_child("SaveDraftName",true,false)
	field.text = "Review save fixture"
	field.text_changed.emit(field.text)
	await capture("save-confirmation",Vector2i(1280,720))
	save_dialog.confirmed.emit()
	await capture("save-result",Vector2i(1280,720))
	app.queue_free()
	await process_frame
	cleanup(folder)
	print("REVIEW_CAPTURE: 6 screenshots, disposable data only")
	quit(0)

func capture(label: String, dimensions: Vector2i) -> void:
	for frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://../docs/evidence/code-review-fixes-2026-10-03/"+label+"-%dx%d.png" % [dimensions.x,dimensions.y]
	if root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) != OK: quit(1)

func cleanup(path: String) -> void:
	if not path.begins_with("user://review_capture_track_"): return
	var directory := DirAccess.open(path)
	if directory == null: return
	for name: String in directory.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name: String in directory.get_directories(): cleanup(path.path_join(name))
	DirAccess.remove_absolute(path)

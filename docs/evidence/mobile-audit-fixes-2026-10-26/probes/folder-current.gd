extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	pass
	var app: Node = load("res://core/app.tscn").instantiate()
	var folder: String = "user://folder-baseline-"+TrackLibrary.unique_id()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.challenges.folder = "received"
	app._show_screen("challenges")
	app._stop_menu_page_motion()
	var page: Control = app.content.find_child("ChallengesPage",true,false)
	print("FOLDER_FIXTURE landing=",page.landing_view," tab_sent=",page.find_child("ChallengeTab_sent",true,false)!=null)
	app.queue_free()
	await process_frame
	quit()

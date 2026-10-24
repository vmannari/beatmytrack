extends SceneTree
## Actual native menu composition with an isolated configuration fixture.
const AppScene = preload("res://core/app.tscn")
const Policy = preload("res://backend/game_config_policy.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var folder: String = "user://configuration-app-"+TrackLibrary.unique_id()
	var destination: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-game-config="): destination = argument.trim_prefix("--capture-game-config=")
	var app: Node = AppScene.instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.set_process(false)
	var configuration: Node = app.game_configuration
	configuration._reset_scope()
	configuration._allowed = true
	for child: Node in configuration.get_children():
		if child is Timer: child.stop()
	var policy: Dictionary = Policy.DEFAULTS.duplicate(true)
	policy["notice.message"] = "Welcome to Beat my track."
	policy["features.challenge_creation"] = false
	configuration.pending = {"settings":policy,"generation":1,"control_revision":1,"resolution_id":"a".repeat(64),"assignments":[]}
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(540,960)]:
		root.size = size
		app._show_screen("tracks")
		for frame: int in range(5): await process_frame
		var notice: Label = app.content.find_child("RemoteGameNotice",true,false) as Label
		check(notice != null and notice.is_visible_in_tree(),"real App displays configured notice: "+str(size))
		if notice != null:
			check(notice.text == policy["notice.message"],"real notice uses exact policy text")
			check(notice.get_global_rect().position.y >= 0 and notice.get_global_rect().end.y <= root.size.y,"notice remains inside viewport")
		if not destination.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(destination)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(destination.path_join("notice-"+str(size.x)+"x"+str(size.y)+".png")) == OK,"write native configuration preview")
	check(not configuration.settings["features.challenge_creation"],"App applies new challenge-entry availability at menu boundary")
	configuration.pending.settings["notice.message"] = "A new menu notice"
	configuration.pending.resolution_id = "b".repeat(64)
	app._navigate_menu_page("tracks")
	for frame: int in range(3): await process_frame
	var refreshed_notice: Label = app.content.find_child("RemoteGameNotice",true,false) as Label
	check(refreshed_notice != null and refreshed_notice.text == "A new menu notice","retained menu transition applies a pending notice")
	check(app.content.get_children().filter(func(child: Node) -> bool: return child.name == "RemoteGameNotice").size() == 1,"retained menu refresh replaces the old notice")
	check(not app.race_ad_breaks.policy.get("ads.permitted",false),"menu entry cannot enable automatic ads")
	app.queue_free()
	await process_frame
	await process_frame
	print("GAME_CONFIGURATION_APP: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

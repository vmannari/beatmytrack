extends "res://tests/test_rivalry_entry.gd"
## Real menu activation must retain failed enrollment and allow an explicit retry.

func error_visible(message: String) -> bool:
	for label: Node in app.content.find_children("*","Label",true,false):
		if label.text == message and label.is_visible_in_tree() and root.get_visible_rect().encloses(label.get_global_rect()): return true
	return false

func run() -> void:
	var profile: String = ProjectSettings.globalize_path("user://").replace("\\","/").simplify_path()
	var isolated_root: String = ProjectSettings.globalize_path("res://../build/rivalry-join-feedback/").replace("\\","/").simplify_path().trim_suffix("/")+"/"
	if not profile.begins_with(isolated_root):
		check(false,"set APPDATA under build/rivalry-join-feedback before running this fixture")
		quit(1)
		return
	OS.set_environment("BMT_API_URL","")
	var offline := ConfigFile.new()
	offline.set_value("backend","url","")
	check(offline.save("user://backend.cfg") == OK,"isolated profile disables real service access")
	evidence = OS.get_environment("BMT_RIVALRY_ENTRY_CAPTURE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	var directory: String = "user://rivalry_join_failure_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.configured and app.online.client.base_url().is_empty(),"fixture starts with no real backend")
	service = Service.new()
	app.add_child(service)
	app.rivalry.client = service
	app.rivalry.cache_directory = ""
	app.online.client.player = service.player
	app.online.client._access_token = "fixture"
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		service.development = false
		app.rivalry.reset()
		app._show_screen("tracks")
		await settle()
		app._open_rivalry()
		service.respond({"ok":false,"error":"CONNECTION_FAILED","data":{}})
		await settle()
		app._finish_menu_page_slide()
		await settle()
		check(not app.rivalry.busy and not app.rivalry.error.is_empty(),"failed entry survives destination activation")
		check(error_visible(app.rivalry.error) and not app.rivalry.error.is_empty(),"failed entry displays a complete visible error")
		var failed_calls: int = service.calls
		app._prefetch_rivalry()
		app._activate_menu_page(app._navigation_generation)
		check(service.calls == failed_calls,"passive preparation preserves the failure without sending another request")
		await capture("entry-failed",dimensions)
		# Resolve any unwanted baseline auto-refresh, then use the actual retry.
		if not service.pending_path.is_empty(): service.respond({"ok":false,"error":"CONNECTION_FAILED","data":{}})
		var retry: Button = app.content.find_child("RivalryRefresh",true,false)
		check(retry != null and not retry.disabled,"failed entry keeps Refresh available")
		if retry != null: retry.pressed.emit()
		check(app.rivalry.busy and service.pending_path.begins_with("/rivalry/current"),"explicit Refresh retries immediately")
		service.respond({"ok":true,"data":{"state":"not_joined","week":41,"ends_at":604800,"server_now":0}})
		await settle()
		var join_button: Button = app.content.find_child("RivalryJoin",true,false)
		check(join_button != null and not join_button.disabled,"confirmed nonmember can join")
		if join_button != null: join_button.pressed.emit()
		check(service.pending_path == "/rivalry/join","actual Join button requests enrollment")
		var joining_calls: int = service.calls
		app.rivalry.join()
		check(service.calls == joining_calls,"repeated Join does not overlap enrollment")
		service.respond({"ok":false,"error":"NOT_ENOUGH_ELIGIBLE_TRACKS","data":{}})
		await settle()
		check(not app.rivalry.busy and error_visible(app.rivalry.error),"failed manual enrollment displays its reason")
		check(app.rivalry.error == "Five eligible tracks are needed before a rivalry can open.","known enrollment rejection retains its actionable explanation")
		await capture("join-failed",dimensions)
		join_button = app.content.find_child("RivalryJoin",true,false)
		check(join_button != null and not join_button.disabled,"failed enrollment enables another Join")
		if join_button != null: join_button.pressed.emit()
		service.respond({"ok":true,"data":snapshot()})
		await settle()
		check(app.rivalry.error.is_empty() and app.content.find_child("RivalryTracksPanel",true,false) != null,"successful Join clears the error and opens all tracks")
		# Development enrollment follows the same failure/retry presentation.
		service.development = true
		app.rivalry.reset()
		app._open_rivalry()
		service.respond({"ok":true,"data":{"state":"not_joined","week":41,"ends_at":604800,"server_now":0,"test_population":true}})
		check(service.pending_path == "/rivalry/join","development entry automatically requests enrollment")
		service.respond({"ok":false,"error":"UNAVAILABLE","data":{}})
		await settle()
		app._finish_menu_page_slide()
		await settle()
		check(not app.rivalry.error.is_empty() and error_visible(app.rivalry.error),"automatic enrollment failure stays visible")
		await capture("automatic-join-failed",dimensions)
		failed_calls = service.calls
		app._prefetch_rivalry()
		check(service.calls == failed_calls and not app.rivalry.busy,"prefetch cannot erase automatic enrollment failure")
		# Advance only the presentation refresh age, without a thirty-second wait.
		app.rivalry._last_refresh_msec -= app.rivalry.REFRESH_INTERVAL_MSEC
		app.rivalry.refresh(false)
		check(app.rivalry.busy and service.pending_path.begins_with("/rivalry/current"),"passive refresh can recover once the normal interval expires")
		service.respond({"ok":true,"data":{"state":"active"}})
		await settle()
		check(not app.rivalry.error.is_empty() and error_visible(app.rivalry.error),"malformed successful response also produces visible failure feedback")
		# A different account starts fresh, even after the previous failure.
		service.player.id = "another-player"
		app.rivalry.refresh(false)
		check(app.rivalry.busy and app.rivalry.error.is_empty(),"failed old identity does not block the new account's initial request")
		service.respond({"ok":true,"data":snapshot()})
		service.player.id = "you"
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("RIVALRY_JOIN_FAILURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends SceneTree
## Native sign-in captures and geometry checks; persistence uses fresh fixtures.
var app: Node
var failures: int = 0
var checks: int = 0
var output: String = ""
var capture_locales: bool = false
func _initialize() -> void: run.call_deferred()
func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--locales": capture_locales = true
	var folder: String = "user://sign_in_fit_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec() + 20000
	while not app.startup_complete and Time.get_ticks_msec() < deadline: await process_frame
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1600,720), Vector2i(800,600)]:
		root.size = dimensions
		for state: String in ["offline", "google", "setup", "retry", "waiting", "name", "country", "account", "long-error"]:
			var account: Node = app.online
			account.client._access_token = "fixture" if state in ["name", "country", "account"] else ""
			account.client.player = {"id":"fixture", "display_name":"Fit fixture", "needs_username":state == "name", "country_code":"" if state in ["name", "country"] else "FI"}
			account.configured = state != "offline"
			account.capabilities = {"development_auth":state != "google", "google_browser_configured":state != "setup"}
			account.retry_available = state == "retry"
			account.waiting_for_google = state == "waiting"
			account.message = "Online sign-in is not configured yet." if state == "offline" else "Could not connect. Check your connection and try again." if state == "retry" else "Complete sign-in in your browser, then return here." if state == "waiting" else ""
			if state == "long-error":
				account.retry_available = true
				account.message = "Could not connect. Check your connection and try again. Your sign-in could not be completed. Please return to the game and retry the connection."
			app._show_screen("account")
			for _frame: int in range(10): await process_frame
			var panel: Control = app.root_ui.find_child("GoogleSignIn", true, false).get_parent().get_parent()
			var bounds: Rect2 = root.get_visible_rect()
			var fits: bool = bounds.grow(-16).encloses(panel.get_global_rect())
			checks += 1
			if not fits: failures += 1
			print("FIT %dx%d %s viewport=%s card=%s min=%s fits=%s" % [dimensions.x,dimensions.y,state,bounds,panel.get_global_rect(),panel.get_combined_minimum_size(),fits])
			checks += 1
			if panel.get_global_rect().get_center().distance_to(bounds.get_center()) > 1.0:
				failures += 1
				print("FAIL: sign-in card is not centered ", dimensions, " ", state)
			var developer: Control = app.root_ui.find_child("DevelopmentSignIn",true,false)
			var google: Control = app.root_ui.find_child("GoogleSignIn",true,false)
			if developer.is_visible_in_tree() and google.is_visible_in_tree():
				checks += 1
				if absf(developer.size.x-google.size.x) > 1.0 or absf(developer.get_global_rect().position.x-google.get_global_rect().position.x) > 1.0:
					failures += 1
					print("FAIL: provider button widths or left edges differ")
			for child: Node in panel.find_children("*", "Control", true, false):
				var control := child as Control
				if not control.is_visible_in_tree() or control.get_window() != panel.get_window(): continue
				checks += 1
				if not panel.get_global_rect().encloses(control.get_global_rect()):
					failures += 1
					print("FAIL: card clips ",control.name," ", control.get_global_rect())
			var ancestor: Node = panel.get_parent()
			while ancestor != app.root_ui:
				checks += 1
				if ancestor is ScrollContainer:
					failures += 1
					print("FAIL: sign-in still scrolls")
				ancestor = ancestor.get_parent()
			if not output.is_empty() and DisplayServer.get_name() != "headless":
				DirAccess.make_dir_recursive_absolute(output)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%s-%dx%d.png" % [state,dimensions.x,dimensions.y]))
	# Provider responses and window changes must refit the retained card too.
	root.size = Vector2i(960,540)
	app.online.client._access_token = ""
	app.online.client.player = {}
	app._show_screen("account")
	var retained: Control = app.root_ui.find_child("GoogleSignIn", true, false).get_parent().get_parent()
	for message: String in ["Could not connect. Check your connection and try again. Your sign-in could not be completed. Please return to the game and retry the connection.", ""]:
		app.online.message = message
		app.online.changed.emit()
		for _frame: int in range(10): await process_frame
		checks += 1
		if not is_instance_valid(retained) or not root.get_visible_rect().grow(-16).encloses(retained.get_global_rect()):
			failures += 1
			print("FAIL: retained sign-in does not refit after provider response")
	root.size = Vector2i(800,600)
	for _frame: int in range(10): await process_frame
	checks += 1
	if not root.get_visible_rect().grow(-16).encloses(retained.get_global_rect()):
		failures += 1
		print("FAIL: retained sign-in does not refit after resize")
	if capture_locales:
		app.online.client._access_token = ""
		app.online.client.player = {}
		app.online.configured = true
		app.online.capabilities = {"development_auth":false, "google_browser_configured":true}
		app.online.retry_available = false
		app.online.waiting_for_google = false
		app.online.message = ""
		var language: Node = root.get_node("Language")
		for code: String in language.locales:
			language.choose(code)
			for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(960,540), Vector2i(800,1000)]:
				root.size = dimensions
				app._show_screen("account")
				for _frame: int in range(10): await process_frame
				var panel: Control = app.root_ui.find_child("AccountCard",true,false)
				checks += 1
				if panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) > 1.0:
					failures += 1
					print("FAIL: localized card is not centered ",code," ",dimensions)
				checks += 1
				if not root.get_visible_rect().grow(-16).encloses(panel.get_global_rect()):
					failures += 1
					print("FAIL: localized card does not fit ",code," ",dimensions," ",panel.get_global_rect())
				for child: Node in panel.find_children("*", "Control", true, false):
					var control := child as Control
					if not control.is_visible_in_tree() or control.get_window() != panel.get_window(): continue
					checks += 1
					if not panel.get_global_rect().encloses(control.get_global_rect()):
						failures += 1
						print("FAIL: localized card clips ",code," ",control.name)
				if not output.is_empty() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join("locale-%s-%dx%d.png" % [code,dimensions.x,dimensions.y]))
	app.queue_free()
	await process_frame
	print("SIGN_IN_FIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

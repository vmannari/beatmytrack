extends SceneTree
## Actual owned notices: input isolation, dismissal, focus, wrapping and rendered UI.
const Fault = preload("res://ui/fault_dialog.gd")
const SERVER_UPDATE: String = "This game update needs a matching server update before online racing is available."
var app: Node
var checks: int = 0
var failures: int = 0
var evidence: String = "res://../docs/evidence/fault-message-2026-10-11"

func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",text)

func settle() -> void:
	for frame: int in range(3): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func current() -> AcceptDialog:
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog: return child
	return null

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))

func click(point: Vector2, touch: bool = false) -> void:
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 9
		event.position = point
		event.pressed = true
		root.push_input(event,true)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event,true)
	else:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = true
		root.push_input(event,true)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event,true)
	await settle()

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event,true)
	await settle()

func check_layout(dialog: AcceptDialog, title: String) -> void:
	var surface: Control = dialog.surface
	var bounds: Rect2 = surface.get_global_rect()
	check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"dialog fits viewport: "+title)
	check(bounds.encloses(dialog.confirm_button.get_global_rect()) and bounds.encloses(dialog.close_button.get_global_rect()),"both dismissal controls fit: "+title)
	check(dialog.confirm_button.size.y >= 52 and dialog.close_button.size.x >= 52 and dialog.close_button.size.y >= 52,"touch targets remain at least 52 logical pixels: "+title)
	check(dialog.copy_scroll.get_global_rect().end.y <= dialog.confirm_button.get_global_rect().position.y-12,"long body cannot overlap the primary action: "+title)
	check(dialog.message_label.text == dialog.dialog_text,"exact actionable cause is preserved: "+title)
	check(not dialog.get_label().visible and not dialog.get_ok_button().visible,"native duplicate text and controls stay hidden: "+title)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	root.size = Vector2i(1280,720)
	var folder: String = "user://fault_dialog_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.rivalry.model = WeeklyRivalry.new(true)
	app.rivalry.model.tracks[0].name = "Dust Cloud"
	app.rivalry.model.tracks[0].theme = "desert"
	app.rivalry_section = "detail"
	app.rivalry_track = 0
	app._show_screen("rivalry")
	await settle()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		var prior: Button = app.root_ui.find_child("Tab_garage",true,false)
		prior.grab_focus()
		app._notice(SERVER_UPDATE)
		await settle()
		var dialog: AcceptDialog = current()
		check(dialog != null and dialog.get_script() == Fault,"application uses the styled owned fault dialog")
		if dialog == null: continue
		check_layout(dialog,str(dimensions))
		check(dialog.heading.text == "Can't go online yet" and dialog.eyebrow.text == "UPDATE REQUIRED","update failure gets a clear category and human title")
		check(dialog.support.visible and dialog.support_body.text == "Choose a downloaded track in Free Race.","support describes a real offline path")
		check(not dialog.support_body.text.contains("being updated") and not dialog.support_body.text.contains("almost") and not dialog.support_body.text.contains("progress"),"fault message makes no rollout or saving promises")
		check(dialog.warning.texture.get_width() >= dialog.warning.size.x,"large warning icon retains sufficient source resolution")
		check(dialog.confirm_button.has_focus(),"primary dismissal receives keyboard focus")
		await click(prior.get_global_rect().get_center())
		check(app.screen == "rivalry" and is_instance_valid(dialog) and dialog.visible,"mouse outside dialog cannot activate underlying menus")
		await click(prior.get_global_rect().get_center(),true)
		check(app.screen == "rivalry" and is_instance_valid(dialog) and dialog.visible,"touch outside dialog cannot activate underlying menus")
		await capture("server-update-%dx%d" % [dimensions.x,dimensions.y])
		var scrim: Node = dialog.backdrop
		var count: Dictionary = {"confirmed":0}
		dialog.confirmed.connect(func() -> void: count.confirmed += 1)
		dialog.confirm_button.pressed.emit()
		await settle()
		check(count.confirmed == 1 and not is_instance_valid(dialog) and not is_instance_valid(scrim),"OK dismisses once and removes both modal and scrim")
		check(prior.has_focus(),"dismissing returns focus to the prior menu control")
	root.size = Vector2i(1280,720)
	for message: String in ["Track download failed. Check your connection and try again.","Garage changes could not be saved. Check free storage space.","Race loading timed out. Try again."]:
		app._notice(message)
		await settle()
		var dialog: AcceptDialog = current()
		check_layout(dialog,message)
		check(not dialog.support.visible,"ordinary faults do not repeat the update-only offline explanation")
		await capture("storage" if message.contains("Garage") else "timeout" if message.contains("timed out") else "connection")
		dialog.close_button.pressed.emit()
		await settle()
		check(current() == null and app.root_ui.find_child("FaultMessageScrim",false,false) == null,"Close uses owned cancellation and removes its scrim")
	for code: Key in [KEY_ESCAPE,KEY_ENTER]:
		app._notice(SERVER_UPDATE)
		await settle()
		await key(code)
		check(current() == null and app.root_ui.find_child("FaultMessageScrim",false,false) == null,"keyboard dismisses without leaving invisible input blockers: "+str(code))
	app._notice("Track could not be prepared. "+"Please select a different downloaded track or check the saved route. ".repeat(20))
	await settle()
	var long_notice: AcceptDialog = current()
	check_layout(long_notice,"long cause")
	check(long_notice.copy_scroll.get_v_scroll_bar().max_value > long_notice.copy_scroll.size.y,"exceptionally long cause scrolls inside its reserved body area")
	await capture("long-cause")
	long_notice.close_button.pressed.emit()
	await settle()
	app._notice("Circuit exported.")
	await settle()
	check(current() != null and current().get_script() == Fault and current().heading.text == "Track exported" and not current().message_label.visible,"successful export uses the shared style without a fault heading or redundant success copy")
	current().queue_free()
	await settle()
	app._notice(SERVER_UPDATE)
	await settle()
	app._show_screen("tracks")
	await settle()
	check(current() == null and app.root_ui.find_child("FaultMessageScrim",false,false) == null,"navigation destroys the old notice and leaves the new page interactive")
	app._notice("Saved on this device. Open Load track to edit or test it.")
	app._show_screen("tracks")
	await settle()
	check(current() == null,"same-frame navigation cancels deferred focus for a discarded information popup")
	app.queue_free()
	await process_frame
	print("FAULT_DIALOG: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

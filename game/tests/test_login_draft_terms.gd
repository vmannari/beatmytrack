extends SceneTree
## Isolated native agreement, reader and exact-copy checks; no provider requests.
var checks: int = 0
var failures: int = 0
var output: String = ""
var continued: int = 0

class FixtureAccount extends "res://backend/account_controller.gd":
	var google_requests: int = 0
	var developer_requests: int = 0
	func _ready() -> void:
		add_child(client)
		configured = true
		capabilities = {"development_auth":true, "google_browser_configured":true}
	func sign_in_google() -> void: google_requests += 1
	func sign_in_developer() -> void: developer_requests += 1

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",description)

func settle() -> void:
	for _frame: int in range(10): await process_frame

func click(control: Control) -> void:
	var position: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = position
		event.global_position = position
		root.push_input(event)
		await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var directory: String = "user://login_terms_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var language: Node = root.get_node("Language")
	language.configure(directory.path_join("language.json"))
	language.choose("en")
	root.size = Vector2i(1280,720)
	var account := FixtureAccount.new()
	root.add_child(account)
	var scenery := preload("res://ui/account_backdrop.gd").new()
	MenuStyle.fill(scenery)
	root.add_child(scenery)
	var center := CenterContainer.new()
	center.theme = MenuStyle.theme()
	MenuStyle.fill(center)
	root.add_child(center)
	var panel := preload("res://ui/account_panel.gd").new()
	panel.account = account
	panel.continue_requested.connect(func() -> void: continued += 1)
	center.add_child(panel)
	await settle()
	check(not panel.terms_check.button_pressed,"draft agreement starts unchecked")
	check(not panel.google_button.disabled and not panel.guest_button.disabled,"unchecked actions accept input to explain the agreement requirement")
	await click(panel.google_button)
	check(panel.terms_attention and panel.footer.text == panel.TERMS_REQUIRED and panel.footer.is_visible_in_tree(),"Google press explains the missing agreement")
	check(panel.terms_check.has_focus(),"missing agreement focuses the highlighted checkbox")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(output)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("terms-required.png"))
	await click(panel.development_button)
	await click(panel.guest_button)
	check(account.google_requests == 0 and account.developer_requests == 0 and continued == 0,"unchecked Google, developer and guest actions never dispatch")
	check(panel.terms_attention,"repeated presses retain the agreement warning")
	check(language.choose("fi") == OK,"language can change while the agreement warning is active")
	await settle()
	check(panel.terms_attention and panel.footer.get_theme_color("font_color") == Color("ff9a86"),"language change preserves warning and highlight")
	check(TranslationServer.translate(panel.TERMS_REQUIRED) == "Hyväksy käyttöehdot jatkaaksesi.","active warning has the correct Finnish instruction")
	language.choose("en")
	await settle()
	panel.terms_copy.meta_clicked.emit("terms")
	await settle()
	var dialog: AcceptDialog = panel.get_node("DraftTermsDialog")
	check(dialog.visible and dialog.title == "Terms of Service (draft)","terms link opens a labeled draft reader")
	var text: RichTextLabel = dialog.find_child("DraftTermsText",true,false)
	check(text.selection_enabled and text.scroll_active,"draft is selectable and scrollable")
	check(text.get_parsed_text().contains("bmt-terms-draft-2026-10-25-r6"),"reader identifies the exact r6 draft")
	check(text.get_parsed_text().contains("19 Sale transfer and successor operators"),"reader includes the final section")
	check(not panel.terms_check.button_pressed,"reading terms does not imply agreement")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(output)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("draft-terms-reader.png"))
	dialog.custom_action.emit("save")
	await settle()
	var picker: FileDialog = null
	for child: Node in dialog.get_children():
		if child is FileDialog: picker = child
	check(picker != null and picker.visible,"Save a copy opens a native destination picker")
	var destination: String = directory.path_join("terms-copy.txt")
	picker.file_selected.emit(destination)
	check(FileAccess.get_file_as_bytes(destination) == FileAccess.get_file_as_bytes(dialog.DOCUMENT),"saved copy preserves every draft byte")
	picker.hide()
	dialog.confirmed.emit()
	await settle()
	check(not panel.has_node("DraftTermsDialog"),"closing reader removes its modal")
	await click(panel.terms_check)
	check(panel.terms_check.button_pressed and not panel.google_button.disabled and not panel.guest_button.disabled,"real checkbox input enables both routes")
	check(not panel.terms_attention and panel.footer.text != panel.TERMS_REQUIRED,"accepting clears the warning and restores the usual footer")
	await click(panel.google_button)
	check(account.google_requests == 1,"agreed Google action reaches the existing controller once")
	await click(panel.development_button)
	check(account.developer_requests == 1,"agreed developer action reaches the existing controller once")
	await click(panel.guest_button)
	check(continued == 1,"agreed guest action dispatches once")
	await click(panel.terms_check)
	await click(panel.google_button)
	check(panel.terms_attention and account.google_requests == 1,"unchecking restores the gate and explains another attempted sign-in")
	panel.terms_check.grab_focus()
	for down: bool in [true,false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = down
		root.push_input(key)
		await process_frame
	check(panel.terms_check.button_pressed,"keyboard Space toggles the focused checkbox")
	check(not panel.google_button.disabled and not panel.guest_button.disabled,"keyboard agreement enables both routes")
	check(not panel.terms_attention,"keyboard agreement clears the warning")
	account.busy = true
	account.changed.emit()
	check(panel.google_button.disabled and panel.development_button.disabled,"busy provider actions remain disabled")
	account.busy = false
	account.configured = false
	panel.terms_check.button_pressed = false
	account.changed.emit()
	await click(panel.google_button)
	check(panel.terms_attention and account.google_requests == 1,"unconfigured sign-in can explain missing terms without starting a provider request")
	panel.terms_check.button_pressed = true
	check(panel.google_button.disabled and panel.development_button.disabled,"accepted terms do not bypass unavailable provider configuration")
	account.configured = true
	account.waiting_for_google = true
	account.changed.emit()
	check(panel.cancel_button.visible and panel.guest_button.disabled,"provider wait retains cancellation and blocks guest navigation")
	account.waiting_for_google = false
	account.client._access_token = "fictional"
	account.client.player = {"id":"fixture","display_name":"Fixture", "country_code":"FI"}
	account.changed.emit()
	check(not panel.terms_row.visible and not panel.guest_button.disabled,"existing signed-in account management stays available")
	center.queue_free()
	scenery.queue_free()
	account.queue_free()
	await process_frame
	print("LOGIN_DRAFT_TERMS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

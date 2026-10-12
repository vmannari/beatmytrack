extends SceneTree
## Real popup builders, native action semantics and reusable windows; isolated saves.
var app: Node
var checks: int = 0
var failures: int = 0
var evidence: String = "res://../docs/evidence/unified-popups-2026-10-11"
const PopupChrome = preload("res://ui/popup_style.gd")
const Fault = preload("res://ui/fault_dialog.gd")

class Scores extends "res://backend/backend_client.gd":
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		await get_tree().process_frame
		return {"ok":true,"data":{"board_id":"fixture","population":2,"items":[{"rank":1,"display_name":"Fixture driver","country_code":"FI","time_ticks":11000},{"rank":2,"display_name":"Other driver","country_code":"GB","time_ticks":12000}],"next_cursor":null,"next_offset":null}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",text)

func settle() -> void:
	for frame: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))

func type_text(field: LineEdit, text: String) -> void:
	field.grab_focus()
	for character: String in text:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.keycode = character.to_upper().unicode_at(0) as Key
		event.physical_keycode = event.keycode
		event.pressed = true
		field.get_viewport().push_input(event,true)
		event = event.duplicate()
		event.pressed = false
		field.get_viewport().push_input(event,true)
	await settle()

func visible_dialog(parent: Node = null) -> AcceptDialog:
	if parent == null: parent = app
	for child: Node in parent.get_children():
		if child is AcceptDialog and child.visible: return child
		var found: AcceptDialog = visible_dialog(child)
		if found != null: return found
	return null

func inspect(dialog: AcceptDialog, label: String) -> void:
	check(dialog != null and dialog.has_meta("menu_popup_style"),"actual popup uses shared style: "+label)
	if dialog == null: return
	var chrome: Node = dialog.get_node_or_null("PopupStyle")
	check(chrome != null and chrome.prepared,"native popup has prepared chrome: "+label)
	if chrome == null: return
	check(dialog.borderless and dialog.transparent,"native window chrome is replaced: "+label)
	check(chrome.art.texture == PopupChrome.ART and chrome.art.size == Vector2(dialog.size),"scenery fills this popup: "+label)
	var bounds := Rect2(Vector2.ZERO,Vector2(dialog.size))
	check(bounds.encloses(chrome.close_button.get_global_rect()),"Close fits popup: "+label)
	check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"popup fits current viewport: "+label)
	check(dialog.get_ok_button().size.y >= 52,"native primary action keeps a touch target: "+label)
	check(chrome.shade_layer.visible,"popup has a visible shared scrim: "+label)
	check(chrome.close_button.size.x >= 52 and chrome.close_button.size.y >= 52,"shared Close keeps a touch target: "+label)
	if chrome.body != null: check(chrome.body.get_global_rect().end.y <= dialog.get_ok_button().get_parent().get_global_rect().position.y,"body leaves room for native actions: "+label)

func close(dialog: AcceptDialog) -> void:
	var chrome: Node = dialog.get_node("PopupStyle")
	var shade: Node = chrome.shade_layer
	chrome.close_button.pressed.emit()
	await settle()
	check(not is_instance_valid(dialog) or not dialog.visible,"Close dismisses through cancellation")
	if is_instance_valid(dialog):
		check(not shade.visible,"reusable popup hides its scrim")
	else:
		check(not is_instance_valid(shade),"owned popup frees its scrim")

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	root.size = Vector2i(1280,720)
	var folder: String = "user://popup_style_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	await settle()
	for text: String in ["Circuit exported.","Track published.","Saved on this device. Open Load track to edit or test it.","Confirm or cancel the pending previews before testing."]:
		app._notice(text)
		await settle()
		var notice: AcceptDialog = visible_dialog()
		check(notice != null and notice.get_script() == Fault,"all information/preview notices use the scenic message family")
		check(notice.dialog_text == text and not notice.warning.texture == MenuIcon.texture("warning",true),"information keeps its meaning and appropriate symbol")
		await capture("information-"+str(checks))
		notice.confirm_button.pressed.emit()
		await settle()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		var dialog := ConfirmationDialog.new()
		dialog.title = "Delete this draft?"
		dialog.dialog_text = "This removes the local draft. Published tracks remain available."
		dialog.ok_button_text = "Delete draft"
		var calls: Dictionary = {"confirmed":0,"canceled":0,"custom":0}
		dialog.confirmed.connect(func() -> void: calls.confirmed += 1)
		dialog.canceled.connect(func() -> void: calls.canceled += 1)
		var extra: Button = dialog.add_button("Keep a copy",true,"copy")
		dialog.custom_action.connect(func(_action: StringName) -> void: calls.custom += 1)
		app._own_dialog(dialog)
		dialog.popup_centered(Vector2i(500,210))
		await settle()
		inspect(dialog,"confirmation "+str(dimensions))
		check(dialog.get_ok_button().text == "Delete draft" and dialog.get_cancel_button().text == "Cancel","native destructive action and cancel labels are preserved")
		extra.pressed.emit()
		check(calls.custom == 1 and calls.confirmed == 0 and dialog.visible,"extra actions keep their native custom-action semantics")
		await capture("confirmation-%dx%d" % [dimensions.x,dimensions.y])
		await close(dialog)
		check(calls.canceled == 1 and calls.confirmed == 0,"Close never confirms a destructive action")
	root.size = Vector2i(1280,720)
	var changing := AcceptDialog.new()
	changing.title = "Share this circuit"
	changing.dialog_text = "Copy this circuit or export a file."
	var copy: Button = changing.add_button("Copy",false,"copy")
	changing.custom_action.connect(func(_action: StringName) -> void: changing.dialog_text = "Circuit copied. Paste it into Import a circuit.")
	app._own_dialog(changing)
	changing.popup_centered(Vector2i(650,220))
	await settle()
	copy.pressed.emit()
	await settle()
	check(changing.get_node("PopupStyle").message.text == changing.dialog_text,"messages changed by native extra actions update in the styled body")
	await capture("share-updated")
	await close(changing)
	app._challenge_code_dialog()
	await settle()
	var dialog: AcceptDialog = visible_dialog()
	inspect(dialog,"challenge code")
	var field: LineEdit = dialog.find_child("ChallengeCode",true,false)
	check(field != null and field.max_length == 2048 and field.has_focus(),"native form retains editable field limits and requested focus")
	check(dialog.get_node("PopupStyle").body.get_global_rect().encloses(field.get_global_rect()),"challenge field is in the reserved body")
	await capture("challenge-code")
	await close(dialog)
	var picker: Button = preload("res://ui/country_picker.gd").new()
	app.root_ui.add_child(picker)
	picker._open()
	await settle()
	dialog = picker.dialog
	inspect(dialog,"country selection")
	await type_text(picker.search,"Finland")
	await settle()
	check(picker.matches == ["FI"] and picker.search.has_focus(),"search still filters the reusable country picker")
	await capture("country-picker")
	picker._choose(0)
	await settle()
	check(picker.country_code == "FI" and not dialog.visible and not dialog.get_node("PopupStyle").shade_layer.visible,"country choice updates the value and hides the reusable popup")
	picker._open()
	await settle()
	check(picker.dialog == dialog and dialog.get_children().filter(func(child: Node) -> bool: return child.name == "PopupStyle").size() == 1,"reopening does not add duplicate chrome or content")
	await close(dialog)
	picker.queue_free()
	await settle()
	var browser: TrackBrowser = app.root_ui.find_child("TrackBrowser",true,false)
	browser.selected_track.metadata.cloud_version = "fixture-rating"
	browser._open_rating()
	await settle()
	dialog = visible_dialog()
	inspect(dialog,"track rating")
	check(dialog.find_child("Rate5",true,false) != null,"existing rating controls remain available")
	await capture("track-rating")
	await close(dialog)
	var client := Scores.new()
	app.add_child(client)
	dialog = preload("res://ui/cloud_leaderboard.gd").new()
	dialog.client = client
	dialog.version = "fixture-scores"
	dialog.vehicle = "compact"
	app.root_ui.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
	await settle()
	inspect(dialog,"high scores")
	check(dialog.rows.get_parsed_text().contains("Fixture driver") and not dialog.busy,"score content still loads through its original adapter")
	await capture("high-scores")
	await close(dialog)
	await app.cloud.show_uploads(app.root_ui)
	await settle()
	dialog = visible_dialog()
	inspect(dialog,"race uploads")
	await capture("uploads")
	await close(dialog)
	app.document = TrackDocument.create_default()
	app._export_file()
	await settle()
	dialog = visible_dialog()
	inspect(dialog,"file export")
	check(dialog is FileDialog and dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE,"file browser keeps its save-file mode")
	var selected: Dictionary = {"confirmed":false}
	dialog.file_selected.connect(func(_file: String) -> void: selected.confirmed = true)
	await capture("file-browser")
	await close(dialog)
	check(not selected.confirmed,"closing a file browser cannot emit file selection")
	var sorting: OptionButton = browser.filter_dialog.sorting
	var menu: PopupMenu = sorting.get_popup()
	check(menu.has_meta("menu_popup_style") and menu.item_count == 4,"option popup inherits the shared style without losing items")
	menu.popup(Rect2i(550,160,240,300))
	await settle()
	await capture("option-menu")
	menu.hide()
	browser.filter_dialog.open_for(browser.state,browser.filter_button)
	await settle()
	if browser.filter_dialog.motion != null and browser.filter_dialog.motion.is_running(): await browser.filter_dialog.motion.finished
	check(browser.filter_dialog.panel.has_meta("menu_popup_panel"),"filter drawer uses the shared scenic panel")
	check(browser.filter_dialog.overlay.get_global_rect().encloses(browser.filter_dialog.panel.get_global_rect()),"opened filter drawer fits the viewport")
	await capture("filter-drawer")
	browser.filter_dialog.close()
	await settle()
	browser.search_dialog.open_for(browser.state,browser.race_button)
	await settle()
	if browser.search_dialog.motion != null and browser.search_dialog.motion.is_running(): await browser.search_dialog.motion.finished
	check(browser.search_dialog.panel.has_meta("menu_popup_panel"),"search drawer uses the shared scenic panel")
	check(browser.search_dialog.overlay.get_global_rect().encloses(browser.search_dialog.panel.get_global_rect()),"opened search drawer fits the viewport")
	await capture("search-drawer")
	browser.search_dialog.close()
	await settle()
	app._show_screen("biome")
	app._select_creation_biome("pine")
	await settle()
	app._request_editor_exit()
	await settle()
	dialog = visible_dialog()
	inspect(dialog,"save/discard draft")
	field = dialog.find_child("SaveDraftName",true,false)
	check(field != null and dialog.get_ok_button().disabled,"Save remains disabled without a draft name")
	await type_text(field,"Popup fixture draft")
	check(not dialog.get_ok_button().disabled,"name editing still enables Save through the original callback")
	await capture("save-draft")
	await close(dialog)
	check(app.screen == "create","canceling the save prompt keeps the editor open")
	var object_popup: PopupPanel = app.object_browser.options
	check(object_popup.has_meta("menu_popup_style"),"contextual object popup shares compact popup styling")
	app.queue_free()
	await process_frame
	print("POPUP_STYLE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

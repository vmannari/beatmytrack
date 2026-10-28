extends AcceptDialog
## Development-only reading/copying of the exact owner-approved draft snapshot.
const DOCUMENT: String = "res://legal/terms-draft-2026-10-25-r6.txt"
const PopupChrome = preload("res://ui/popup_style.gd")
var body: RichTextLabel

func _ready() -> void:
	name = "DraftTermsDialog"
	title = "Terms of Service (draft)"
	ok_button_text = "Close"
	dialog_text = ""
	var extent: Vector2 = get_parent().get_viewport_rect().size.min(Vector2(get_parent().get_window().size))
	body = RichTextLabel.new()
	body.name = "DraftTermsText"
	body.selection_enabled = true
	body.custom_minimum_size = Vector2(minf(760, extent.x - 112), clampf(extent.y - 240, 160, 440))
	body.add_theme_font_override("normal_font", MenuStyle.BODY)
	body.add_theme_font_size_override("normal_font_size", 18)
	body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(body)
	for line: String in FileAccess.get_file_as_string(DOCUMENT).split("\n"):
		if line.begins_with("#"):
			body.push_font(MenuStyle.DISPLAY, 24)
			body.add_text(line.trim_prefix("#").trim_prefix("#").strip_edges() + "\n")
			body.pop()
		else:
			body.add_text(line.replace("**", "").replace("`", "") + "\n")
	add_button("Save a copy", false, "save")
	custom_action.connect(_custom_action)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	PopupChrome.watch(self)

func _custom_action(action: StringName) -> void:
	if action != "save": return
	var picker := FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.txt ; Text file"])
	picker.current_file = "beat-my-track-terms-draft-r6.txt"
	picker.file_selected.connect(func(path: String) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null: file.store_buffer(FileAccess.get_file_as_bytes(DOCUMENT))
		else:
			var error := AcceptDialog.new()
			error.dialog_text = "Could not save the terms. Please try again."
			add_child(error)
			error.confirmed.connect(error.queue_free)
			error.popup_centered())
	picker.visibility_changed.connect(func() -> void:
		if not picker.visible: picker.queue_free())
	add_child(picker)
	picker.popup_centered_ratio(0.8)

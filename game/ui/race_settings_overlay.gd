extends MarginContainer
## Shared settings above an explicitly paused Game; never changes scene-tree pause.
signal closed
var game: Node
var page: SettingsPage
var editor: ControlLayoutEditor
var column: VBoxContainer
var back_button: Button
var selected_section: String = "controls"
var title: Label

func _ready() -> void:
	name = "RaceSettingsOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + edge, 16)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title = MenuStyle.label("SETTINGS", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	back_button = MenuStyle.button("Back", go_back)
	back_button.name = "Back"
	back_button.icon = MenuIcon.texture("arrow")
	header.add_child(back_button)
	_mount_page()
	resized.connect(_resize)
	_resize()
	back_button.grab_focus()

func _resize() -> void:
	# The sidebar already identifies Settings when both columns fit.
	title.visible = size.x < 1132.0

func _mount_page() -> void:
	page = SettingsPage.new()
	page.records = game.preference_records if game.preference_records != null else LocalRecords.new("")
	page.race_context = true
	page.development_available = false
	page.live_ghost_settings = game.personal_ghost != null and not game.opponent_ghost
	page.allowed_sections = ["controls", "camera", "ghosts", "audio", "haptics", "graphics", "language"]
	page.section = selected_section
	page.settings_applied.connect(game.apply_saved_driving_settings)
	page.customize_requested.connect(_customize)
	column.add_child(page)

func _customize() -> void:
	selected_section = page.section
	column.hide()
	editor = ControlLayoutEditor.new()
	editor.records = page.records
	editor.closed.connect(_editor_closed)
	add_child(editor)

func _editor_closed() -> void:
	game.apply_saved_driving_settings()
	column.remove_child(page)
	page.queue_free()
	_mount_page()
	column.show()
	editor = null
	back_button.grab_focus()

func go_back() -> void:
	if is_instance_valid(editor):
		editor._close()
		return
	closed.emit()

func finish_for_resume() -> bool:
	if is_instance_valid(editor):
		if not editor._save(): return false
		game.apply_saved_driving_settings()
	return true

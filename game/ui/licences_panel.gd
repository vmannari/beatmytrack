extends VBoxContainer
## Read-only, offline notices with a fixed selector and one scrollable document.
const Notices = preload("res://legal/third_party_notices.gd")
var entries: Array[Dictionary] = []
var selector: OptionButton
var document: RichTextLabel
var selected_id: String = "engine"
var _pointer: int = -1
var _origin := Vector2.ZERO
var _initial_scroll: float = 0.0
var _dragged: bool = false

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	entries = Notices.entries(OS.get_name(), OS.is_debug_build())
	selector = OptionButton.new()
	selector.name = "LicenceSelector"
	selector.custom_minimum_size.y = 52
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.fit_to_longest_item = false
	selector.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	selector.clip_text = true
	selector.add_theme_font_size_override("font_size", 22)
	selector.item_selected.connect(_select)
	add_child(selector)
	document = RichTextLabel.new()
	document.name = "LicenceDocument"
	document.size_flags_vertical = Control.SIZE_EXPAND_FILL
	document.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	document.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	document.bbcode_enabled = false
	document.selection_enabled = true
	document.context_menu_enabled = true
	document.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	document.add_theme_font_size_override("normal_font_size", 18)
	document.add_theme_color_override("default_color", MenuStyle.TEXT)
	document.add_theme_constant_override("line_separation", 4)
	document.meta_clicked.connect(_open_link)
	add_child(document)
	_refresh_titles()
	_select(0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(selector): _refresh_titles()
	elif what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pointer = -1
		_dragged = false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not is_instance_valid(document): return
	# RichTextLabel keeps desktop text selection, while finger motion scrolls.
	if event is InputEventMouseButton and event.pressed:
		if event.device != InputEvent.DEVICE_ID_EMULATION: _dragged = false
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _pointer >= 0: return
			if not document.get_global_rect().has_point(event.position): return
			if document.get_v_scroll_bar().get_global_rect().has_point(event.position): return
			_pointer = event.index
			_origin = event.position
			_initial_scroll = document.get_v_scroll_bar().value
			_dragged = false
		elif event.index == _pointer:
			_pointer = -1
			if _dragged: get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _pointer:
		var distance: Vector2 = event.position-_origin
		if distance.length() < 12.0 and not _dragged: return
		_dragged = true
		document.get_v_scroll_bar().value = _initial_scroll-distance.y
		get_viewport().set_input_as_handled()
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION and _dragged:
		get_viewport().set_input_as_handled()

func _refresh_titles() -> void:
	var index: int = maxi(0, selector.selected)
	selector.clear()
	for entry: Dictionary in entries: selector.add_item(GameText.message(entry.title))
	selector.select(index)
	selector.tooltip_text = selector.get_item_text(index)

func _select(index: int) -> void:
	_pointer = -1
	_dragged = false
	selected_id = str(entries[index].id)
	selector.select(index)
	selector.tooltip_text = selector.get_item_text(index)
	var text: String = Notices.text_for(entries[index])
	document.clear()
	if text.is_empty():
		document.add_text(GameText.message("This notice could not be loaded."))
		return
	# Render exact plain text, adding clickable metadata only to visible web URLs.
	var pattern := RegEx.create_from_string("https?://[^\\s<>()]+")
	var offset: int = 0
	for found: RegExMatch in pattern.search_all(text):
		document.add_text(text.substr(offset,found.get_start()-offset))
		var url: String = found.get_string().trim_suffix(".")
		document.push_meta(url)
		document.push_color(MenuStyle.ACCENT)
		document.add_text(url)
		document.pop()
		document.pop()
		offset = found.get_start()+url.length()
	document.add_text(text.substr(offset))
	document.scroll_to_line(0)

func _open_link(meta: Variant) -> void:
	if _dragged: return
	var url: String = str(meta)
	if url.begins_with("https://") or url.begins_with("http://"): OS.shell_open(url)

class_name ChallengeCreate
extends VBoxContainer
## A result stays bound to its completed ticket while verification finishes.
signal race_to_set_requested(entry: Dictionary, vehicle_id: String, duration_seconds: int, attempt_limit: int)
signal confirmed
signal canceled
var adapter: ChallengesClient
var entries: Array[Dictionary] = []
var initial_version: String = ""
var initial_vehicle: String = ""
var initial_ticket: String = ""
var initial_duration: int = 604800
var initial_attempt_limit: int = 0
var attempt_limit: int = 0
var _attempt_buttons: Array[Button] = []
var _preview_art: TextureRect
var _preview_route: LapRouteView
var _preview_title: Label
var _preview_creator: Label
var _car_art: TextureRect
var _summary_car: Label
var _summary_time: Label
var _summary_tries: Label
var _summary_duration: Label
var _tries_note: Label
var result_context: Dictionary = {}
var created_callback: Callable
var mode: int = 0
var duration: int = 604800
var _track: OptionButton
var _vehicle: OptionButton
var _source: Dictionary = {}
var _notice: Label
var _race: Button
var _create_button: Button
var _retry: Button
var _time: Label
var _serial: int = 0
var _checking: bool = false
var _submitting: bool = false
var _next_check: int = 0
var _search: LineEdit
var _search_timer: Timer
var _search_serial: int = 0
var _base_entries: Array[Dictionary] = []
var _searching: bool = false
var _mode_buttons: Array[Button] = []
var _duration_buttons: Array[Button] = []
var _panel: PanelContainer
var _close_button: Button
var _source_scope: String = ""

func locked_result() -> bool: return not initial_ticket.is_empty() or not result_context.is_empty()

func _ready() -> void:
	name = "ChallengeCreate"
	theme = MenuStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	_source_scope = str(result_context.get("scope",adapter.scope()))
	duration = initial_duration
	attempt_limit = initial_attempt_limit
	_base_entries = entries.duplicate(true)
	var header := HBoxContainer.new()
	add_child(header)
	_close_button = MenuStyle.button("Back",close)
	_close_button.name = "CloseChallengeCreate"
	_close_button.custom_minimum_size = Vector2(90,52)
	header.add_child(_close_button)
	var glyph := _icon("target",32)
	glyph.modulate = MenuStyle.ACCENT
	header.add_child(glyph)
	header.add_child(MenuStyle.label("CREATE CHALLENGE",34))
	var columns := HBoxContainer.new()
	columns.name = "ChallengeCreateColumns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",18)
	add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.name = "ChallengeSettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.35
	columns.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right",10)
	scroll.add_child(gutter)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation",8)
	gutter.add_child(fields)
	var track_row := _field(fields,"TRACK","compass")
	if locked_result():
		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track_row.add_child(identity)
		identity.add_child(MenuStyle.label(str(_entry().get("name","")),24))
		identity.add_child(MenuStyle.label(str(_entry().get("creator","")),16,true))
	else:
		var choices := VBoxContainer.new()
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track_row.add_child(choices)
		_track = OptionButton.new()
		_track.name = "ChallengeTrackChoice"
		_track.custom_minimum_size.y = 52
		choices.add_child(_track)
		for index: int in range(entries.size()):
			_track.add_item(str(entries[index].name),index)
			if str(entries[index].version_id) == initial_version: _track.select(index)
		_search = LineEdit.new()
		_search.placeholder_text = "Find a track or creator"
		_search.max_length = 80
		_search.custom_minimum_size.y = 48
		_search.hide()
		choices.add_child(_search)
		var find := MenuStyle.button("",func() -> void:
			_search.visible = not _search.visible
			if _search.visible: _search.grab_focus())
		find.icon = MenuIcon.texture("search")
		find.tooltip_text = "Find a track or creator"
		find.custom_minimum_size = Vector2(52,52)
		track_row.add_child(find)
		_search_timer = Timer.new()
		_search_timer.wait_time = 0.35
		_search_timer.one_shot = true
		_search_timer.timeout.connect(_find_tracks)
		add_child(_search_timer)
		_search.text_changed.connect(func(_text: String) -> void:
			_search_serial += 1
			_serial += 1
			_searching = true
			_update()
			_search_timer.start())
		_track.item_selected.connect(func(_i: int) -> void: _check_source())
	var modes := _field(fields,"TYPE","friends")
	for index: int in range(2):
		var choice := _segment(modes,["Beat my time","Group challenge"][index],_choose_mode.bind(index))
		choice.name = ["ChallengeBeat","ChallengeGroup"][index]
		_mode_buttons.append(choice)
	var car := _field(fields,"CAR","car")
	_car_art = TextureRect.new()
	_car_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_car_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_car_art.custom_minimum_size = Vector2(96,52)
	car.add_child(_car_art)
	if locked_result():
		car.add_child(MenuStyle.label(VehicleCatalog.title(initial_vehicle),22))
	else:
		_vehicle = OptionButton.new()
		_vehicle.custom_minimum_size.y = 52
		_vehicle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		car.add_child(_vehicle)
		for title: String in VehicleCatalog.NAMES: _vehicle.add_item(title)
		_vehicle.select(VehicleCatalog.IDS.find(VehicleCatalog.valid_id(initial_vehicle)))
		_vehicle.item_selected.connect(func(_i: int) -> void: _check_source())
	var target := _field(fields,"TARGET","target")
	var time_box := VBoxContainer.new()
	time_box.add_theme_constant_override("separation",0)
	target.add_child(time_box)
	_time = MenuStyle.label("",28)
	_time.name = "ChallengeFinishedTime"
	_time.add_theme_color_override("font_color",MenuStyle.ACCENT)
	time_box.add_child(_time)
	time_box.add_child(MenuStyle.label("This finish" if locked_result() else "My best time",15,true))
	var tries := _field(fields,"TRIES","restart")
	tries.tooltip_text = "Each started race uses one try, including abandoned races. Upload retries do not use another."
	for value: int in [1,3,5,0]:
		var choice := _segment(tries,"Unlimited" if value == 0 else str(value),_choose_attempt_limit.bind(value))
		choice.name = "ChallengeTries_"+str(value)
		choice.tooltip_text = tries.tooltip_text
		_attempt_buttons.append(choice)
	_tries_note = MenuStyle.label("Each started race uses a try, including restarts and abandoned races.",15,true)
	_tries_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tries_note.hide()
	fields.add_child(_tries_note)
	var help := MenuStyle.button("",func() -> void: _tries_note.visible = not _tries_note.visible)
	help.icon = MenuIcon.texture("help")
	help.tooltip_text = "How tries are counted"
	help.custom_minimum_size = Vector2(52,52)
	tries.add_child(help)
	var durations := _field(fields,"DURATION","clock")
	for index: int in range(3):
		var seconds: int = [86400,259200,604800][index]
		var choice := _segment(durations,["24 hours","3 days","7 days"][index],_choose_duration.bind(seconds))
		choice.name = "ChallengeDuration_"+str(seconds)
		_duration_buttons.append(choice)
	_panel = PanelContainer.new()
	_panel.name = "ChallengeCreatePanel"
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_theme_stylebox_override("panel",MenuStyle.card(12))
	columns.add_child(_panel)
	var preview := VBoxContainer.new()
	preview.add_theme_constant_override("separation",8)
	_panel.add_child(preview)
	var hero := PanelContainer.new()
	hero.name = "ChallengeFinishedRace"
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.custom_minimum_size.y = 110
	hero.clip_contents = true
	hero.add_theme_stylebox_override("panel",MenuStyle.box(Color("102632"),12))
	preview.add_child(hero)
	_preview_art = TextureRect.new()
	_preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.add_child(_preview_art)
	var identity := VBoxContainer.new()
	hero.add_child(identity)
	_preview_title = MenuStyle.label("",28)
	_preview_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_preview_title.add_theme_color_override("font_shadow_color",Color.BLACK)
	_preview_title.add_theme_constant_override("shadow_offset_x",2)
	_preview_title.add_theme_constant_override("shadow_offset_y",2)
	identity.add_child(_preview_title)
	_preview_creator = MenuStyle.label("",16)
	identity.add_child(_preview_creator)
	_preview_route = LapRouteView.new()
	_preview_route.name = "ChallengeFinishedRoute"
	_preview_route.miniature = true
	_preview_route.size_flags_vertical = Control.SIZE_EXPAND_FILL
	identity.add_child(_preview_route)
	_summary_car = _summary(preview,"Car","car")
	_summary_time = _summary(preview,"Target","target")
	_summary_tries = _summary(preview,"Tries per driver","restart")
	_summary_duration = _summary(preview,"Duration","clock")
	var status := HBoxContainer.new()
	add_child(status)
	_notice = MenuStyle.label("",17,true)
	_notice.name = "ChallengeSourceStatus"
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(_notice)
	_retry = MenuStyle.button("Retry",_check_source)
	_retry.name = "RetryChallengeSource"
	_retry.custom_minimum_size.y = 52
	status.add_child(_retry)
	var actions := HBoxContainer.new()
	actions.name = "ChallengeCreateActions"
	add_child(actions)
	var cancel := MenuStyle.button("Cancel",close)
	cancel.custom_minimum_size = Vector2(140,56)
	actions.add_child(cancel)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(space)
	_race = MenuStyle.button("Race to set a time",_race_to_set,true)
	_race.name = "RaceToSetChallenge"
	_race.custom_minimum_size = Vector2(260,56)
	actions.add_child(_race)
	_create_button = MenuStyle.button("Create & share",func() -> void: confirmed.emit(),true)
	_create_button.icon = MenuIcon.texture("share")
	_create_button.add_theme_color_override("font_focus_color",MenuStyle.INK)
	_create_button.name = "ConfirmChallengeCreate"
	_create_button.custom_minimum_size = Vector2(260,56)
	actions.add_child(_create_button)
	confirmed.connect(_create)
	_check_source()

func _icon(glyph: String, extent: int = 24) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = MenuIcon.texture(glyph)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(extent,extent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _field(parent: Control, caption: String, glyph: String) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",MenuStyle.box(Color("0c1e2bee"),6))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	panel.add_child(row)
	row.add_child(_icon(glyph))
	var label := MenuStyle.label(caption,16,true)
	label.custom_minimum_size.x = 68
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation",6)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(choices)
	return choices

func _segment(parent: Control, caption: String, action: Callable) -> Button:
	var button := MenuStyle.button(caption,action)
	button.add_theme_font_size_override("font_size",20)
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button

func _summary(parent: Control, caption: String, glyph: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	parent.add_child(row)
	row.add_child(_icon(glyph,22))
	var label := MenuStyle.label(caption,16,true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := MenuStyle.label("",18)
	value.name = "ChallengeSummary_"+caption.replace(" ","")
	row.add_child(value)
	return value

func _choose_attempt_limit(value: int) -> void:
	attempt_limit = value
	_update()

func _refresh_preview() -> void:
	if _preview_art == null: return
	var entry: Dictionary = _entry()
	_preview_art.texture = TrackTile.scenery_texture(str(entry.get("theme","pine")))
	_preview_art.modulate = Color(0.72,0.78,0.82)
	_preview_title.text = str(entry.get("name","Choose a track"))
	_preview_creator.text = str(entry.get("creator",""))
	_preview_route.route.clear()
	for point: Array in entry.get("points",[]): _preview_route.route.append(Vector2(point[0],point[1]))
	_preview_route._fit()
	_car_art.texture = VehicleCatalog.artwork(_vehicle_id())
	_summary_car.text = VehicleCatalog.title(_vehicle_id())
	var total: float = float(result_context.get("total",0.0)) if locked_result() else 0.0
	if _source.get("status") == "verified": total = float(_source.get("ms",0))/1000.0
	_time.text = MenuStyle.time_text(total) if total > 0.0 else "?"
	_time.get_parent().get_child(1).text = "This finish" if locked_result() else "My best time" if mode == 0 else "Fastest time wins"
	_summary_time.text = _time.text if mode == 0 else "Fastest time wins"
	_summary_tries.text = "Unlimited" if attempt_limit == 0 else str(attempt_limit)
	_summary_duration.text = "24 hours" if duration == 86400 else "3 days" if duration == 259200 else "7 days"

func _entry() -> Dictionary:
	if locked_result():
		if result_context.get("entry") is Dictionary: return result_context.entry
		for entry: Dictionary in entries:
			if str(entry.get("version_id","")) == initial_version: return entry
		return {}
	return entries[_track.selected] if _track != null and _track.selected >= 0 and _track.selected < entries.size() else {}

func _vehicle_id() -> String:
	return initial_vehicle if locked_result() else VehicleCatalog.IDS[_vehicle.selected]

func _choose_mode(index: int) -> void:
	mode = index
	_update()

func _choose_duration(seconds: int) -> void:
	duration = seconds
	_update()

func popup_centered(_size: Vector2i = Vector2i.ZERO) -> void:
	show()
	set_process_input(true)

func get_ok_button() -> Button: return _create_button

func close() -> void:
	if _submitting: return
	_serial += 1
	_search_serial += 1
	hide()
	set_process_input(false)
	canceled.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _check_source() -> void:
	_serial += 1
	var serial: int = _serial
	_source = {}
	_checking = false
	var entry: Dictionary = _entry()
	if entry.is_empty():
		_update()
		return
	if adapter.scope() != _source_scope:
		_next_check = Time.get_ticks_msec()+3000
		_source = {"status":"unavailable","error":"Sign in again to create this challenge."}
		_update()
		return
	_checking = true
	_next_check = Time.get_ticks_msec()+3000
	_update()
	var ticket: String = initial_ticket if locked_result() else ""
	var value: Dictionary = await adapter.source(str(entry.version_id),_vehicle_id(),ticket)
	if not is_instance_valid(self) or serial != _serial: return
	_checking = false
	_source = value
	_next_check = Time.get_ticks_msec()+3000
	_update()

func _update() -> void:
	if _create_button == null: return
	var verified: bool = _source.get("status") == "verified"
	var has_entry: bool = not _entry().is_empty()
	var pending: bool = _source.get("status") in ["not_set","queued","verifying"]
	_create_button.disabled = _checking or _searching or _submitting or not has_entry or (not verified and (locked_result() or mode == 0)) or adapter.scope() != _source_scope
	_race.visible = not locked_result() and mode == 0 and has_entry and _source.get("status") == "not_set" and not _checking
	_create_button.visible = not _race.visible
	_race.disabled = _submitting or _searching
	_close_button.disabled = _submitting
	_retry.visible = _source.get("status") == "unavailable" and not _checking and not _submitting
	_notice.text = "Creating…" if _submitting else "Finding tracks…" if _searching else "Verifying result…" if locked_result() and (_checking or pending) else "Checking time…" if _checking else str(_source.get("error","")) if _source.has("error") else "This result was not verified." if locked_result() and not verified else "Choose a published track." if not has_entry else ""
	_notice.visible = not _notice.text.is_empty()
	_refresh_preview()
	if _track != null: _track.disabled = _submitting
	if _vehicle != null: _vehicle.disabled = _submitting
	if _search != null: _search.editable = not _submitting
	for index: int in range(_attempt_buttons.size()): _selection(_attempt_buttons[index],[1,3,5,0][index] == attempt_limit)
	for index: int in range(_mode_buttons.size()): _selection(_mode_buttons[index],index == mode)
	for index: int in range(_duration_buttons.size()): _selection(_duration_buttons[index],[86400,259200,604800][index] == duration)

func _selection(button: Button, chosen: bool) -> void:
	var style := MenuStyle.box(MenuStyle.ACCENT if chosen else Color("152c3b"),10)
	style.border_color = MenuStyle.ACCENT if chosen else Color("2b4657")
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal",style)
	for key: String in ["font_color","font_focus_color","font_hover_color"]: button.add_theme_color_override(key,MenuStyle.INK if chosen else MenuStyle.TEXT)
	button.disabled = _submitting

func _create() -> void:
	if _create_button.disabled: return
	_submitting = true
	_update()
	var entry: Dictionary = _entry()
	var payload: Dictionary = {"version_id":str(entry.version_id),"vehicle_id":_vehicle_id(),"mode":"group" if mode == 1 else "beat","duration_seconds":duration}
	if attempt_limit > 0: payload.attempt_limit = attempt_limit
	if locked_result():
		if initial_ticket.is_empty():
			_submitting = false
			_source = {"status":"unavailable","error":"Could not recover this result."}
			_update()
			return
		payload.source_ticket_id = initial_ticket
	elif _source.get("status") == "verified" and mode == 0: payload.source_run_id = str(_source.run_id)
	await adapter.create_challenge(payload)
	if not is_instance_valid(self): return
	_submitting = false
	if adapter.error.is_empty() and not adapter.selected.is_empty():
		hide()
		if created_callback.is_valid(): created_callback.call()
	else:
		_update()
		_notice.text = adapter.error
		_notice.show()

func _race_to_set() -> void:
	if locked_result() or _entry().is_empty(): return
	hide()
	race_to_set_requested.emit(_entry(),_vehicle_id(),duration,attempt_limit)

func _find_tracks() -> void:
	if locked_result(): return
	var serial: int = _search_serial
	var query: String = _search.text.strip_edges()
	_searching = true
	_update()
	var results: Array[Dictionary] = []
	if query.is_empty(): results = _base_entries.duplicate(true)
	else:
		var payload: Dictionary = preload("res://backend/discovery_pages.gd").payload({"search":query,"section":"all"})
		var response: Dictionary = await adapter.client.request_discovery(payload,get_instance_id())
		if not is_instance_valid(self) or serial != _search_serial or adapter.scope() != _source_scope: return
		if not response.get("ok",false) or not response.data.get("items") is Array:
			_searching = false
			_checking = false
			entries.clear()
			_track.clear()
			_source = {"status":"unavailable","error":"Could not find tracks. Try again."}
			_update()
			return
		for entry: Variant in response.data.items:
			if entry is Dictionary and adapter.cloud._valid_entry(entry): results.append(entry)
	if serial != _search_serial: return
	entries = results
	_track.clear()
	for index: int in range(entries.size()): _track.add_item(str(entries[index].name),index)
	if not entries.is_empty(): _track.select(0)
	_searching = false
	_checking = false
	_check_source()
	if entries.is_empty():
		_notice.text = "No matching tracks."
		_notice.show()

func _process(_delta: float) -> void:
	if visible and not _checking and not _submitting and (locked_result() and _source.get("status") in ["not_set","queued","verifying","unavailable"] or _source.get("status") in ["queued","verifying"]):
		if Time.get_ticks_msec() >= _next_check: _check_source()

func _exit_tree() -> void:
	if adapter != null: adapter.client.cancel_public_reads(get_instance_id())

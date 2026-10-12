class_name ChallengeCreate
extends CanvasLayer
## A result stays bound to its completed ticket while verification finishes.
signal race_to_set_requested(entry: Dictionary, vehicle_id: String, duration_seconds: int)
signal confirmed
signal canceled
var adapter: ChallengesClient
var entries: Array[Dictionary] = []
var initial_version: String = ""
var initial_vehicle: String = ""
var initial_ticket: String = ""
var initial_duration: int = 604800
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
var _overlay: Control
var _panel: PanelContainer
var _close_button: Button
var _source_scope: String = ""
var _motion: Tween

func locked_result() -> bool: return not initial_ticket.is_empty() or not result_context.is_empty()

func _ready() -> void:
	name = "ChallengeCreate"
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_source_scope = str(result_context.get("scope",adapter.scope()))
	duration = initial_duration
	_overlay = Control.new()
	_overlay.theme = MenuStyle.theme()
	MenuStyle.fill(_overlay)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.005,0.013,0.02,0.78)
	MenuStyle.fill(dim)
	_overlay.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: close())
	_panel = PanelContainer.new()
	_panel.name = "ChallengeCreatePanel"
	var style := MenuStyle.card(22)
	style.bg_color = Color("0b1823")
	style.border_color = Color("355264")
	style.shadow_size = 22
	style.shadow_color = Color(0,0,0,0.55)
	_panel.add_theme_stylebox_override("panel",style)
	_overlay.add_child(_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	_panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var glyph := TextureRect.new()
	glyph.texture = MenuIcon.texture("target")
	glyph.modulate = MenuStyle.ACCENT
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(30,30)
	header.add_child(glyph)
	var heading := MenuStyle.label("CREATE CHALLENGE",30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_close_button = MenuStyle.button("",close)
	_close_button.name = "CloseChallengeCreate"
	_close_button.icon = MenuIcon.texture("close")
	_close_button.tooltip_text = "Close"
	_close_button.custom_minimum_size = Vector2(52,52)
	_close_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,8))
	header.add_child(_close_button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right",12)
	scroll.add_child(gutter)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation",12)
	gutter.add_child(fields)
	_base_entries = entries.duplicate(true)
	if locked_result(): _result_hero(fields)
	else: _track_choices(fields)
	var modes := HBoxContainer.new()
	fields.add_child(modes)
	for index: int in range(2):
		var choice := MenuStyle.button(["Beat my time","Group challenge"][index],_choose_mode.bind(index))
		choice.name = ["ChallengeBeat","ChallengeGroup"][index]
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.custom_minimum_size.y = 52
		modes.add_child(choice)
		_mode_buttons.append(choice)
	fields.add_child(MenuStyle.label("DURATION",14,true))
	var durations := HBoxContainer.new()
	fields.add_child(durations)
	for index: int in range(3):
		var seconds: int = [86400,259200,604800][index]
		var choice := MenuStyle.button(["24 hours","3 days","7 days"][index],_choose_duration.bind(seconds))
		choice.name = "ChallengeDuration_"+str(seconds)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.custom_minimum_size.y = 52
		durations.add_child(choice)
		_duration_buttons.append(choice)
	var status := HBoxContainer.new()
	body.add_child(status)
	_notice = MenuStyle.label("",17,true)
	_notice.name = "ChallengeSourceStatus"
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(_notice)
	_retry = MenuStyle.button("Retry",_check_source)
	_retry.name = "RetryChallengeSource"
	_retry.custom_minimum_size.y = 52
	status.add_child(_retry)
	_race = MenuStyle.button("Race to set a time",_race_to_set,true)
	_race.name = "RaceToSetChallenge"
	_race.custom_minimum_size.y = 56
	body.add_child(_race)
	_create_button = MenuStyle.button("Create & share",func() -> void: confirmed.emit(),true)
	_create_button.add_theme_color_override("font_focus_color",MenuStyle.INK)
	_create_button.name = "ConfirmChallengeCreate"
	_create_button.custom_minimum_size.y = 56
	body.add_child(_create_button)
	confirmed.connect(_create)
	_overlay.resized.connect(_layout)
	_layout.call_deferred()
	_check_source()

func _result_hero(parent: Control) -> void:
	var entry: Dictionary = _entry()
	var hero := PanelContainer.new()
	hero.name = "ChallengeFinishedRace"
	hero.custom_minimum_size.y = 126
	hero.clip_contents = true
	hero.add_theme_stylebox_override("panel",MenuStyle.box(Color("102632"),0))
	parent.add_child(hero)
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(str(entry.get("theme","pine")))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(0.45,0.53,0.58)
	hero.add_child(art)
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	hero.add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation",0)
	row.add_child(identity)
	var title := MenuStyle.label(str(entry.get("name",result_context.get("title",""))),23)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(title)
	var total: float = float(result_context.get("total",0.0))
	_time = MenuStyle.label(MenuStyle.time_text(total) if total > 0.0 else "—",58)
	_time.name = "ChallengeFinishedTime"
	_time.add_theme_color_override("font_color",MenuStyle.ACCENT)
	identity.add_child(_time)
	identity.add_child(MenuStyle.label("%d laps · %s" % [int(result_context.get("laps",5)),VehicleCatalog.title(initial_vehicle)],15))
	var route := LapRouteView.new()
	route.name = "ChallengeFinishedRoute"
	route.miniature = true
	route.custom_minimum_size.x = 130
	for point: Array in entry.get("points",[]): route.route.append(Vector2(point[0],point[1]))
	row.add_child(route)

func _track_choices(parent: Control) -> void:
	_track = _choice(parent,"Track",[])
	for index: int in range(entries.size()):
		_track.add_item(str(entries[index].name),index)
		if str(entries[index].version_id) == initial_version: _track.select(index)
	_search = LineEdit.new()
	_search.placeholder_text = "Find a track or creator"
	_search.max_length = 80
	_search.custom_minimum_size.y = 48
	parent.add_child(_search)
	_search_timer = Timer.new()
	_search_timer.wait_time = 0.35
	_search_timer.one_shot = true
	_search_timer.timeout.connect(_find_tracks)
	add_child(_search_timer)
	_search.text_changed.connect(func(_text: String) -> void:
		_search_serial += 1
		_serial += 1
		_search_timer.start())
	_vehicle = _choice(parent,"Car",VehicleCatalog.NAMES)
	_vehicle.select(VehicleCatalog.IDS.find(VehicleCatalog.valid_id(initial_vehicle)))
	_track.item_selected.connect(func(_i: int) -> void: _check_source())
	_vehicle.item_selected.connect(func(_i: int) -> void: _check_source())

func _choice(parent: Control, caption: String, choices: Array) -> OptionButton:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	parent.add_child(row)
	row.add_child(MenuStyle.label(caption.to_upper(),14,true))
	var choice := OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.custom_minimum_size.y = 52
	for item: Variant in choices: choice.add_item(str(item))
	row.add_child(choice)
	return choice

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

func _layout() -> void:
	if _panel == null: return
	var viewport: Vector2 = _overlay.size
	var width: float = minf(560.0,viewport.x-40.0)
	var height: float = minf(508.0 if locked_result() else 552.0,viewport.y-40.0)
	_panel.size = Vector2(width,height)
	_panel.position = (viewport-_panel.size)*0.5

func popup_centered(_size: Vector2i = Vector2i.ZERO) -> void:
	show()
	set_process_input(true)
	if _overlay != null:
		_overlay.modulate.a = 0.0
		_motion = create_tween()
		_motion.tween_property(_overlay,"modulate:a",1.0,0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_layout.call_deferred()

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
	if _time != null and verified: _time.text = MenuStyle.time_text(float(_source.ms)/1000.0)
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
	race_to_set_requested.emit(_entry(),_vehicle_id(),duration)

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

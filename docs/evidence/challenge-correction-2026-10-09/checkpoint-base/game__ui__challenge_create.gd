class_name ChallengeCreate
extends ConfirmationDialog
signal race_to_set_requested(entry: Dictionary, vehicle_id: String, duration_seconds: int)
var adapter: ChallengesClient
var entries: Array[Dictionary] = []
var initial_version: String = ""
var initial_vehicle: String = ""
var initial_ticket: String = ""
var initial_duration: int = 604800
var created_callback: Callable
var _track: OptionButton
var _vehicle: OptionButton
var _type: OptionButton
var _duration: OptionButton
var _source: Dictionary = {}
var _notice: Label
var _race: Button
var _serial: int = 0
var _checking: bool = false
var _submitting: bool = false
var _next_check: int = 0
var _search: LineEdit
var _search_timer: Timer
var _search_serial: int = 0
var _base_entries: Array[Dictionary] = []
var _searching: bool = false

func _ready() -> void:
	name = "ChallengeCreate"
	title = "Create challenge"
	ok_button_text = "Create & share"
	dialog_hide_on_ok = false
	add_theme_stylebox_override("embedded_border",MenuStyle.box(MenuStyle.PANEL,12))
	add_theme_stylebox_override("embedded_unfocused_border",MenuStyle.box(MenuStyle.PANEL,12))
	add_theme_color_override("title_color",MenuStyle.TEXT)
	add_theme_font_override("title_font",MenuStyle.DISPLAY)
	get_ok_button().add_theme_stylebox_override("normal",MenuStyle.box(MenuStyle.ACCENT))
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		get_ok_button().add_theme_color_override(state,MenuStyle.INK)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",14)
	add_child(body)
	_type = _choice(body,"Challenge",["Beat my time","Group challenge"])
	_track = _choice(body,"Track",[])
	_base_entries = entries.duplicate(true)
	for index: int in range(entries.size()):
		_track.add_item(str(entries[index].name),index)
		if str(entries[index].version_id) == initial_version: _track.select(index)
	var search_row := HBoxContainer.new()
	body.add_child(search_row)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 100
	search_row.add_child(spacer)
	_search = LineEdit.new()
	_search.placeholder_text = "Find a track or creator"
	_search.max_length = 80
	_search.custom_minimum_size.y = 44
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_child(_search)
	_search_timer = Timer.new()
	_search_timer.wait_time = 0.35
	_search_timer.one_shot = true
	_search_timer.timeout.connect(_find_tracks)
	add_child(_search_timer)
	_search.text_changed.connect(func(_text: String) -> void:
		_search_serial += 1
		_serial += 1
		_search_timer.start())
	_vehicle = _choice(body,"Car",VehicleCatalog.NAMES)
	_vehicle.select(VehicleCatalog.IDS.find(VehicleCatalog.valid_id(initial_vehicle)))
	_duration = _choice(body,"Duration",["24 hours","3 days","7 days"])
	_duration.select(maxi(0,[86400,259200,604800].find(initial_duration)))
	_notice = MenuStyle.label("",19,true)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size.x = 460
	body.add_child(_notice)
	_race = MenuStyle.button("Race to set a time",_race_to_set,true)
	body.add_child(_race)
	_track.item_selected.connect(func(_i: int) -> void: _check_source())
	_vehicle.item_selected.connect(func(_i: int) -> void: _check_source())
	_type.item_selected.connect(func(_i: int) -> void: _update())
	confirmed.connect(_create)
	_check_source()

func _find_tracks() -> void:
	var serial: int = _search_serial
	var query: String = _search.text.strip_edges()
	_searching = true
	_update()
	var results: Array[Dictionary] = []
	if query.is_empty(): results = _base_entries.duplicate(true)
	else:
		var original: String = adapter.scope()
		var payload: Dictionary = preload("res://backend/discovery_pages.gd").payload({"search":query,"section":"all"})
		var response: Dictionary = await adapter.client.request_discovery(payload,get_instance_id())
		if not is_instance_valid(self) or serial != _search_serial or original != adapter.scope(): return
		if not response.get("ok",false) or not response.data.get("items") is Array:
			_searching = false
			_checking = false
			_source = {}
			entries.clear()
			_track.clear()
			_update()
			_notice.text = "Could not find tracks. Try again."
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
	if entries.is_empty(): _notice.text = "No matching tracks."

func _exit_tree() -> void:
	if adapter != null: adapter.client.cancel_public_reads(get_instance_id())

func _choice(parent: Control, caption: String, choices: Array) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := MenuStyle.label(caption,20)
	label.custom_minimum_size.x = 100
	row.add_child(label)
	var choice := OptionButton.new()
	choice.custom_minimum_size = Vector2(360,52)
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: Variant in choices: choice.add_item(str(item))
	row.add_child(choice)
	return choice

func _check_source() -> void:
	_serial += 1
	var serial: int = _serial
	_source = {}
	if entries.is_empty():
		_update()
		return
	_checking = true
	_next_check = Time.get_ticks_msec()+3000
	_update()
	var entry: Dictionary = entries[_track.selected]
	var vehicle: String = VehicleCatalog.IDS[_vehicle.selected]
	var ticket_id: String = initial_ticket if str(entry.version_id) == initial_version and vehicle == initial_vehicle else ""
	var value: Dictionary = await adapter.source(str(entry.version_id),vehicle,ticket_id)
	if not is_instance_valid(self) or serial != _serial: return
	_checking = false
	_source = value
	_next_check = Time.get_ticks_msec()+3000
	_update()

func _update() -> void:
	var verified: bool = _source.get("status") == "verified"
	var group: bool = _type.selected == 1
	var pending: bool = _source.get("status") in ["queued","verifying"] or (not initial_ticket.is_empty() and _source.get("status") == "not_set")
	get_ok_button().disabled = _checking or _searching or _submitting or entries.is_empty() or (not group and not verified)
	_race.visible = not group and not verified and not pending and not _checking and not entries.is_empty()
	_race.disabled = _submitting or _searching or _source.get("status") in ["queued","verifying"]
	_notice.text = "Creating…" if _submitting else "Finding tracks…" if _searching else "Checking your time…" if _checking else "Choose a published track from Race first." if entries.is_empty() else "Verifying your race…" if pending and not group else str(_source.get("error","")) if _source.has("error") else "%.3f s · 5 laps" % (float(_source.get("ms",0))/1000.0) if verified and not group else "" if group else "Set a verified five-lap time to challenge someone."

func _create() -> void:
	if get_ok_button().disabled: return
	_submitting = true
	_update()
	var entry: Dictionary = entries[_track.selected]
	var payload: Dictionary = {"version_id":str(entry.version_id),"vehicle_id":VehicleCatalog.IDS[_vehicle.selected],"mode":"group" if _type.selected == 1 else "beat","duration_seconds":[86400,259200,604800][_duration.selected]}
	if _source.get("status") == "verified" and (_type.selected == 0 or not initial_ticket.is_empty()): payload.source_run_id = str(_source.run_id)
	await adapter.create_challenge(payload)
	if not is_instance_valid(self): return
	_submitting = false
	if adapter.error.is_empty() and not adapter.selected.is_empty():
		hide()
		if created_callback.is_valid(): created_callback.call()
	else:
		_update()
		_notice.text = adapter.error

func _race_to_set() -> void:
	if entries.is_empty(): return
	hide()
	race_to_set_requested.emit(entries[_track.selected],VehicleCatalog.IDS[_vehicle.selected],[86400,259200,604800][_duration.selected])

func _process(_delta: float) -> void:
	if visible and not _checking and not _submitting and (_source.get("status") in ["queued","verifying"] or (not initial_ticket.is_empty() and _source.get("status") == "not_set")):
		if Time.get_ticks_msec() >= _next_check: _check_source()

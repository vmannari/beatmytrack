extends AcceptDialog
## Verified daily board. Every reply is fenced by day, revision, car and account.
signal vehicle_selected(index: int)
signal day_changed
var client: Node
var cloud: Node
var version: String
var vehicle: String
var track_name: String
var day: int
var ends_at: int
var server_now: int
var flying_laps: bool = false
var records: LocalRecords
var local_best_seconds: float = 0.0
var local_vehicle: String = ""
var _local_owner: String = ""
var busy: bool = false
var _sample_msec: int
var _serial: int = 0
var _expired: bool = false
var _dirty: bool = false
var _page: int = 0
var _cursors: Array[String] = [""]
var _next_cursor: String = ""
var _rows: VBoxContainer
var _own: VBoxContainer
var _status: Label
var _previous: Button
var _next: Button
var _refresh: Button
var _cars: OptionButton
var _tick_rate: int = 120
var _population: int = -1
var _shade: CanvasLayer
var _body: VBoxContainer

func _init() -> void:
	# App observes node-added before _ready, so opt out before it can attach shared chrome.
	set_meta("menu_popup_custom",true)

func _ready() -> void:
	name = "DailyStandings"
	title = "Today's standings"
	size = Vector2i(900,680)
	wrap_controls = false
	borderless = true
	transparent_bg = true
	transparent = true
	unresizable = true
	set_meta("menu_popup_custom",true)
	theme = MenuStyle.theme()
	add_theme_stylebox_override("panel",MenuStyle.popup_panel(20))
	_sample_msec = Time.get_ticks_msec()
	_local_owner = _account_scope()
	get_ok_button().get_parent().hide()
	get_label().hide()
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var body := VBoxContainer.new()
	_body = body
	# Wrap text at its actual width before the native dialog measures its contents.
	body.custom_minimum_size.x = 800
	body.size = Vector2(844,480)
	body.add_theme_constant_override("separation",8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var title_row := HBoxContainer.new()
	body.add_child(title_row)
	var symbol := TextureRect.new()
	symbol.texture = preload("res://ui/race_mode_icons.gd").texture("trophy")
	symbol.modulate = MenuStyle.ACCENT
	symbol.custom_minimum_size = Vector2(32,32)
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(symbol)
	var title_label: Label = MenuStyle.label("Today's standings",32)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	var close := MenuStyle.button("",queue_free)
	close.icon = MenuIcon.texture("close",true)
	close.expand_icon = true
	close.add_theme_constant_override("icon_max_width",24)
	close.custom_minimum_size = Vector2(48,48)
	close.tooltip_text = "Close"
	close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(close)
	var identity := HBoxContainer.new()
	body.add_child(identity)
	var heading: Label = MenuStyle.user_label(track_name,26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.tooltip_text = track_name
	identity.add_child(heading)
	_cars = OptionButton.new()
	_cars.name = "DailyStandingsCar"
	_cars.custom_minimum_size = Vector2(220,48)
	_cars.clip_text = true
	for car_name: String in VehicleCatalog.NAMES: _cars.add_item(car_name)
	_cars.select(VehicleCatalog.IDS.find(vehicle))
	_cars.item_selected.connect(_select_vehicle)
	identity.add_child(_cars)
	var context := HBoxContainer.new()
	body.add_child(context)
	var caption: Label = MenuStyle.label("Verified best flying laps" if flying_laps else "Today's verified races (UTC)",16,true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context.add_child(caption)
	context.add_child(MenuStyle.label(Time.get_date_string_from_unix_time(day*86400),16,true))
	_status = MenuStyle.label("Loading verified scores…",18,true)
	_status.name = "DailyStandingsStatus"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context.add_child(_status)
	var headings := MarginContainer.new()
	headings.add_theme_constant_override("margin_left",10)
	headings.add_theme_constant_override("margin_right",10+MenuStyle.SCROLLBAR_LANE)
	headings.add_child(_columns(["Rank","Driver","Time","Gap"],true))
	body.add_child(headings)
	var scroll := ScrollContainer.new()
	scroll.name = "DailyStandingsScroll"
	scroll.custom_minimum_size = Vector2(580,80)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	body.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation",5)
	scroll.add_child(_rows)
	_own = VBoxContainer.new()
	_own.name = "DailyOwnResult"
	_own.add_theme_constant_override("separation",6)
	body.add_child(_own)
	var footer: Label = MenuStyle.label("Verified track bests · one per driver and car." if flying_laps else "One best time per driver and car.",15,true)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(footer)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	_previous = MenuStyle.button("Previous",func() -> void:
		if busy or _page == 0: return
		_page -= 1
		load_page())
	_next = MenuStyle.button("Next",func() -> void:
		if busy or _next_cursor.is_empty(): return
		_cursors.resize(_page+1)
		_cursors.append(_next_cursor)
		_page += 1
		load_page())
	_refresh = MenuStyle.button("Refresh",_restart)
	for button: Button in [_previous,_next,_refresh]: actions.add_child(button)
	if client.has_signal("identity_changed"): client.identity_changed.connect(_restart)
	if is_instance_valid(cloud) and cloud.has_signal("race_verified"): cloud.race_verified.connect(_verified)
	about_to_popup.connect(_opening)
	get_parent().get_viewport().size_changed.connect(_fit.call_deferred)
	load_page()

func _fit() -> void:
	# Native wrapping can retain its first zero-width measurement until layout settles.
	for _frame: int in range(2): await get_tree().process_frame
	if not is_inside_tree() or not visible: return
	var extent: Vector2i = Vector2i(get_parent().get_viewport().get_visible_rect().size)
	min_size = Vector2i.ZERO
	size = Vector2i(900,680).min(extent-Vector2i(32,32))
	position = (extent-size)/2
	_body.position = Vector2(20,20)
	_body.size = Vector2(size)-Vector2(40,40)

func _opening() -> void:
	if not is_instance_valid(_shade):
		_shade = CanvasLayer.new()
		_shade.layer = 90
		get_parent().add_child(_shade)
		var fill := ColorRect.new()
		fill.color = MenuStyle.POPUP_DIM
		_shade.add_child(fill)
		MenuStyle.fill(fill)
	_shade.show()
	_fit.call_deferred()

func _scope() -> String:
	return str([client.base_url() if client.has_method("base_url") else "",client.player.get("id","") if client.signed_in() else "",vehicle,version,day])

func _account_scope() -> String:
	return str([client.base_url() if client.has_method("base_url") else "",client.player.get("id","") if client.signed_in() else "guest"])

func _local_best() -> float:
	# Never carry an account's local result into a different account's view.
	if not flying_laps or _account_scope() != _local_owner: return 0.0
	var progress := preload("res://persistence/daily_progress.gd")
	var saved: Dictionary = progress.best(progress.load_entries(records),day,version,vehicle)
	var seconds: float = float(saved.get("best_ms",0))/1000.0
	if vehicle == local_vehicle and local_best_seconds > 0.0:
		seconds = minf(seconds,local_best_seconds) if seconds > 0.0 else local_best_seconds
	return seconds

func _select_vehicle(index: int) -> void:
	vehicle = VehicleCatalog.IDS[index]
	vehicle_selected.emit(index)
	_restart()

func _restart() -> void:
	_serial += 1
	busy = false
	_page = 0
	_cursors = [""]
	client.cancel_public_reads(get_instance_id())
	load_page()

func _verified() -> void:
	if not visible: return
	if busy: _dirty = true
	else: _restart()

func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func load_page() -> void:
	if busy or _expired or not is_inside_tree(): return
	busy = true
	_serial += 1
	var serial: int = _serial
	var scope: String = _scope()
	_clear(_rows)
	_clear(_own)
	(_rows.get_parent() as ScrollContainer).scroll_vertical = 0
	_next_cursor = ""
	_population = -1
	_status.text = "Loading verified scores…"
	for button: Button in [_previous,_next,_refresh]: button.disabled = true
	var path: String = "/track-of-the-day/standings?day=%d&version_id=%s&vehicle_id=%s&limit=10" % [day,version.uri_encode(),vehicle.uri_encode()]
	if flying_laps: path = path.replace("/standings?","/lap-standings?")
	if not _cursors[_page].is_empty(): path += "&cursor="+_cursors[_page].uri_encode()
	var response: Dictionary = await client.request_api(path,HTTPClient.METHOD_GET,{},"",true) if client.signed_in() else await client.request_public(path,get_instance_id())
	if not is_inside_tree() or serial != _serial or scope != _scope() or _expired: return
	busy = false
	if int(response.get("status",0)) == 409:
		_expire()
		return
	var data: Dictionary = response.get("data",{}) if response.get("data") is Dictionary else {}
	if not response.get("ok",false) or not _valid(data):
		_status.text = "Could not load today's standings. Try again."
	else:
		_tick_rate = int(data.tick_rate)
		_population = int(data.population)
		server_now = int(data.server_now)
		_sample_msec = Time.get_ticks_msec()
		_status.text = GameText.message("%d verified racers\n\n").strip_edges() % int(data.population)
		for item: Dictionary in data.items:
			_rows.add_child(_row(item,str(item.player_id) == str(client.player.get("id","")) and client.signed_in()))
		if data.items.is_empty(): _status.text = "No flying laps yet." if flying_laps else "No verified times today."
		if client.signed_in():
			_own.add_child(MenuStyle.label("Your best lap" if flying_laps else "Your best today",16,true))
			if data.get("player") is Dictionary: _own.add_child(_row(data.player,true,true))
			else: _own.add_child(MenuStyle.label("No verified lap yet." if flying_laps else "Complete a verified race to appear here.",16,true))
		else: _own.add_child(MenuStyle.label("Sign in to record a verified time.",16,true))
		var local_seconds: float = _local_best()
		if local_seconds > 0.0:
			var local := HBoxContainer.new()
			local.name = "DailyLocalResult"
			local.add_theme_constant_override("separation",12)
			var description: Label = MenuStyle.label("Your daily lap · saved locally",16,true)
			description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			local.add_child(description)
			var local_time: Label = MenuStyle.user_label(MenuStyle.time_text(local_seconds),20)
			local_time.add_theme_color_override("font_color",MenuStyle.ACCENT)
			local.add_child(local_time)
			_own.add_child(local)
			var note: Label = MenuStyle.label("Daily challenge laps are not submitted to verified standings.",14,true)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_own.add_child(note)
		_next_cursor = str(data.next_cursor) if data.get("next_cursor") is String else ""
	_previous.disabled = _page == 0
	_next.disabled = _next_cursor.is_empty()
	_refresh.disabled = false
	if _dirty:
		_dirty = false
		_restart.call_deferred()

func _valid(data: Dictionary) -> bool:
	if (data.get("day") != day or data.get("version_id") != version or data.get("vehicle_id") != vehicle
		or data.get("ends_at") != ends_at or data.get("tick_rate") != 120
		or not _whole(data.get("population")) or int(data.population) < 0 or not data.get("items") is Array
		or data.items.size() > 10 or not _whole(data.get("server_now"))
		or int(data.server_now) < day*86400 or int(data.server_now) >= ends_at): return false
	for item: Variant in data.items:
		if not _valid_row(item,int(data.population)): return false
	return data.get("player") == null or (client.signed_in()
		and _valid_row(data.player,int(data.population))
		and str(data.player.player_id) == str(client.player.get("id","")))

func _valid_row(item: Variant, population: int) -> bool:
	return (item is Dictionary and item.get("player_id") is String and item.get("display_name") is String
		and _whole(item.get("rank")) and int(item.rank) > 0 and int(item.rank) <= population
		and _whole(item.get("time_ticks")) and int(item.time_ticks) > 0 and int(item.time_ticks) <= 216000
		and _whole(item.get("gap_ticks")) and int(item.gap_ticks) >= 0)

func _whole(value: Variant) -> bool:
	# Godot's JSON decoder represents wire integers as floats. Fractions, booleans,
	# infinities and NaNs still cannot become verified ranks or timing ticks.
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func _columns(values: Array, headers: bool = false, country: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	for index: int in range(4):
		var label: Label = MenuStyle.label(str(values[index]),16 if headers else 19,headers)
		if not headers: GameText.user_text(label)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if index == 1 else Control.SIZE_FILL
		label.custom_minimum_size.x = [50,0,118,96][index]
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if index >= 2: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if index == 1:
			var identity := HBoxContainer.new()
			identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			identity.add_theme_constant_override("separation",8)
			if headers:
				var space := Control.new()
				space.custom_minimum_size.x = 24
				identity.add_child(space)
			else: identity.add_child(PlayerCountry.flag(country,24))
			label.tooltip_text = str(values[index])
			identity.add_child(label)
			row.add_child(identity)
		else: row.add_child(label)
	return row

func _row(item: Dictionary, own: bool, sticky: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "DailySelfRow" if own else "DailyStanding"
	var style: StyleBoxFlat = MenuStyle.box(Color("ffd34820") if own else Color("0b1c2799"),10)
	if own:
		style.set_border_width_all(1)
		style.border_color = MenuStyle.ACCENT
	style.set_corner_radius_all(5)
	if sticky: style.content_margin_right = 10+MenuStyle.SCROLLBAR_LANE
	panel.add_theme_stylebox_override("panel",style)
	var gap: String = "+%.3f" % (float(item.gap_ticks)/_tick_rate) if int(item.gap_ticks) > 0 else "—"
	var columns: HBoxContainer = _columns([str(int(item.rank)),str(item.display_name),MenuStyle.time_text(float(item.time_ticks)/_tick_rate),gap],false,str(item.get("country_code","")))
	panel.add_child(columns)
	for label: Label in columns.find_children("*","Label",true,false):
		if own: label.add_theme_color_override("font_color",MenuStyle.ACCENT)
	columns.get_child(1).tooltip_text = str(item.display_name)
	return panel

func _process(_delta: float) -> void:
	if not _expired and ends_at > 0 and server_now+int((Time.get_ticks_msec()-_sample_msec)/1000) >= ends_at: _expire()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(_status) and _population > 0 and not _expired:
		_status.text = GameText.message("%d verified racers\n\n").strip_edges() % _population

func _expire() -> void:
	_expired = true
	_serial += 1
	busy = false
	_clear(_rows)
	_clear(_own)
	_status.text = "Today's track has changed. Reopen Track of the Day."
	for button: Button in [_previous,_next,_refresh]: button.disabled = true
	day_changed.emit()

func _exit_tree() -> void:
	if is_instance_valid(_shade): _shade.queue_free()
	if is_instance_valid(client): client.cancel_public_reads(get_instance_id())

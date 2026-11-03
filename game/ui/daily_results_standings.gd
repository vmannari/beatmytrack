extends PanelContainer
## Read-only comparison for this attempt. Never substitutes race totals or a PB.
signal standings_requested
const Rules = preload("res://race/daily_elimination.gd")
var client: Node
var cloud: Node
var day: int = -1
var version: String = ""
var vehicle: String = ""
var best_seconds: float = 0.0
var summary: Dictionary = {}
var _serial: int = 0
var _sample_msec: int = 0
var _server_now: int = 0
var _expired: bool = false
var _busy: bool = false
var _dirty: bool = false
var _rows: VBoxContainer
var _status: Label
var _position: Label
var _refresh: Button
var _view: Button

func _ready() -> void:
	var style: StyleBoxFlat = MenuStyle.box(Color("0b1c29f5"),20)
	style.border_color = MenuStyle.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	add_child(column)
	var heading: Label = MenuStyle.label("Standings",32)
	heading.uppercase = true
	column.add_child(heading)
	var index: int = VehicleCatalog.IDS.find(vehicle)
	column.add_child(MenuStyle.label(VehicleCatalog.NAMES[index] if index >= 0 else "",16,true))
	column.add_child(HSeparator.new())
	column.add_child(_columns("#",tr("Driver"),tr("Best lap"),true))
	_rows = VBoxContainer.new()
	_rows.name = "DailyResultStandingRows"
	_rows.add_theme_constant_override("separation",4)
	column.add_child(_rows)
	_status = MenuStyle.label("",16,true)
	_status.name = "DailyResultStandingsStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_refresh = MenuStyle.button("Try again",refresh)
	_refresh.name = "DailyResultStandingsRetry"
	column.add_child(_refresh)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	column.add_child(HSeparator.new())
	column.add_child(MenuStyle.label("Your position",16,true))
	_position = MenuStyle.user_label("—",38)
	_position.name = "DailyResultPosition"
	_position.add_theme_color_override("font_color",MenuStyle.ACCENT)
	column.add_child(_position)
	_view = MenuStyle.button("View full standings",func() -> void: standings_requested.emit())
	_view.name = "DailyResultsStandingsButton"
	_view.icon = MenuIcon.texture("arrow")
	_view.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_view.add_theme_color_override("font_color",MenuStyle.ACCENT)
	_view.add_theme_color_override("icon_normal_color",MenuStyle.ACCENT)
	_view.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	column.add_child(_view)
	var caption: Label = MenuStyle.label("One best flying lap per driver and car.",14,true)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)
	if is_instance_valid(client) and client.has_signal("identity_changed"): client.identity_changed.connect(_identity_changed)
	if is_instance_valid(cloud) and cloud.has_signal("race_verified"): cloud.race_verified.connect(_verified)
	refresh()

func _scope() -> String:
	return str([client.base_url() if client.has_method("base_url") else "",client.player.get("id","") if client.signed_in() else "guest",day,version,vehicle])

func _identity_changed() -> void:
	_serial += 1
	_busy = false
	if is_instance_valid(client): client.cancel_public_reads(get_instance_id())
	refresh()

func _verified() -> void:
	if _busy: _dirty = true
	else: refresh()

func _clear() -> void:
	summary = {}
	_position.text = "—"
	_status.show()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

func refresh() -> void:
	if _busy or _expired: return
	_serial += 1
	_clear()
	_refresh.hide()
	_view.disabled = client == null or day < 0 or version.is_empty() or vehicle.is_empty()
	if _view.disabled:
		_status.text = tr("Standings unavailable")
		return
	_status.text = tr("Loading standings…")
	_busy = true
	var serial: int = _serial
	var scope: String = _scope()
	var ticks: int = clampi(roundi(best_seconds*120.0),1,216000)
	var path: String = "/track-of-the-day/lap-standings?day=%d&version_id=%s&vehicle_id=%s&limit=3&around=true" % [day,version.uri_encode(),vehicle.uri_encode()]
	if best_seconds > 0: path += "&lap_ticks=%d" % ticks
	var response: Dictionary = await client.request_api(path,HTTPClient.METHOD_GET,{},"",true) if client.signed_in() else await client.request_public(path,get_instance_id())
	if not is_inside_tree() or serial != _serial or scope != _scope() or _expired: return
	_busy = false
	var data: Dictionary = response.get("data",{}) if response.get("data") is Dictionary else {}
	if int(response.get("status",0)) == 409:
		_expire()
	elif response.get("ok",false) and _valid(data,ticks):
		summary = data.duplicate(true)
		_server_now = int(data.server_now)
		_sample_msec = Time.get_ticks_msec()
		_render()
	else:
		_status.text = tr("Could not load today's standings. Try again.")
		_refresh.show()
	if _dirty:
		_dirty = false
		refresh.call_deferred()

func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func _valid(data: Dictionary, ticks: int) -> bool:
	if data.get("day") != day or data.get("version_id") != version or data.get("vehicle_id") != vehicle or data.get("ends_at") != (day+1)*86400 or data.get("tick_rate") != 120: return false
	if not _whole(data.get("server_now")) or int(data.server_now) < day*86400 or int(data.server_now) >= (day+1)*86400: return false
	if not _whole(data.get("population")) or int(data.population) < 0 or not data.get("items") is Array or data.items.size() > 3: return false
	for row: Variant in data.items:
		if not row is Dictionary or not row.get("player_id") is String or not row.get("display_name") is String: return false
		if not _whole(row.get("rank")) or int(row.rank) < 1 or int(row.rank) > int(data.population) or not _whole(row.get("time_ticks")) or int(row.time_ticks) < 1 or int(row.time_ticks) > 216000: return false
	var own: Variant = data.get("comparison")
	if best_seconds > 0:
		if not own is Dictionary: return false
		for key: String in ["position","population","candidate_ticks"]:
			if not _whole(own.get(key)) or int(own[key]) < 1: return false
		if int(own.position) > int(own.population) or int(own.population) != int(data.population) or int(own.candidate_ticks) != ticks: return false
	return true

func _render() -> void:
	var rows: Array = summary.items.duplicate(true)
	var own: Dictionary = summary.get("comparison",{}) if summary.get("comparison") is Dictionary else {}
	if best_seconds > 0 and not own.is_empty():
		# Keep this attempt even if a service also returns an older PB.
		if client.signed_in(): rows = rows.filter(func(row: Dictionary) -> bool: return str(row.player_id) != str(client.player.get("id","")))
		var country: String = str(client.player.get("country_code","")) if client.signed_in() else ""
		rows.append({"rank":int(own.position),"time_ticks":int(own.candidate_ticks),"display_name":tr("You"),"country_code":country,"self":true})
		_position.text = "#%d / %d" % [int(own.position),int(own.population)]
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.time_ticks) < int(b.time_ticks))
	for item: Dictionary in rows:
		var panel := PanelContainer.new()
		var is_self: bool = item.get("self",false) or (client.signed_in() and str(item.get("player_id","")) == str(client.player.get("id","")))
		panel.name = "DailyResultStandingSelf" if is_self else "DailyResultStanding"
		var style: StyleBoxFlat = MenuStyle.box(Color("ffd34820") if is_self else Color("0b1c2799"),8)
		style.set_border_width_all(1 if is_self else 0)
		style.border_color = MenuStyle.ACCENT
		panel.add_theme_stylebox_override("panel",style)
		_rows.add_child(panel)
		var seconds: float = best_seconds if is_self else float(item.time_ticks)/120.0
		var columns: HBoxContainer = _columns(str(int(item.rank)),str(item.display_name),Rules.time_text(seconds),false,str(item.get("country_code","")))
		panel.add_child(columns)
		if is_self:
			for label: Label in columns.find_children("*","Label",true,false): label.add_theme_color_override("font_color",MenuStyle.ACCENT)
	_status.text = tr("No flying laps yet.") if rows.is_empty() else ""
	_status.visible = rows.is_empty()

func _columns(rank: String, driver: String, time: String, headers: bool = false, country: String = "") -> HBoxContainer:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",8)
	for index: int in range(3):
		var label: Label = MenuStyle.user_label([rank,driver,time][index],14 if headers else 18,headers)
		label.custom_minimum_size.x = [24,0,78][index]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if index == 1 else Control.SIZE_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if index == 2: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if index == 1:
			var identity := HBoxContainer.new()
			identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			identity.add_theme_constant_override("separation",8)
			if headers:
				var space := Control.new()
				space.custom_minimum_size.x = 22
				identity.add_child(space)
			else: identity.add_child(PlayerCountry.flag(country,22))
			label.tooltip_text = driver
			identity.add_child(label)
			columns.add_child(identity)
		else: columns.add_child(label)
	return columns

func _process(_delta: float) -> void:
	if not _expired and _server_now > 0 and _server_now+int((Time.get_ticks_msec()-_sample_msec)/1000) >= (day+1)*86400: _expire()

func _expire() -> void:
	_expired = true
	_serial += 1
	_busy = false
	_clear()
	_status.text = tr("Today's track has changed. Reopen Track of the Day.")
	_refresh.hide()
	_view.disabled = true

func _exit_tree() -> void:
	_serial += 1
	if is_instance_valid(client): client.cancel_public_reads(get_instance_id())

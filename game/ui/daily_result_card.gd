extends PanelContainer
signal race_requested
signal standings_requested
const Progress = preload("res://persistence/daily_progress.gd")
const Medal = preload("res://ui/daily_medal.gd")
const Rules = preload("res://race/daily_elimination.gd")
const MenuCache = preload("res://persistence/daily_menu_cache.gd")
const NEARBY_LIMIT: int = 6
const FRESH_MSEC: int = 30000
var client: Node
var cloud: Node
var records: LocalRecords
var vehicle: String = "compact"
var version: String = ""
var day: int = 0
var ends_at: int = 0
var summary: Dictionary = {}
var result: Dictionary = {}
var preview: bool = false
var race_button: Button
var standings_button: Button
var _serial: int = 0
var _heading: Label
var _time: Label
var _position: Label
var _medals: HBoxContainer
var _target: Label
var _target_row: HBoxContainer
var _target_caption: Label
var _standings_header: HBoxContainer
var _rows_scroll: ScrollContainer
var _rows: VBoxContainer
var _loading: bool = false
var _failed: bool = false
var _retry: Button
var _request_key: String = ""

func _ready() -> void:
	name = "DailyRacePanel"
	var style: StyleBoxFlat = MenuStyle.box(Color("0b1a26f5"),16)
	style.border_color = Color("3b5362")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",0)
	add_child(column)
	_heading = MenuStyle.label("Chase the podium",24)
	_heading.name = "DailyChallengeTitle"
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameText.bind(_heading,"Chase the podium")
	column.add_child(_heading)
	_gap(column,4)
	# Offline results still expose the best lap; normally it belongs in the self row.
	_time = MenuStyle.label("—",20)
	_time.name = "DailyResultTime"
	GameText.user_text(_time)
	column.add_child(_time)
	_position = MenuStyle.label("",16,true)
	_position.name = "DailyResultPosition"
	GameText.user_text(_position)
	_position.hide()
	column.add_child(_position)
	_medals = HBoxContainer.new()
	_medals.add_theme_constant_override("separation",4)
	column.add_child(_medals)
	_target_row = HBoxContainer.new()
	_target_row.name = "DailyTarget"
	_target_row.custom_minimum_size.y = 36
	_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_target_row)
	_target_caption = MenuStyle.label("Target",18,true)
	_target_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameText.bind(_target_caption,"Target")
	_target_row.add_child(_target_caption)
	_target = MenuStyle.label("",26)
	GameText.user_text(_target)
	_target.mouse_filter = Control.MOUSE_FILTER_PASS
	_target_row.add_child(_target)
	var divider := HSeparator.new()
	divider.modulate.a = 0.6
	column.add_child(divider)
	_gap(column,16)
	var standings := HBoxContainer.new()
	_standings_header = standings
	standings.name = "DailyStandingsHeader"
	column.add_child(standings)
	var heading: Label = MenuStyle.label("Standings",20)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	standings.add_child(heading)
	standings_button = MenuStyle.button("View all",func() -> void: standings_requested.emit())
	standings_button.name = "DailyStandingsButton"
	standings_button.custom_minimum_size.y = 32
	standings_button.add_theme_font_size_override("font_size",18)
	for state: String in ["normal","hover","pressed"]: standings_button.add_theme_stylebox_override(state,MenuStyle.box(Color.TRANSPARENT,2))
	standings_button.add_theme_color_override("font_color",MenuStyle.ACCENT)
	standings.add_child(standings_button)
	_gap(column,8)
	_rows_scroll = ScrollContainer.new()
	_rows_scroll.name = "DailyNearbyScroll"
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_scroll.custom_minimum_size.y = 100
	_rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_rows_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "DailyNearbyStandings"
	_rows.add_theme_constant_override("separation",1)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_scroll.add_child(_rows)
	_retry = MenuStyle.button("Try again",refresh)
	_retry.hide()
	column.add_child(_retry)
	_gap(column,8)
	race_button = MenuStyle.button("Race",func() -> void: race_requested.emit(),true)
	race_button.name = "DailyRace"
	race_button.custom_minimum_size.y = 48
	for state: String in ["normal","hover","pressed"]: race_button.get_theme_stylebox(state).set_content_margin_all(6)
	race_button.icon = MenuIcon.texture("arrow")
	race_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	race_button.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	column.add_child(race_button)
	race_button.disabled = true
	standings_button.disabled = true
	if is_instance_valid(client) and client.has_signal("identity_changed"): client.identity_changed.connect(refresh)
	if is_instance_valid(cloud) and cloud.has_signal("race_verified"): cloud.race_verified.connect(refresh)
	_render()

func _gap(parent: Control, height: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)

func _scope() -> String:
	return str([client.base_url() if client != null and client.has_method("base_url") else "",_player().get("id","guest"),day,version,vehicle])

func _player() -> Dictionary:
	var value: Variant = client.get("player") if client != null and client.signed_in() else null
	return value if value is Dictionary else {}

func configure(next_day: int, next_version: String, end: int) -> void:
	day = next_day
	version = next_version
	ends_at = end
	ensure_fresh()

func refresh() -> void:
	_refresh(true)

func ensure_fresh() -> void:
	_refresh(false)

func _refresh(force: bool) -> void:
	result = Progress.best(Progress.load_entries(records),day,version,vehicle)
	# The service client outlives menu pages. Reuse only this exact account,
	# event, car and local comparison; elapsed time fences the UTC boundary.
	var cache_key: String = _scope()+str([records.path if records != null else "",result.get("best_ms",0),NEARBY_LIMIT])
	# Activation/configuration can arrive several times during one page slide.
	# Keep the original request and its retry clock for this exact comparison.
	if not force and _loading and _request_key == cache_key: return
	var had_failure: bool = _failed
	_serial += 1
	_request_key = cache_key
	summary = {}
	_loading = not preview and not version.is_empty() and client != null
	_failed = false
	var cache: Dictionary = client.get_meta("daily_card_standings",{}) if is_instance_valid(client) else {}
	var cached: Dictionary = cache.get(cache_key,{})
	var restored_from_disk: bool = false
	if cached.is_empty():
		var restored: Dictionary = MenuCache.read(records,cache_key,"standings")
		if not restored.is_empty() and _valid(restored):
			cached = {"data":restored,"sample_msec":Time.get_ticks_msec()}
			restored_from_disk = true
	if not cached.is_empty():
		var elapsed: int = maxi(0,Time.get_ticks_msec()-int(cached.sample_msec))/1000
		if int(cached.data.server_now)+elapsed < ends_at and _valid(cached.data):
			summary = cached.data.duplicate(true)
	if not force and not had_failure and not restored_from_disk and not summary.is_empty() and Time.get_ticks_msec() >= int(cached.sample_msec) and Time.get_ticks_msec()-int(cached.sample_msec) < FRESH_MSEC:
		_loading = false
	_render()
	if not _loading: return
	var serial: int = _serial
	var scope: String = _scope()
	var page_limit: int = NEARBY_LIMIT+(0 if result.is_empty() else 1)
	var path: String = "/track-of-the-day/lap-standings?day=%d&version_id=%s&vehicle_id=%s&limit=%d&around=true" % [day,version.uri_encode(),vehicle.uri_encode(),page_limit]
	if not result.is_empty(): path += "&lap_ticks=%d" % maxi(1,roundi(float(result.best_ms)*0.12))
	var response: Dictionary = {}
	for attempt: int in range(4):
		response = await client.request_api(path,HTTPClient.METHOD_GET,{},"",true) if client.signed_in() else await client.request_public(path,get_instance_id())
		if not is_inside_tree() or serial != _serial or scope != _scope(): return
		# A newly selected car can still be preparing its server snapshot. Keep
		# the loading state while the service does that work, then retry boundedly.
		if attempt == 3 or int(response.get("status",0)) != 503 or str(response.get("error","")) not in ["LAP_STANDINGS_PREPARING","LAP_LIMITS_PREPARING","TRACK_OF_DAY_PREPARING"]: break
		await get_tree().create_timer(clampi(int(response.get("retry_after",5)),1,30)).timeout
		if not is_inside_tree() or serial != _serial or scope != _scope(): return
	if not is_inside_tree() or serial != _serial or scope != _scope(): return
	_loading = false
	var data: Dictionary = response.get("data",{}) if response.get("data") is Dictionary else {}
	if response.get("ok",false) and _valid(data):
		summary = data.duplicate(true)
		cache = client.get_meta("daily_card_standings",{})
		cache[cache_key] = {"data":summary.duplicate(true),"sample_msec":Time.get_ticks_msec()}
		while cache.size() > 24: cache.erase(cache.keys()[0])
		client.set_meta("daily_card_standings",cache)
		MenuCache.write(records,cache_key,"standings",summary)
	else:
		_failed = true
	_render()

func _valid(data: Dictionary) -> bool:
	if data.get("day") != day or data.get("version_id") != version or data.get("vehicle_id") != vehicle or data.get("ends_at") != ends_at: return false
	if not _whole(data.get("server_now")) or int(data.server_now) < day*86400 or int(data.server_now) >= ends_at or not _whole(data.get("population")) or int(data.population) < 1: return false
	if not data.get("items") is Array or data.items.size() > NEARBY_LIMIT or not data.get("cutoffs") is Array or data.cutoffs.size() != 9: return false
	var previous: int = 216000
	for index: int in range(9):
		var cutoff: Variant = data.cutoffs[index]
		if not cutoff is Dictionary or cutoff.get("percentile") != Progress.PERCENTILES[index] or not _whole(cutoff.get("lap_ticks")): return false
		if int(cutoff.lap_ticks) < 1 or int(cutoff.lap_ticks) > previous: return false
		previous = int(cutoff.lap_ticks)
	for row: Variant in data.items:
		if not row is Dictionary or not row.get("display_name") is String: return false
		if not _whole(row.get("rank")) or int(row.rank) < 1 or int(row.rank) > int(data.population) or not _whole(row.get("time_ticks")) or int(row.time_ticks) < 1 or int(row.time_ticks) > 216000: return false
	if data.get("comparison") != null:
		if not data.comparison is Dictionary: return false
		for field: String in ["position","population","top_percent","candidate_ticks"]:
			if not _whole(data.comparison.get(field)) or int(data.comparison[field]) < 1: return false
		if int(data.comparison.position) > int(data.comparison.population) or int(data.comparison.top_percent) > 100 or int(data.comparison.candidate_ticks) > 216000: return false
	return true

func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

func invalidate() -> void:
	_serial += 1
	summary = {}
	result = {}
	version = ""
	_loading = false
	_failed = false
	_render()

func _render() -> void:
	if not is_instance_valid(_time): return
	var played: bool = not result.is_empty()
	_time.text = Rules.time_text(float(result.best_ms)/1000.0) if played else "—"
	_time.visible = played and not summary.get("comparison") is Dictionary
	_position.text = ""
	if played and summary.get("comparison") is Dictionary:
		var position: Dictionary = summary.comparison
		_position.text = "#%d / %s  ·  %s" % [int(position.get("position",0)),str(int(position.get("population",0))),tr("Top %d%%") % int(position.get("top_percent",100))]
	for child: Node in _medals.get_children():
		_medals.remove_child(child)
		child.queue_free()
	var tier: int = Progress.tier(int(result.get("passed",0)))
	for level: int in range(1,5):
		var medal := Medal.new()
		medal.tier = level
		medal.earned = tier >= level
		medal.selected = tier == level
		medal.card_display = true
		medal.custom_minimum_size = Vector2(0,84)
		medal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		medal.tooltip_text = tr(Progress.TITLES[level])
		_medals.add_child(medal)
		medal.mouse_filter = Control.MOUSE_FILTER_PASS
		var label: Label = MenuStyle.label(Progress.TITLES[level],14)
		label.name = "DailyMedalLabel"
		GameText.bind(label,Progress.TITLES[level])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_top = -25
		label.offset_bottom = -5
		medal.add_child(label)
		var target_tier: int = mini(tier+1,4)
		if level == target_tier:
			label.add_theme_color_override("font_color",MenuStyle.ACCENT)
			var underline := ColorRect.new()
			underline.name = "DailyMedalTarget"
			underline.color = MenuStyle.ACCENT
			underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			underline.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			underline.anchor_left = 0.12
			underline.anchor_right = 0.88
			underline.offset_top = -2
			medal.add_child(underline)
	_target.text = ""
	_target.tooltip_text = ""
	if tier < 4 and summary.get("cutoffs") is Array and summary.cutoffs.size() == 9:
		var next_stage: int = [0,3,5,8][tier]
		var target: float = float(summary.cutoffs[next_stage].lap_ticks)/120.0
		var next_title: String = tr(Progress.TITLES[tier+1])
		var gap: float = float(result.get("best_ms",0))/1000.0-target
		_target.text = Rules.time_text(target)
		_target.tooltip_text = tr("%.3f s to %s") % [gap,next_title] if played and gap > 0 else tr("Clear the next stage: %s") % next_title
	_target.visible = not _target.text.is_empty()
	_target_row.visible = _target.visible
	race_button.text = tr("Race again") if played else tr("Race")
	_render_rows()

func _render_rows() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var rows: Array = summary.get("items",[]).duplicate(true)
	_retry.visible = _failed
	if not result.is_empty() and summary.get("comparison") is Dictionary:
		var own: Dictionary = summary.comparison
		rows = rows.filter(func(row: Dictionary) -> bool: return str(row.get("player_id","")) != str(_player().get("id","")))
		rows.append({"rank":int(own.position),"time_ticks":int(own.candidate_ticks),"time_ms":int(result.best_ms),"display_name":str(_player().get("display_name",tr("You"))),"country_code":str(_player().get("country_code","")),"self":true})
	# An unplayed account remains visible without inventing a score or a rank.
	elif not summary.is_empty() and not _player().is_empty() and not rows.any(func(row: Dictionary) -> bool: return str(row.get("player_id","")) == str(_player().get("id",""))):
		rows.append({"rank":0,"time_ticks":216001,"display_name":str(_player().get("display_name",tr("You"))),"country_code":str(_player().get("country_code","")),"self":true,"unplayed":true})
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.time_ticks) < int(b.time_ticks))
	if rows.is_empty():
		var empty: Label = MenuStyle.label("No flying laps yet." if not version.is_empty() and not summary.is_empty() else "Standings unavailable",16,true)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if _loading: empty.text = tr("Loading standings…")
		elif _failed: empty.text = tr("Could not load today's standings. Try again.")
		_rows.add_child(empty)
	for value: Variant in rows.slice(0,NEARBY_LIMIT+1):
		if not value is Dictionary or not value.get("display_name") is String: continue
		var row: Dictionary = value
		row["self"] = row.get("self",false) or (not _player().is_empty() and str(row.get("player_id","")) == str(_player().get("id","")))
		var panel := PanelContainer.new()
		panel.name = "DailyNearbySelf" if row.get("self",false) else "DailyNearbyRow"
		panel.custom_minimum_size.y = 28
		var style: StyleBoxFlat = MenuStyle.box(Color("1a303df0") if row.get("self",false) else Color.TRANSPARENT,2)
		style.content_margin_left = 12
		style.content_margin_right = 6
		panel.add_theme_stylebox_override("panel",style)
		_rows.add_child(panel)
		if row.get("self",false):
			# Span the entire row; content margins only inset the rank and name.
			var overlay := Control.new()
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(overlay)
			var accent := ColorRect.new()
			accent.name = "DailyNearbySelfAccent"
			accent.color = MenuStyle.ACCENT
			accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			accent.anchor_bottom = 1.0
			accent.offset_left = -style.content_margin_left
			accent.offset_right = accent.offset_left+3
			accent.offset_top = -style.content_margin_top
			accent.offset_bottom = style.content_margin_bottom
			overlay.add_child(accent)
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation",8)
		panel.add_child(columns)
		var rank: Label = MenuStyle.user_label("—" if row.get("unplayed",false) else str(int(row.get("rank",0))),16)
		rank.custom_minimum_size.x = maxf(24,rank.get_minimum_size().x)
		columns.add_child(rank)
		columns.add_child(PlayerCountry.flag(str(row.get("country_code","")),22))
		var driver: Label = MenuStyle.user_label(str(row.display_name),16)
		driver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		driver.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		driver.tooltip_text = str(row.display_name)
		driver.mouse_filter = Control.MOUSE_FILTER_PASS
		columns.add_child(driver)
		var seconds: float = float(row.time_ms)/1000.0 if row.has("time_ms") else float(row.get("time_ticks",0))/120.0
		var time: Label = MenuStyle.user_label("—" if row.get("unplayed",false) else Rules.time_text(seconds),16)
		time.name = "DailyNearbyTime"
		var tabular := FontVariation.new()
		tabular.base_font = MenuStyle.BODY
		tabular.opentype_features = {"tnum":1}
		time.add_theme_font_override("font",tabular)
		columns.add_child(time)

func _exit_tree() -> void:
	if is_instance_valid(client): client.cancel_public_reads(get_instance_id())

class_name RaceResults
extends VBoxContainer

signal retry_requested
signal return_requested
signal continue_requested

var vehicle_name: String = ""
var circuit: String
var total: float
var previous: float
var best: float
var laps: Array[float]
var clean: bool
var saved: bool
var editor: bool
var result: RaceResultData
var selected_lap: int = 0
var map: LapRouteView
var lap_heading: Label
var average_label: Label
var top_label: Label
var comparison_label: Label
var sector_table: PanelContainer
var sector_rows: GridContainer
var next_button: Button
var lap_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []

func _ready() -> void:
	name = "RaceResults"
	add_theme_constant_override("separation",10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if result == null:
		result = RaceResultData.new()
		for i: int in range(laps.size()):
			result.laps.append({"index":i,"time":laps[i],"duration":laps[i],"valid":clean,"samples":[]})
			if clean and (result.fastest < 0 or laps[i] < laps[result.fastest]): result.fastest = i
	_header()
	var main := HBoxContainer.new()
	main.name = "ResultsMain"
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation",14)
	add_child(main)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 365
	left.add_theme_constant_override("separation",8)
	main.add_child(left)
	_summary(left)
	_visualization(main)
	add_child(HSeparator.new())
	_lap_list(self)
	_actions()
	select_lap(maxi(0,result.fastest))

func _header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	add_child(row)
	var flag := Control.new()
	flag.custom_minimum_size = Vector2(40,48)
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag.draw.connect(func() -> void:
		for y: int in range(3):
			for x: int in range(4):
				var corner := Vector2(8+x*8-y*3,10+y*9)
				var color := Color(0.9,0.94,0.96,0.9 if (x+y)%2 == 0 else 0.23)
				flag.draw_polygon(PackedVector2Array([corner,corner+Vector2(8,0),corner+Vector2(5,9),corner+Vector2(-3,9)]),PackedColorArray([color])))
	row.add_child(flag)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation",0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	titles.add_child(MenuStyle.label("RACE RESULT",30))
	titles.add_child(MenuStyle.label("%s  /  %s  /  %d LAPS" % [circuit.to_upper(),vehicle_name.to_upper(),laps.size()],16,true))
	var brand := MenuStyle.label("B E A T   M Y   T R A C K",13,true)
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(brand)

func _summary(parent: Control) -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	parent.add_child(body)
	var timer := MenuStyle.label(MenuStyle.time_text(total), 94)
	timer.name = "ResultTime"
	body.add_child(timer)
	var delta_text: String = "%+.3f s vs personal best" % (total-previous) if previous > 0 else "Your first benchmark"
	if previous > 0 and absf(total-previous) < 0.0005: delta_text = "Matched your personal best"
	if not clean: delta_text = "Practice result"
	var delta := MenuStyle.label(delta_text, 25, true)
	delta.name = "ResultDelta"
	body.add_child(delta)
	body.add_child(MenuStyle.label("PB  "+(MenuStyle.time_text(best) if best > 0 else "\u2014"), 21, true))
	var gap := Control.new()
	gap.custom_minimum_size.y = 22
	body.add_child(gap)
	var achievement := HBoxContainer.new()
	achievement.add_theme_constant_override("separation", 14)
	body.add_child(achievement)
	achievement.add_child(ResultsIcons.view("trophy", 52, MenuStyle.ACCENT))
	var title: String = "RACE COMPLETE" if clean else "PRACTICE COMPLETE"
	var caption: String = "Five laps. One more benchmark."
	var facts: Dictionary = get_meta("reward_facts", {})
	if clean and previous > 0 and total < previous-0.0005:
		title = "NEW PERSONAL BEST"
		caption = "%.3f s faster than your previous best." % (previous-total)
	elif clean and bool(facts.get("incident_free", false)):
		title = "CLEAN RACE"
		caption = "Every lap. No collisions or off-track incidents."
	elif clean and previous <= 0:
		title = "FIRST FINISH"
		caption = "Your next race has a time to chase."
	var headline := MenuStyle.label(title, 34)
	headline.name = "RaceAchievement"
	headline.add_theme_color_override("font_color", MenuStyle.ACCENT)
	achievement.add_child(headline)
	var note := MenuStyle.label(caption, 16, true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 340
	body.add_child(note)

func _lap_list(parent: Control) -> void:
	var lower := HBoxContainer.new()
	lower.name = "LapTimesStrip"
	lower.add_theme_constant_override("separation", 24)
	parent.add_child(lower)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(stack)
	stack.add_child(MenuStyle.label("LAP TIMES", 19))
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	stack.add_child(strip)
	for i: int in range(laps.size()):
		var button := Button.new()
		button.name = "Lap%d" % (i+1)
		button.custom_minimum_size = Vector2(90, 98)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, _selection_style(false))
		button.pressed.connect(select_lap.bind(i))
		strip.add_child(button)
		lap_buttons.append(button)
		var marker: String = "  \u2605" if i == result.fastest else ""
		var detail: String = "FASTEST" if i == result.fastest else ("%+.3f" % (laps[i]-laps[result.fastest]) if result.fastest >= 0 else "\u2014")
		var prior_lap: float = float(get_meta("reward_facts", {}).get("previous_lap", 0.0))
		if i > 0 and prior_lap > 0 and i != result.fastest:
			if laps[i] >= prior_lap and laps[i]-prior_lap <= 0.05: detail = "NEAR PB"
		if _is_lap_pb(i): detail = "Personal best"
		if not result.laps[i].valid: detail = "INVALID"
		button.text = "%02d%s\n%.3f\n%s" % [i+1, marker, laps[i], detail]
		button.add_theme_font_size_override("font_size", 23)
		for color_state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			button.add_theme_color_override(color_state, MenuStyle.ACCENT if i == result.fastest else MenuStyle.TEXT)
		button.tooltip_text = "Lap %d / %s" % [i+1, "Standing start" if i == 0 else "Flying lap"]
	var stats := VBoxContainer.new()
	stats.custom_minimum_size.x = 210
	stats.add_theme_constant_override("separation", 3)
	lower.add_child(stats)
	average_label = _stat(stats, "Race average speed", "Speed")
	top_label = _stat(stats, "Race top speed", "bars")
	comparison_label = MenuStyle.label("", 17, true)
	stats.add_child(comparison_label)
	var duration: float = 0.0
	var weighted: float = 0.0
	var peak: float = 0.0
	var collisions: int = 0
	for lap: Dictionary in result.laps:
		if not lap.get("samples", []).is_empty():
			var speeds: Vector2 = RaceResultData.speed_stats(lap)
			var seconds: float = float(lap.get("duration", 0))
			duration += seconds
			weighted += speeds.x*seconds
			peak = maxf(peak, speeds.y)
		for event: Dictionary in lap.get("events", []):
			if str(event.kind) == "collision": collisions += 1
	average_label.text = "%d km/h" % roundi(weighted/duration) if duration > 0 else "\u2014"
	top_label.text = "%d km/h" % roundi(peak) if duration > 0 else "\u2014"
	comparison_label.text = "%d collisions" % collisions if duration > 0 else "Incidents unavailable"

func _visualization(parent: Control) -> void:
	var body: VBoxContainer = _card(parent,4)
	body.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	var header := HBoxContainer.new()
	body.add_child(header)
	lap_heading = MenuStyle.label("",16)
	lap_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lap_heading.clip_text = true
	lap_heading.custom_minimum_size.x = 80
	header.add_child(lap_heading)
	for mode: String in ["Track","Sectors","Speed"]:
		var button: Button = MenuStyle.button(mode,select_mode.bind(mode))
		button.custom_minimum_size = Vector2(110,48)
		button.icon = ResultsIcons.texture("Time diff" if mode == "Track" else mode,Color.WHITE)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",24)
		button.add_theme_constant_override("h_separation",10)
		button.add_theme_font_size_override("font_size",18)
		header.add_child(button)
		mode_buttons.append(button)
	lap_heading.tooltip_text = "Tap the route to inspect. Differences compare the selected lap with the fastest valid lap in this race."
	map = LapRouteView.new()
	map.name = "LapVisualization"
	map.route = result.route
	# Fit once to the race-wide incident extent, never the selected lap.
	for lap: Dictionary in result.laps:
		for event: Dictionary in lap.get("events", []):
			map.framing_points.append(event.position)
	map.boundaries = result.sector_boundaries
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.custom_minimum_size = Vector2(350,200)
	var analysis := HBoxContainer.new()
	analysis.size_flags_vertical = Control.SIZE_EXPAND_FILL
	analysis.add_theme_constant_override("separation",12)
	body.add_child(analysis)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	analysis.add_child(map)
	sector_table = PanelContainer.new()
	sector_table.name = "SectorTable"
	sector_table.custom_minimum_size.x = 218
	sector_table.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sector_table.add_theme_stylebox_override("panel",_panel_style(12))
	analysis.add_child(sector_table)
	sector_rows = GridContainer.new()
	sector_rows.columns = 3
	sector_rows.add_theme_constant_override("h_separation",16)
	sector_rows.add_theme_constant_override("v_separation",12)
	sector_table.add_child(sector_rows)
	select_mode("Track")

func _stat(parent: Control, caption: String, symbol: String) -> Label:
	if parent is HBoxContainer and parent.get_child_count() > 0:
		var divider := VSeparator.new()
		var line := MenuStyle.box(Color("304c5b"),0)
		line.content_margin_left = 1
		divider.add_theme_stylebox_override("separator",line)
		divider.custom_minimum_size.x = 1
		parent.add_child(divider)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	row.add_child(ResultsIcons.view(symbol,24,MenuStyle.ACCENT if symbol == "trophy" else Color("a5c8df")))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation",0)
	row.add_child(col)
	var value := MenuStyle.label("—",27)
	col.add_child(value)
	col.add_child(MenuStyle.label(caption,14,true))
	return value

func _actions() -> void:
	var row := HBoxContainer.new()
	row.name = "ResultsActions"
	row.add_theme_constant_override("separation",16)
	add_child(row)
	var retry := MenuStyle.button("\u21bb   RACE AGAIN\n"+_retry_motivation(),func() -> void: retry_requested.emit())
	retry.name = "RetryRace"
	retry.add_theme_stylebox_override("normal",_panel_style(8))
	row.add_child(retry)
	next_button = MenuStyle.button("CONTINUE   \u2192",func() -> void: continue_requested.emit(),true)
	next_button.name = "ContinueResults"
	row.add_child(next_button)
	for button: Button in [retry,next_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 70

func select_lap(index: int) -> void:
	if result.laps.is_empty(): return
	selected_lap = clampi(index,0,result.laps.size()-1)
	for i: int in range(lap_buttons.size()):
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var style: StyleBoxFlat = _selection_style(i == selected_lap)
			if i != selected_lap and state in ["hover", "focus"]: style.bg_color = Color(0.07,0.15,0.20,0.30)
			lap_buttons[i].add_theme_stylebox_override(state,style)
	var lap: Dictionary = result.laps[selected_lap]
	lap_heading.text = "LAP %02d / %s" % [selected_lap+1,"FASTEST LAP" if selected_lap == result.fastest else ("STANDING START" if selected_lap == 0 else "FLYING LAP")]
	if _is_lap_pb(selected_lap): lap_heading.text = "LAP %02d / PERSONAL BEST" % (selected_lap+1)
	if not lap.valid: lap_heading.text = "LAP %02d / INVALID" % (selected_lap+1)
	map.show_lap(lap,result.laps[result.fastest] if result.fastest >= 0 else {})
	_update_sectors(lap)

func select_mode(mode: String) -> void:
	sector_table.visible = mode == "Sectors"
	map.mode = "Time diff" if mode == "Track" else mode
	map.queue_redraw()
	for button: Button in mode_buttons:
		var style: StyleBoxFlat = _panel_style(12)
		if button.text == mode: style.border_color = MenuStyle.ACCENT
		button.add_theme_color_override("font_color",MenuStyle.ACCENT if button.text == mode else Color("dbe7ed"))
		button.add_theme_color_override("icon_normal_color",MenuStyle.ACCENT if button.text == mode else Color("a5c8df"))
		button.add_theme_stylebox_override("normal",style)
		for state: String in ["hover", "pressed", "focus", "disabled"]:
			var stable: StyleBoxFlat = button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			stable.set_content_margin_all(12)
			button.add_theme_stylebox_override(state, stable)

func _update_sectors(lap: Dictionary) -> void:
	for child: Node in sector_rows.get_children():
		sector_rows.remove_child(child)
		child.queue_free()
	for heading: String in ["SECTOR","TIME","\u0394 BEST"]:
		sector_rows.add_child(MenuStyle.label(heading,14,true))
	var sectors: Array[Dictionary] = LapTelemetry.sectors(lap,result.sector_boundaries)
	var reference: Array[Dictionary] = LapTelemetry.sectors(map.reference,result.sector_boundaries)
	for i: int in range(sectors.size()):
		var available: bool = not lap.get("samples",[]).is_empty()
		var comparable: bool = available and not map.reference.get("samples",[]).is_empty() and i < reference.size()
		var delta: float = float(sectors[i].time)-float(reference[i].time) if comparable else 0.0
		var delta_color: Color = Color("ed8056") if delta > 0.0005 else (Color("55dbaa") if delta < -0.0005 else Color("9bb6c5"))
		var title := MenuStyle.label("\u25cf  S%d" % (i+1),18)
		title.add_theme_color_override("font_color",delta_color)
		sector_rows.add_child(title)
		sector_rows.add_child(MenuStyle.label("%.2f s" % sectors[i].time if available else "\u2014",19))
		var difference := MenuStyle.label("%+.3f" % delta if comparable else "\u2014",18)
		difference.add_theme_color_override("font_color",delta_color)
		sector_rows.add_child(difference)
	for index: int in range(sector_rows.get_child_count()):
		var cell := sector_rows.get_child(index) as Label
		cell.custom_minimum_size.x = [58.0, 78.0, 82.0][index % 3]
		cell.clip_text = true
	sector_table.tooltip_text = "Sector differences compared with your fastest valid lap in this race."

static func _panel_style(padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.box(Color(0.025,0.065,0.092,0.88),padding)
	style.border_color = Color("425b69")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _retry_motivation() -> String:
	if not clean: return "Set a timed benchmark"
	if previous > 0 and total > previous+0.0005: return "%.3f s to beat your PB" % (total-previous)
	return "Beat your new benchmark" if best > 0 else "Find your next fastest lap"

func _is_lap_pb(index: int) -> bool:
	# Historical lap records are flying laps; a standing start is not comparable.
	if not clean or index <= 0 or index >= result.laps.size() or not result.laps[index].valid: return false
	# Only the best eligible flying lap owns the new record. First occurrence wins ties.
	for other: int in range(1, result.laps.size()):
		if not result.laps[other].valid or other == index: continue
		if laps[other] < laps[index] or (laps[other] == laps[index] and other < index): return false
	var prior: float = float(get_meta("reward_facts", {}).get("previous_lap", 0.0))
	return prior <= 0.0 or laps[index] < prior-0.0005

static func _selection_style(selected: bool) -> StyleBoxFlat:
	var style := MenuStyle.box(Color(0.07,0.15,0.20,0.85) if selected else Color.TRANSPARENT, 5)
	return style

static func _card(parent: Control, padding: int) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuStyle.box(Color.TRANSPARENT, padding))
	parent.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	return body

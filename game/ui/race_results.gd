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
	left.custom_minimum_size.x = 402
	left.add_theme_constant_override("separation",8)
	main.add_child(left)
	_summary(left)
	_lap_list(left)
	_visualization(main)
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
	var body: VBoxContainer = _card(parent,10)
	body.add_theme_constant_override("separation",1)
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation",10)
	body.add_child(values)
	var time_column := VBoxContainer.new()
	time_column.add_theme_constant_override("separation",0)
	time_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.add_child(time_column)
	time_column.add_child(MenuStyle.label("TOTAL RACE TIME",17,true))
	var timer := MenuStyle.label(MenuStyle.time_text(total),52)
	timer.name = "ResultTime"
	timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_column.add_child(timer)
	var pb := VBoxContainer.new()
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_constant_override("separation",0)
	var wreath := HBoxContainer.new()
	wreath.name = "PersonalBestLaurels"
	wreath.add_theme_constant_override("separation",0)
	wreath.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	values.add_child(wreath)
	wreath.add_child(ResultsIcons.view("laurel",20,MenuStyle.ACCENT))
	wreath.add_child(pb)
	var right_leaf := ResultsIcons.view("laurel",20,MenuStyle.ACCENT)
	right_leaf.flip_h = true
	wreath.add_child(right_leaf)
	var pb_title := MenuStyle.label("PERSONAL BEST",14)
	pb_title.add_theme_color_override("font_color",MenuStyle.ACCENT)
	pb.add_child(pb_title)
	var pb_time := MenuStyle.label(MenuStyle.time_text(best) if best > 0 else "\u2014",26)
	pb_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_time.add_theme_color_override("font_color",MenuStyle.ACCENT)
	pb.add_child(pb_time)

func _lap_list(parent: Control) -> void:
	var panel: VBoxContainer = _card(parent,5)
	panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.get_parent().custom_minimum_size.y = min(laps.size(),5)*65+6
	panel.add_theme_constant_override("separation",4)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",4)
	scroll.add_child(list)
	for i: int in range(laps.size()):
		var button := Button.new()
		button.name = "Lap%d" % (i+1)
		button.custom_minimum_size.y = 61
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_lap.bind(i))
		list.add_child(button)
		lap_buttons.append(button)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left",12)
		margin.add_theme_constant_override("margin_right",12)
		margin.add_theme_constant_override("margin_top",8)
		margin.add_theme_constant_override("margin_bottom",8)
		button.add_child(margin)
		MenuStyle.fill(margin)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stack.add_theme_constant_override("separation",1)
		margin.add_child(stack)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(row)
		var number := MenuStyle.label("%02d" % (i+1),24,true)
		number.custom_minimum_size.x = 34
		row.add_child(number)
		var classification: String = "Standing start" if i == 0 else "Flying lap"
		if i == result.fastest: classification = ("Standing start \u2605" if i == 0 else "Fastest lap \u2605")
		if not result.laps[i].valid: classification += " · Invalid"
		var title := MenuStyle.label(classification,15,true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == result.fastest: title.add_theme_color_override("font_color",MenuStyle.ACCENT)
		row.add_child(title)
		row.add_child(MenuStyle.label("%.3f" % laps[i],28))
		var delta := MenuStyle.label("—" if result.fastest < 0 or i == result.fastest else "%+.3f" % (laps[i]-laps[result.fastest]),15,true)
		delta.custom_minimum_size.x = 65
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(delta)
		var bar := ProgressBar.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size.y = 4
		bar.show_percentage = false
		bar.max_value = laps.max()
		bar.value = laps[i]
		bar.add_theme_stylebox_override("fill",MenuStyle.box(MenuStyle.ACCENT if i == result.fastest else Color("729db6"),0))
		stack.add_child(bar)

func _visualization(parent: Control) -> void:
	var body: VBoxContainer = _card(parent,16)
	body.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	var header := HBoxContainer.new()
	body.add_child(header)
	lap_heading = MenuStyle.label("",25)
	lap_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lap_heading.clip_text = true
	lap_heading.custom_minimum_size.x = 210
	header.add_child(lap_heading)
	for mode: String in ["Sectors","Time diff","Speed"]:
		var button: Button = MenuStyle.button(mode,select_mode.bind(mode))
		button.custom_minimum_size = Vector2(124,48)
		button.icon = ResultsIcons.texture(mode,Color.WHITE)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",24)
		button.add_theme_constant_override("h_separation",10)
		button.add_theme_font_size_override("font_size",18)
		header.add_child(button)
		mode_buttons.append(button)
	body.add_child(MenuStyle.label("Tap or drag the route to inspect your lap",14,true))
	map = LapRouteView.new()
	map.name = "LapVisualization"
	map.route = result.route
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
	body.add_child(HSeparator.new())
	var stats := HBoxContainer.new()
	stats.custom_minimum_size.y = 57
	stats.add_theme_constant_override("separation",16)
	body.add_child(stats)
	average_label = _stat(stats,"Average speed","Speed")
	top_label = _stat(stats,"Top speed","bars")
	comparison_label = _stat(stats,"vs. fastest valid lap","trophy")
	select_mode("Sectors")

func _stat(parent: Control, caption: String, symbol: String) -> Label:
	if parent.get_child_count() > 0:
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
	row.add_child(ResultsIcons.view(symbol,34,MenuStyle.ACCENT if symbol == "trophy" else Color("a5c8df")))
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
	var retry := MenuStyle.button("\u21bb   RACE AGAIN",func() -> void: retry_requested.emit())
	retry.name = "RetryRace"
	retry.add_theme_stylebox_override("normal",_panel_style(8))
	row.add_child(retry)
	next_button = MenuStyle.button("CONTINUE   \u2192",func() -> void: continue_requested.emit(),true)
	next_button.name = "ContinueResults"
	row.add_child(next_button)
	for button: Button in [retry,next_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 66

func select_lap(index: int) -> void:
	if result.laps.is_empty(): return
	selected_lap = clampi(index,0,result.laps.size()-1)
	for i: int in range(lap_buttons.size()): lap_buttons[i].add_theme_stylebox_override("normal",_selection_style(i == selected_lap))
	var lap: Dictionary = result.laps[selected_lap]
	lap_heading.text = "LAP %02d / %s" % [selected_lap+1,"FASTEST LAP" if selected_lap == result.fastest else ("STANDING START" if selected_lap == 0 else "FLYING LAP")]
	if not lap.valid: lap_heading.text = "LAP %02d / INVALID" % (selected_lap+1)
	map.show_lap(lap,result.laps[result.fastest] if result.fastest >= 0 else {})
	_update_sectors(lap)
	var stats: Vector2 = RaceResultData.speed_stats(lap)
	average_label.text = "%d km/h" % roundi(stats.x) if not lap.samples.is_empty() else "—"
	top_label.text = "%d km/h" % roundi(stats.y) if not lap.samples.is_empty() else "—"
	comparison_label.text = "—" if result.fastest < 0 or selected_lap == result.fastest else "%+.3f s" % (float(lap.time)-float(result.laps[result.fastest].time))

func select_mode(mode: String) -> void:
	sector_table.visible = mode == "Sectors"
	map.mode = mode
	map.queue_redraw()
	for button: Button in mode_buttons:
		var style: StyleBoxFlat = _panel_style(6)
		if button.text == mode: style.border_color = MenuStyle.ACCENT
		button.add_theme_color_override("font_color",MenuStyle.ACCENT if button.text == mode else Color("dbe7ed"))
		button.add_theme_color_override("icon_normal_color",MenuStyle.ACCENT if button.text == mode else Color("a5c8df"))
		button.add_theme_stylebox_override("normal",style)

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
	sector_table.tooltip_text = "Sector differences compared with your fastest valid lap in this race."

static func _panel_style(padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.box(Color(0.025,0.065,0.092,0.88),padding)
	style.border_color = Color("425b69")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

static func _selection_style(selected: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = _panel_style(5)
	if selected:
		style.border_color = MenuStyle.ACCENT
		style.set_border_width_all(2)
		style.bg_color = Color(0.15,0.15,0.09,0.65)
	return style

static func _card(parent: Control, padding: int) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_panel_style(padding))
	parent.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	return body

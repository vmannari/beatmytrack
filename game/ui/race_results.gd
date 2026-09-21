class_name RaceResults
extends VBoxContainer

signal retry_requested
signal return_requested
signal analysis_requested(lap_index: int)
signal next_requested(recommendation: Dictionary)

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
var recommendations: Array[Dictionary] = []
var selected_lap: int = 0
var selected_recommendation: int = -1
var map: LapRouteView
var lap_heading: Label
var average_label: Label
var top_label: Label
var comparison_label: Label
var next_title: Label
var next_subtitle: Label
var next_button: Button
var lap_buttons: Array[Button] = []
var recommendation_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var analysis_dialog: AcceptDialog

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
	_recommendations()
	_actions()
	select_lap(maxi(0,result.fastest))
	if not recommendations.is_empty(): select_recommendation(0)

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
	var body: VBoxContainer = _card(parent,12)
	body.add_theme_constant_override("separation",1)
	body.add_child(MenuStyle.label("TOTAL RACE TIME",17,true))
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation",10)
	body.add_child(values)
	var timer := MenuStyle.label(MenuStyle.time_text(total),60)
	timer.name = "ResultTime"
	timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.add_child(timer)
	var pb := VBoxContainer.new()
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_constant_override("separation",0)
	values.add_child(pb)
	pb.add_child(MenuStyle.label("YOUR BEST",12,true))
	pb.add_child(MenuStyle.label(MenuStyle.time_text(best) if best > 0 else "—",24))
	var feedback: Dictionary = RaceDebrief.feedback(total,previous,clean,saved,editor)
	var detail: String = feedback.detail
	if clean and saved:
		detail = "%+.3f from your best" % (total-previous) if previous > 0 else "Your first benchmark is set"
	var delta := MenuStyle.label(detail,17,true)
	delta.name = "ResultDelta"
	delta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(delta)
	var status := MenuStyle.label(feedback.title+" · Local time",12,true)
	status.name = "ResultStatus"
	# Keep the status value independently accessible for record-flow diagnostics.
	status.text = feedback.title
	status.visible = false
	if not clean or not saved: delta.text = feedback.title+" \u00b7 "+feedback.detail
	body.add_child(status)

func _lap_list(parent: Control) -> void:
	var panel: VBoxContainer = _card(parent,5)
	panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.get_parent().custom_minimum_size.y = min(laps.size(),5)*53+6
	panel.add_theme_constant_override("separation",4)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",4)
	scroll.add_child(list)
	for i: int in range(laps.size()):
		var button := Button.new()
		button.name = "Lap%d" % (i+1)
		button.custom_minimum_size.y = 49
		button.pressed.connect(select_lap.bind(i))
		list.add_child(button)
		lap_buttons.append(button)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left",12)
		margin.add_theme_constant_override("margin_right",12)
		margin.add_theme_constant_override("margin_top",4)
		button.add_child(margin)
		MenuStyle.fill(margin)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		row.add_child(MenuStyle.label("%.3f" % laps[i],24))
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
	var body: VBoxContainer = _card(parent,14)
	body.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",4)
	var header := HBoxContainer.new()
	body.add_child(header)
	lap_heading = MenuStyle.label("",25)
	lap_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lap_heading)
	for mode: String in ["Speed","Time diff","Sectors"]:
		var button: Button = MenuStyle.button(mode,select_mode.bind(mode))
		button.custom_minimum_size = Vector2(78,48)
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
	body.add_child(map)
	body.add_child(HSeparator.new())
	var stats := HBoxContainer.new()
	stats.custom_minimum_size.y = 49
	body.add_child(stats)
	average_label = _stat(stats,"Average speed")
	top_label = _stat(stats,"Top speed")
	comparison_label = _stat(stats,"vs. fastest valid lap")
	select_mode("Speed")

func _stat(parent: Control, caption: String) -> Label:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation",0)
	parent.add_child(col)
	var value := MenuStyle.label("—",27)
	col.add_child(value)
	col.add_child(MenuStyle.label(caption,14,true))
	return value

func _recommendations() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_panel_style(9))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	panel.add_child(row)
	var intro := VBoxContainer.new()
	intro.custom_minimum_size.x = 150
	intro.add_theme_constant_override("separation",4)
	row.add_child(intro)
	intro.add_child(MenuStyle.label("RACE NEXT",27))
	intro.add_child(MenuStyle.label("Keep the momentum.\nPick what’s next.",15,true))
	if recommendations.is_empty():
		var empty := MenuStyle.label("No other local tracks yet. Create or import a track to discover more.",18,true)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(empty)
	for i: int in range(recommendations.size()):
		var item: Dictionary = recommendations[i]
		var button := Button.new()
		button.name = "Recommendation%d" % i
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0,98)
		button.pressed.connect(select_recommendation.bind(i))
		button.tooltip_text = item.name+" · "+item.reason
		row.add_child(button)
		recommendation_buttons.append(button)
		var margin := MarginContainer.new()
		for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,9)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		MenuStyle.fill(margin)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation",4)
		margin.add_child(stack)
		var category := MenuStyle.label("TRY SOMETHING DIFFERENT" if item.category == "different_biome" else "RECOMMENDED",12,true)
		category.clip_text = true
		stack.add_child(category)
		var content := HBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(content)
		var preview := LapRouteView.new()
		preview.miniature = true
		preview.route = item.route
		preview.custom_minimum_size = Vector2(80,55)
		content.add_child(preview)
		var copy := VBoxContainer.new()
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_theme_constant_override("separation",2)
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(copy)
		var title := MenuStyle.label(item.name,23)
		title.clip_text = true
		copy.add_child(title)
		copy.add_child(MenuStyle.label("%d laps · ~%d:%02d" % [item.laps,int(float(item.estimated_seconds)/60),int(item.estimated_seconds)%60],14,true))
		var reason := MenuStyle.label(item.reason,12,true)
		reason.clip_text = true
		copy.add_child(reason)

func _actions() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	add_child(row)
	var tracks := MenuStyle.button("‹   Tracks" if not editor else "‹   Back to editor",func() -> void: return_requested.emit())
	tracks.name = "ResultsTracks"
	row.add_child(tracks)
	var analysis := MenuStyle.button("Lap analysis",_open_analysis)
	analysis.name = "LapAnalysis"
	row.add_child(analysis)
	var retry := MenuStyle.button("\u21bb   Race again",func() -> void: retry_requested.emit())
	retry.name = "RetryRace"
	row.add_child(retry)
	next_button = MenuStyle.button("NEXT RACE \u2192\nChoose another local track",func() -> void:
		if selected_recommendation >= 0: next_requested.emit(recommendations[selected_recommendation]),true)
	next_button.text = ""
	var next_center := CenterContainer.new()
	next_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_button.add_child(next_center)
	MenuStyle.fill(next_center)
	var next_copy := VBoxContainer.new()
	next_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_copy.add_theme_constant_override("separation",0)
	next_center.add_child(next_copy)
	next_title = MenuStyle.label("NEXT RACE \u2192",25)
	next_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_title.add_theme_color_override("font_color",MenuStyle.INK)
	next_copy.add_child(next_title)
	next_subtitle = MenuStyle.label("No other local tracks",15)
	next_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_subtitle.add_theme_color_override("font_color",MenuStyle.INK)
	next_copy.add_child(next_subtitle)
	next_button.name = "NextRace"
	next_button.disabled = recommendations.is_empty()
	row.add_child(next_button)
	for button: Button in [tracks,analysis,retry,next_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 61
		if button != next_button: button.add_theme_stylebox_override("normal",_panel_style(8))
	next_button.size_flags_stretch_ratio = 1.4

func select_lap(index: int) -> void:
	if result.laps.is_empty(): return
	selected_lap = clampi(index,0,result.laps.size()-1)
	for i: int in range(lap_buttons.size()): lap_buttons[i].add_theme_stylebox_override("normal",_selection_style(i == selected_lap))
	var lap: Dictionary = result.laps[selected_lap]
	lap_heading.text = "LAP %02d / %s" % [selected_lap+1,"FASTEST LAP" if selected_lap == result.fastest else ("STANDING START" if selected_lap == 0 else "FLYING LAP")]
	if not lap.valid: lap_heading.text = "LAP %02d / INVALID" % (selected_lap+1)
	map.show_lap(lap,result.laps[result.fastest] if result.fastest >= 0 else {})
	var stats: Vector2 = RaceResultData.speed_stats(lap)
	average_label.text = "%d km/h" % roundi(stats.x) if not lap.samples.is_empty() else "—"
	top_label.text = "%d km/h" % roundi(stats.y) if not lap.samples.is_empty() else "—"
	comparison_label.text = "—" if result.fastest < 0 or selected_lap == result.fastest else "%+.3f s" % (float(lap.time)-float(result.laps[result.fastest].time))

func select_mode(mode: String) -> void:
	map.mode = mode
	map.queue_redraw()
	for button: Button in mode_buttons:
		var style: StyleBoxFlat = _panel_style(6)
		if button.text == mode: style.border_color = Color("829daa")
		button.add_theme_stylebox_override("normal",style)

func select_recommendation(index: int) -> void:
	selected_recommendation = index
	for i: int in range(recommendation_buttons.size()): recommendation_buttons[i].add_theme_stylebox_override("normal",_selection_style(i == index))
	var item: Dictionary = recommendations[index]
	next_subtitle.text = "%s \u00b7 %d laps" % [item.name,item.laps]
	next_button.tooltip_text = next_subtitle.text

func _open_analysis() -> void:
	analysis_requested.emit(selected_lap)
	if analysis_dialog == null:
		analysis_dialog = AcceptDialog.new()
		analysis_dialog.title = "Lap analysis"
		analysis_dialog.dialog_text = "Detailed performance analysis is coming later.\nExplore Speed, Time diff and Sectors on this screen."
		add_child(analysis_dialog)
	analysis_dialog.popup_centered(Vector2i(460,160))

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

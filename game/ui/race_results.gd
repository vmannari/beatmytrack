class_name RaceResults
extends VBoxContainer

signal retry_requested
signal return_requested

var vehicle_name: String = ""
var circuit: String
var total: float
var previous: float
var best: float
var laps: Array[float]
var clean: bool
var saved: bool
var editor: bool

func _ready() -> void:
	custom_minimum_size.x = 1040
	add_theme_constant_override("separation",20)
	var feedback: Dictionary = RaceDebrief.feedback(total,previous,clean,saved,editor)
	var heading := HBoxContainer.new()
	add_child(heading)
	var heading_label := MenuStyle.label("RACE RESULT" + ("  /  " + vehicle_name if not vehicle_name.is_empty() else ""),24,true)
	heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_label)
	var circuit_label := MenuStyle.label(circuit.to_upper(),30)
	circuit_label.custom_minimum_size.x = 450
	circuit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	circuit_label.clip_text = true
	heading.add_child(circuit_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	add_child(row)
	var summary: VBoxContainer = _card(row,620)
	summary.add_child(MenuStyle.label("FIVE-LAP RACE TIME",16,true))
	var time_label := MenuStyle.label(MenuStyle.time_text(total),92)
	time_label.name = "ResultTime"
	summary.add_child(time_label)
	var badge := PanelContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var highlight: Color = MenuStyle.POSITIVE if feedback.title in ["PERSONAL BEST","FIRST TIME SET"] else MenuStyle.PANEL
	badge.add_theme_stylebox_override("panel",MenuStyle.box(highlight,10))
	summary.add_child(badge)
	var status := MenuStyle.label(feedback.title,24)
	status.name = "ResultStatus"
	if highlight == MenuStyle.POSITIVE: status.add_theme_color_override("font_color",MenuStyle.INK)
	badge.add_child(status)
	var delta := MenuStyle.label(feedback.detail,21)
	delta.name = "ResultDelta"
	delta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(delta)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.add_child(space)
	summary.add_child(HSeparator.new())
	var record_row := HBoxContainer.new()
	summary.add_child(record_row)
	var record_label := MenuStyle.label("PERSONAL BEST",16,true)
	record_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_row.add_child(record_label)
	record_row.add_child(MenuStyle.label(MenuStyle.time_text(best) if best > 0.0 else "—",26))
	var splits: VBoxContainer = _card(row,400)
	splits.add_child(MenuStyle.label("LAP BREAKDOWN",24))
	splits.add_child(MenuStyle.label("Find your rhythm. Carry it forward.",16,true))
	var fastest: int = 1 if laps.size() > 1 else 0
	var longest: float = 0.001
	for index: int in range(laps.size()):
		longest = maxf(longest,laps[index])
		if index > 0 and laps[index] < laps[fastest]: fastest = index
	for index: int in range(laps.size()):
		var lap_row := HBoxContainer.new()
		splits.add_child(lap_row)
		var name_label := MenuStyle.label("%02d   %s" % [index+1,"Standing start" if index == 0 else ("Fastest flying lap" if index == fastest else "Flying lap")],16,true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lap_row.add_child(name_label)
		var lap_time := MenuStyle.label("%.3f" % laps[index],25)
		if index == fastest and index > 0: lap_time.add_theme_color_override("font_color",MenuStyle.POSITIVE)
		lap_row.add_child(lap_time)
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 4
		bar.show_percentage = false
		bar.max_value = longest
		bar.value = laps[index]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("fill",MenuStyle.box(MenuStyle.POSITIVE if index == fastest and index > 0 else Color("5f849c"),0))
		splits.add_child(bar)
	var actions := HBoxContainer.new()
	add_child(actions)
	var back: Button = MenuStyle.button("Back to editor" if editor else "Choose track",func() -> void: return_requested.emit())
	back.custom_minimum_size = Vector2(220,64)
	actions.add_child(back)
	var legal := MenuStyle.label("Local personal best · Unverified time",15,true)
	legal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(legal)
	var retry: Button = MenuStyle.button("RACE AGAIN  →",func() -> void: retry_requested.emit(),true)
	retry.name = "RetryRace"
	retry.custom_minimum_size = Vector2(300,64)
	actions.add_child(retry)

func _card(parent: HBoxContainer, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width,380)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	panel.add_child(body)
	return body

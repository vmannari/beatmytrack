class_name RaceResults
extends VBoxContainer

signal retry_requested
signal return_requested

var circuit: String
var total: float
var previous: float
var best: float
var laps: Array[float]
var clean: bool
var saved: bool
var editor: bool

func _ready() -> void:
	custom_minimum_size.x = 1000
	add_theme_constant_override("separation",20)
	var feedback: Dictionary = RaceDebrief.feedback(total,previous,clean,saved,editor)
	var status := MenuStyle.label(feedback.title,24)
	status.name = "ResultStatus"
	if feedback.title == "PERSONAL BEST": status.add_theme_color_override("font_color",Color("a6ce91"))
	add_child(status)
	var title := MenuStyle.label(circuit.to_upper(),50)
	title.clip_text = true
	add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",80)
	add_child(row)
	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(summary)
	summary.add_child(MenuStyle.label("FIVE-LAP RACE TIME",16,true))
	summary.add_child(MenuStyle.label(MenuStyle.time_text(total),88))
	var delta := MenuStyle.label(feedback.detail,22)
	delta.name = "ResultDelta"
	delta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(delta)
	var space := Control.new()
	space.custom_minimum_size.y = 16
	summary.add_child(space)
	if best > 0.0:
		summary.add_child(MenuStyle.label("PERSONAL BEST   "+MenuStyle.time_text(best),20,true))
	var splits := VBoxContainer.new()
	splits.custom_minimum_size.x = 310
	row.add_child(splits)
	splits.add_child(MenuStyle.label("LAP BREAKDOWN",18,true))
	var fastest: int = 1
	for index: int in range(2,laps.size()):
		if laps[index] < laps[fastest]: fastest = index
	for index: int in range(laps.size()):
		var lap_row := HBoxContainer.new()
		splits.add_child(lap_row)
		var name_label := MenuStyle.label("%02d%s" % [index+1,"  Standing start" if index == 0 else ("  Fastest lap" if index == fastest else "")],18,index != fastest)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lap_row.add_child(name_label)
		lap_row.add_child(MenuStyle.label("%.3f" % laps[index],26,index != fastest))
	add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	add_child(actions)
	var retry: Button = MenuStyle.button("Retry",func() -> void: retry_requested.emit(),true)
	retry.custom_minimum_size = Vector2(290,64)
	actions.add_child(retry)
	actions.add_child(MenuStyle.tab("Back to editor" if editor else "Choose track",func() -> void: return_requested.emit()))
	add_child(MenuStyle.label("Local personal best · Unverified time",15,true))

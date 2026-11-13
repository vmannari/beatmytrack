extends Control
signal retry_requested
signal return_requested
var rules: RefCounted
var session: TrackSession

func _ready() -> void:
	MenuStyle.fill(self)
	var shade := ColorRect.new()
	shade.color = Color("08121bef")
	MenuStyle.fill(shade)
	add_child(shade)
	var margin := MarginContainer.new()
	MenuStyle.fill(margin)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	column.add_child(MenuStyle.label("Track of the Day",24,true))
	var title: Label = MenuStyle.label("Eliminated" if rules.eliminated else "Top 1% — challenge complete",36)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	column.add_child(MenuStyle.label(tr("Stages passed: %d / 9") % rules.passed,24))
	var grid := GridContainer.new()
	grid.name = "DailyLapGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",12)
	column.add_child(grid)
	for heading: String in ["Flying lap","Lap time","Limit"]: grid.add_child(MenuStyle.label(heading,16,true))
	for index: int in range(1,session.lap_times.size()):
		var percentile: int = rules.PERCENTILES[index-1]
		grid.add_child(MenuStyle.label(tr("Top %d%%") % percentile,20))
		var time: Label = MenuStyle.label(rules.time_text(session.lap_times[index]),20)
		time.modulate = Color("ff8b78") if rules.eliminated and index == session.lap_times.size()-1 else Color("abdfad")
		grid.add_child(time)
		grid.add_child(MenuStyle.label(rules.time_text(rules.limits[index-1]),20,true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",16)
	column.add_child(actions)
	actions.add_child(MenuStyle.button("Race again",func() -> void: retry_requested.emit(),true))
	actions.add_child(MenuStyle.button("Back",func() -> void: return_requested.emit()))

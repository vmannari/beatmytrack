extends Control
signal retry_requested
signal return_requested
var rules: RefCounted
var session: TrackSession
var result_saved: bool = true
var client: Node
var cloud: Node
var day: int = -1
var version: String = ""
var vehicle: String = ""
var track_name: String = ""

var _lap_grid: GridContainer

func _ready() -> void:
	MenuStyle.fill(self)
	var shade := ColorRect.new()
	shade.color = Color("08121bf5")
	MenuStyle.fill(shade)
	add_child(shade)
	var margin := MarginContainer.new()
	MenuStyle.fill(margin)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)

	var eyebrow: Label = MenuStyle.label("Track of the Day",16,true)
	eyebrow.add_theme_color_override("font_color",MenuStyle.ACCENT)
	column.add_child(eyebrow)
	var summary := PanelContainer.new()
	summary.name = "DailyResultSummary"
	summary.add_theme_stylebox_override("panel",_card_style(Color("102938"),Color("416173"),22))
	column.add_child(summary)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation",16)
	summary.add_child(summary_row)
	var headline := VBoxContainer.new()
	headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headline.add_theme_constant_override("separation",4)
	summary_row.add_child(headline)
	var title: Label = MenuStyle.label("Eliminated" if rules.eliminated else "Challenge complete",36)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_child(title)
	var stages: Label = MenuStyle.label(tr("Stages passed: %d / 9") % rules.passed,22,true)
	headline.add_child(stages)
	if session.lap_times.size() > 1:
		var best: float = INF
		for index: int in range(1,session.lap_times.size()): best = minf(best,session.lap_times[index])
		var best_label: Label = MenuStyle.user_label("%s  %s" % [tr("Best flying lap"),rules.time_text(best)],18)
		best_label.add_theme_color_override("font_color",MenuStyle.ACCENT)
		headline.add_child(best_label)
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation",4)
	headline.add_child(progress)
	for index: int in range(9):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(8,5)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.color = MenuStyle.ACCENT if index < rules.passed else Color("425866")
		progress.add_child(segment)
	var award: int = preload("res://persistence/daily_progress.gd").tier(rules.passed)
	if award > 0:
		var medal_column := VBoxContainer.new()
		medal_column.add_theme_constant_override("separation",0)
		summary_row.add_child(medal_column)
		var medal := preload("res://ui/daily_medal.gd").new()
		medal.tier = award
		medal.selected = true
		medal.custom_minimum_size = Vector2(76,76)
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		medal_column.add_child(medal)
		var earned: Label = MenuStyle.label(preload("res://persistence/daily_progress.gd").TITLES[award],20)
		earned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		medal_column.add_child(earned)
	if not result_saved:
		var warning: Label = MenuStyle.label("Daily result could not be saved.",18,true)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(warning)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	column.add_child(actions)
	var retry: Button = MenuStyle.button("Race again",func() -> void: retry_requested.emit(),true)
	retry.name = "DailyRetryRace"
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(retry)
	var back: Button = MenuStyle.button("Back",func() -> void: return_requested.emit())
	back.name = "DailyReturn"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(back)
	if client != null and day >= 0 and not version.is_empty() and not vehicle.is_empty():
		var board := PanelContainer.new()
		board.name = "DailyResultsStandings"
		board.add_theme_stylebox_override("panel",_card_style(Color("0d202c"),Color("344e5d"),14))
		column.add_child(board)
		var board_row := HBoxContainer.new()
		board_row.add_theme_constant_override("separation",12)
		board.add_child(board_row)
		var board_copy := VBoxContainer.new()
		board_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		board_row.add_child(board_copy)
		board_copy.add_child(MenuStyle.label("Standings",20))
		var caption: Label = MenuStyle.label("One best flying lap per driver and car.",16,true)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		board_copy.add_child(caption)
		var view: Button = MenuStyle.button("View all",_open_standings)
		view.name = "DailyResultsStandingsButton"
		board_row.add_child(view)

	var laps_panel := PanelContainer.new()
	laps_panel.add_theme_stylebox_override("panel",_card_style(Color("0b1a26"),Color("344e5d"),14))
	column.add_child(laps_panel)
	var laps_column := VBoxContainer.new()
	laps_column.add_theme_constant_override("separation",10)
	laps_panel.add_child(laps_column)
	var lap_heading := HBoxContainer.new()
	laps_column.add_child(lap_heading)
	var lap_title: Label = MenuStyle.label("Flying lap",20)
	lap_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lap_heading.add_child(lap_title)
	lap_heading.add_child(MenuStyle.label("Lap time",16,true))
	_lap_grid = GridContainer.new()
	_lap_grid.name = "DailyLapGrid"
	_lap_grid.add_theme_constant_override("h_separation",8)
	_lap_grid.add_theme_constant_override("v_separation",8)
	laps_column.add_child(_lap_grid)
	for index: int in range(1,session.lap_times.size()):
		var failed: bool = rules.eliminated and index == session.lap_times.size()-1
		var lap_card := PanelContainer.new()
		lap_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lap_card.add_theme_stylebox_override("panel",_card_style(Color("352b2c") if failed else Color("142d38"),Color("a55e55") if failed else Color("365460"),8))
		_lap_grid.add_child(lap_card)
		var lap_row := HBoxContainer.new()
		lap_card.add_child(lap_row)
		var number: Label = MenuStyle.user_label("%02d" % index,18,true)
		number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lap_row.add_child(number)
		var time: Label = MenuStyle.user_label(rules.time_text(session.lap_times[index]),20)
		time.add_theme_color_override("font_color",Color("ff9e8e") if failed else MenuStyle.TEXT)
		lap_row.add_child(time)
	resized.connect(_resize_grid)
	_resize_grid.call_deferred()

func _resize_grid() -> void:
	if is_instance_valid(_lap_grid):
		_lap_grid.columns = clampi(int((size.x-64)/165),1,5)

func _open_standings() -> void:
	var existing: Node = get_node_or_null("DailyStandings")
	if existing != null: return
	var dialog := preload("res://ui/daily_standings.gd").new()
	dialog.flying_laps = true
	dialog.client = client
	dialog.cloud = cloud
	dialog.day = day
	dialog.version = version
	dialog.vehicle = vehicle
	dialog.track_name = track_name
	dialog.ends_at = (day + 1) * 86400
	# The board replaces this with server time on a successful response.
	dialog.server_now = day * 86400
	add_child(dialog)
	dialog.popup_centered()

func _card_style(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.box(background,padding)
	style.set_corner_radius_all(9)
	style.border_color = border
	style.set_border_width_all(1)
	return style

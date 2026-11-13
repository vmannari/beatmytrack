extends Control
## The completed attempt owns times and medals; standings are read-only.
signal retry_requested
signal return_requested
const Progress = preload("res://persistence/daily_progress.gd")
const Medal = preload("res://ui/daily_medal.gd")
var rules: RefCounted
var session: TrackSession
var result_saved: bool = true
var client: Node
var cloud: Node
var day: int = -1
var version: String = ""
var vehicle: String = ""
var track_name: String = ""
var theme_id: String = "pine"
var _lap_grid: GridContainer
var _body: BoxContainer
var _left: VBoxContainer
var _title: Label
var _time: Label
var _medal: Control
var _brand: Control
var _margin: MarginContainer
var _retry: Button
var _back: Button
var _best_index: int = -1

func _ready() -> void:
	MenuStyle.fill(self)
	theme = MenuStyle.theme()
	var scenery := TextureRect.new()
	scenery.texture = TrackTile.scenery_texture(theme_id)
	scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuStyle.fill(scenery)
	add_child(scenery)
	var shade := ColorRect.new()
	shade.color = Color("060f18b8")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuStyle.fill(shade)
	add_child(shade)
	_margin = MarginContainer.new()
	MenuStyle.fill(_margin)
	add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	_margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",20)
	column.add_child(header)
	_brand = MenuBrand.new()
	header.add_child(_brand)
	header.add_child(VSeparator.new())
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation",2)
	header.add_child(identity)
	var eyebrow: Label = MenuStyle.label("Track of the Day",18)
	eyebrow.uppercase = true
	eyebrow.add_theme_color_override("font_color",MenuStyle.ACCENT)
	identity.add_child(eyebrow)
	var car_index: int = VehicleCatalog.IDS.find(vehicle)
	var car: String = VehicleCatalog.NAMES[car_index] if car_index >= 0 else ""
	var track: Label = MenuStyle.user_label(track_name+(" · "+tr(car) if not car.is_empty() else ""),18,true)
	track.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	track.tooltip_text = track_name
	identity.add_child(track)
	var scroll := ScrollContainer.new()
	scroll.name = "DailyResultsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = BoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",16)
	scroll.add_child(_body)
	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.size_flags_stretch_ratio = 1.8
	_left.add_theme_constant_override("separation",12)
	_body.add_child(_left)
	for index: int in range(1,session.lap_times.size()):
		if _best_index < 0 or session.lap_times[index] < session.lap_times[_best_index]: _best_index = index
	_build_summary()
	_build_laps()
	var board := preload("res://ui/daily_results_standings.gd").new()
	board.name = "DailyResultsStandings"
	board.client = client
	board.cloud = cloud
	board.day = day
	board.version = version
	board.vehicle = vehicle
	board.best_seconds = session.lap_times[_best_index] if _best_index >= 0 else 0.0
	board.standings_requested.connect(_open_standings)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(board)
	if not result_saved:
		var warning: Label = MenuStyle.label("Daily result could not be saved.",16,true)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(warning)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	column.add_child(actions)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(space)
	_back = MenuStyle.button("Back",func() -> void: return_requested.emit())
	_back.name = "DailyReturn"
	_back.add_theme_stylebox_override("normal",_card_style(Color("0b1b27f5"),MenuStyle.BORDER,12))
	actions.add_child(_back)
	_retry = MenuStyle.button("Race again",func() -> void: retry_requested.emit(),true)
	_retry.name = "DailyRetryRace"
	_retry.icon = MenuIcon.texture("arrow")
	_retry.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_retry.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	actions.add_child(_retry)
	resized.connect(_arrange)
	_lap_grid.resized.connect(_resize_grid)
	_arrange.call_deferred()

func _build_summary() -> void:
	var panel := PanelContainer.new()
	panel.name = "DailyResultSummary"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",_card_style(Color("0b1d2aee"),Color("4b6c7e"),20))
	_left.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var headline := VBoxContainer.new()
	headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headline.add_theme_constant_override("separation",2)
	row.add_child(headline)
	_title = MenuStyle.label("Eliminated" if rules.eliminated else "Challenge complete",40)
	_title.name = "DailyResultTitle"
	_title.uppercase = true
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_child(_title)
	headline.add_child(MenuStyle.user_label(tr("Stages passed: %d / 9") % rules.passed,18,true))
	var space := Control.new()
	space.custom_minimum_size.y = 8
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	headline.add_child(space)
	headline.add_child(MenuStyle.label("Best flying lap",15,true))
	_time = MenuStyle.user_label(rules.time_text(session.lap_times[_best_index]) if _best_index >= 0 else "—",60)
	_time.name = "DailyResultBestLap"
	headline.add_child(_time)
	var award: int = Progress.tier(rules.passed)
	if award > 0:
		var medal_column := VBoxContainer.new()
		medal_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		medal_column.add_theme_constant_override("separation",0)
		row.add_child(medal_column)
		_medal = Medal.new()
		_medal.name = "DailyResultMedal"
		_medal.tier = award
		_medal.selected = true
		medal_column.add_child(_medal)
		var earned: Label = MenuStyle.label(Progress.TITLES[award],28)
		earned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		earned.add_theme_color_override("font_color",Medal.COLORS[award])
		medal_column.add_child(earned)
	var progress := HBoxContainer.new()
	progress.name = "DailyStageRail"
	progress.add_theme_constant_override("separation",4)
	column.add_child(progress)
	for index: int in range(9):
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 24
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation",3)
		progress.add_child(cell)
		var level: int = [1,0,0,2,0,3,0,0,4][index]
		var milestone := Medal.new()
		milestone.custom_minimum_size = Vector2(24,26)
		milestone.tier = level
		milestone.earned = rules.passed > index
		milestone.visible = level > 0
		var slot := CenterContainer.new()
		slot.custom_minimum_size.y = 26
		slot.add_child(milestone)
		cell.add_child(slot)
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(4,7)
		segment.color = MenuStyle.ACCENT if index < rules.passed else Color("344e5d")
		cell.add_child(segment)
		var number: Label = MenuStyle.user_label("%02d" % (index+1),12,true)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(number)

func _build_laps() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_card_style(Color("0b1b27f2"),MenuStyle.BORDER,14))
	_left.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	var heading: Label = MenuStyle.label("Flying laps",24)
	heading.uppercase = true
	column.add_child(heading)
	_lap_grid = GridContainer.new()
	_lap_grid.name = "DailyLapGrid"
	_lap_grid.add_theme_constant_override("h_separation",8)
	_lap_grid.add_theme_constant_override("v_separation",6)
	column.add_child(_lap_grid)
	for index: int in range(1,session.lap_times.size()):
		var failed: bool = rules.eliminated and index == session.lap_times.size()-1
		var best: bool = index == _best_index
		var card := PanelContainer.new()
		card.name = "DailyLap%d" % index
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 40
		card.add_theme_stylebox_override("panel",_card_style(MenuStyle.ACCENT if best else Color("352b2c") if failed else Color("102632"),MenuStyle.ACCENT if best else Color("a55e55") if failed else Color("2c4a59"),7))
		_lap_grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		card.add_child(row)
		var number: Label = MenuStyle.user_label("%02d" % index,16,true)
		if best: number.add_theme_color_override("font_color",MenuStyle.INK)
		row.add_child(number)
		var time: Label = MenuStyle.user_label(rules.time_text(session.lap_times[index]),20)
		time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time.add_theme_color_override("font_color",MenuStyle.INK if best else Color("ff9e8e") if failed else MenuStyle.TEXT)
		if best: time.add_theme_font_override("font",MenuStyle.DISPLAY)
		row.add_child(time)
		if best and not failed:
			var trophy := TextureRect.new()
			trophy.texture = MenuIcon.texture("trophy")
			trophy.modulate = MenuStyle.INK
			trophy.custom_minimum_size = Vector2(18,18)
			trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(trophy)
		else:
			var status: Label = MenuStyle.user_label("×" if failed else "✓",18)
			status.add_theme_color_override("font_color",Color("a12d22") if best and failed else Color("ff9e8e") if failed else MenuStyle.POSITIVE)
			row.add_child(status)
		card.tooltip_text = tr("Best flying lap") if best else ""
	if _best_index < 0: column.add_child(MenuStyle.label("No flying laps yet.",18,true))

func _arrange() -> void:
	if not is_instance_valid(_body): return
	var narrow: bool = size.x < 780
	var compact: bool = size.x < 1100 or size.y < 600
	_body.vertical = narrow
	for side: String in ["left","right","top","bottom"]: _margin.add_theme_constant_override("margin_"+side,16 if compact else 28)
	_brand.custom_minimum_size = Vector2(104,42) if narrow else Vector2(160,52)
	_title.add_theme_font_size_override("font_size",28 if compact else 40)
	_time.add_theme_font_size_override("font_size",44 if compact else 60)
	if is_instance_valid(_medal): _medal.custom_minimum_size = Vector2(88,88) if compact else Vector2(144,144)
	_retry.custom_minimum_size.x = 140 if narrow else 240
	_back.custom_minimum_size.x = 90 if narrow else 140
	_back.text = tr("Back")
	GameText.user_text(_back)
	_back.tooltip_text = tr("Back to daily track")
	for button: Button in [_retry,_back]: button.add_theme_font_size_override("font_size",18 if narrow else 23)
	_resize_grid.call_deferred()

func _resize_grid() -> void:
	if not is_instance_valid(_lap_grid): return
	# Use the available viewport width rather than the grid's old minimum.
	# Otherwise three columns can prevent the grid from shrinking on rotation.
	var inset: float = 32.0 if size.x < 1100 or size.y < 600 else 56.0
	var available: float = size.x-inset
	if size.x >= 780: available = (available-16.0)*1.8/2.8
	_lap_grid.columns = clampi(int((available-28.0+8.0)/164.0),1,3)

func _open_standings() -> void:
	if client == null or day < 0 or version.is_empty() or vehicle.is_empty(): return
	if get_node_or_null("DailyStandings") != null: return
	var dialog := preload("res://ui/daily_standings.gd").new()
	dialog.flying_laps = true
	dialog.client = client
	dialog.cloud = cloud
	dialog.local_vehicle = vehicle
	dialog.local_best_seconds = session.lap_times[_best_index] if _best_index >= 0 else 0.0
	dialog.day = day
	dialog.version = version
	dialog.vehicle = vehicle
	dialog.track_name = track_name
	dialog.ends_at = (day+1)*86400
	dialog.server_now = day*86400
	add_child(dialog)
	dialog.popup_centered()

func _card_style(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.box(background,padding)
	style.set_corner_radius_all(6)
	style.border_color = border
	style.set_border_width_all(1)
	return style

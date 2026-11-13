extends "res://ui/fault_dialog.gd"
## Championship sheet; only the explicit Continue action can roll over a week.
signal continue_requested
const Banner = preload("res://ui/rivalry_summary_banner.gd")
const ProfileCar = preload("res://ui/profile_car.gd")
const DESIGN := Vector2(880,540)
var summary: Dictionary = {}
var week: int = 0
var circuit: bool = false
var player_name: String = ""
var vehicle_id: String = "compact"
var livery: Dictionary = {}
var customisation: Dictionary = {}
var condition: Dictionary = {}
var context_current: Callable
var continue_available: Callable
var receipt_key: String = ""
var payload: String = ""
var canvas: Control
var hero: Control
var ornament: Control
var perfect: Label
var position_label: Label
var rank_label: Label
var field_label: Label
var no_results_label: Label
var driver_label: Label
var player_points: Label
var opponent_points: Label
var lead_label: Label
var vehicle: Control
var metrics: Control
var metric_labels: Array[Label] = []
var continue_button: Button
var display_face: Font

func _ready() -> void:
	name = "RivalrySummaryDialog"
	title = "Weekly Rivalry results"
	borderless = true
	transparent_bg = true
	transparent = true
	unresizable = true
	exclusive = true
	wrap_controls = false
	min_size = Vector2i(480,300)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	get_label().hide()
	get_ok_button().hide()
	summary = summary.duplicate(true)
	display_face = MenuStyle.DISPLAY.duplicate()
	display_face.fallbacks = []
	surface = PanelContainer.new()
	surface.name = "WeeklySummarySurface"
	surface.theme = MenuStyle.theme()
	var frame: StyleBoxFlat = MenuStyle.popup_panel(0)
	frame.bg_color = Color("06141c")
	frame.border_color = MenuStyle.ACCENT
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(12)
	surface.add_theme_stylebox_override("panel",frame)
	add_child(surface)
	MenuStyle.fill(surface)
	canvas = Control.new()
	canvas.name = "WeeklySummaryCanvas"
	surface.add_child(canvas)
	_build_header()
	_build_hero()
	_build_comparison()
	_build_metrics()
	_build_actions()
	canvas.resized.connect(_layout)
	about_to_popup.connect(_opening)
	visibility_changed.connect(_visibility_changed)
	get_parent().get_viewport().size_changed.connect(_fit_to_view)
	_layout()

func _build_header() -> void:
	_summary_label(canvas,"COMPACT CIRCUIT" if circuit else "WEEKLY RIVALRY",20,MenuStyle.MUTED,Rect2(28,23,610,28))
	var date: Label = _summary_label(canvas,GameText.message("WEEK %02d") % week,18,MenuStyle.ACCENT,Rect2(665,24,130,28))
	date.name = "WeeklySummaryWeek"
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_button = MenuStyle.button("",_cancel)
	close_button.name = "WeeklySummaryClose"
	close_button.icon = MenuIcon.texture("close",true)
	close_button.expand_icon = true
	close_button.add_theme_constant_override("icon_max_width",24)
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.tooltip_text = "Close"
	close_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	canvas.add_child(close_button)
	_place(close_button,Rect2(812,12,52,52))
	_line(canvas,Rect2(1,64,878,1),MenuStyle.BORDER)

func _build_hero() -> void:
	hero = Control.new()
	hero.name = "WeeklySummaryCelebration"
	hero.clip_contents = true
	canvas.add_child(hero)
	_place(hero,Rect2(0,65,880,195))
	ornament = Banner.new()
	ornament.name = "WeeklySummaryDecorations"
	ornament.tier = int(summary.tier)
	ornament.empty_week = summary.rank == null and int(summary.completed) == 0
	hero.add_child(ornament)
	MenuStyle.fill(ornament)
	position_label = _summary_label(hero,"FINAL POSITION",20,MenuStyle.MUTED,Rect2(566,14,250,28))
	position_label.name = "WeeklySummaryPlace"
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var titles: Dictionary = {"WEEKLY CHAMPION":"Weekly Champion","PODIUM FINISH":"PODIUM\nFINISH","WEEK COMPLETE":"Week complete"}
	var title_source: String = titles.get(str(summary.title),str(summary.title))
	heading = _summary_label(hero,GameText.message(title_source).replace("\n"," ").to_upper(),60,MenuStyle.ACCENT if int(summary.tier) > 0 else MenuStyle.TEXT,Rect2(103,28,420,90))
	heading.name = "WeeklySummaryAward"
	var bold := FontVariation.new()
	bold.base_font = _font_for(heading.text)
	bold.variation_embolden = 0.3
	bold.variation_transform = Transform2D(Vector2(0.92,0),Vector2(0,1),Vector2.ZERO)
	bold.spacing_glyph = -2
	bold.spacing_top = -10
	bold.spacing_bottom = -10
	heading.add_theme_font_override("font",bold)
	driver_label = _summary_label(hero,player_name.to_upper(),36,MenuStyle.TEXT,Rect2(103,128,420,57))
	driver_label.name = "WeeklySummaryDriver"
	GameText.user_text(driver_label)
	perfect = _summary_label(hero,"PERFECT WEEK",18,MenuStyle.ACCENT,Rect2(329,151,192,25))
	perfect.name = "WeeklySummaryPerfect"
	perfect.visible = bool(summary.perfect)
	if perfect.visible: driver_label.size.x = 215
	var rank_text: String = "—" if summary.rank == null else str(int(summary.rank))
	rank_label = _summary_label(hero,rank_text,120,MenuStyle.ACCENT if summary.rank != null else MenuStyle.MUTED,Rect2(566,38,250,113))
	rank_label.name = "WeeklySummaryRank"
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.visible = not ornament.empty_week
	var italic := FontVariation.new()
	italic.base_font = display_face
	italic.variation_embolden = 0.3
	italic.variation_transform = Transform2D.IDENTITY
	italic.spacing_glyph = -2
	italic.spacing_top = -15
	italic.spacing_bottom = -15
	rank_label.add_theme_font_override("font",italic)
	field_label = _summary_label(hero,GameText.message("OF %d DRIVERS") % int(summary.drivers),20,MenuStyle.MUTED,Rect2(566,154,250,29))
	field_label.name = "WeeklySummaryField"
	field_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	field_label.visible = summary.rank != null
	position_label.visible = summary.rank != null
	no_results_label = _summary_label(hero,GameText.message("No races completed").to_upper(),30,MenuStyle.MUTED,Rect2(566,55,250,84))
	no_results_label.name = "WeeklySummaryNoResults"
	no_results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	no_results_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	no_results_label.visible = ornament.empty_week
	_line(canvas,Rect2(1,260,878,1),MenuStyle.BORDER)

func _build_comparison() -> void:
	_card(canvas,Rect2(34,277,286,76))
	_card(canvas,Rect2(560,277,286,76))
	vehicle = ProfileCar.make_preview(vehicle_id,livery,customisation)
	vehicle.name = "WeeklySummaryVehicle"
	vehicle.condition = condition.duplicate(true)
	canvas.add_child(vehicle)
	_place(vehicle,Rect2(47,287,87,56))
	ProfileCar.apply_presentation(vehicle)
	_summary_label(canvas,"YOUR POINTS",21,MenuStyle.MUTED,Rect2(145,282,163,28))
	player_points = _summary_label(canvas,_points(int(summary.points)),39,MenuStyle.ACCENT,Rect2(145,305,163,45))
	player_points.name = "WeeklySummaryPlayerPoints"
	var opponent: Label = _summary_label(canvas,"CO-LEADER" if bool(summary.champion) and int(summary.get("lead",0)) == 0 else "RUNNER-UP" if bool(summary.champion) else "TOP SCORE",21,MenuStyle.MUTED,Rect2(572,282,262,28))
	opponent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_points = _summary_label(canvas,"—" if summary.get("opponent_points") == null else _points(int(summary.opponent_points)),35,MenuStyle.MUTED,Rect2(572,305,262,43))
	opponent_points.name = "WeeklySummaryOpponentPoints"
	opponent_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lead: String = "" if summary.rank == null or summary.get("opponent_points") == null else "TIED FOR LEAD" if int(summary.get("lead",0)) == 0 else GameText.message("+%d POINT LEAD") % int(summary.lead) if bool(summary.champion) else GameText.message("%d PTS BEHIND") % absi(int(summary.get("lead",0)))
	lead_label = _summary_label(canvas,lead,22,MenuStyle.MUTED,Rect2(330,299,220,30))
	lead_label.name = "WeeklySummaryLead"
	lead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_metrics() -> void:
	metrics = Control.new()
	metrics.name = "WeeklySummaryMetrics"
	canvas.add_child(metrics)
	_place(metrics,Rect2(34,370,812,76))
	var facts: Array = [["TRACKS COMPLETED","%d / %d" % [int(summary.completed),summary.results.size()],"flag"],["TRACK VICTORIES",str(int(summary.wins)),"trophy"],["PERSONAL BESTS",str(int(summary.get("personal_bests",0))),"clock"]]
	for index: int in range(3):
		var card: Control = _card(metrics,Rect2(index*275,0,262,76))
		var number: Label = _summary_label(card,str(facts[index][1]),37,MenuStyle.ACCENT,Rect2(16,3,196,46))
		metric_labels.append(number)
		_summary_label(card,str(facts[index][0]),16,MenuStyle.MUTED,Rect2(16,49,226,23))
		var icon := TextureRect.new()
		icon.texture = MenuIcon.texture(str(facts[index][2]),true)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = MenuStyle.MUTED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		_place(icon,Rect2(210,22,32,32))

func _build_actions() -> void:
	confirm_button = MenuStyle.button("VIEW STANDINGS",_confirm)
	confirm_button.name = "WeeklySummaryViewResults"
	var outline: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,0)
	outline.border_color = MenuStyle.ACCENT
	outline.set_border_width_all(2)
	confirm_button.add_theme_stylebox_override("normal",outline)
	canvas.add_child(confirm_button)
	_place(confirm_button,Rect2(34,466,294,54))
	continue_button = MenuStyle.button("CONTINUE TO NEXT WEEK",_continue,true)
	continue_button.name = "WeeklySummaryContinue"
	continue_button.add_theme_color_override("font_focus_color",MenuStyle.INK)
	continue_button.add_theme_color_override("font_pressed_color",MenuStyle.INK)
	canvas.add_child(continue_button)
	_place(continue_button,Rect2(344,466,502,54))

func _summary_label(parent: Control, value: String, font_size: int, color: Color, rectangle: Rect2) -> Label:
	var label := MenuStyle.label(value,font_size)
	label.add_theme_font_override("font",_font_for(GameText.message(value)))
	label.add_theme_color_override("font_color",color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = value
	label.set_meta("summary_height",rectangle.size.y)
	parent.add_child(label)
	_place(label,rectangle)
	return label

func _font_for(value: String) -> Font:
	# Fallback fonts have taller line metrics. Keep the reference's Latin cap
	# height while retaining the shared script coverage for translated text/names.
	for index: int in range(value.length()):
		if not display_face.has_char(value.unicode_at(index)): return MenuStyle.DISPLAY
	return display_face

func _place(node: Control, rectangle: Rect2) -> void:
	node.position = rectangle.position
	node.size = rectangle.size

func _card(parent: Control, rectangle: Rect2) -> Control:
	var panel := Panel.new()
	var frame: StyleBoxFlat = MenuStyle.card(0)
	frame.bg_color = Color("091a24")
	frame.border_color = MenuStyle.BORDER
	panel.add_theme_stylebox_override("panel",frame)
	parent.add_child(panel)
	_place(panel,rectangle)
	return panel

func _line(parent: Control, rectangle: Rect2, color: Color) -> void:
	var line := ColorRect.new()
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	_place(line,rectangle)

func _points(value: int) -> String:
	return "%d %s" % [value,GameText.message("PTS")]

func present() -> void:
	popup_centered(_target_size())
	_layout.call_deferred()

func _target_size() -> Vector2i:
	var bounds: Vector2 = get_parent().get_viewport().get_visible_rect().size-Vector2(48,48)
	return Vector2i(DESIGN*minf(1,minf(bounds.x/DESIGN.x,bounds.y/DESIGN.y)))

func _fit_to_view() -> void:
	if not visible: return
	size = _target_size()
	position = Vector2i((get_parent().get_viewport().get_visible_rect().size-Vector2(size))*0.5)
	_layout.call_deferred()

func _fit_label(label: Label, preferred: int, minimum: int) -> void:
	var font: Font = label.get_theme_font("font")
	var words: String = label.text
	var font_size: int = preferred
	var height: float = float(label.get_meta("summary_height"))
	while font_size > minimum and (font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > label.size.x-4 or font.get_height(font_size) > height): font_size -= 1
	label.add_theme_font_size_override("font_size",font_size)
	label.size.y = maxf(float(label.get_meta("summary_height")),label.get_combined_minimum_size().y)

func _layout() -> void:
	if not is_instance_valid(canvas) or not is_instance_valid(heading): return
	var scale_factor: float = minf(canvas.size.x/DESIGN.x,canvas.size.y/DESIGN.y)
	for child: Control in canvas.get_children():
		if not child.has_meta("summary_position"): child.set_meta("summary_position",child.position)
		child.position = Vector2(child.get_meta("summary_position"))*scale_factor
		child.scale = Vector2.ONE*scale_factor
	_fit_label(heading,64,28)
	_fit_label(driver_label,36,24)
	_fit_label(rank_label,130,60)
	_fit_label(position_label,20,13)
	_fit_label(field_label,20,13)
	_fit_label(player_points,39,25)
	_fit_label(lead_label,21,15)
	for button: Button in [confirm_button,continue_button]:
		var font: Font = button.get_theme_font("font")
		var font_size: int = 23
		while font_size > 16 and font.get_string_size(GameText.message(button.text),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > button.size.x-24: font_size -= 1
		button.add_theme_font_size_override("font_size",font_size)

func _continue() -> void:
	if not visible or continue_button.disabled: return
	continue_button.disabled = true
	continue_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER] and gui_get_focus_owner() == continue_button:
		_continue()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _process(_delta: float) -> void:
	if visible and context_current.is_valid() and not context_current.call():
		hide()
		queue_free()
	elif visible and continue_available.is_valid(): continue_button.disabled = not continue_available.call()

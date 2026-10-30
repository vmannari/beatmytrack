extends "res://ui/fault_dialog.gd"
## Read-only weekly celebration. Closing this never acknowledges or rolls a week.
const AwardArt = preload("res://ui/rivalry_award_art.gd")
var summary: Dictionary = {}
var week: int = 0
var circuit: bool = false
var context_current: Callable
var receipt_key: String = ""
var payload: String = ""
var hero: Control
var ornament: Control
var perfect: Label
var metrics: HBoxContainer
var metric_labels: Array[Label] = []
var highlights: GridContainer

func _ready() -> void:
	name = "RivalrySummaryDialog"
	title = "Weekly Rivalry results"
	borderless = true
	transparent_bg = true
	transparent = true
	unresizable = true
	exclusive = true
	wrap_controls = false
	min_size = Vector2i(600,440)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	get_label().hide()
	get_ok_button().hide()
	summary = summary.duplicate(true)
	surface = PanelContainer.new()
	surface.name = "WeeklySummarySurface"
	surface.theme = MenuStyle.theme()
	var frame: StyleBoxFlat = MenuStyle.popup_panel(20)
	frame.border_color = Color("b59a45") if int(summary.tier) >= 2 else MenuStyle.POPUP_BORDER
	frame.border_width_top = 2
	surface.add_theme_stylebox_override("panel",frame)
	add_child(surface)
	MenuStyle.fill(surface)
	details = VBoxContainer.new()
	details.add_theme_constant_override("separation",10)
	surface.add_child(details)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",12)
	details.add_child(header)
	var event: Label = _summary_label(header,"COMPACT CIRCUIT" if circuit else "WEEKLY RIVALRY",20,MenuStyle.MUTED)
	event.add_theme_font_override("font",MenuStyle.DISPLAY)
	event.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var date: Label = _summary_label(header,GameText.message("WEEK %02d") % week,18,MenuStyle.ACCENT)
	date.name = "WeeklySummaryWeek"
	date.custom_minimum_size.x = date.get_theme_font("font").get_string_size(date.text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+2
	date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button = MenuStyle.button("",_cancel)
	close_button.name = "WeeklySummaryClose"
	close_button.icon = MenuIcon.texture("close")
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.tooltip_text = "Close"
	close_button.custom_minimum_size = Vector2(52,52)
	close_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	header.add_child(close_button)
	hero = Control.new()
	hero.name = "WeeklySummaryCelebration"
	hero.custom_minimum_size.y = 128
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(hero)
	ornament = AwardArt.new()
	ornament.name = "WeeklySummaryDecorations"
	ornament.tier = int(summary.tier)
	hero.add_child(ornament)
	heading = _summary_label(hero,GameText.message(str(summary.title)),42,Color("ffe49a") if int(summary.tier) > 0 else MenuStyle.TEXT)
	heading.name = "WeeklySummaryAward"
	heading.add_theme_font_override("font",MenuStyle.DISPLAY)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perfect = _summary_label(hero,"PERFECT WEEK",18,MenuStyle.ACCENT)
	perfect.name = "WeeklySummaryPerfect"
	perfect.add_theme_font_override("font",MenuStyle.DISPLAY)
	perfect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perfect.visible = bool(summary.perfect)
	metrics = HBoxContainer.new()
	metrics.name = "WeeklySummaryMetrics"
	metrics.add_theme_constant_override("separation",10)
	details.add_child(metrics)
	for fact: Array in [["FINAL POSITION","—" if summary.rank == null else "%d / %d" % [int(summary.rank),int(summary.drivers)]],["TOTAL POINTS",str(int(summary.points))],["TRACK VICTORIES","%d / 5" % int(summary.wins)]]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",MenuStyle.card(8))
		metrics.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation",2)
		panel.add_child(box)
		var number: Label = _summary_label(box,str(fact[1]),34,MenuStyle.ACCENT)
		number.add_theme_font_override("font",MenuStyle.DISPLAY)
		metric_labels.append(number)
		_summary_label(box,str(fact[0]),12,MenuStyle.MUTED)
	highlights = GridContainer.new()
	highlights.name = "WeeklySummaryHighlights"
	highlights.columns = 2
	highlights.add_theme_constant_override("h_separation",16)
	highlights.add_theme_constant_override("v_separation",4)
	details.add_child(highlights)
	for fact: String in summary.highlights:
		var item: Label = _summary_label(highlights,("✓  " if int(summary.completed) > 0 else "")+fact,15,MenuStyle.POSITIVE if int(summary.completed) > 0 else MenuStyle.MUTED)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button = MenuStyle.button("Back to results",_confirm,true)
	confirm_button.name = "WeeklySummaryViewResults"
	confirm_button.custom_minimum_size.y = 54
	confirm_button.add_theme_color_override("font_focus_color",MenuStyle.INK)
	confirm_button.add_theme_color_override("font_pressed_color",MenuStyle.INK)
	details.add_child(confirm_button)
	hero.resized.connect(_layout)
	about_to_popup.connect(_opening)
	visibility_changed.connect(_visibility_changed)
	get_parent().get_viewport().size_changed.connect(_fit_to_view)
	_layout()

func _summary_label(parent: Control, value: String, font_size: int, color: Color) -> Label:
	var label := MenuStyle.label(value,font_size)
	label.add_theme_color_override("font_color",color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = value
	parent.add_child(label)
	return label

func present() -> void:
	popup_centered(_target_size())
	_layout.call_deferred()

func _target_size() -> Vector2i:
	var bounds: Vector2 = get_parent().get_viewport().get_visible_rect().size
	return Vector2i(minf(880,bounds.x-48),minf(maxf(520,surface.get_combined_minimum_size().y),bounds.y-48))

func _fit_to_view() -> void:
	if not visible: return
	size = _target_size()
	position = Vector2i((get_parent().get_viewport().get_visible_rect().size-Vector2(size))*0.5)
	_layout.call_deferred()

func _layout() -> void:
	if not is_instance_valid(hero) or not is_instance_valid(heading): return
	var font: Font = heading.get_theme_font("font")
	var font_size: int = 42
	var crown_space: float = 38 if int(summary.tier) >= 2 else 0
	var perfect_height: float = perfect.get_combined_minimum_size().y if perfect.visible else 0
	var title_height: float = 0
	while true:
		heading.add_theme_font_size_override("font_size",font_size)
		title_height = heading.get_combined_minimum_size().y
		var total: float = crown_space+title_height+(perfect_height+6 if perfect.visible else 0)
		if font_size <= 24 or (font.get_string_size(heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= hero.size.x-128 and total <= hero.size.y): break
		font_size -= 1
	var group_height: float = crown_space+title_height+(perfect_height+6 if perfect.visible else 0)
	var title_top: float = maxf(0,(hero.size.y-group_height)*0.5)+crown_space
	heading.position = Vector2(64,title_top)
	heading.size = Vector2(maxf(0,hero.size.x-128),title_height)
	var words_width: float = font.get_string_size(heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	ornament.position = Vector2((hero.size.x-words_width-112)*0.5,title_top)
	ornament.size = Vector2(words_width+112,title_height)
	ornament.crown_center_y = -26
	ornament.queue_redraw()
	perfect.position = Vector2(0,title_top+title_height+6)
	perfect.size = Vector2(hero.size.x,perfect_height)

func _process(_delta: float) -> void:
	if visible and context_current.is_valid() and not context_current.call():
		hide()
		queue_free()

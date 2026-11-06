extends VBoxContainer
## A compact collection. Details use one on-demand sheet and no backend reads.
signal trophy_room_requested
var service: Node
var selected: String = "races"
var grid: GridContainer
var detail: VBoxContainer
var summary: Label
var scroll: ScrollContainer
var _sheet_layer: CanvasLayer
var _sheet_panel: PanelContainer
var _sheet_footer: VBoxContainer
var _sheet_eyebrow: Label
var _sheet_return_focus: WeakRef
var _sheet_content_scroll: ScrollContainer
var _sheet_content_padding: MarginContainer
var _sheet_kind: String = ""
const TIER_NAMES: Array[String] = ["Locked","Bronze","Silver","Gold","Platinum"]
const SHEET_SCROLLBAR_GUTTER: int = 12

func _ready() -> void:
	name = "AchievementsMenu"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	var toolbar := HBoxContainer.new()
	toolbar.name = "AchievementToolbar"
	toolbar.add_theme_constant_override("separation",6)
	add_child(toolbar)
	var title: Label = MenuStyle.label("ACHIEVEMENTS",26)
	title.name = "AchievementTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	summary = MenuStyle.label("0 / 130",20)
	summary.name = "AchievementSummary"
	summary.tooltip_text = "Unlocked tiers and prestige honors"
	toolbar.add_child(summary)
	var close: Button = _icon_button("close","Back to Trophy Room",func() -> void:
		_close_sheet()
		trophy_room_requested.emit())
	close.name = "AchievementClose"
	toolbar.add_child(close)
	scroll = preload("res://ui/vertical_swipe_scroll.gd").new()
	scroll.name = "AchievementScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	grid = GridContainer.new()
	grid.name = "AchievementGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(grid)
	service.changed.connect(_rebuild)
	resized.connect(func() -> void:
		_columns()
		_layout_sheet())
	_rebuild()
	if is_visible_in_tree(): service.refresh()

func _icon_button(icon: String, caption: String, action: Callable) -> Button:
	var button: Button = MenuStyle.button("",action)
	button.icon = MenuIcon.texture(icon)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width",28)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(52,52)
	button.tooltip_text = caption
	return button

func _columns() -> void:
	if is_instance_valid(grid): grid.columns = clampi(floori((size.x+8.0)/312.0),1,4)

func _rebuild() -> void:
	if not is_instance_valid(grid): return
	var position: int = scroll.scroll_vertical
	for node: Node in grid.get_children():
		grid.remove_child(node)
		node.queue_free()
	var earned: int = 0
	var visible_families: Array[Dictionary] = []
	for family: Dictionary in AchievementProgress.catalog().families:
		var source: Dictionary = service.source(family)
		var level: int = AchievementProgress.tier(family,source)
		earned += level
		visible_families.append(family)
	var visible_ids: Array[String] = []
	for family: Dictionary in visible_families: visible_ids.append(family.id)
	if selected not in visible_ids: selected = visible_ids[0] if not visible_ids.is_empty() else ""
	for family: Dictionary in visible_families:
		var source: Dictionary = service.source(family)
		_card(family,source,AchievementProgress.tier(family,source))
	if visible_families.is_empty(): grid.add_child(MenuStyle.label("No achievements in this view yet",20,true))
	summary.text = "%d / 130" % earned
	summary.tooltip_text = "Unlocked tiers and prestige honors" if service.status.is_empty() else service.status
	if _sheet_kind == "achievement": _detail()
	_columns()
	scroll.set_deferred("scroll_vertical",position)

func _card(f: Dictionary, source: Dictionary, level: int) -> void:
	var button := Button.new()
	button.name = "Achievement_"+f.id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(300,100)
	button.tooltip_text = f.title
	var normal: StyleBoxFlat = MenuStyle.box(Color("111f2a"),10)
	normal.set_border_width_all(1)
	normal.border_color = Color("283944") if level == 0 else AchievementBadge.METALS[3 if f.prestige else level].darkened(0.62)
	button.add_theme_stylebox_override("normal",normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("20343f")
	hover.border_color = AchievementBadge.METALS[3 if f.prestige else maxi(level,1)].darkened(0.2)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	button.pressed.connect(_show_achievement.bind(str(f.id)))
	grid.add_child(button)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",10)
	button.add_child(row)
	MenuStyle.fill(row)
	row.offset_left = 10
	row.offset_top = 8
	row.offset_right = -10
	row.offset_bottom = -8
	row.minimum_size_changed.connect(func() -> void:
		if is_instance_valid(button): button.custom_minimum_size.y = maxf(100,row.get_combined_minimum_size().y+16))
	var badge := AchievementBadge.new()
	badge.tier = 3 if f.prestige and level > 0 else level
	badge.prestige = f.prestige
	badge.motif = AchievementProgress.catalog().families.find(f)
	badge.family_id = f.id
	row.add_child(badge)
	badge.custom_minimum_size = Vector2(68,80)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)
	var title: Label = MenuStyle.label(f.title,22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.y = 28
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	var next: int = mini(level,f.tiers.size()-1)
	var target: int = int(f.tiers[next])
	var value: int = mini(int(source.get("metrics",{}).get(f.metric,0)),target)
	var progress := ProgressBar.new()
	progress.name = "AchievementProgress_"+f.id
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.custom_minimum_size.y = 4
	progress.add_theme_stylebox_override("background",MenuStyle.box(Color("21333d"),0))
	progress.add_theme_stylebox_override("fill",MenuStyle.box(AchievementBadge.METALS[3 if f.prestige else maxi(level,1)],0))
	progress.max_value = target
	progress.value = target if level == f.tiers.size() else value
	progress.show_percentage = false
	copy.add_child(progress)
	var progress_text: String = GameText.message("%.1f / %d km") % [value/1000.0,target/1000] if f.metric == "distance_m" else "%d / %d" % [value,target]
	var caption: String = tr("Prestige earned") if f.prestige else tr(["","Bronze complete","Silver complete","Gold complete","Platinum complete"][level])
	if level < f.tiers.size(): caption = GameText.message("{progress}  /  {next}",{"progress":progress_text,"next":tr("Prestige next" if f.prestige else ["Bronze next","Silver next","Gold next","Platinum next"][next])})
	var progress_label: Label = MenuStyle.label(caption,16,true)
	GameText.user_text(progress_label)
	progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(progress_label)

func _show_achievement(id: String) -> void:
	selected = id
	for f: Dictionary in AchievementProgress.catalog().families:
		if f.id != selected: continue
		_open_sheet(str(f.title),"achievement")
		_detail()
		return

func _open_sheet(title: String, kind: String) -> void:
	_close_sheet()
	var focused: Control = get_viewport().gui_get_focus_owner()
	_sheet_return_focus = weakref(focused) if is_instance_valid(focused) else null
	_sheet_kind = kind
	_sheet_layer = CanvasLayer.new()
	_sheet_layer.name = "AchievementSheet"
	_sheet_layer.layer = 100
	add_child(_sheet_layer)
	# The existing menu swipe owner recognizes layers above 20 as modal.
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.name = "AchievementScrim"
	shade.color = Color(0.005,0.012,0.02,0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_layer.add_child(shade)
	MenuStyle.fill(shade)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
			get_viewport().set_input_as_handled()
			_close_sheet())
	_sheet_panel = PanelContainer.new()
	_sheet_panel.name = "AchievementDetail"
	_sheet_panel.theme = MenuStyle.theme()
	_sheet_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style: StyleBoxFlat = MenuStyle.popup_panel(20)
	panel_style.bg_color = Color("101e29")
	panel_style.border_color = Color("405461")
	panel_style.border_width_top = 2
	panel_style.shadow_size = 24
	panel_style.shadow_color = Color(0,0,0,0.45)
	_sheet_panel.add_theme_stylebox_override("panel",panel_style)
	_sheet_panel.minimum_size_changed.connect(_layout_sheet.call_deferred)
	_sheet_layer.add_child(_sheet_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	_sheet_panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title_group := VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_group.alignment = BoxContainer.ALIGNMENT_CENTER
	title_group.add_theme_constant_override("separation",0)
	header.add_child(title_group)
	_sheet_eyebrow = MenuStyle.label("YOUR COLLECTION",13,true)
	title_group.add_child(_sheet_eyebrow)
	var heading: Label = MenuStyle.label(title,28)
	heading.name = "AchievementDetailTitle"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_group.add_child(heading)
	var close: Button = _icon_button("close","Close",_close_sheet)
	close.name = "AchievementDetailClose"
	close.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	close.add_theme_constant_override("icon_max_width",22)
	var close_focus: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,0)
	close_focus.set_border_width_all(1)
	close_focus.border_color = MenuStyle.MUTED
	close_focus.set_expand_margin_all(-5)
	close.add_theme_stylebox_override("focus",close_focus)
	header.add_child(close)
	# Inset the complete scroll lane from the header, footer and panel edge.
	var content_frame := MarginContainer.new()
	content_frame.name = "AchievementDetailViewport"
	content_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_frame.add_theme_constant_override("margin_top",6)
	content_frame.add_theme_constant_override("margin_bottom",6)
	content_frame.add_theme_constant_override("margin_right",6)
	body.add_child(content_frame)
	var content: ScrollContainer = preload("res://ui/vertical_swipe_scroll.gd").new()
	content.name = "AchievementDetailScroll"
	content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_frame.add_child(content)
	_sheet_content_scroll = content
	# A stable inner gutter keeps copy clear of the bar whenever it is needed.
	_sheet_content_padding = MarginContainer.new()
	_sheet_content_padding.name = "AchievementDetailContentPadding"
	_sheet_content_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_content_padding.add_theme_constant_override("margin_right",SHEET_SCROLLBAR_GUTTER)
	_sheet_content_padding.minimum_size_changed.connect(_layout_sheet.call_deferred)
	content.add_child(_sheet_content_padding)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation",10)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_content_padding.add_child(detail)
	_sheet_footer = VBoxContainer.new()
	_sheet_footer.add_theme_constant_override("separation",10)
	body.add_child(_sheet_footer)
	_layout_sheet()
	_focus_sheet_close.call_deferred(weakref(close))
	_sheet_panel.modulate.a = 0.0
	_sheet_panel.create_tween().tween_property(_sheet_panel,"modulate:a",1.0,0.16)

func _focus_sheet_close(reference: WeakRef) -> void:
	var close: Control = reference.get_ref()
	if is_instance_valid(close) and close.is_inside_tree() and close.is_visible_in_tree(): close.grab_focus()

func _layout_sheet() -> void:
	if not is_instance_valid(_sheet_panel): return
	var extent: Vector2 = get_viewport_rect().size
	_sheet_panel.size.x = minf(640,extent.x-32)
	# ScrollContainer deliberately omits child height from its minimum. Add the
	# actual wrapped content back so ordinary screens need no scrolling.
	var needed_height: float = _sheet_panel.get_combined_minimum_size().y
	if is_instance_valid(_sheet_content_padding) and is_instance_valid(_sheet_content_scroll):
		needed_height += _sheet_content_padding.get_combined_minimum_size().y-_sheet_content_scroll.get_combined_minimum_size().y
	_sheet_panel.size.y = minf(maxf(400,ceilf(needed_height)+2),extent.y-32)
	_sheet_panel.position = (extent-_sheet_panel.size)*0.5

func _close_sheet() -> void:
	var was_open: bool = not _sheet_kind.is_empty()
	if is_instance_valid(_sheet_layer):
		_sheet_layer.hide()
		_sheet_layer.queue_free()
	_sheet_layer = null
	_sheet_panel = null
	_sheet_content_scroll = null
	_sheet_content_padding = null
	_sheet_kind = ""
	detail = null
	if is_instance_valid(scroll): scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	if was_open and is_visible_in_tree():
		var target: Control = _sheet_return_focus.get_ref() if _sheet_return_focus != null else null
		if not is_instance_valid(target) or not target.is_inside_tree() or not target.is_visible_in_tree():
			target = grid.get_node_or_null("Achievement_"+selected) if is_instance_valid(grid) else null
		if is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree(): target.grab_focus()
	_sheet_return_focus = null

func _input(event: InputEvent) -> void:
	if _sheet_kind.is_empty(): return
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var close: Button = _sheet_panel.find_child("AchievementDetailClose",true,false)
		var pin: Button = _sheet_footer.find_child("AchievementFeature",true,false)
		if is_instance_valid(pin) and not pin.disabled and close.has_focus(): pin.grab_focus()
		else: close.grab_focus()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not _sheet_kind.is_empty() and event.is_action_pressed("ui_cancel"):
		_close_sheet()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree(): _close_sheet()
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(grid): _rebuild.call_deferred()

func _clear(container: Node) -> void:
	for node: Node in container.get_children():
		container.remove_child(node)
		node.queue_free()

func _detail() -> void:
	if not is_instance_valid(detail): return
	var previous_pin: Button = _sheet_footer.find_child("AchievementFeature",true,false)
	var restore_focus: bool = is_instance_valid(previous_pin) and previous_pin.has_focus()
	_clear(detail)
	_clear(_sheet_footer)
	for f: Dictionary in AchievementProgress.catalog().families:
		if f.id != selected: continue
		var source: Dictionary = service.source(f)
		var level: int = AchievementProgress.tier(f,source)
		GameText.bind(_sheet_eyebrow,"{category} / ACHIEVEMENT",{"category":tr(str(f.category)).to_upper()})
		var style: StyleBoxFlat = _sheet_panel.get_theme_stylebox("panel").duplicate()
		style.border_color = AchievementBadge.METALS[3 if f.prestige else maxi(level,1)].darkened(0.4)
		_sheet_panel.add_theme_stylebox_override("panel",style)
		preload("res://ui/achievement_detail.gd").build(detail,_sheet_footer,f,source,level,service)
		if restore_focus: _sheet_footer.find_child("AchievementFeature",true,false).grab_focus.call_deferred()



extends VBoxContainer
## Full ordered track board with a pinned copy only while the player is offscreen.
const VISIBLE_ROWS: int = 8
const GUTTER: int = 8
var board: Array[Dictionary] = []
var scroll: ScrollContainer
var rows: VBoxContainer
var viewport: Control
var player: Control
var sticky: Control
var more: Button

func _ready() -> void:
	name = "RivalryTrackStandings"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",4)
	viewport = Control.new()
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport.custom_minimum_size.y = 28*VISIBLE_ROWS+2*(VISIBLE_ROWS-1)
	add_child(viewport)
	scroll = WeeklyRivalryResult.PlayerList.new()
	scroll.name = "RivalryTrackStandingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	viewport.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right",GUTTER)
	scroll.add_child(margin)
	rows = VBoxContainer.new()
	rows.name = "RivalryTrackDriverRows"
	rows.add_theme_constant_override("separation",2)
	margin.add_child(rows)
	var own: Dictionary = WeeklyRivalry.self_row(board)
	for driver: Dictionary in board:
		var row: Control = _row(driver,own)
		rows.add_child(row)
		if driver.id == WeeklyRivalry.SELF: player = row
	if not own.is_empty():
		sticky = _row(own,own,true)
		sticky.name = "RivalryTrackStickyPlayer"
		sticky.visible = false
		_ignore_input(sticky)
		viewport.add_child(sticky)
	more = MenuStyle.button("",_next_page)
	more.name = "RivalryTrackMoreDrivers"
	more.custom_minimum_size.y = 48
	more.add_theme_font_size_override("font_size",15)
	more.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	more.visible = board.size() > VISIBLE_ROWS
	add_child(more)
	scroll.resized.connect(_resize_rows)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _update_sticky.call_deferred())
	_resize_rows.call_deferred()

func _ignore_input(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children(): _ignore_input(child)

func _label(parent: Control, text: String, width: int, color: Color, id: String, font_size: int = 16) -> Label:
	var label: Label = MenuStyle.label(text,font_size)
	label.name = id
	label.custom_minimum_size.x = width
	label.add_theme_color_override("font_color",color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(label)
	return label

func _row(driver: Dictionary, own: Dictionary, pinned: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.name = "RivalryTrackDriver_"+str(driver.id)
	var is_player: bool = driver.id == WeeklyRivalry.SELF
	var style: StyleBoxFlat = MenuStyle.box(Color("263329") if pinned else Color("ffd34820") if is_player else Color("0b1c2799"),0)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	if is_player:
		style.border_color = MenuStyle.ACCENT
		style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",6)
	panel.add_child(line)
	var color: Color = MenuStyle.ACCENT if is_player else MenuStyle.TEXT
	_label(line,"#%d" % int(driver.rank) if driver.get("rank") != null else "—",28,color,"Rank")
	line.add_child(PlayerCountry.flag(str(driver.get("country_code","")),22))
	var display_name: String = str(driver.name)
	if bool(driver.get("is_test_driver",false)):
		var marker: int = display_name.find(" T")
		if marker >= 0 and display_name.substr(marker+2).contains("-"): display_name = display_name.substr(0,marker)
	var identity: Label = _label(line,display_name,0,color,"Name")
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.clip_text = true
	identity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var time: Label = _label(line,MenuStyle.time_text(int(driver.ms)/1000.0) if driver.get("ms") != null else "—",80,color,"Time",20)
	time.add_theme_font_override("font",MenuStyle.DISPLAY)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var difference: String = "—"
	if not is_player and driver.get("ms") != null and own.get("ms") != null:
		difference = "%+.3f" % ((int(driver.ms)-int(own.ms))/1000.0)
	_label(line,difference,65,color if is_player else MenuStyle.MUTED,"Gap").horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return panel

func _resize_rows() -> void:
	if not is_instance_valid(rows): return
	var available: int = maxi(28*VISIBLE_ROWS,floori(scroll.size.y)-2*(VISIBLE_ROWS-1))
	var height: int = available/VISIBLE_ROWS
	var remainder: int = available%VISIBLE_ROWS
	for index: int in range(rows.get_child_count()):
		var row: Control = rows.get_child(index)
		row.custom_minimum_size.y = height+(1 if index%VISIBLE_ROWS < remainder else 0)
	_update_sticky.call_deferred()

func _update_sticky() -> void:
	if not is_inside_tree(): return
	if is_instance_valid(player) and is_instance_valid(sticky):
		var top: float = player.get_global_rect().position.y-scroll.get_global_rect().position.y
		sticky.visible = top < -0.5 or top+player.size.y > scroll.size.y+0.5
		sticky.position = Vector2(0,0 if top < 0 else maxf(0,scroll.size.y-player.size.y))
		sticky.size = Vector2(rows.size.x,player.size.y)
	var remaining: int = 0
	for row: Control in rows.get_children():
		if row.get_global_rect().end.y > scroll.get_global_rect().end.y+0.5: remaining += 1
	more.text = "↓  %d more drivers" % remaining if remaining > 0 else "↑  Back to top"

func _next_page() -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if scroll.scroll_vertical >= bar.max_value-bar.page-1: scroll.scroll_vertical = 0
	else: scroll.scroll_vertical += roundi(scroll.size.y-(player.size.y+2 if is_instance_valid(player) else 0))

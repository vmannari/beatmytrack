class_name WeeklyRivalryPage
extends VBoxContainer
## Championship hub with track details as the race entry point.
signal section_requested(section: String)
signal track_requested(index: int)
signal track_selected(index: int)
signal race_requested(index: int, ghost_choice: int)
signal free_race_requested
signal challenges_requested
signal join_requested
signal refresh_requested
signal continue_requested
signal retry_requested
var model: WeeklyRivalry
var section: String = "overview"
var selected: int = 0
var busy: bool = false
var error: String = ""
var signed_in: bool = false
var pending_result: bool = false
var race_details: Dictionary = {}
var ghost_choice: int = 0
var clock_label: Label
var track_rows: Array[Button] = []
var track_markers: Array[ColorRect] = []
var detail_route: LapRouteView
const WINTER_ART: Texture2D = preload("res://assets/menu/rivalry_winter_v1.png")
const COMPACT_ART: Texture2D = preload("res://assets/menu/rivalry_compact_cutout_v1.png")
const STANDINGS_GUTTER: int = 12
const QUIET_BORDER := Color("2e495a88")
const Badge = preload("res://ui/biome_badge.gd")

func _ready() -> void:
	name = "WeeklyRivalryPage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var rail := RaceModeRail.new()
	rail.selected = "rivalry"
	rail.mode_requested.connect(func(mode: String) -> void:
		if mode == "free": free_race_requested.emit()
		elif mode == "rivalry": section_requested.emit("overview")
		elif mode == "challenges": challenges_requested.emit())
	if section != "result": row.add_child(rail)
	else: rail.free()
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(main)
	main.add_theme_constant_override("separation",12)
	var header := HBoxContainer.new()
	header.name = "RivalrySectionNavigation"
	header.add_theme_constant_override("separation",24)
	main.add_child(header)
	if section == "result":
		var trophy := PanelContainer.new()
		trophy.add_theme_stylebox_override("panel",MenuStyle.box(MenuStyle.ACCENT,12))
		trophy.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		header.add_child(trophy)
		var glyph := TextureRect.new()
		glyph.texture = MenuIcon.texture("trophy")
		glyph.modulate = MenuStyle.INK
		glyph.custom_minimum_size = Vector2(34,34)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trophy.add_child(glyph)
	var identity := VBoxContainer.new()
	identity.name = "RivalryIdentity"
	identity.add_theme_constant_override("separation",4)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	var heading := MenuStyle.label("WEEKLY RIVALRY",38)
	heading.add_theme_color_override("font_shadow_color",Color("061320"))
	heading.add_theme_constant_override("shadow_offset_y",2)
	identity.add_child(heading)
	var context := HBoxContainer.new()
	context.name = "RivalryWeekAndClock"
	context.visible = model.sample or model.received_msec > 0
	context.add_theme_constant_override("separation",12)
	identity.add_child(context)
	var week_label := MenuStyle.label("WEEK %02d" % model.week,21)
	week_label.add_theme_font_override("font",MenuStyle.DISPLAY)
	week_label.add_theme_color_override("font_color",MenuStyle.ACCENT)
	context.add_child(week_label)
	var clock_icon := TextureRect.new()
	clock_icon.texture = MenuIcon.texture("clock")
	clock_icon.custom_minimum_size = Vector2(22,22)
	clock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	clock_icon.modulate = MenuStyle.MUTED
	context.add_child(clock_icon)
	clock_label = MenuStyle.label(model.countdown(),20)
	clock_label.name = "RivalryCountdown"
	context.add_child(clock_label)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func() -> void: clock_label.text = model.countdown())
	add_child(timer)
	var body := HBoxContainer.new()
	body.name = "RivalryBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	# An unresolved membership is not a confirmed invitation to join.
	if model.tracks.is_empty() and signed_in and error.is_empty() and (busy or model.received_msec == 0): _loading(body)
	elif model.tracks.is_empty(): _empty(body)
	elif section == "result": _result(body)
	elif section == "overview" and model.completed: _finale(body)
	elif section == "detail": _detail(body)
	else: _overview(body)

func _draw() -> void:
	var art: Texture2D = WINTER_ART
	var source := Rect2(0,art.get_height()*0.16,art.get_width(),art.get_height()*0.84)
	var factor: float = maxf(size.x/source.size.x,size.y/source.size.y)
	var visible: Vector2 = size/factor
	source.position += (source.size-visible)*0.5
	source.size = visible
	draw_texture_rect_region(art,Rect2(Vector2.ZERO,size),source)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.035,0.05,0.26))


func _card(parent: Control, theme_id: String = "", padding: int = 20) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame: StyleBoxFlat = MenuStyle.card(padding)
	frame.border_color = QUIET_BORDER
	frame.shadow_size = 3
	panel.add_theme_stylebox_override("panel",frame)
	parent.add_child(panel)
	if not theme_id.is_empty():
		var art := TextureRect.new()
		art.texture = TrackTile.scenery_texture(theme_id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(art)
		var overlay := TextureRect.new()
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color("071520d9"),Color("06121be8"),Color("06121bfa")])
		gradient.offsets = PackedFloat32Array([0.0,0.5,1.0])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0,0)
		texture.fill_to = Vector2(0,1)
		overlay.texture = texture
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(overlay)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	return column

func _space(parent: Control) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func _copy(parent: Control, text: String, font_size: int = 18, color: Color = MenuStyle.TEXT) -> Label:
	var label := MenuStyle.label(text,font_size)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent is HBoxContainer: label.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(label)
	return label

func _action(parent: Control, text: String, id: String, action: Callable, primary: bool = false) -> Button:
	var button := MenuStyle.button(text,action,primary)
	button.name = id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button

static func rank_text(row: Dictionary) -> String:
	return "#%d" % int(row.rank) if row.get("rank") != null else "—"

func _rank(parent: Control, row: Dictionary, count: int, font_size: int = 64) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",8)
	parent.add_child(line)
	_copy(line,rank_text(row),font_size,MenuStyle.ACCENT)
	var total := _copy(line,"/ %d" % count,32,MenuStyle.MUTED)
	total.size_flags_vertical = Control.SIZE_SHRINK_END

func _route(parent: Control, index: int, height: int = 82, markers: bool = false) -> void:
	var route := LapRouteView.new()
	route.miniature = true
	route.show_race_markers = markers
	if markers: detail_route = route
	for point: Array in model.tracks[index].document.get("points",[]): route.route.append(Vector2(point[0],point[1]))
	route.custom_minimum_size = Vector2(0,height)
	route.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route.modulate = Color("ffffff")
	parent.add_child(route)

func apply_track_preview(document: Dictionary) -> void:
	if not is_instance_valid(detail_route) or document.is_empty(): return
	var samples: Dictionary = TrackDocument.route_data(document)
	var route: PackedVector2Array = samples.points
	var widths: PackedFloat32Array = samples.widths
	if document.corners[0] == "sharp":
		var offset: int = mini(8,maxi(1,floori(Vector2(document.points[0][0],document.points[0][1]).distance_to(Vector2(document.points[1][0],document.points[1][1]))*0.5)))
		route = route.slice(offset)+route.slice(0,offset)
		widths = widths.slice(offset)+widths.slice(0,offset)
	if document.has("start_line"):
		route = CreatorStartLine.route_from_start(route,widths,document.start_line).points
	detail_route.race_route = route
	detail_route.show_race_markers = true
	detail_route._fit()

func _table_row(parent: Control, row: Dictionary, value: String, compact: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.name = "Driver_"+str(row.id)
	var style := MenuStyle.box(Color("ffd34820") if row.id == WeeklyRivalry.SELF else Color("0b1c2799"),8)
	if row.id == WeeklyRivalry.SELF:
		style.border_color = MenuStyle.ACCENT
		style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",10)
	panel.add_child(line)
	var color: Color = MenuStyle.ACCENT if row.id == WeeklyRivalry.SELF else MenuStyle.TEXT
	var place := _copy(line,rank_text(row),19,color)
	place.custom_minimum_size.x = 34
	line.add_child(PlayerCountry.flag(str(row.get("country_code","")),24))
	var driver := _copy(line,str(row.name),18 if not compact else 16,color)
	driver.autowrap_mode = TextServer.AUTOWRAP_OFF
	driver.clip_text = true
	driver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy(line,value,18 if not compact else 16,color)

func _loading(parent: Control) -> void:
	parent.name = "RivalryLoading"
	parent.add_theme_constant_override("separation",14)
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation",12)
	parent.add_child(field)
	var podium := HBoxContainer.new()
	podium.custom_minimum_size.y = 170
	podium.add_theme_constant_override("separation",10)
	field.add_child(podium)
	for _position: int in range(3): _loading_block(podium,148).size_flags_vertical = Control.SIZE_SHRINK_END
	var standings: VBoxContainer = _card(field,"",12)
	_copy(standings,"STANDINGS",27)
	_copy(standings,"Loading…",18,MenuStyle.MUTED)
	_space(standings)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.13
	right.add_theme_constant_override("separation",6)
	parent.add_child(right)
	var flourish_space := Control.new()
	flourish_space.custom_minimum_size.y = 30
	right.add_child(flourish_space)
	var tracks: VBoxContainer = _card(right,"",12)
	tracks.add_theme_constant_override("separation",6)
	_copy(tracks,"THIS WEEK'S TRACKS",26)
	for _slot: int in range(5): _loading_block(tracks,48).size_flags_vertical = Control.SIZE_EXPAND_FILL

func _loading_block(parent: Control, height: int) -> Control:
	var block := PanelContainer.new()
	block.custom_minimum_size.y = height
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_stylebox_override("panel",MenuStyle.box(Color("29425266"),6))
	parent.add_child(block)
	return block

func _empty(parent: Control) -> void:
	var hero: VBoxContainer = _card(parent,"winter",28)
	_copy(hero,"A SMALL CHAMPIONSHIP.\nA NEW RIVALRY EACH WEEK.",46)
	_copy(hero,"Five tracks. Drivers near your pace.\nYour best result on each track counts.",22,MenuStyle.MUTED)
	_space(hero)
	if not error.is_empty(): _copy(hero,error,20,MenuStyle.MUTED)
	elif busy: _copy(hero,"Finding this week's rivalry…",20,MenuStyle.MUTED)
	else: _copy(hero,"Race as often as you like. Find your next rival.",20,MenuStyle.MUTED)
	var actions := HBoxContainer.new()
	hero.add_child(actions)
	var join_button: Button = _action(actions,"JOIN THIS WEEK  →" if signed_in else "SIGN IN TO JOIN  →","RivalryJoin",func() -> void: join_requested.emit(),true)
	join_button.disabled = busy
	_action(actions,"FREE RACE","RivalryFreeRace",func() -> void: free_race_requested.emit())
	_action(hero,"Refresh","RivalryRefresh",func() -> void: refresh_requested.emit()).disabled = busy

func _overview(parent: Control) -> void:
	_championship(parent,false)

func _championship(parent: Control, finale: bool) -> void:
	selected = clampi(selected,0,model.tracks.size()-1)
	parent.add_theme_constant_override("separation",14)
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = 1.0
	field.add_theme_constant_override("separation",12)
	parent.add_child(field)
	_podium(field)
	_driver_table(field,"STANDINGS")
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.13
	right.add_theme_constant_override("separation",6)
	parent.add_child(right)
	var flourish := MenuStyle.label("Small Tracks. Big Thrills.",20,true)
	flourish.name = "RivalryBrandFlourish"
	flourish.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	flourish.custom_minimum_size.y = 30
	var italic := FontVariation.new()
	italic.base_font = MenuStyle.DISPLAY
	italic.variation_transform = Transform2D(Vector2(1,0),Vector2(-0.18,1),Vector2.ZERO)
	flourish.add_theme_font_override("font",italic)
	right.add_child(flourish)
	var tracks: VBoxContainer = _card(right,"",12)
	tracks.get_parent().name = "RivalryTracksPanel"
	tracks.add_theme_constant_override("separation",6)
	var heading := HBoxContainer.new()
	tracks.add_child(heading)
	_copy(heading,"TRACK RESULTS" if finale else "THIS WEEK'S TRACKS",26).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var completed: int = 0
	for index: int in range(model.tracks.size()):
		if model.gaps(index).own.get("ms") != null: completed += 1
	_copy(heading,"%d / 5 COMPLETED" % completed,14,MenuStyle.MUTED)
	var subtitle: Label = _copy(tracks,error if not error.is_empty() else "Week complete. Your best results." if finale else "Choose a track and beat your best time.",15,MenuStyle.MUTED)
	subtitle.name = "RivalryStatusMessage"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle.clip_text = true
	subtitle.tooltip_text = subtitle.text
	track_rows.clear()
	track_markers.clear()
	for index: int in range(model.tracks.size()): _track_row(tracks,index,finale)
	if finale:
		var next: Button = _action(tracks,"CONTINUE TO NEXT WEEK","RivalryNextWeek",func() -> void: continue_requested.emit(),true)
		next.custom_minimum_size.y = 64
		next.disabled = busy
	_select_track(selected)

func _driver_table(parent: Control, title: String) -> void:
	var table: VBoxContainer = _card(parent,"",12)
	table.get_parent().name = "RivalryDriversPanel"
	table.add_theme_constant_override("separation",7)
	var heading := HBoxContainer.new()
	table.add_child(heading)
	_copy(heading,title,27).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy(heading,"%d DRIVERS" % model.standing().size(),14,MenuStyle.MUTED)
	var scroll := ScrollContainer.new()
	scroll.name = "RivalryStandingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	var legend_margin := MarginContainer.new()
	legend_margin.name = "RivalryStandingsColumnHeader"
	legend_margin.add_theme_constant_override("margin_left",5)
	legend_margin.add_theme_constant_override("margin_right",ceili(scroll.get_v_scroll_bar().get_combined_minimum_size().x)+STANDINGS_GUTTER+5)
	table.add_child(legend_margin)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation",9)
	legend_margin.add_child(legend)
	_copy(legend,"#",14,MenuStyle.MUTED).custom_minimum_size.x = 30
	_copy(legend,"DRIVER",14,MenuStyle.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for column: Array in [["POINTS",60],["GAP",54]]:
		var label: Label = _copy(legend,str(column[0]),14,MenuStyle.MUTED)
		label.name = "RivalryColumn_"+str(column[0])
		label.custom_minimum_size.x = int(column[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	table.add_child(scroll)
	var row_margin := MarginContainer.new()
	row_margin.name = "RivalryStandingsScrollGutter"
	row_margin.add_theme_constant_override("margin_right",STANDINGS_GUTTER)
	row_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row_margin)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",2)
	row_margin.add_child(rows)
	var own_panel: Control
	var standings: Array[Dictionary] = model.standing()
	var leader_points: int = int(standings[0].points)
	for driver: Dictionary in standings:
		var panel := PanelContainer.new()
		panel.name = "Driver_"+str(driver.id)
		panel.custom_minimum_size.y = 38
		panel.add_theme_stylebox_override("panel",_driver_style(driver))
		rows.add_child(panel)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",9)
		panel.add_child(line)
		var own: bool = driver.id == WeeklyRivalry.SELF
		var color: Color = MenuStyle.ACCENT if own else MenuStyle.TEXT
		var badge := PanelContainer.new()
		badge.custom_minimum_size.x = 30
		var podium_color: Color = _medal_color(int(driver.rank)-1) if driver.get("rank") != null and int(driver.rank) <= 3 else Color.TRANSPARENT
		badge.add_theme_stylebox_override("panel",MenuStyle.box(Color(podium_color,0.48) if podium_color.a > 0.0 else Color.TRANSPARENT,0))
		line.add_child(badge)
		var place: Label = _copy(badge,str(int(driver.rank)) if driver.get("rank") != null else "--",19,color)
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(PlayerCountry.flag(str(driver.get("country_code","")),28))
		var name_label: Label = _copy(line,_display_name(driver),18,color)
		name_label.name = "RivalryPlayerName_"+str(driver.id)
		name_label.add_theme_font_override("font",MenuStyle.DISPLAY)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var points: Label = _copy(line,str(int(driver.points)),18,color)
		points.name = "RivalryPlayerPoints_"+str(driver.id)
		points.custom_minimum_size.x = 60
		points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var gap: Label = _copy(line,"--" if driver.get("rank") == null or int(driver.points) == leader_points else str(int(driver.points)-leader_points),18,color if own else MenuStyle.MUTED)
		gap.name = "RivalryPlayerGap_"+str(driver.id)
		gap.custom_minimum_size.x = 54
		gap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if own: own_panel = panel
	if own_panel != null: _reveal_player.call_deferred(scroll,own_panel)

func _reveal_player(scroll: ScrollContainer, player: Control) -> void:
	# One-shot callbacks disconnect when a refresh removes this page.
	if not is_inside_tree(): return
	get_tree().process_frame.connect(_reveal_after_sort.bind(scroll,player),CONNECT_ONE_SHOT)

func _reveal_after_sort(scroll: ScrollContainer, player: Control) -> void:
	if not is_inside_tree() or not is_instance_valid(scroll) or not is_instance_valid(player): return
	get_tree().process_frame.connect(_ensure_player_visible.bind(scroll,player),CONNECT_ONE_SHOT)

func _ensure_player_visible(scroll: ScrollContainer, player: Control) -> void:
	if is_inside_tree() and is_instance_valid(scroll) and is_instance_valid(player):
		scroll.ensure_control_visible(player)

func _display_name(row: Dictionary) -> String:
	var value: String = str(row.name)
	if bool(row.get("is_test_driver",false)):
		var marker: int = value.find(" T")
		if marker >= 0 and value.substr(marker+2).contains("-"): value = value.substr(0,marker)
	return value

func _driver_style(row: Dictionary) -> StyleBoxFlat:
	var style := MenuStyle.box(Color("ffd3480b") if row.id == WeeklyRivalry.SELF else Color("08172022"),5)
	style.border_color = MenuStyle.ACCENT if row.id == WeeklyRivalry.SELF else Color("2c485755")
	if row.id == WeeklyRivalry.SELF: style.set_border_width_all(2)
	else: style.border_width_bottom = 1
	return style

func _medal_color(position: int) -> Color:
	return MenuStyle.ACCENT if position == 0 else Color("c0d4e3") if position == 1 else Color("dc9069")

func _podium(parent: Control) -> void:
	var podium := HBoxContainer.new()
	podium.name = "RivalryPodium"
	podium.custom_minimum_size.y = 170
	podium.add_theme_constant_override("separation",10)
	parent.add_child(podium)
	var leaders: Array[Dictionary] = []
	for row: Dictionary in model.standing():
		if row.get("rank") != null and leaders.size() < 3: leaders.append(row)
	if leaders.is_empty():
		var intro: VBoxContainer = _card(podium,"winter",12)
		_copy(intro,"THE WEEK STARTS HERE",28,MenuStyle.ACCENT)
		_copy(intro,"Five circuits. Unlimited attempts.",17)
		_copy(intro,"Set your first time to join the battle.",16,MenuStyle.MUTED)
		return
	for position: int in [1,0,2]:
		if position >= leaders.size(): continue
		var driver: Dictionary = leaders[position]
		var color: Color = _medal_color(position)
		var card: VBoxContainer = _card(podium,"",9)
		var panel: PanelContainer = card.get_parent()
		panel.name = "RivalryPodium_"+str(position+1)
		panel.custom_minimum_size.y = 170 if position == 0 else 148
		panel.size_flags_vertical = Control.SIZE_SHRINK_END
		panel.size_flags_stretch_ratio = 1.08 if position == 0 else 1.0
		var style: StyleBoxFlat = MenuStyle.card(9)
		style.bg_color = Color("453b13e6") if position == 0 else Color("294252c9") if position == 1 else Color("492a20dd")
		style.border_color = Color(color,0.82)
		style.shadow_size = 4
		panel.add_theme_stylebox_override("panel",style)
		card.add_theme_constant_override("separation",1)
		var rank := HBoxContainer.new()
		rank.add_theme_constant_override("separation",8)
		card.add_child(rank)
		var icon := TextureRect.new()
		icon.texture = MenuIcon.texture("trophy")
		icon.custom_minimum_size = Vector2(32,34) if position == 0 else Vector2(28,30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = color
		rank.add_child(icon)
		_copy(rank,rank_text(driver),38 if position == 0 else 33,color)
		var identity := HBoxContainer.new()
		identity.add_theme_constant_override("separation",6)
		card.add_child(identity)
		identity.add_child(PlayerCountry.flag(str(driver.get("country_code","")),24))
		var driver_name: Label = _copy(identity,_display_name(driver),20)
		driver_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		driver_name.add_theme_font_override("font",MenuStyle.DISPLAY)
		driver_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		driver_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_copy(card,str(int(driver.points))+" pts",22,color)
		_space(card)
		var car := TextureRect.new()
		car.name = "RivalryPodiumCar_"+str(position+1)
		car.texture = COMPACT_ART if model.vehicle_id == "compact" else VehicleCatalog.artwork(model.vehicle_id)
		car.custom_minimum_size.y = 72 if position == 0 else 60
		car.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		car.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		car.modulate = Color("fff0cd") if position == 0 else Color("dbe9f5") if position == 1 else Color("f8cfb9")
		car.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		car.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(car)

func _track_row(parent: Control, index: int, finale: bool) -> void:
	var track: Dictionary = model.tracks[index]
	var line := HBoxContainer.new()
	line.name = "RivalryTrackRow_"+str(index)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation",6)
	parent.add_child(line)
	var row := MenuStyle.button("",func() -> void: track_requested.emit(index))
	row.name = "SelectRivalryTrack_"+str(index)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0,54)
	row.tooltip_text = "View "+str(track.name)
	row.focus_entered.connect(func() -> void: _select_track(index))
	line.add_child(row)
	track_rows.append(row)
	var mark := ColorRect.new()
	mark.name = "RivalryTrackSelectionMark_"+str(index)
	mark.color = MenuStyle.ACCENT
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	mark.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	mark.offset_right = 3
	mark.offset_top = 7
	mark.offset_bottom = -7
	track_markers.append(mark)
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation",10)
	row.add_child(content_row)
	content_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_row.offset_left = 6
	content_row.offset_right = -6
	content_row.offset_top = 4
	content_row.offset_bottom = -4
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(str(track.theme))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.custom_minimum_size.x = 88
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	content_row.add_child(art)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation",1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(copy)
	var title: Label = _copy(copy,str(track.name).capitalize(),22)
	title.add_theme_font_override("font",MenuStyle.DISPLAY)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var gap: Dictionary = model.gaps(index)
	var biome := HBoxContainer.new()
	biome.add_theme_constant_override("separation",5)
	copy.add_child(biome)
	var glyph := TextureRect.new()
	glyph.texture = MenuIcon.texture(Badge.icon(str(track.theme)))
	glyph.modulate = Badge.color(str(track.theme))
	glyph.custom_minimum_size = Vector2(15,15)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	biome.add_child(glyph)
	_copy(biome,"City" if track.theme == "night_city" else TrackTheme.title(str(track.theme)),14,MenuStyle.MUTED)
	var position: Label = _copy(content_row,rank_text(gap.own),22,MenuStyle.ACCENT if gap.own.get("rank") == 1 else MenuStyle.TEXT)
	position.custom_minimum_size.x = 30
	position.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var times := VBoxContainer.new()
	times.custom_minimum_size.x = 104
	times.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	times.add_theme_constant_override("separation",1)
	content_row.add_child(times)
	var time: Label = _copy(times,MenuStyle.time_text(int(gap.own.ms)/1000.0) if gap.own.get("ms") != null else MenuStyle.time_text(int(gap.leader.ms)/1000.0) if not gap.leader.is_empty() else "—",23)
	time.add_theme_font_override("font",MenuStyle.DISPLAY)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var delta: Label = _copy(times,WeeklyRivalry.gap_text(int(gap.own.ms)-int(gap.leader.ms))+" to lead" if gap.own.get("ms") != null and not gap.leader.is_empty() and gap.own.rank != 1 else "Leading" if gap.own.get("rank") == 1 else "Leader time" if not gap.leader.is_empty() else "Set a time",13,MenuStyle.POSITIVE if gap.own.get("rank") == 1 else MenuStyle.MUTED)
	delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ignore_tree(content_row)
	var action: Button = _action(line,"","OpenRivalryTrack_"+str(index),func() -> void: track_requested.emit(index))
	action.icon = MenuIcon.texture("arrow")
	action.custom_minimum_size = Vector2(48,54)
	action.size_flags_horizontal = Control.SIZE_FILL
	action.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action.tooltip_text = "View results" if finale else "View "+str(track.name)

func _select_track(index: int) -> void:
	if selected != index: track_selected.emit(index)
	selected = index
	for slot: int in range(track_rows.size()):
		var style: StyleBoxFlat = MenuStyle.box(Color("16313cd9") if slot == index else Color("0b1c2788"),0)
		style.border_color = QUIET_BORDER
		style.set_border_width_all(1)
		track_rows[slot].add_theme_stylebox_override("normal",style)
		track_markers[slot].visible = slot == index

func _ignore_tree(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children(): _ignore_tree(child)

func _detail(parent: Control) -> void:
	selected = clampi(selected,0,model.tracks.size()-1)
	var track: Dictionary = model.tracks[selected]
	var scene: VBoxContainer = _card(parent,str(track.theme))
	scene.get_parent().size_flags_stretch_ratio = 1.25
	var back: Button = _action(scene,"←  BACK TO TRACKS","RivalryBackToOverview",func() -> void: section_requested.emit("overview"))
	back.custom_minimum_size.y = 48
	scene.add_child(Badge.view(str(track.theme),15))
	_copy(scene,str(track.name).to_upper(),48)
	_route(scene,selected,100,true)
	if model.sample: apply_track_preview(track.document)
	else: detail_route.show_race_markers = false # Wait for the verified full document's start/direction.
	_copy(scene,VehicleCatalog.title(model.vehicle_id),18,MenuStyle.MUTED)
	var board: VBoxContainer = _card(parent,"",14)
	_copy(board,"YOUR POSITION",18,MenuStyle.MUTED)
	var gap: Dictionary = model.gaps(selected)
	_rank(board,gap.own,model.board(selected).size(),52)
	var standings := preload("res://ui/rivalry_track_standings.gd").new()
	standings.board = model.board(selected)
	board.add_child(standings)
	var duel: VBoxContainer = _card(parent,"",16)
	_copy(duel,"YOUR NEXT RIVAL",18,MenuStyle.MUTED)
	if not gap.ahead.is_empty():
		var identity := HBoxContainer.new()
		duel.add_child(identity)
		identity.add_child(PlayerCountry.flag(str(gap.ahead.get("country_code","")),32))
		var rival_name: Label = _copy(identity,str(gap.ahead.name).to_upper(),38)
		rival_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rival_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_copy(duel,WeeklyRivalry.gap_text(int(gap.own.ms)-int(gap.ahead.ms))+" ahead of you",22,MenuStyle.ACCENT)
	elif gap.own.get("ms") == null:
		_copy(duel,"SET THE PACE",32)
		_copy(duel,"Your first finish puts you on the board.",17,MenuStyle.MUTED)
	else:
		_copy(duel,"DEFEND THE LEAD",32)
		_copy(duel,"Push your best further.",19,MenuStyle.MUTED)
	var closest: Dictionary = model.closest_challenger(selected)
	if not closest.is_empty():
		duel.add_child(HSeparator.new())
		_copy(duel,"Closest challenger",17,MenuStyle.MUTED)
		var challenger := HBoxContainer.new()
		challenger.add_theme_constant_override("separation",8)
		duel.add_child(challenger)
		challenger.add_child(PlayerCountry.flag(str(closest.get("country_code","")),30))
		_copy(challenger,rank_text(closest),18)
		var challenger_name: Label = _copy(challenger,_display_name(closest),18)
		challenger_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		challenger_name.clip_text = true
		challenger_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var challenger_time: Label = _copy(challenger,MenuStyle.time_text(int(closest.ms)/1000.0),22)
		challenger_time.name = "RivalryClosestChallengerTime"
		challenger_time.add_theme_font_override("font",MenuStyle.DISPLAY)
		var challenger_gap: Label = _copy(duel,"+%.3f behind you" % ((int(closest.ms)-int(gap.own.ms))/1000.0) if int(closest.ms) > int(gap.own.ms) else "Level with you",16,MenuStyle.MUTED)
		challenger_gap.name = "RivalryClosestChallengerGap"
	duel.add_child(HSeparator.new())
	_copy(duel,"Race with ghost",18,MenuStyle.MUTED)
	var selector := OptionButton.new()
	selector.name = "RivalryGhostSelector"
	selector.custom_minimum_size = Vector2(0,54)
	selector.fit_to_longest_item = false
	selector.add_theme_font_size_override("font_size",17)
	var target: Dictionary = model.ghost_target(selected,0)
	selector.add_item(_display_name(target)+" ("+rank_text(target)+")" if not target.is_empty() else "Rival · unavailable")
	selector.add_item("Leader: "+str(gap.leader.name) if not gap.leader.is_empty() else "Weekly leader · unavailable")
	selector.add_item("My weekly PB")
	selector.add_item("No ghost")
	selector.set_item_disabled(0,target.is_empty())
	selector.set_item_disabled(1,gap.leader.is_empty())
	selector.set_item_disabled(2,gap.own.get("ms") == null)
	if selector.is_item_disabled(ghost_choice): ghost_choice = 3
	selector.select(ghost_choice)
	duel.add_child(selector)
	var ghost_copy := _copy(duel,"Your recorded weekly best." if ghost_choice == 2 else "Drive without a ghost." if ghost_choice == 3 else "Race against their best time.",15,MenuStyle.MUTED)
	selector.item_selected.connect(func(index: int) -> void:
		ghost_choice = index
		ghost_copy.text = "Your recorded weekly best." if index == 2 else "Drive without a ghost." if index == 3 else "Race against their best time.")
	_space(duel)
	var race: Button = _action(duel,"RACE "+str(track.name).to_upper()+"  →","RivalryStartRace",func() -> void: race_requested.emit(selected,ghost_choice),true)
	race.disabled = busy or model.completed or model.status != "active" or not bool(track.get("available",true))
	if not bool(track.get("available",true)): _copy(duel,"This track is unavailable for racing.",15,MenuStyle.MUTED)
	if not error.is_empty(): _copy(duel,error,15,MenuStyle.MUTED)

func _result(parent: Control) -> void:
	var result_view := WeeklyRivalryResult.new()
	result_view.model = model
	result_view.index = clampi(selected,0,model.tracks.size()-1)
	result_view.details = race_details
	result_view.pending = pending_result
	result_view.busy = busy
	result_view.error = error
	result_view.retry_requested.connect(func() -> void: retry_requested.emit())
	result_view.home_requested.connect(func() -> void: section_requested.emit("overview"))
	parent.add_child(result_view)

func _finale(parent: Control) -> void:
	_championship(parent,true)

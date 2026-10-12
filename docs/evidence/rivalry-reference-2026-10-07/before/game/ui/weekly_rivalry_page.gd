class_name WeeklyRivalryPage
extends VBoxContainer
## Five immediately playable tracks and verified standings in one championship hub.
signal section_requested(section: String)
signal track_requested(index: int)
signal track_selected(index: int)
signal race_requested(index: int, ghost_choice: int)
signal free_race_requested
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
var ghost_choice: int = 0
var clock_label: Label
var track_rows: Array[Button] = []
var race_selection: Button
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
		elif mode == "rivalry": section_requested.emit("overview"))
	row.add_child(rail)
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(main)
	var header := HBoxContainer.new()
	header.name = "RivalrySectionNavigation"
	main.add_child(header)
	var heading := MenuStyle.label("WEEKLY RIVALRY",30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var navigation := PanelContainer.new()
	navigation.add_theme_stylebox_override("panel",MenuStyle.box(Color("091721ed"),0))
	header.add_child(navigation)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",0)
	navigation.add_child(tabs)
	for id: String in ["overview","tracks","standings"]:
		var tab := MenuStyle.tab(id.to_upper(),func() -> void: section_requested.emit(id),section == id or (section == "detail" and id == "tracks"))
		tab.name = "RivalryTab_"+id
		tab.custom_minimum_size = Vector2(116,52)
		tab.add_theme_font_size_override("font_size",19)
		tabs.add_child(tab)
	var context := HBoxContainer.new()
	main.add_child(context)
	var week_label := MenuStyle.label("WEEK %02d" % model.week,16)
	week_label.add_theme_color_override("font_color",MenuStyle.ACCENT)
	context.add_child(week_label)
	clock_label = MenuStyle.label(model.countdown(),16,true)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	if model.tracks.is_empty(): _empty(body)
	elif section == "result": _result(body)
	elif section == "overview" and model.completed: _finale(body)
	elif section == "tracks": _tracks(body)
	elif section == "detail": _detail(body)
	elif section == "standings": _standings(body)
	else: _overview(body)
	var footer := HBoxContainer.new()
	main.add_child(footer)
	var notice: String = ("TEST RIVALRY · Artificial drivers · Verified races" if model.test_population else "Placement group · Building your pace profile" if model.placement else "Matched by verified pace")+"   ·   "+VehicleCatalog.title(model.vehicle_id)
	var foot := MenuStyle.label("CONCEPT PREVIEW · Sample drivers and results" if model.sample else notice,14,true)
	foot.name = "RivalryDataNotice"
	if not error.is_empty(): foot.text += "  -  "+error
	foot.tooltip_text = foot.text
	foot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(foot)

func _draw() -> void:
	var art: Texture2D = TrackTile.scenery_texture("winter")
	var factor: float = maxf(size.x/art.get_width(),size.y/art.get_height())
	var drawn: Vector2 = art.get_size()*factor
	draw_texture_rect(art,Rect2((size-drawn)*0.5,drawn),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.035,0.05,0.68))


func _card(parent: Control, theme_id: String = "", padding: int = 20) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",MenuStyle.card(padding))
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

func _route(parent: Control, index: int, height: int = 82) -> void:
	var route := LapRouteView.new()
	route.miniature = true
	for point: Array in model.tracks[index].document.get("points",[]): route.route.append(Vector2(point[0],point[1]))
	route.custom_minimum_size = Vector2(0,height)
	route.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route.modulate = Color("ffffff")
	parent.add_child(route)

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
	var monogram := _copy(line,str(row.name).left(1).to_upper(),18,MenuStyle.MUTED)
	monogram.custom_minimum_size.x = 18
	var driver := _copy(line,str(row.name),18 if not compact else 16,color)
	driver.autowrap_mode = TextServer.AUTOWRAP_OFF
	driver.clip_text = true
	driver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if row.get("is_test_driver",false): _copy(line,"TEST",12,MenuStyle.MUTED)
	_copy(line,value,18 if not compact else 16,color)

func _gaps(parent: Control) -> void:
	var gap: Dictionary = model.overall_gaps()
	if gap.own.get("rank") == null:
		_copy(parent,"Set a time to enter the standings.",18,MenuStyle.MUTED)
		return
	if not gap.ahead.is_empty(): _copy(parent,"%d pts to #%d" % [int(gap.ahead.points)-int(gap.own.points),int(gap.ahead.rank)],22,MenuStyle.MUTED)
	if not gap.behind.is_empty(): _copy(parent,"%d pts ahead of #%d" % [int(gap.own.points)-int(gap.behind.points),int(gap.behind.rank)],22,MenuStyle.MUTED)
	if gap.ahead.is_empty(): _copy(parent,"You're leading the rivalry",22,MenuStyle.POSITIVE)

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
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = 0.94
	field.add_theme_constant_override("separation",10)
	parent.add_child(field)
	_podium(field)
	var table: VBoxContainer = _card(field,"",12)
	table.add_theme_constant_override("separation",6)
	var title := HBoxContainer.new()
	table.add_child(title)
	_copy(title,"ALL DRIVERS",24).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy(title,"%d DRIVERS" % model.standing().size(),14,MenuStyle.MUTED)
	var legend := HBoxContainer.new()
	table.add_child(legend)
	_copy(legend,"#",14,MenuStyle.MUTED).custom_minimum_size.x = 28
	_copy(legend,"DRIVER",14,MenuStyle.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy(legend,"POINTS   GAP",14,MenuStyle.MUTED)
	var scroll := ScrollContainer.new()
	scroll.name = "RivalryStandingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",3)
	scroll.add_child(rows)
	var standings: Array[Dictionary] = model.standing()
	var leader_points: int = int(standings[0].points)
	for row: Dictionary in standings:
		_table_row(rows,row,str(row.points)+" pts  "+("—" if row.get("rank") == null or int(row.points) == leader_points else "−%d" % (leader_points-int(row.points))),true)
		rows.get_child(-1).add_theme_stylebox_override("panel",_driver_style(row))
	var own: Dictionary = WeeklyRivalry.self_row(standings)
	var summary := HBoxContainer.new()
	table.add_child(summary)
	_copy(summary,"YOU  "+rank_text(own),20,MenuStyle.ACCENT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy(summary,str(own.points)+" pts",20,MenuStyle.ACCENT)
	var tracks: VBoxContainer = _card(parent,"",14)
	tracks.get_parent().size_flags_stretch_ratio = 1.24
	tracks.add_theme_constant_override("separation",7)
	var heading := HBoxContainer.new()
	tracks.add_child(heading)
	_copy(heading,"TRACK RESULTS" if finale else "THIS WEEK'S TRACKS",26).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var completed: int = 0
	for index: int in range(model.tracks.size()):
		if model.gaps(index).own.get("ms") != null: completed += 1
	_copy(heading,"%d / 5 COMPLETED" % completed,15,MenuStyle.MUTED)
	_copy(tracks,"Week complete · Your best results" if finale else "Choose a circuit. Your best result on each track counts.",16,MenuStyle.MUTED)
	track_rows.clear()
	for index: int in range(model.tracks.size()): _track_row(tracks,index,finale)
	if finale:
		_action(tracks,"CONTINUE TO NEXT WEEK  →","RivalryNextWeek",func() -> void: continue_requested.emit(),true).disabled = busy
	else:
		race_selection = _action(tracks,"","RivalryRaceSelected",func() -> void: race_requested.emit(selected,_default_ghost(selected)),true)
		race_selection.icon = MenuIcon.texture("flag")
		race_selection.add_theme_color_override("icon_normal_color",MenuStyle.INK)
		race_selection.add_theme_color_override("icon_hover_color",MenuStyle.INK)
		_select_track(selected)

func _driver_style(row: Dictionary) -> StyleBoxFlat:
	var style := MenuStyle.box(Color("ffd34812") if row.id == WeeklyRivalry.SELF else Color("081720bb"),6)
	if row.id == WeeklyRivalry.SELF:
		style.border_color = MenuStyle.ACCENT
		style.set_border_width_all(1)
	return style

func _podium(parent: Control) -> void:
	var podium := HBoxContainer.new()
	podium.name = "RivalryPodium"
	podium.custom_minimum_size.y = 120
	podium.add_theme_constant_override("separation",8)
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
		var color: Color = MenuStyle.ACCENT if position == 0 else Color("bbced8") if position == 1 else Color("c68b63")
		var card: VBoxContainer = _card(podium,"",8)
		var style: StyleBoxFlat = MenuStyle.card(8)
		style.bg_color = Color("273024ee") if position == 0 else Color("132430ee")
		style.border_color = color.darkened(0.3)
		card.get_parent().add_theme_stylebox_override("panel",style)
		card.add_theme_constant_override("separation",3)
		var rank := HBoxContainer.new()
		card.add_child(rank)
		var icon := TextureRect.new()
		icon.texture = MenuIcon.texture("trophy")
		icon.custom_minimum_size = Vector2(22,22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.modulate = color
		rank.add_child(icon)
		_copy(rank,rank_text(driver),29,color)
		var driver_name: Label = _copy(card,str(driver.name),19)
		driver_name.add_theme_font_override("font",MenuStyle.DISPLAY)
		driver_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		driver_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_copy(card,str(driver.points)+" pts",23,color)
		_copy(card,"WEEK LEADER" if position == 0 else "CONTENDER",12,MenuStyle.MUTED)

func _default_ghost(index: int) -> int:
	var gap: Dictionary = model.gaps(index)
	return 0 if not gap.ahead.is_empty() else 1 if not gap.leader.is_empty() and gap.leader.id != WeeklyRivalry.SELF else 2 if gap.own.get("ms") != null else 3

func _track_row(parent: Control, index: int, finale: bool) -> void:
	var track: Dictionary = model.tracks[index]
	var line := HBoxContainer.new()
	line.name = "RivalryTrackRow_"+str(index)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation",6)
	parent.add_child(line)
	var row := MenuStyle.button("",func() -> void: _select_track(index))
	row.name = "SelectRivalryTrack_"+str(index)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0,52)
	row.tooltip_text = "Select "+str(track.name)
	row.focus_entered.connect(func() -> void: _select_track(index))
	line.add_child(row)
	track_rows.append(row)
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation",10)
	row.add_child(content_row)
	content_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_row.offset_left = 7
	content_row.offset_right = -7
	content_row.offset_top = 4
	content_row.offset_bottom = -4
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(str(track.theme))
	art.custom_minimum_size.x = 64
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	content_row.add_child(art)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation",1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(copy)
	var title: Label = _copy(copy,str(track.name),21)
	title.add_theme_font_override("font",MenuStyle.DISPLAY)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var gap: Dictionary = model.gaps(index)
	_copy(copy,"5 laps · "+str(int(gap.own.points))+" pts" if gap.own.get("ms") != null else "5 laps · No time yet",13,MenuStyle.MUTED)
	var position: Label = _copy(content_row,rank_text(gap.own),22,MenuStyle.ACCENT if gap.own.get("rank") == 1 else MenuStyle.TEXT)
	position.custom_minimum_size.x = 30
	position.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var times := VBoxContainer.new()
	times.custom_minimum_size.x = 96
	times.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	times.add_theme_constant_override("separation",1)
	content_row.add_child(times)
	var time: Label = _copy(times,MenuStyle.time_text(int(gap.own.ms)/1000.0) if gap.own.get("ms") != null else MenuStyle.time_text(int(gap.leader.ms)/1000.0) if not gap.leader.is_empty() else "—",18)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var delta: Label = _copy(times,WeeklyRivalry.gap_text(int(gap.own.ms)-int(gap.leader.ms))+" to lead" if gap.own.get("ms") != null and not gap.leader.is_empty() and gap.own.rank != 1 else "Leading" if gap.own.get("rank") == 1 else "Leader time" if not gap.leader.is_empty() else "Set a time",13,MenuStyle.POSITIVE if gap.own.get("rank") == 1 else MenuStyle.MUTED)
	delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ignore_tree(content_row)
	var action: Button = _action(line,"›","RivalryRaceTrack_"+str(index),func() -> void:
		if finale: track_requested.emit(index)
		else: race_requested.emit(index,_default_ghost(index)))
	action.text = ""
	action.icon = MenuIcon.texture("arrow")
	action.custom_minimum_size = Vector2(48,52)
	action.size_flags_horizontal = Control.SIZE_FILL
	action.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action.tooltip_text = "View results" if finale else "Race "+str(track.name)
	action.disabled = not finale and (busy or model.status != "active" or not bool(track.get("available",true)))

func _select_track(index: int) -> void:
	if selected != index: track_selected.emit(index)
	selected = index
	for slot: int in range(track_rows.size()):
		var style: StyleBoxFlat = MenuStyle.box(Color("ffd34812") if slot == index else Color("0b1c27cc"),0)
		style.border_color = MenuStyle.ACCENT if slot == index else MenuStyle.BORDER
		style.set_border_width_all(1)
		track_rows[slot].add_theme_stylebox_override("normal",style)
	if is_instance_valid(race_selection):
		race_selection.text = "RACE "+str(model.tracks[index].name).to_upper()+"  →"
		race_selection.disabled = busy or model.status != "active" or not bool(model.tracks[index].get("available",true))

func _tracks(parent: Control) -> void:
	for index: int in range(model.tracks.size()):
		var track: Dictionary = model.tracks[index]
		var card: VBoxContainer = _card(parent,str(track.theme),12)
		var panel: PanelContainer = card.get_parent()
		panel.name = "RivalryTrack_"+str(index)
		var button := MenuStyle.button("",func() -> void: track_requested.emit(index))
		button.name = "OpenRivalryTrack_"+str(index)
		button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
		button.add_theme_stylebox_override("hover",MenuStyle.box(Color("ffd34812"),0))
		button.add_theme_stylebox_override("pressed",MenuStyle.box(Color("ffd34824"),0))
		button.tooltip_text = "Open "+str(track.name)
		panel.add_child(button)
		panel.move_child(button,2)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(Badge.view(str(track.theme),13))
		_route(card,index,100)
		_copy(card,str(track.name).to_upper(),26)
		var gap: Dictionary = model.gaps(index)
		_rank(card,gap.own,model.board(index).size(),42)
		if gap.own.get("ms") == null:
			_copy(card,"Set your first time",17,MenuStyle.ACCENT)
			_copy(card,"A place is waiting",16,MenuStyle.MUTED)
		elif gap.ahead.is_empty():
			_copy(card,"You're leading",17,MenuStyle.POSITIVE)
			_copy(card,WeeklyRivalry.gap_text(int(gap.behind.ms)-int(gap.own.ms))+" ahead" if not gap.behind.is_empty() else "First time on the board",16,MenuStyle.MUTED)
		else:
			_copy(card,WeeklyRivalry.gap_text(int(gap.own.ms)-int(gap.ahead.ms))+" to #"+str(gap.ahead.rank),17)
			_copy(card,WeeklyRivalry.gap_text(int(gap.own.ms)-int(gap.leader.ms))+" to #1" if gap.ahead.rank != 1 else "The lead is within reach",16,MenuStyle.MUTED)
		_copy(card,"VIEW DUEL  →",16,MenuStyle.ACCENT)
		_ignore_tree(card)
		var race: Button = _action(card,"RACE","RivalryCardRace_"+str(index),func() -> void: race_requested.emit(index,_default_ghost(index)),true)
		race.disabled = busy or model.status != "active" or not bool(track.get("available",true))

func _ignore_tree(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children(): _ignore_tree(child)

func _detail(parent: Control) -> void:
	selected = clampi(selected,0,model.tracks.size()-1)
	var track: Dictionary = model.tracks[selected]
	var scene: VBoxContainer = _card(parent,str(track.theme))
	scene.get_parent().size_flags_stretch_ratio = 1.25
	_action(scene,"←  BACK TO TRACKS","RivalryBackToTracks",func() -> void: section_requested.emit("tracks"))
	scene.add_child(Badge.view(str(track.theme),15))
	_copy(scene,str(track.name).to_upper(),48)
	_route(scene,selected,100)
	_copy(scene,"5 laps · "+VehicleCatalog.title(model.vehicle_id),18,MenuStyle.MUTED)
	var board: VBoxContainer = _card(parent,"",14)
	_copy(board,"YOUR POSITION",18,MenuStyle.MUTED)
	var gap: Dictionary = model.gaps(selected)
	_rank(board,gap.own,model.board(selected).size(),52)
	_space(board)
	for row: Dictionary in model.nearby(selected): _table_row(board,row,MenuStyle.time_text(int(row.ms)/1000.0) if row.get("ms") != null else "No time",true)
	var duel: VBoxContainer = _card(parent,"",16)
	_copy(duel,"YOUR NEXT RIVAL",18,MenuStyle.MUTED)
	if not gap.ahead.is_empty():
		_copy(duel,str(gap.ahead.name).to_upper(),38)
		_copy(duel,WeeklyRivalry.gap_text(int(gap.own.ms)-int(gap.ahead.ms))+" ahead of you",22,MenuStyle.ACCENT)
	elif gap.own.get("ms") == null:
		_copy(duel,"SET THE PACE",32)
		_copy(duel,"Your first finish puts you on the board.",17,MenuStyle.MUTED)
	else:
		_copy(duel,"DEFEND THE LEAD",32)
		_copy(duel,"Push your best further.",19,MenuStyle.MUTED)
	_space(duel)
	_copy(duel,"Race with ghost",18,MenuStyle.MUTED)
	var selector := OptionButton.new()
	selector.name = "RivalryGhostSelector"
	selector.custom_minimum_size = Vector2(0,54)
	selector.fit_to_longest_item = false
	selector.add_theme_font_size_override("font_size",17)
	selector.add_item(str(gap.ahead.name)+" (#"+str(gap.ahead.rank)+")" if not gap.ahead.is_empty() else "Rival ahead · unavailable")
	selector.add_item("Leader: "+str(gap.leader.name) if not gap.leader.is_empty() else "Weekly leader · unavailable")
	selector.add_item("My weekly PB")
	selector.add_item("No ghost")
	selector.set_item_disabled(0,gap.ahead.is_empty())
	selector.set_item_disabled(1,gap.leader.is_empty())
	selector.set_item_disabled(2,gap.own.get("ms") == null)
	if selector.is_item_disabled(ghost_choice): ghost_choice = 3
	selector.select(ghost_choice)
	duel.add_child(selector)
	var ghost_copy := _copy(duel,"Your recorded weekly best." if ghost_choice == 2 else "Drive without a ghost." if ghost_choice == 3 else "Follow your rival and find time.",15,MenuStyle.MUTED)
	selector.item_selected.connect(func(index: int) -> void:
		ghost_choice = index
		ghost_copy.text = "Your recorded weekly best." if index == 2 else "Drive without a ghost." if index == 3 else "Follow the rival's verified recording.")
	var race: Button = _action(duel,"RACE "+str(track.name).to_upper()+"  →","RivalryStartRace",func() -> void: race_requested.emit(selected,ghost_choice),true)
	race.disabled = busy or model.status != "active" or not bool(track.get("available",true))
	if not bool(track.get("available",true)): _copy(duel,"This track is unavailable for racing.",15,MenuStyle.MUTED)
	if not error.is_empty(): _copy(duel,error,15,MenuStyle.MUTED)

func _standings(parent: Control) -> void:
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = 1.6
	field.add_theme_constant_override("separation",10)
	parent.add_child(field)
	_podium(field)
	var table: VBoxContainer = _card(field,"",14)
	_copy(table,"OVERALL STANDINGS",28)
	var scroll := ScrollContainer.new()
	scroll.name = "RivalryStandingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",4)
	scroll.add_child(rows)
	for row: Dictionary in model.standing():
		_table_row(rows,row,str(row.get("completed",0))+" / 5    "+str(row.points)+" pts")
	var context: VBoxContainer = _card(parent,"winter",20)
	_copy(context,"YOUR CHAMPIONSHIP",20,MenuStyle.MUTED)
	var own: Dictionary = WeeklyRivalry.self_row(model.standing())
	_rank(context,own,model.standing().size(),68)
	_copy(context,str(own.points)+" POINTS",30,MenuStyle.ACCENT)
	_gaps(context)
	_space(context)
	_copy(context,"Five circuits.
Every best counts.",32)
	_action(context,"CHOOSE YOUR NEXT TRACK","RivalryStandingsTracks",func() -> void: section_requested.emit("overview"),true)

func _result(parent: Control) -> void:
	var index: int = clampi(selected,0,model.tracks.size()-1)
	var result: Dictionary = model.last_result
	var preview: bool = pending_result and bool(result.get("provisional",false))
	var scene: VBoxContainer = _card(parent,str(model.tracks[index].theme),26)
	scene.get_parent().size_flags_stretch_ratio = 1.3
	scene.add_child(Badge.view(str(model.tracks[index].theme),16))
	_copy(scene,str(model.tracks[index].name).to_upper(),36)
	_space(scene)
	_copy(scene,"PROVISIONAL RESULT" if preview else "VERIFYING YOUR RACE" if pending_result else "NEW WEEKLY BEST" if result.get("improved",false) else "RACE COMPLETE",23,MenuStyle.MUTED if pending_result else MenuStyle.POSITIVE)
	if result.has("ms"): _copy(scene,MenuStyle.time_text(int(result.ms)/1000.0),76)
	_copy(scene,"Based on current standings · verification pending." if preview else "Your weekly result updates after replay verification." if pending_result else "Your best result counts. Race again anytime.",19,MenuStyle.MUTED)
	var feedback: VBoxContainer = _card(parent,"",24)
	if pending_result and not preview:
		_copy(feedback,"RESULT SAVED",32)
		_copy(feedback,"Checking your race…",24,MenuStyle.ACCENT)
		_copy(feedback,"Your standings will update automatically.",18,MenuStyle.MUTED)
	elif result.has_all(["before","after","overall_before","overall_after"]):
		_copy(feedback,"EXPECTED TRACK POSITION" if preview else "POSITION IMPROVED" if result.get("improved",false) and result.before.get("rank") != result.after.get("rank") else "YOUR TRACK POSITION",18,MenuStyle.ACCENT if preview else MenuStyle.POSITIVE)
		_copy(feedback,rank_text(result.before)+"  →  "+rank_text(result.after),64,MenuStyle.ACCENT)
		var beaten: Array = result.get("beaten",[])
		if not beaten.is_empty():
			var nearest: Dictionary = beaten[-1]
			_copy(feedback,("Ahead of %s by %.3f s" if preview else "You beat %s by %.3f s") % [str(nearest.name),(int(nearest.ms)-int(result.ms))/1000.0],21)
		_copy(feedback,"Weekly points  +%d" % int(result.get("points_delta",0)),28,MenuStyle.ACCENT)
		_copy(feedback,"Overall "+rank_text(result.overall_before)+"  →  "+rank_text(result.overall_after),20,MenuStyle.MUTED)
		if preview: _copy(feedback,"Final standings update after verification.",18,MenuStyle.MUTED)
	else:
		_copy(feedback,"WEEKLY BEST UNCHANGED",32)
		_copy(feedback,"This attempt has no verified rivalry result.",20,MenuStyle.MUTED)
	if not error.is_empty(): _copy(feedback,error,18,MenuStyle.MUTED)
	_space(feedback)
	_action(feedback,"RACE AGAIN","RivalryRaceAgain",func() -> void: retry_requested.emit()).disabled = busy or model.status != "active"
	_action(feedback,"BACK TO RIVALRY  →","RivalryResultHome",func() -> void: section_requested.emit("overview"),true)

func _finale(parent: Control) -> void:
	_championship(parent,true)

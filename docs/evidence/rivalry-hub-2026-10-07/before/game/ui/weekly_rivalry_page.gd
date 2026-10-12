class_name WeeklyRivalryPage
extends VBoxContainer
## One question per view, using the same scenic art and controls as Free Race.
signal section_requested(section: String)
signal track_requested(index: int)
signal race_requested(index: int, ghost_choice: int)
signal free_race_requested
signal join_requested
signal refresh_requested
signal continue_requested
signal retry_requested
signal test_population_requested(enabled: bool)
var model: WeeklyRivalry
var section: String = "overview"
var selected: int = 0
var busy: bool = false
var error: String = ""
var signed_in: bool = false
var pending_result: bool = false
var test_drivers_available: bool = false
var test_population: bool = false
var ghost_choice: int = 0
var clock_label: Label
const Badge = preload("res://ui/biome_badge.gd")

func _ready() -> void:
	name = "WeeklyRivalryPage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	for id: String in ["overview","tracks","standings"]:
		var tab := MenuStyle.tab(id.to_upper(),func() -> void: section_requested.emit(id),section == id or (section == "detail" and id == "tracks"))
		tab.name = "RivalryTab_"+id
		tab.custom_minimum_size = Vector2(116,52)
		tab.add_theme_font_size_override("font_size",19)
		header.add_child(tab)
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
	var notice: String = "TEST RIVALRY · Artificial drivers · Verified races" if model.test_population else ("Placement group · Building your pace profile" if model.placement else "Matched by verified pace")+"   ·   "+VehicleCatalog.title(model.vehicle_id)
	var foot := MenuStyle.label("CONCEPT PREVIEW · Sample drivers and results" if model.sample else notice,14,true)
	foot.name = "RivalryDataNotice"
	foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(foot)
	if test_drivers_available:
		var toggle := MenuStyle.button("TEST RIVALS: ON" if test_population else "TEST RIVALS: OFF",func() -> void: test_population_requested.emit(not test_population))
		toggle.name = "RivalryTestPopulation"
		toggle.custom_minimum_size = Vector2(188,48)
		toggle.add_theme_font_size_override("font_size",15)
		toggle.disabled = busy or pending_result
		footer.add_child(toggle)

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
		gradient.colors = PackedColorArray([Color("07152070"),Color("06121bd9"),Color("06121bfa")])
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
	var hero: VBoxContainer = _card(parent,"winter",26)
	hero.get_parent().size_flags_stretch_ratio = 1.6
	_copy(hero,"FIVE TRACKS. ONE RIVALRY.",18,MenuStyle.ACCENT)
	_copy(hero,"MAKE THIS\nYOUR WEEK.",56 if model.forming else 66)
	_copy(hero,"%d drivers · Best results count" % model.standing().size(),22,MenuStyle.MUTED)
	if model.forming: _copy(hero,"Your group is forming. More drivers can join this week.",17,MenuStyle.MUTED)
	_space(hero)
	var index: int = model.opportunity()
	_action(hero,"CONTINUE RIVALRY  →","RivalryContinue",func() -> void: track_requested.emit(index),true).disabled = model.status != "active"
	var opportunity := MenuStyle.button("",func() -> void: track_requested.emit(index))
	opportunity.name = "RivalryOpportunity"
	opportunity.custom_minimum_size.y = 78
	hero.add_child(opportunity)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opportunity.add_child(line)
	MenuStyle.fill(line)
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(model.tracks[index].theme)
	art.custom_minimum_size = Vector2(88,72)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(art)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(copy)
	_copy(copy,str(model.tracks[index].name)+" is your next opportunity",20)
	var gap: Dictionary = model.gaps(index)
	_copy(copy,(WeeklyRivalry.gap_text(int(gap.own.ms)-int(gap.ahead.ms))+" to gain a position") if not gap.ahead.is_empty() else "Set your first time and enter the battle" if gap.own.get("ms") == null else "You're leading here. Push your best further.",16,MenuStyle.MUTED)
	_copy(line,"→",28,MenuStyle.ACCENT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(side)
	var position: VBoxContainer = _card(side)
	_copy(position,"YOUR POSITION",18,MenuStyle.MUTED)
	_rank(position,WeeklyRivalry.self_row(model.standing()),model.standing().size())
	_gaps(position)
	var leaders: VBoxContainer = _card(side)
	leaders.add_theme_constant_override("separation",6)
	_copy(leaders,"LEADING THE WEEK" if model.standing()[0].get("rank") != null else "THE FIELD",18,MenuStyle.MUTED)
	for row: Dictionary in model.standing().slice(0,3): _table_row(leaders,row,str(row.points))
	_space(leaders)

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
		_copy(duel,"SET THE PACE",38)
		_copy(duel,"Your first finish puts you on the board.",19,MenuStyle.MUTED)
	else:
		_copy(duel,"DEFEND THE LEAD",34)
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
	var table: VBoxContainer = _card(parent,"",16)
	table.get_parent().size_flags_stretch_ratio = 1.1
	_copy(table,"OVERALL STANDINGS",32)
	var scroll := ScrollContainer.new()
	scroll.name = "RivalryStandingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",4)
	scroll.add_child(rows)
	for row: Dictionary in model.standing(): _table_row(rows,row,str(row.points)+" pts")
	var context: VBoxContainer = _card(parent,"winter",26)
	_copy(context,"THE CHAMPIONSHIP",18,MenuStyle.MUTED)
	_rank(context,WeeklyRivalry.self_row(model.standing()),model.standing().size(),72)
	_gaps(context)
	_space(context)
	_copy(context,"Every track is a chance\nto move up.",38)
	_action(context,"FIND YOUR NEXT DUEL  →","RivalryStandingsTracks",func() -> void: section_requested.emit("tracks"),true)

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
	var body: VBoxContainer = _card(parent,"winter",20)
	_copy(body,"WEEK %02d COMPLETE" % model.week,40)
	var own: Dictionary = WeeklyRivalry.self_row(model.standing())
	_copy(body,"You finished "+rank_text(own)+" / "+str(model.standing().size()) if own.get("rank") != null else "Next week is another chance to set your pace.",22,MenuStyle.ACCENT)
	var podium := HBoxContainer.new()
	podium.name = "RivalryPodium"
	podium.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(podium)
	var leaders: Array[Dictionary] = []
	for driver: Dictionary in model.standing():
		if driver.get("rank") != null and leaders.size() < 3: leaders.append(driver)
	for position: int in [1,0,2]:
		if position >= leaders.size(): continue
		var column: VBoxContainer = _card(podium,"",12)
		_space(column)
		_copy(column,rank_text(leaders[position]),38,MenuStyle.ACCENT if position == 0 else MenuStyle.MUTED)
		_copy(column,str(leaders[position].name),26)
		_copy(column,str(leaders[position].points)+" pts",20,MenuStyle.ACCENT)
		if position == 0: _copy(column,"WEEKLY WINNER",14,MenuStyle.ACCENT)
	var summary := HBoxContainer.new()
	body.add_child(summary)
	_copy(summary,"%d track wins" % model.wins(),23)
	_copy(summary,"%d / 5 tracks completed" % int(own.get("completed",5 if model.sample else 0)),23,MenuStyle.MUTED)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	_action(actions,"VIEW FULL RESULTS","RivalryFullResults",func() -> void: section_requested.emit("standings"))
	_action(actions,"CONTINUE  →","RivalryNextWeek",func() -> void: continue_requested.emit(),true).disabled = busy

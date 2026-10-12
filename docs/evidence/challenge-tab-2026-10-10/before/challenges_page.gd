class_name ChallengesPage
extends VBoxContainer
signal mode_requested(mode: String)
signal folder_requested(folder: String)
signal selected_requested(code: String)
signal create_requested
signal code_requested
signal race_requested
signal share_requested
signal rematch_requested
signal cancel_requested
signal refresh_requested
signal more_requested
signal sign_in_requested
signal back_requested
var items: Array[Dictionary] = []
var selected: Dictionary = {}
var folder: String = "received"
var signed_in: bool = false
var busy: bool = false
var error: String = ""
var result_view: bool = false
var result_state: String = ""
var outcome: Dictionary = {}
var has_more: bool = false
var _received_at: int = 0
var _clock: Label

func _ready() -> void:
	name = "ChallengesPage"
	_received_at = Time.get_ticks_msec()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	var root := HBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation",18)
	add_child(root)
	var rail := RaceModeRail.new()
	rail.selected = "challenges"
	rail.mode_requested.connect(func(mode: String) -> void: mode_requested.emit(mode))
	if not result_view: root.add_child(rail)
	else: rail.free()
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation",12)
	root.add_child(main)
	var header := HBoxContainer.new()
	header.name = "ChallengeHeader"
	header.add_theme_constant_override("separation",12)
	main.add_child(header)
	var title := MenuStyle.label("CHALLENGES",34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if result_view:
		_action(header,"Back to Challenges",func() -> void: back_requested.emit())
	else:
		_action(header,"Enter code",func() -> void: code_requested.emit())
		_action(header,"Create challenge",func() -> void: create_requested.emit(),true)
		var refresh := _action(header,"",func() -> void: refresh_requested.emit())
		refresh.icon = MenuIcon.texture("restart")
		refresh.tooltip_text = "Refresh challenges"
		refresh.custom_minimum_size.x = 52
	if not error.is_empty():
		var notice := MenuStyle.label(error,17,true)
		notice.name = "ChallengeNotice"
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		main.add_child(notice)
	var body := HBoxContainer.new()
	body.name = "ChallengeBody"
	body.add_theme_constant_override("separation",18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	if not result_view: _inbox(body)
	if not selected.is_empty(): _detail(body)
	elif signed_in:
		var blank := _panel(body)
		blank.add_child(MenuStyle.label("Choose a challenge" if not items.is_empty() else "No received challenges" if folder == "received" else "No sent challenges",26))
		var scene := TextureRect.new()
		scene.texture = TrackTile.scenery_texture("pine")
		scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
		blank.add_child(scene)
	else:
		var blank := _panel(body)
		blank.add_child(MenuStyle.label("Race your friends' times",30))
		_action(blank,"Sign in",func() -> void: sign_in_requested.emit(),true)

func _inbox(parent: Control) -> void:
	var column := VBoxContainer.new()
	column.name = "ChallengeInbox"
	column.custom_minimum_size.x = 290
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 0.72
	parent.add_child(column)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for id: String in ["received","sent"]:
		var button := MenuStyle.tab(id.capitalize(),func() -> void: folder_requested.emit(id),folder == id)
		button.name = "ChallengeTab_"+id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 52
		tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.name = "ChallengeInboxScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right",16)
	scroll.add_child(gutter)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation",10)
	gutter.add_child(list)
	for item: Dictionary in items:
		var target: String = "%.3f s" % (float(item.target_ms)/1000.0) if item.get("target_ms") != null else "Group challenge"
		var tile := MenuStyle.button("",func() -> void: selected_requested.emit(str(item.code)))
		tile.name = "ChallengeCard_"+str(item.code)
		tile.custom_minimum_size.y = 120 if item.state == "active" else 140
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(tile)
		var fill := MarginContainer.new()
		MenuStyle.fill(fill)
		for side: String in ["left","right","top","bottom"]: fill.add_theme_constant_override("margin_"+side,12)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(fill)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.add_child(row)
		var image := TextureRect.new()
		image.texture = TrackTile.scenery_texture(str(item.entry.get("theme","pine")))
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.custom_minimum_size.x = 70
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		var lines: Array = [[item.entry.name,21],[str(item.creator),15],[target,21]]
		if item.state != "active": lines.append([str(item.state).capitalize(),14])
		for data: Array in lines:
			var label := MenuStyle.label(str(data[0]),int(data[1]),int(data[1]) < 20)
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info.add_child(label)
		if str(item.code) == str(selected.get("code","")):
			var style := MenuStyle.box(Color("294352"),10)
			style.border_color = MenuStyle.ACCENT
			style.set_border_width_all(1)
			tile.add_theme_stylebox_override("normal",style)
	if has_more: _action(list,"More",func() -> void: more_requested.emit())

func _detail(parent: Control) -> void:
	var column := _panel(parent)
	column.name = "ChallengeDetail"
	var heading := MenuStyle.label(str(selected.entry.name),30)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(heading)
	var line := HBoxContainer.new()
	column.add_child(line)
	var creator := MenuStyle.label(str(selected.creator),17,true)
	creator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(creator)
	_clock = MenuStyle.label("",16,true)
	line.add_child(_clock)
	_update_clock()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_clock)
	add_child(timer)
	var preview := PanelContainer.new()
	preview.name = "ChallengeTrackPreview"
	preview.custom_minimum_size.y = 132
	preview.add_theme_stylebox_override("panel",MenuStyle.box(Color("091720"),0))
	column.add_child(preview)
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(str(selected.entry.get("theme","pine")))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.add_child(art)
	var overlay := HBoxContainer.new()
	preview.add_child(overlay)
	var route := LapRouteView.new()
	route.name = "ChallengeRoute"
	route.miniature = true
	route.custom_minimum_size.x = 130
	route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for point: Array in selected.entry.points: route.route.append(Vector2(point[0],point[1]))
	overlay.add_child(route)
	var time_box := VBoxContainer.new()
	time_box.custom_minimum_size.x = 170
	time_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	overlay.add_child(time_box)
	var target: Variant = selected.get("target_ms")
	if target == null and not selected.standings.is_empty(): target = selected.standings[0].ms
	var clock := MenuStyle.label("%.3f" % (float(target)/1000.0) if target != null else "—",46)
	clock.name = "ChallengeTargetTime"
	clock.add_theme_color_override("font_color",MenuStyle.ACCENT)
	time_box.add_child(clock)
	time_box.add_child(MenuStyle.label("Target time" if selected.mode == "beat" else "Leading time",16))
	column.add_child(MenuStyle.label("5 laps · "+VehicleCatalog.title(str(selected.vehicle_id)),16,true))
	var exhausted: bool = selected.get("attempts_remaining") != null and int(selected.attempts_remaining) <= 0
	if selected.get("attempt_limit") != null:
		column.add_child(MenuStyle.label("No tries remaining" if exhausted else "%d of %d tries remaining" % [int(selected.attempts_remaining),int(selected.attempt_limit)],16,true))
	if result_view:
		var feedback: String = "Verifying"
		if result_state == "verified" and outcome.get("counted",false):
			feedback = "Target beaten" if outcome.get("beaten",false) and selected.mode == "beat" else "Time verified"
			if outcome.get("gap_ms") != null: feedback += "  %+.3f s" % (float(outcome.gap_ms)/1000.0)
		elif result_state in ["rejected","expired"]: feedback = "Not counted"
		elif result_state == "verified": feedback = "Not counted"
		var status := MenuStyle.label(feedback,23)
		status.name = "ChallengeResultFeedback"
		column.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.name = "ChallengeStandingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right",16)
	scroll.add_child(gutter)
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation",4)
	gutter.add_child(table)
	for row: Dictionary in selected.standings:
		var card := PanelContainer.new()
		var own: bool = str(row.id) == str(selected.self_id)
		card.name = "ChallengeDriver_"+str(row.id)
		card.add_theme_stylebox_override("panel",MenuStyle.box(MenuStyle.ACCENT if own else Color("172b38"),8))
		table.add_child(card)
		var values := HBoxContainer.new()
		card.add_child(values)
		for index: int in range(3):
			var text: String = str(int(row.rank)) if index == 0 and row.rank != null else "—" if index == 0 else str(row.name) if index == 1 else "%.3f" % (float(row.ms)/1000.0) if row.ms != null else "—"
			var label := MenuStyle.label(text,19)
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.add_theme_color_override("font_color",MenuStyle.INK if own else MenuStyle.TEXT)
			if index == 1: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else: label.custom_minimum_size.x = 24 if index == 0 else 70
			values.add_child(label)
	var actions := HBoxContainer.new()
	actions.name = "ChallengeActions"
	actions.add_theme_constant_override("separation",8)
	column.add_child(actions)
	_action(actions,"Share",func() -> void: share_requested.emit())
	var own: Dictionary = {}
	for row: Dictionary in selected.standings:
		if row.id == selected.self_id: own = row
	var winning: bool = own.get("ticks") != null and (int(own.rank) == 1 if selected.mode == "group" else int(own.ticks) < int(selected.target_ticks))
	if winning: _action(actions,"Rematch",func() -> void: rematch_requested.emit())
	if str(selected.creator_id) == str(selected.self_id) and selected.state == "active":
		var cancel := _action(actions,"×",func() -> void: cancel_requested.emit())
		cancel.tooltip_text = "Cancel challenge"
		cancel.custom_minimum_size.x = 52
	var race := _action(actions,"Race again" if result_view else "Race" if selected.joined else "Join & race" if signed_in else "Try track",func() -> void: race_requested.emit(),true)
	race.name = "ChallengeRace"
	race.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	race.disabled = busy or exhausted or selected.state != "active" or (selected.mode == "beat" and selected.creator_id == selected.self_id)

func _update_clock() -> void:
	if _clock == null: return
	var remaining: int = maxi(0,int(selected.ends_at)-int(selected.server_now)-(Time.get_ticks_msec()-_received_at)/1000)
	_clock.text = str(selected.state).capitalize() if selected.state != "active" else "%dd %02dh" % [remaining/86400,(remaining%86400)/3600] if remaining >= 86400 else "%02dh %02dm" % [remaining/3600,(remaining%3600)/60]

func _action(parent: Control, title: String, action: Callable, primary: bool = false) -> Button:
	var button := MenuStyle.button(title,action,primary)
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size",20)
	button.disabled = busy
	parent.add_child(button)
	return button

func _panel(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",MenuStyle.box(Color("091720ee"),14))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	return column

class_name ChallengesPage
extends VBoxContainer
signal stage_requested(index: int)
var selected_stage: int = 0
signal mode_requested(mode: String)
signal folder_requested(folder: String)
signal selected_requested(code: String)
signal filters_requested(query: String, mode: String, vehicle: String, order: String)
signal create_requested
signal browse_requested
signal landing_requested
signal code_requested
signal race_requested
signal share_requested
signal rematch_requested
signal cancel_requested
signal refresh_requested
signal more_requested
signal sign_in_requested
signal back_requested
var safety_client: Node
var items: Array[Dictionary] = []
var selected: Dictionary = {}
var folder: String = "discover"
var search: String = ""
var mode_filter: String = "all"
var vehicle_filter: String = ""
var sort_order: String = "ending"
var _search: LineEdit
var _mode: OptionButton
var _vehicle: OptionButton
var _sort: OptionButton
var signed_in: bool = false
var busy: bool = false
var error: String = ""
var result_view: bool = false
var landing_view: bool = false
var result_state: String = ""
var outcome: Dictionary = {}
var has_more: bool = false
var _received_at: int = 0
var _clock: Label

func _ready() -> void:
	name = "ChallengesPage"
	theme = MenuStyle.theme()
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
	var title := MenuStyle.label("CHALLENGES" if landing_view and not result_view else "CHALLENGE CLUB",34)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if result_view:
		_action(header,"Back to Challenges",func() -> void: back_requested.emit())
	elif landing_view:
		_landing(main)
		return
	else:
		var back := _action(header,"Back",func() -> void: landing_requested.emit())
		back.name = "ChallengeBrowseBack"
		back.disabled = false
		_action(header,"Create challenge",_request_creation,true)
		var refresh := _action(header,"",func() -> void: refresh_requested.emit())
		refresh.icon = MenuIcon.texture("restart")
		refresh.tooltip_text = "Refresh challenges"
		refresh.custom_minimum_size.x = 52
	if not result_view:
		var intro := MenuStyle.label("Find your next rival. Set a time. Make it count.",17,true)
		intro.name = "ChallengeIntroduction"
		main.add_child(intro)
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation",8)
		main.add_child(tabs)
		for id: String in ["discover","friends","received","sent"]:
			var caption: String = {"discover":"Discover","friends":"Friends","received":"Joined","sent":"Created"}[id]
			var button := MenuStyle.tab(caption,func() -> void: folder_requested.emit(id),folder == id)
			button.name = "ChallengeTab_"+id
			button.custom_minimum_size.y = 52
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tabs.add_child(button)
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
	if not selected.is_empty():
		if result_view: _detail(body)
		else: _hub_detail(body)
	elif signed_in or folder == "discover":
		var blank := _panel(body)
		blank.name = "ChallengeEmptyState"
		blank.add_child(MenuStyle.label("Choose your next race" if not items.is_empty() else "Finding challenges…" if busy else "Start something worth chasing",30))
		var scene := TextureRect.new()
		scene.texture = TrackTile.scenery_texture("pine")
		scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
		blank.add_child(scene)
		var help := MenuStyle.label("No matches. Try a different search or car." if not search.is_empty() or mode_filter != "all" or not vehicle_filter.is_empty() else "Your friends' public challenges appear here." if folder == "friends" else "Browse Discover and join a race directly." if folder == "received" else "Create a public challenge and let your next rival find you.",19,true)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blank.add_child(help)
		_action(blank,"Create challenge" if signed_in else "Sign in to compete",_request_creation,true)
	else:
		var blank := _panel(body)
		blank.add_child(MenuStyle.label("Bring your friends. Find your rivals.",30))
		_action(blank,"Sign in",func() -> void: sign_in_requested.emit(),true)

func _landing(parent: Control) -> void:
	var intro := MenuStyle.label("Find a challenge to race, or start one of your own.",19,true)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.name = "ChallengeEntryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var choices := GridContainer.new()
	choices.name = "ChallengeEntryChoices"
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("h_separation",18)
	choices.add_theme_constant_override("v_separation",18)
	scroll.add_child(choices)
	var layout := func() -> void: choices.columns = 2 if scroll.size.x >= 560 else 1
	scroll.resized.connect(layout)
	layout.call()
	_entry_card(choices,"Find & play","Browse challenges and join your next race.","entry-find-play-v1",func() -> void: browse_requested.emit(),"ChallengeFindAndPlay")
	_entry_card(choices,"Create a challenge","Choose the format, tracks and car. Invite your rivals.","entry-create-v1",_request_creation,"ChallengeCreateNew")

func _request_creation() -> void:
	if signed_in: create_requested.emit()
	else: sign_in_requested.emit()

func _entry_card(parent: Control, title: String, description: String, poster: String, action: Callable, node_name: String) -> void:
	var card := MenuStyle.button(title,action)
	card.name = node_name
	card.tooltip_text = title+". "+description
	card.custom_minimum_size = Vector2(220,160)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	for state: String in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		card.add_theme_color_override(state,Color.TRANSPARENT)
	card.add_theme_font_size_override("font_size",1)
	parent.add_child(card)
	var content := VBoxContainer.new()
	MenuStyle.fill(content)
	content.offset_left = 3
	content.offset_top = 3
	content.offset_right = -3
	content.offset_bottom = -3
	content.add_theme_constant_override("separation",0)
	card.add_child(content)
	var art := TextureRect.new()
	art.texture = load("res://assets/menu/challenges/"+poster+".png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.custom_minimum_size.y = 48
	content.add_child(art)
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",MenuStyle.box(Color("091720"),16))
	content.add_child(footer)
	var copy := VBoxContainer.new()
	footer.add_child(copy)
	var caption := MenuStyle.label(title+"  ›",30)
	caption.add_theme_color_override("font_color",MenuStyle.ACCENT)
	copy.add_child(caption)
	var detail := MenuStyle.label(description,17,true)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(detail)
	# The complete poster remains one pointer/touch and keyboard target.
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Control in content.find_children("*","Control",true,false): child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _inbox(parent: Control) -> void:
	var column := VBoxContainer.new()
	column.name = "ChallengeInbox"
	column.custom_minimum_size.x = 290
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 0.62
	column.add_theme_constant_override("separation",12)
	parent.add_child(column)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation",6)
	column.add_child(search_row)
	_search = LineEdit.new()
	_search.name = "ChallengeSearch"
	_search.placeholder_text = "Find a track or driver"
	_search.text = search
	_search.max_length = 80
	_search.custom_minimum_size.y = 52
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_submitted.connect(func(_value: String) -> void: _apply_filters())
	search_row.add_child(_search)
	var find := _action(search_row,"Find",_apply_filters)
	find.name = "ChallengeFind"
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation",6)
	column.add_child(filters)
	_mode = _choice(filters,"ChallengeModeFilter",["All races","Beat a time","Group races","3×3"],["all","beat","group","3x3"],mode_filter)
	_vehicle = _choice(filters,"ChallengeCarFilter",["Any car","Compact","Pickup","Classic","Formula","Kart"],["","compact","pickup","classic","formula","kart"],vehicle_filter)
	_sort = _choice(filters,"ChallengeSort",["Ending soon","Newest first"] if folder in ["discover","friends"] else ["Newest first"],["ending","newest"] if folder in ["discover","friends"] else ["newest"],sort_order)
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
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	gutter.add_child(list)
	for item: Dictionary in items:
		var target: Variant = _target_ms(item)
		var tile := MenuStyle.button("",func() -> void: selected_requested.emit(str(item.code)))
		tile.name = "ChallengeCard_"+str(item.code)
		tile.custom_minimum_size.y = 154
		tile.clip_contents = true
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(tile)
		var fill := MarginContainer.new()
		MenuStyle.fill(fill)
		for side: String in ["left","right","top","bottom"]: fill.add_theme_constant_override("margin_"+side,12)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(fill)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.add_child(row)
		var image := TextureRect.new()
		image.texture = TrackTile.scenery_texture(str(item.entry.get("theme","pine")))
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.custom_minimum_size.x = 80
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
		var route := LapRouteView.new()
		route.miniature = true
		route.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyle.fill(route)
		route.route = _card_outline(item.entry.points)
		image.add_child(route)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation",2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		var competition: String = "TIME ATTACK" if item.mode == "beat" else "3×3" if item.mode == "3x3" else "GROUP RACE"
		var performance: String = MenuStyle.time_text(float(target)/1000.0) if target != null else "Set the first time"
		var lines: Array = [[competition+" · "+_remaining_text(item),14],[item.entry.name,25],[str(item.creator),15],[performance,24],[_reward_caption(item),15]]
		for data: Array in lines:
			var label := MenuStyle.label(str(data[0]),int(data[1]),int(data[1]) < 20)
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info.add_child(label)
			if int(data[1]) == 24 or str(data[0]) == _reward_caption(item): label.add_theme_color_override("font_color",MenuStyle.ACCENT)
		if str(item.code) == str(selected.get("code","")):
			var style := MenuStyle.box(Color("1b3443"),10)
			style.border_color = MenuStyle.ACCENT
			style.border_width_left = 3
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_width_right = 1
			tile.add_theme_stylebox_override("normal",style)
	if has_more: _action(list,"More",func() -> void: more_requested.emit())

func _stage_picker(parent: Control) -> void:
	if selected.get("mode") != "3x3": return
	parent.add_child(MenuStyle.label("3 TRACKS · 3 TRIES EACH · LOWEST TOTAL TIME WINS",16,true))
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation",6)
	parent.add_child(choices)
	for stage: Dictionary in selected.stages:
		var button := MenuStyle.tab(str(int(stage.index)+1)+"  "+str(stage.entry.name)+"  ·  "+str(stage.attempts_remaining)+" tries left",func() -> void: stage_requested.emit(int(stage.index)),int(stage.index) == selected_stage)
		button.name = "ChallengeStage_"+str(int(stage.index))
		button.disabled = busy
		button.custom_minimum_size.y = 52
		choices.add_child(button)

func _stage_data() -> Dictionary:
	return selected.stages[selected_stage] if selected.get("mode") == "3x3" else selected

func _hub_detail(parent: Control) -> void:
	# Race browsing has its own composition; post-race feedback keeps _detail.
	var panel := _panel(parent)
	panel.name = "ChallengeDetail"
	var content_scroll := ScrollContainer.new()
	content_scroll.name = "ChallengeDetailScroll"
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(content_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	content_scroll.add_child(column)
	_stage_picker(column)
	var heading := MenuStyle.label(str(_stage_data().entry.name),32)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(heading)
	var identity := HBoxContainer.new()
	column.add_child(identity)
	var competition: String = "Your challenge" if selected.mode == "beat" and selected.creator_id == selected.self_id else "Beat "+str(selected.creator)+"'s time" if selected.mode == "beat" else "Group challenge · "+str(selected.creator)
	var creator := MenuStyle.label(competition,17,true)
	creator.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	creator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(creator)
	_clock = MenuStyle.label("",16,true)
	identity.add_child(_clock)
	_update_clock()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_clock)
	add_child(timer)
	var preview := HBoxContainer.new()
	preview.name = "ChallengeTrackPreview"
	preview.custom_minimum_size.y = 118
	preview.add_theme_constant_override("separation",0)
	column.add_child(preview)
	var scenery := PanelContainer.new()
	scenery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scenery.clip_contents = true
	scenery.add_theme_stylebox_override("panel",MenuStyle.box(Color("102632"),10))
	preview.add_child(scenery)
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(str(_stage_data().entry.get("theme","pine")))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(0.83,0.87,0.9)
	scenery.add_child(art)
	var route := LapRouteView.new()
	route.name = "ChallengeRoute"
	route.miniature = true
	for point: Array in _stage_data().entry.points: route.route.append(Vector2(point[0],point[1]))
	scenery.add_child(route)
	var performance := PanelContainer.new()
	performance.custom_minimum_size.x = 242
	performance.add_theme_stylebox_override("panel",MenuStyle.box(Color("122a38"),12))
	preview.add_child(performance)
	var time_box := VBoxContainer.new()
	time_box.add_theme_constant_override("separation",2)
	time_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	performance.add_child(time_box)
	var target: Variant = _target_ms(selected)
	time_box.add_child(MenuStyle.label("Time to beat" if selected.mode == "beat" else "Leading total" if selected.mode == "3x3" and target != null else "Leading time" if target != null else "3×3 total" if selected.mode == "3x3" else "Group challenge",16,true))
	var clock := MenuStyle.label(MenuStyle.time_text(float(target)/1000.0) if target != null else "Set the first time",44 if target != null else 28)
	clock.name = "ChallengeTargetTime"
	clock.add_theme_color_override("font_color",MenuStyle.ACCENT)
	time_box.add_child(clock)
	var own: Dictionary = _own_standing()
	if own.get("ms") != null:
		var best := MenuStyle.label("Your best  "+MenuStyle.time_text(float(own.ms)/1000.0),17)
		best.name = "ChallengePersonalBest"
		time_box.add_child(best)
		if target != null:
			var difference: int = int(own.ms)-int(target)
			var shared_lead: bool = selected.mode != "beat" and selected.standings.any(func(row: Dictionary) -> bool: return row.get("ms") != null and int(row.ms) == int(target) and str(row.id) != str(selected.self_id))
			var gap := MenuStyle.label("Target beaten" if difference < 0 and selected.mode == "beat" else "Joint lead" if difference == 0 and shared_lead else "You lead" if difference == 0 and selected.mode != "beat" else "Tied with target" if difference == 0 else "%+.3f s" % (float(difference)/1000.0),18,true)
			gap.name = "ChallengePersonalGap"
			if difference < 0 or (difference == 0 and selected.mode != "beat"): gap.add_theme_color_override("font_color",MenuStyle.POSITIVE)
			time_box.add_child(gap)
	var facts := HBoxContainer.new()
	column.add_child(facts)
	var car := MenuStyle.label("5 laps · "+VehicleCatalog.title(str(selected.vehicle_id)),16,true)
	car.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_child(car)
	if _stage_data().get("attempt_limit") != null:
		facts.add_child(MenuStyle.label("%d tries left" % int(_stage_data().attempts_remaining),16,true))
	facts.add_child(MenuStyle.label("%d / %d drivers" % [selected.standings.size(),int(selected.get("capacity",2 if selected.mode == "beat" else 20))],16,true))
	var heading_gutter := MarginContainer.new()
	heading_gutter.add_theme_constant_override("margin_left",6)
	heading_gutter.add_theme_constant_override("margin_right",30)
	column.add_child(heading_gutter)
	var labels := HBoxContainer.new()
	labels.name = "ChallengeStandingsHeader"
	heading_gutter.add_child(labels)
	_standing_values(labels,"#","Driver","Time","Gap (s)",true)
	var scroll := ScrollContainer.new()
	scroll.name = "ChallengeStandingsScroll"
	scroll.custom_minimum_size.y = 80
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right",12)
	scroll.add_child(gutter)
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation",4)
	gutter.add_child(table)
	for row: Dictionary in selected.standings:
		var card := PanelContainer.new()
		var player: bool = str(row.id) == str(selected.self_id)
		card.name = "ChallengeDriver_"+str(row.id)
		card.custom_minimum_size.y = 36
		card.add_theme_stylebox_override("panel",MenuStyle.box(MenuStyle.ACCENT if player else Color("172b38"),6))
		table.add_child(card)
		var values := HBoxContainer.new()
		card.add_child(values)
		var delta: String = "—"
		if row.get("ms") != null and target != null: delta = "%+.3f" % (float(int(row.ms)-int(target))/1000.0)
		_standing_values(values,str(row.rank) if row.rank != null else "—",str(row.name),MenuStyle.time_text(float(row.ms)/1000.0) if row.ms != null else str(int(row.get("completed_tracks",0)))+"/3 tracks" if selected.mode == "3x3" else "—",delta,false,player)
	_reward_strip(panel,selected)
	var actions := HBoxContainer.new()
	actions.name = "ChallengeActions"
	actions.add_theme_constant_override("separation",8)
	panel.add_child(actions)
	var share := _action(actions,"Share",func() -> void: share_requested.emit())
	share.icon = MenuIcon.texture("share")
	if is_instance_valid(safety_client) and str(selected.creator_id) != str(selected.self_id):
		var report := _action(actions,"…",func() -> void: preload("res://ui/community_safety_ui.gd").open(self,safety_client,"player",{"reported_player_id":str(selected.creator_id),"name":str(selected.creator)}))
		report.tooltip_text = "Report / block creator"
	var winning: bool = own.get("ticks") != null and (int(own.rank) == 1 if selected.mode != "beat" else int(own.ticks) < int(selected.target_ticks))
	if winning and selected.mode != "3x3": _action(actions,"Rematch",func() -> void: rematch_requested.emit())
	if str(selected.creator_id) == str(selected.self_id) and selected.state == "active":
		var cancel := _action(actions,"",func() -> void: cancel_requested.emit())
		cancel.icon = MenuIcon.texture("close")
		cancel.tooltip_text = "Cancel challenge"
		cancel.custom_minimum_size.x = 52
	var exhausted: bool = _stage_data().get("attempts_remaining") != null and int(_stage_data().attempts_remaining) <= 0
	var creator_target: bool = selected.mode == "beat" and selected.creator_id == selected.self_id
	var full: bool = not selected.joined and selected.standings.size() >= int(selected.get("capacity",2 if selected.mode == "beat" else 20))
	var caption: String = "No tries left" if exhausted else "Challenge ended" if selected.state != "active" else "Waiting for opponent" if creator_target else "Full" if full else "Race" if selected.joined else "Join & race" if signed_in else "Try track"
	var race := _action(actions,caption,func() -> void: race_requested.emit(),true)
	race.name = "ChallengeRace"
	race.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	race.disabled = busy or exhausted or full or selected.state != "active" or creator_target

func _choice(parent: Control, identity: String, titles: Array, values: Array, current: String) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = identity
	choice.custom_minimum_size.y = 52
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.fit_to_longest_item = false
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	choice.add_theme_font_size_override("font_size",17)
	for index: int in range(titles.size()):
		choice.add_item(str(titles[index]))
		choice.set_item_metadata(index,values[index])
		if str(values[index]) == current: choice.select(index)
	choice.item_selected.connect(func(_index: int) -> void: _apply_filters())
	parent.add_child(choice)
	return choice

func _apply_filters() -> void:
	filters_requested.emit(_search.text,str(_mode.get_selected_metadata()),str(_vehicle.get_selected_metadata()),str(_sort.get_selected_metadata()))

static func _card_outline(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count: int = mini(96,points.size())
	for index: int in range(count):
		var point: Array = points[index*(points.size()-1)/maxi(1,count-1)]
		result.append(Vector2(point[0],point[1]))
	return result

func _reward_caption(item: Dictionary) -> String:
	var rewards: Dictionary = item.get("rewards",{})
	if rewards.is_empty(): return "Challenge rewards unavailable"
	if item.mode == "beat" and str(item.creator_id) == str(item.self_id): return "Your target is live" if item.state == "active" else "Your challenge has ended"
	if not signed_in: return "Sign in to earn Coins"
	if rewards.get("finish_earned",false) and rewards.get("goal_earned",false): return "Rewards earned"
	if item.state != "active": return "Challenge ended"
	if not rewards.get("eligible",false): return "Daily reward limit reached"
	var amount: int = (0 if rewards.get("finish_earned",false) else int(rewards.get("finish",0)))+(0 if rewards.get("goal_earned",false) else int(rewards.get("goal",0)))
	return "Up to %d Coins" % amount

func _reward_strip(parent: Control, item: Dictionary) -> void:
	var rewards: Dictionary = item.get("rewards",{})
	if rewards.is_empty(): return
	if item.mode == "beat" and str(item.creator_id) == str(item.self_id):
		var invitation := MenuStyle.label("Your target is listed in Discover. Let your next rival come to you." if item.get("visibility","private") == "public" else "Share the invitation link to find an opponent for your target.",17,true)
		invitation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(invitation)
		return
	var goals := HBoxContainer.new()
	goals.name = "ChallengeRewards"
	goals.add_theme_constant_override("separation",8)
	parent.add_child(goals)
	for index: int in range(2):
		var earned: bool = bool(rewards.get("finish_earned" if index == 0 else "goal_earned",false))
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := MenuStyle.box(Color("193c36") if earned else Color("263329"),8)
		style.border_color = MenuStyle.POSITIVE if earned else Color("706238")
		style.border_width_left = 3
		card.add_theme_stylebox_override("panel",style)
		goals.add_child(card)
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation",0)
		card.add_child(lines)
		var goal: String = "Finish five laps" if index == 0 else "Beat the target" if item.mode == "beat" else "Outrun a rival & lead"
		var heading := MenuStyle.label(goal,15,true)
		heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lines.add_child(heading)
		var amount := MenuStyle.label("Earned" if earned else "Ended" if item.state != "active" else "Daily limit" if signed_in and not rewards.get("eligible",false) else "+%d Coins" % int(rewards.get("finish" if index == 0 else "goal",0)),23)
		amount.add_theme_color_override("font_color",MenuStyle.POSITIVE if earned else MenuStyle.ACCENT)
		lines.add_child(amount)
	var explanation := MenuStyle.label("Sign in to earn Coins for verified races." if not signed_in else "Daily reward limit reached. Return tomorrow for more Coins." if not rewards.get("eligible",false) else "Verified races · Rewards once each · %d new reward challenges left today (UTC)" % int(rewards.get("remaining_today",0)),14,true)
	explanation.name = "ChallengeRewardRules"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(explanation)

func _standing_values(parent: HBoxContainer, rank: String, driver: String, time: String, gap: String, header: bool = false, player: bool = false) -> void:
	parent.add_theme_constant_override("separation",8)
	for index: int in range(4):
		var label := MenuStyle.label([rank,driver,time,gap][index],15 if header else 19,header)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if player: label.add_theme_color_override("font_color",MenuStyle.INK)
		if index == 1: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			label.custom_minimum_size.x = [24,0,96,68][index]
			if index > 1: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		parent.add_child(label)

func _own_standing() -> Dictionary:
	for row: Dictionary in selected.get("standings",[]):
		if str(row.id) == str(selected.get("self_id","")): return row
	return {}

func _target_ms(item: Dictionary) -> Variant:
	if item.mode == "beat": return item.get("target_ms")
	for row: Dictionary in item.get("standings",[]):
		if row.get("ms") != null: return row.ms
	return null

func _remaining_text(item: Dictionary) -> String:
	if item.state != "active": return "Ended" if item.state == "complete" else "Finalizing results" if item.state == "settling" else str(item.state).capitalize()
	var remaining: int = maxi(0,int(item.ends_at)-int(item.server_now)-(Time.get_ticks_msec()-_received_at)/1000)
	if remaining == 0: return "Ending"
	if remaining < 60: return "<1m left"
	return "%dd %02dh left" % [remaining/86400,(remaining%86400)/3600] if remaining >= 86400 else "%dh %02dm left" % [remaining/3600,(remaining%3600)/60]

func _detail(parent: Control) -> void:
	var column := _panel(parent)
	_stage_picker(column)
	column.name = "ChallengeDetail"
	var heading := MenuStyle.label(str(_stage_data().entry.name),30)
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
	art.texture = TrackTile.scenery_texture(str(_stage_data().entry.get("theme","pine")))
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
	for point: Array in _stage_data().entry.points: route.route.append(Vector2(point[0],point[1]))
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
	var exhausted: bool = _stage_data().get("attempts_remaining") != null and int(_stage_data().attempts_remaining) <= 0
	if _stage_data().get("attempt_limit") != null:
		column.add_child(MenuStyle.label("No tries remaining" if exhausted else "%d of %d tries remaining" % [int(_stage_data().attempts_remaining),int(_stage_data().attempt_limit)],16,true))
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
		if selected.has("rewards"):
			var progress := MenuStyle.label("Reward progress: "+_reward_caption(selected),18,true)
			progress.name = "ChallengeRewardProgress"
			column.add_child(progress)
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
			var text: String = str(int(row.rank)) if index == 0 and row.rank != null else "—" if index == 0 else str(row.name) if index == 1 else "%.3f" % (float(row.ms)/1000.0) if row.ms != null else str(int(row.get("completed_tracks",0)))+"/3 tracks" if selected.mode == "3x3" else "—"
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
	var winning: bool = own.get("ticks") != null and (int(own.rank) == 1 if selected.mode != "beat" else int(own.ticks) < int(selected.target_ticks))
	if winning and selected.mode != "3x3": _action(actions,"Rematch",func() -> void: rematch_requested.emit())
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
	if not result_view:
		_clock.text = _remaining_text(selected)
		return
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

class_name RaceComplete
extends VBoxContainer
signal back_requested
signal home_requested
signal tracks_requested
signal race_requested(recommendation: Dictionary)
var results: RaceResults
var rating_records: LocalRecords
var rating_track_id: String
var facts: Dictionary
var recommendations: Array[Dictionary] = []
var cards: Array[Button] = []
var race_button: Button
var selected: int = -1
var rewards: Array[Dictionary] = []
var reward_panels: Array[PanelContainer] = []
var reward_total: Label
var reward_reveal: Tween
var revealed_count: int = 0

func _ready() -> void:
	name = "RaceComplete"
	add_theme_constant_override("separation",10)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",14)
	add_child(header)
	header.add_child(ResultsIcons.view("flag",42))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation",0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(MenuStyle.label("RACE COMPLETE",30))
	titles.add_child(MenuStyle.label("%s / %s / %d LAPS" % [results.circuit.to_upper(),results.vehicle_name.to_upper(),results.laps.size()],16,true))
	var home := MenuStyle.button("",func() -> void: home_requested.emit())
	home.name = "MainMenu"
	home.tooltip_text = "Main menu"
	home.icon = ResultsIcons.texture("home")
	home.expand_icon = true
	home.add_theme_constant_override("icon_max_width",30)
	home.custom_minimum_size = Vector2(56,54)
	header.add_child(home)
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation",12)
	add_child(main)
	_rewards(main)
	_standings(main)
	_recommendations()
	_actions()
	if not recommendations.is_empty(): select_track(0)

func _rewards(parent: Control) -> void:
	var body: VBoxContainer = RaceResults._card(parent,12)
	body.get_parent().custom_minimum_size.x = 396
	body.add_theme_constant_override("separation",6)
	body.add_child(MenuStyle.label("REWARDS",28))
	body.add_child(MenuStyle.label("Provisional amounts / not added to a balance",13,true))
	var scroll := ScrollContainer.new()
	scroll.name = "RewardScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",5)
	scroll.add_child(list)
	rewards = RaceRewardPreview.build(facts)
	for item: Dictionary in rewards:
		if not item.eligible: continue
		var slot := Control.new()
		slot.custom_minimum_size.y = 64
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(slot)
		var panel := PanelContainer.new()
		panel.name = "RewardRow%d" % reward_panels.size()
		panel.set_meta("amount",int(item.amount))
		panel.add_theme_stylebox_override("panel",RaceResults._panel_style(12))
		panel.modulate.a = 0.0
		slot.add_child(panel)
		MenuStyle.fill(panel)
		reward_panels.append(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		panel.add_child(row)
		row.add_child(ResultsIcons.view(item.icon,30,MenuStyle.ACCENT))
		var title := MenuStyle.label(item.title,22)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(title)
		row.add_child(ResultsIcons.view("coin",22,MenuStyle.ACCENT))
		var amount := MenuStyle.label("+ %d" % item.amount,25)
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(amount)
	if reward_panels.is_empty():
		list.add_child(MenuStyle.label("No rewards for this race.",18,true))
	body.add_child(HSeparator.new())
	var total_row := HBoxContainer.new()
	body.add_child(total_row)
	var caption := MenuStyle.label("ELIGIBLE TOTAL",20,true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(caption)
	total_row.add_child(ResultsIcons.view("coin",24,MenuStyle.ACCENT))
	reward_total = MenuStyle.label("+ 0",30)
	total_row.add_child(reward_total)
	_reveal_rewards()

func _reveal_rewards() -> void:
	if reward_panels.is_empty(): return
	reward_reveal = create_tween()
	reward_reveal.tween_interval(0.18)
	var running_total: int = 0
	for panel: PanelContainer in reward_panels:
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var previous_total: int = running_total
		running_total += int(panel.get_meta("amount"))
		reward_reveal.tween_callback(func() -> void:
			revealed_count += 1
			panel.position.x = 16
			style.border_color = MenuStyle.ACCENT
			reward_total.add_theme_color_override("font_color",MenuStyle.ACCENT))
		reward_reveal.tween_property(panel,"modulate:a",1.0,0.24)
		reward_reveal.parallel().tween_property(panel,"position:x",0.0,0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		reward_reveal.parallel().tween_method(_set_reward_total,float(previous_total),float(running_total),0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reward_reveal.parallel().tween_property(style,"border_color",Color("425b69"),0.48)
		reward_reveal.tween_interval(0.12)
	reward_reveal.tween_callback(func() -> void: reward_total.add_theme_color_override("font_color",MenuStyle.TEXT))

func _set_reward_total(value: float) -> void:
	reward_total.text = "+ %d" % roundi(value)

func _standings(parent: Control) -> void:
	var body: VBoxContainer = RaceResults._card(parent,12)
	body.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	body.add_child(MenuStyle.label("WHERE YOU STAND",28))
	for kind: String in ["RACE TIME","BEST LAP"]:
		var card: VBoxContainer = RaceResults._card(body,16)
		card.add_theme_constant_override("separation",4)
		card.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		card.add_child(row)
		var title := MenuStyle.label(kind,25)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var value: float = results.total if kind == "RACE TIME" else float(facts.get("flying",0))
		row.add_child(MenuStyle.label(MenuStyle.time_text(value) if value > 0 else "\u2014",32))
		var space := Control.new()
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(space)
		card.add_child(MenuStyle.label("PERCENTILE NOT AVAILABLE",22,true))
		card.add_child(MenuStyle.label("Global comparison data is not connected yet.",15,true))
		card.add_child(MenuStyle.label("Best flying lap" if kind == "BEST LAP" else "Your completed race time",13,true))
	if rating_records != null and not results.editor:
		var rating := TrackRating.new()
		rating.records = rating_records
		rating.track_id = rating_track_id
		body.add_child(rating)

func _recommendations() -> void:
	var panel: VBoxContainer = RaceResults._card(self,10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	panel.add_child(row)
	var intro := VBoxContainer.new()
	intro.custom_minimum_size.x = 155
	row.add_child(intro)
	intro.add_child(MenuStyle.label("NEXT TRACKS",26))
	intro.add_child(MenuStyle.label("Keep the momentum.\nPick what's next.",16,true))
	if recommendations.is_empty():
		row.add_child(MenuStyle.label("No other local tracks yet. Open Tracks to create or import one.",17,true))
	for i: int in range(recommendations.size()):
		var item: Dictionary = recommendations[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0,106)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_track.bind(i))
		row.add_child(button)
		cards.append(button)
		var margin := MarginContainer.new()
		for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		MenuStyle.fill(margin)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation",4)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(stack)
		var card_header := HBoxContainer.new()
		card_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(card_header)
		var category := MenuStyle.label("RECOMMENDED" if i == 0 else ("DIFFERENT SCENERY" if item.category == "different_biome" else "LOCAL TRACK"),13,true)
		category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category.clip_text = true
		card_header.add_child(category)
		var detail := HBoxContainer.new()
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(detail)
		var preview := LapRouteView.new()
		preview.miniature = true
		preview.route = item.route
		preview.custom_minimum_size = Vector2(72,55)
		detail.add_child(preview)
		var copy := VBoxContainer.new()
		copy.add_theme_constant_override("separation",0)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.add_child(copy)
		var title := MenuStyle.label(item.name,24)
		title.clip_text = true
		copy.add_child(title)
		copy.add_child(MenuStyle.label("%d laps / ~%d:%02d" % [item.laps,int(item.estimated_seconds/60),int(item.estimated_seconds)%60],14,true))
		var reason := MenuStyle.label(item.reason,12,true)
		reason.clip_text = true
		copy.add_child(reason)
		var score: int = 0
		if rating_records != null:
			score = int(rating_records.settings.get("track_ratings",{}).get(str(item.entry.id),0))
		var rating_line := HBoxContainer.new()
		rating_line.name = "RecommendationRating"
		rating_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rating_line.add_theme_constant_override("separation",5)
		card_header.add_child(rating_line)
		var star := TextureRect.new()
		star.texture = MenuIcon.texture("star_filled" if score > 0 else "star")
		star.custom_minimum_size = Vector2(16,16)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.modulate = MenuStyle.ACCENT if score > 0 else MenuStyle.MUTED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rating_line.add_child(star)
		rating_line.add_child(MenuStyle.label("%.1f (1)" % score if score > 0 else "\u2014 (0)",14,score == 0))
		button.tooltip_text = "%.1f (1) — local votes on this device" % score if score > 0 else "Unrated (0) — local votes on this device"

func _actions() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	add_child(row)
	var back := MenuStyle.button("",func() -> void: back_requested.emit())
	back.name = "BackToResults"
	back.tooltip_text = "Back to results"
	back.text = "RESULTS"
	var back_arrow := ResultsIcons.view("back",26,MenuStyle.ACCENT)
	back.add_child(back_arrow)
	back_arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	back_arrow.offset_left = 18
	back_arrow.offset_right = 44
	back_arrow.offset_top = -13
	back_arrow.offset_bottom = 13
	row.add_child(back)
	var tracks := MenuStyle.button("BACK TO EDITOR" if results.editor else "TRACKS",func() -> void: tracks_requested.emit())
	tracks.name = "ChooseTrack"
	var track_caption: String = tracks.text
	tracks.text = ""
	var track_center := CenterContainer.new()
	track_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracks.add_child(track_center)
	MenuStyle.fill(track_center)
	var track_copy := HBoxContainer.new()
	track_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_copy.add_theme_constant_override("separation",16)
	track_center.add_child(track_copy)
	track_copy.add_child(ResultsIcons.view("track",34))
	track_copy.add_child(MenuStyle.label(track_caption,24))
	row.add_child(tracks)
	race_button = MenuStyle.button("CHOOSE A TRACK",func() -> void:
		if selected >= 0: race_requested.emit(recommendations[selected]),true)
	race_button.name = "RaceSelectedTrack"
	race_button.disabled = recommendations.is_empty()
	race_button.size_flags_stretch_ratio = 1.6
	row.add_child(race_button)
	for button: Button in [back,tracks,race_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 60

func select_track(index: int) -> void:
	selected = index
	for i: int in range(cards.size()): cards[i].add_theme_stylebox_override("normal",RaceResults._selection_style(i == index))
	race_button.text = "RACE %s  \u2192" % str(recommendations[index].name).to_upper()
	race_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

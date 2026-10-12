class_name RaceComplete
extends VBoxContainer
signal back_requested
signal home_requested
signal tracks_requested
signal race_requested(recommendation: Dictionary)
var results: RaceResults
var rating_records: LocalRecords
var rating_track_id: String
var cloud_client: Node
var cloud_version: String = ""
var cloud_sync: Node
var global_rank: Label
var global_status: Label
var standings_busy: bool = false
var race_chart: TrackDistribution
var race_context: Label
var lap_chart: TrackDistribution
var lap_context: Label
var lap_population: Label
const COMPARISON_BINS: int = 8
var vehicle_id: String = "compact"
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
	var body: VBoxContainer = _section(parent,16)
	body.get_parent().custom_minimum_size.x = 350
	body.add_theme_constant_override("separation",6)
	body.add_child(MenuStyle.label("REWARDS",28))
	body.add_child(MenuStyle.label("Reward preview / no balance credited",13,true))
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
		slot.custom_minimum_size.y = 45
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(slot)
		var panel := PanelContainer.new()
		panel.name = "RewardRow%d" % reward_panels.size()
		panel.set_meta("amount",int(item.amount))
		panel.add_theme_stylebox_override("panel",MenuStyle.box(Color.TRANSPARENT,4))
		panel.modulate.a = 0.0
		slot.add_child(panel)
		MenuStyle.fill(panel)
		reward_panels.append(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		panel.add_child(row)
		row.add_child(ResultsIcons.view(item.icon,30,MenuStyle.ACCENT))
		var title := MenuStyle.label(item.title,21)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(title)
		var amount := MenuStyle.label("+%d" % item.amount,28)
		amount.add_theme_color_override("font_color",MenuStyle.ACCENT)
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(amount)
	if reward_panels.is_empty():
		list.add_child(MenuStyle.label("No rewards for this race.",18,true))
	body.add_child(HSeparator.new())
	var total_row := HBoxContainer.new()
	body.add_child(total_row)
	var caption := MenuStyle.label("TOTAL REWARDS",20,true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(caption)
	total_row.add_child(ResultsIcons.view("coin",38,MenuStyle.ACCENT))
	reward_total = MenuStyle.label("+ 0",48)
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
	reward_reveal.tween_callback(func() -> void: reward_total.add_theme_color_override("font_color",MenuStyle.ACCENT))

func _set_reward_total(value: float) -> void:
	reward_total.text = "+ %d" % roundi(value)

func _standings(parent: Control) -> void:
	var body: VBoxContainer = _section(parent,16)
	body.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	body.add_child(MenuStyle.label("W H E R E  Y O U  S T A N D",23))
	body.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",18)
	body.add_child(columns)
	for kind: String in ["RACE TIME","BEST LAP"]:
		if kind == "BEST LAP": columns.add_child(VSeparator.new())
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation",2)
		columns.add_child(card)
		card.add_child(MenuStyle.label(kind,22,true))
		var value: float = results.total if kind == "RACE TIME" else float(facts.get("flying",0))
		card.add_child(MenuStyle.label(MenuStyle.time_text(value) if value > 0 else "\u2014",34))
		var prior: float = results.previous if kind == "RACE TIME" else float(facts.get("previous_lap",0))
		var context := MenuStyle.label("",14,true)
		context.clip_text = true
		card.add_child(context)
		context.hide()
		var chart := TrackDistribution.new()
		chart.custom_minimum_size = Vector2(180,130)
		chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var values: Array[float] = []
		if kind == "RACE TIME":
			race_chart = chart
			race_context = context
			if results.total > 0: values.append(results.total)
			if prior > 0: values.append(prior)
			context.text = "This race + previous PB" if prior > 0 else "First recorded race"
		else:
			lap_chart = chart
			lap_context = context
			for index: int in range(1,results.laps.size()):
				if results.result.laps[index].valid: values.append(results.laps[index])
			context.text = "This race / %d flying laps" % values.size()
		chart.snapshot = _local_distribution(values,value)
		chart.snapshot.markers = _comparison_markers(kind)
		chart.snapshot.marker_label = "THIS RACE" if kind == "RACE TIME" else "BEST LAP"
		chart.snapshot.empty_text = "No completed race time" if kind == "RACE TIME" else "No valid flying laps"
		chart.snapshot.empty_detail = "Finish a timed race to compare"
		chart.tooltip_text = context.text
		card.add_child(chart)
		if kind == "RACE TIME":
			global_rank = MenuStyle.label("Your race times",13,true)
			global_status = MenuStyle.label("Your times on this track",12,true)
			global_status.clip_text = true
			card.add_child(global_rank)
			card.add_child(global_status)
			global_status.hide()
		else:
			lap_population = MenuStyle.label("Your flying laps / %d samples" % values.size(),13,true)
			card.add_child(lap_population)
	body.add_child(HSeparator.new())
	if rating_records != null and not results.editor:
		var rating := TrackRating.new()
		rating.records = rating_records
		rating.track_id = rating_track_id
		rating.cloud_client = cloud_client
		rating.cloud_version = cloud_version
		rating.cloud_sync = cloud_sync
		body.add_child(rating)
	if not cloud_version.is_empty():
		call_deferred("_refresh_rank")
		if cloud_sync != null: cloud_sync.changed.connect(_refresh_rank)

static func _local_distribution(values: Array[float], marker: float) -> Dictionary:
	if values.is_empty(): return {}
	var rounded: Array[float] = []
	for value: float in values: rounded.append(roundi(value*1000.0)/1000.0)
	marker = roundi(marker*1000.0)/1000.0
	var low: float = rounded.min()
	var high: float = rounded.max()
	var bins: Array[int] = []
	bins.resize(mini(COMPARISON_BINS,maxi(1,ceili(sqrt(rounded.size())))))
	bins.fill(0)
	var span: float = maxf(high-low,0.001)
	for value: float in rounded: bins[clampi(int((value-low)/span*bins.size()),0,bins.size()-1)] += 1
	var edges: Array[float] = []
	for index: int in range(bins.size()+1): edges.append((low+span*index/bins.size())*1000.0)
	return {"bins":bins,"min_ms":low*1000.0,"max_ms":high*1000.0,"edges_ms":edges,"player_bin":clampi(int((marker-low)/span*bins.size()),0,bins.size()-1)}

func _comparison_markers(kind: String) -> Array[Dictionary]:
	var current: float = results.total if kind == "RACE TIME" else float(facts.get("flying",0))
	var best: float = results.best if kind == "RACE TIME" else float(facts.get("previous_lap",0))
	if kind == "RACE TIME" and best <= 0: best = results.previous
	if results.clean and not results.editor and current > 0:
		best = minf(best,current) if best > 0 else current
	var markers: Array[Dictionary] = []
	if current > 0: markers.append({"value_ms":roundi(current*1000.0),"label":"THIS RACE","color":MenuStyle.ACCENT})
	if best > 0: markers.append({"value_ms":roundi(best*1000.0),"label":"YOUR BEST","color":Color("b8e3f4")})
	return markers

func _show_distribution(chart: TrackDistribution, data: Dictionary, context: Label, own_ticks: int = -1) -> void:
	var counts: Array[int] = []
	var edges: Array[float] = []
	var own_bin: int = -1
	for index: int in range(data.bins.size()):
		var bin: Dictionary = data.bins[index]
		counts.append(int(bin.count))
		edges.append(float(bin.from_ticks)*1000.0/VehicleSimulation.TICK_RATE)
		if own_ticks >= int(bin.from_ticks) and own_ticks < int(bin.to_ticks_exclusive): own_bin = index
	edges.append(float(data.bins[-1].to_ticks_exclusive)*1000.0/VehicleSimulation.TICK_RATE)
	var markers: Array = chart.snapshot.get("markers",[])
	if chart == race_chart and own_ticks > 0:
		var verified_ms: float = own_ticks*1000.0/VehicleSimulation.TICK_RATE
		var found: bool = false
		for marker: Dictionary in markers:
			if marker.label == "YOUR BEST":
				marker.value_ms = mini(int(marker.value_ms),roundi(verified_ms))
				found = true
		if not found: markers.append({"value_ms":roundi(verified_ms),"label":"YOUR BEST","color":Color("b8e3f4")})
	chart.snapshot = {"bins":counts,"min_ms":float(data.minimum_ticks)*1000.0/VehicleSimulation.TICK_RATE,"max_ms":float(data.maximum_ticks)*1000.0/VehicleSimulation.TICK_RATE,"player_bin":own_bin,"edges_ms":edges,"markers":markers}
	chart.queue_redraw()
	var comparison: String = "driver best laps" if chart == lap_chart else "personal bests"
	context.text = "%d verified %s / %s" % [int(data.population),"test drivers" if data.get("test_population",false) else "players",comparison]
	chart.tooltip_text = context.text
	if chart == lap_chart: lap_population.text = context.text

static func _section(parent: Control, padding: int) -> VBoxContainer:
	var body: VBoxContainer = RaceResults._card(parent,padding)
	(body.get_parent() as PanelContainer).add_theme_stylebox_override("panel",RaceResults._panel_style(padding))
	return body

func _refresh_rank() -> void:
	if standings_busy or not is_instance_valid(global_rank) or cloud_client == null: return
	if not cloud_client.signed_in():
		global_rank.text = "OFFLINE RESULT"
		global_status.text = "Sign in before racing to enter the leaderboard."
		return
	standings_busy = true
	var response: Dictionary = await cloud_client.request_api("/track-versions/"+cloud_version+"/leaderboard?vehicle_id="+vehicle_id.uri_encode())
	if not is_inside_tree(): return
	if response.ok and int(response.data.population) > 0:
		var board: String = str(response.data.board_id)
		var histogram: Dictionary = await cloud_client.request_api("/boards/"+board+"/histogram?bins=%d" % COMPARISON_BINS)
		if not is_inside_tree(): return
		response = await cloud_client.request_api("/boards/"+board+"/around-me",HTTPClient.METHOD_GET,{},"",true)
		if not is_inside_tree(): return
		if histogram.ok and not histogram.data.bins.is_empty():
			var own_ticks: int = int(response.data.player.time_ticks) if response.ok and response.data.player != null else -1
			_show_distribution(race_chart,histogram.data,race_context,own_ticks)
		var lap_histogram: Dictionary = await cloud_client.request_api("/boards/"+board+"/histogram?bins=%d&metric=best_lap" % COMPARISON_BINS)
		if not is_inside_tree(): return
		if lap_histogram.ok and lap_histogram.data.get("metric","") == "best_lap" and int(lap_histogram.data.population) > 0:
			_show_distribution(lap_chart,lap_histogram.data,lap_context)
		if response.ok and response.data.player != null:
			global_rank.text = "RANK %d OF %d" % [int(response.data.player.rank),int(response.data.population)]
			global_rank.add_theme_color_override("font_color",MenuStyle.ACCENT)
			global_status.text = "Your verified PB"
			if response.data.get("faster_than_percent") != null:
				global_status.text += " / faster than %.1f%%" % float(response.data.faster_than_percent)
		else:
			global_rank.text = "AWAITING VERIFIED SCORE"
			global_status.text = "Uploads retry while signed in."
	else:
		global_rank.text = "UNRANKED"
		global_status.text = "Publication or verified score pending." if response.ok or int(response.status) == 404 else "Leaderboard unavailable · retrying automatically."
	if cloud_client.test_drivers_available():
		var test_path: String = "/dev/test-drivers/track-versions/"+cloud_version+"/histogram?vehicle_id="+vehicle_id.uri_encode()+"&bins=%d" % COMPARISON_BINS
		var test_histogram: Dictionary = await cloud_client.request_api(test_path,HTTPClient.METHOD_GET,{},"",true)
		if not is_inside_tree(): return
		if test_histogram.ok and int(test_histogram.data.population) > 0:
			_show_distribution(race_chart,test_histogram.data,race_context)
		var test_laps: Dictionary = await cloud_client.request_api(test_path+"&metric=best_lap",HTTPClient.METHOD_GET,{},"",true)
		if not is_inside_tree(): return
		if test_laps.ok and test_laps.data.get("metric","") == "best_lap" and int(test_laps.data.population) > 0:
			_show_distribution(lap_chart,test_laps.data,lap_context)
	standings_busy = false

func _recommendations() -> void:
	var panel: VBoxContainer = RaceResults._card(self,0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	panel.add_child(row)
	var heading := HBoxContainer.new()
	heading.add_child(MenuStyle.label("NEXT TRACKS",28))
	heading.add_child(MenuStyle.label("Keep the momentum. Pick what's next.",16,true))
	panel.add_child(heading)
	panel.move_child(heading,0)
	if recommendations.is_empty():
		row.add_child(MenuStyle.label("No other local tracks yet. Open Tracks to create or import one.",17,true))
	for i: int in range(recommendations.size()):
		var item: Dictionary = recommendations[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0,136)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_track.bind(i))
		row.add_child(button)
		cards.append(button)
		button.clip_contents = true
		var artwork := TextureRect.new()
		artwork.texture = TrackTile.scenery_texture(str(item.entry.get("theme","pine")))
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(artwork)
		MenuStyle.fill(artwork)
		var shade := ColorRect.new()
		shade.color = Color(0.015,0.04,0.06,0.52)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(shade)
		MenuStyle.fill(shade)
		var frame := Panel.new()
		frame.name = "SelectionFrame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(frame)
		MenuStyle.fill(frame)

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
		preview.custom_minimum_size = Vector2(105,92)
		var copy := VBoxContainer.new()
		copy.add_theme_constant_override("separation",0)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.add_child(copy)
		var title := MenuStyle.label(item.name,27)
		title.clip_text = true
		copy.add_child(title)
		copy.add_child(MenuStyle.label("%d laps / est. %d:%02d" % [item.laps,int(item.estimated_seconds/60),int(item.estimated_seconds)%60],14,true))
		var reason := MenuStyle.label(item.reason,12,true)
		reason.clip_text = true
		copy.add_child(reason)
		detail.add_child(preview)
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
		if item.entry.get("source") == "cloud":
			var aggregate: String = "%.1f (%d)" % [float(item.entry.rating_average),int(item.entry.rating_count)] if item.entry.get("rating_average") != null else "Unrated (0)"
			rating_line.add_child(MenuStyle.label(aggregate,14,int(item.entry.rating_count) == 0))
			button.tooltip_text = aggregate+" · verified racers"
		else:
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
	for i: int in range(cards.size()):
		var style := MenuStyle.box(Color.TRANSPARENT,0)
		style.border_color = MenuStyle.ACCENT if i == index else MenuStyle.BORDER
		style.set_border_width_all(2 if i == index else 1)
		(cards[i].get_node("SelectionFrame") as Panel).add_theme_stylebox_override("panel",style)
	race_button.text = "RACE %s  \u2192" % str(recommendations[index].name).to_upper()
	race_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

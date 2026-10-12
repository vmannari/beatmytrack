class_name RaceComplete
extends VBoxContainer
signal back_requested
signal home_requested
signal tracks_requested
signal race_requested(recommendation: Dictionary)
var results: RaceResults
var embedded_comparison: bool = false
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
var race_best_caption: Label
var lap_best_caption: Label
var race_time_caption: Label
var lap_time_caption: Label
var comparison_scope: String = "all"
var last_comparison: Dictionary = {}
var refresh_again: bool = false
var comparison_refresh: Timer
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
	if embedded_comparison:
		name = "ResultsComparison"
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		_standings(self)
		return
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
	var heading := HBoxContainer.new()
	var title := MenuStyle.label("W H E R E  Y O U  S T A N D",23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	heading.add_child(title)
	if embedded_comparison: title.hide()
	var legend := Control.new()
	legend.custom_minimum_size = Vector2(116,28)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.draw.connect(func() -> void:
		legend.draw_colored_polygon(PackedVector2Array([Vector2(2,9),Vector2(10,9),Vector2(6,16)]),MenuStyle.ACCENT)
		legend.draw_string(MenuStyle.BODY,Vector2(17,18),"RACE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MenuStyle.ACCENT)
		legend.draw_circle(Vector2(78,13),3.5,Color("b8e3f4"))
		legend.draw_string(MenuStyle.BODY,Vector2(88,18),"PB",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b8e3f4")))
	heading.add_child(legend)
	body.add_child(heading)
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
		var card_heading := HBoxContainer.new()
		var caption := MenuStyle.label(kind,22,true)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_heading.add_child(caption)
		var position_label := MenuStyle.label("",16)
		position_label.custom_minimum_size = Vector2(94,28)
		position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		position_label.add_theme_color_override("font_color",MenuStyle.ACCENT)
		card_heading.add_child(position_label)
		card.add_child(card_heading)
		var value: float = results.total if kind == "RACE TIME" else float(facts.get("flying",0))
		var times := HBoxContainer.new()
		var current_time := MenuStyle.label(MenuStyle.time_text(value) if value > 0 else "\u2014",34)
		current_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		times.add_child(current_time)
		var best_caption := MenuStyle.label("",13,true)
		best_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		best_caption.add_theme_color_override("font_color",Color("b8e3f4"))
		times.add_child(best_caption)
		card.add_child(times)
		if embedded_comparison: times.hide() # PB and lap values already appear in the summary.
		var context := MenuStyle.label("",14,true)
		context.clip_text = true
		card.add_child(context)
		context.hide()
		var chart := TrackDistribution.new()
		chart.custom_minimum_size = Vector2(180,130)
		chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if kind == "RACE TIME":
			race_chart = chart
			race_context = context
			global_rank = position_label
			race_best_caption = best_caption
			race_time_caption = current_time
		else:
			lap_chart = chart
			lap_context = context
			lap_population = position_label
			lap_best_caption = best_caption
			lap_time_caption = current_time
		chart.snapshot = {}
		chart.snapshot.markers = _comparison_markers(kind)
		chart.snapshot.empty_text = "Loading comparison" if not cloud_version.is_empty() and cloud_client != null else "No comparison records"
		chart.snapshot.empty_detail = "Other drivers' best times"
		_update_best_caption(best_caption,chart.snapshot.markers)
		chart.tooltip_text = context.text
		card.add_child(chart)
	global_status = race_context
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
		comparison_refresh = Timer.new()
		comparison_refresh.one_shot = true
		comparison_refresh.wait_time = 0.25
		comparison_refresh.timeout.connect(_refresh_rank)
		add_child(comparison_refresh)
		call_deferred("_refresh_rank")
		if cloud_sync != null: cloud_sync.changed.connect(_queue_comparison_refresh)

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
	var value: float = results.total if chart == race_chart else float(facts.get("flying",0))
	(race_time_caption if chart == race_chart else lap_time_caption).text = MenuStyle.time_text(value) if value > 0 else "\u2014"
	var counts: Array[int] = []
	var edges: Array[float] = []
	var own_bin: int = -1
	for index: int in range(data.bins.size()):
		var bin: Dictionary = data.bins[index]
		counts.append(int(bin.count))
		edges.append(float(bin.from_ticks)*1000.0/VehicleSimulation.TICK_RATE)
		if own_ticks >= int(bin.from_ticks) and own_ticks < int(bin.to_ticks_exclusive): own_bin = index
	if not data.bins.is_empty(): edges.append(float(data.bins[-1].to_ticks_exclusive)*1000.0/VehicleSimulation.TICK_RATE)
	var markers: Array = _comparison_markers("RACE TIME" if chart == race_chart else "BEST LAP")
	own_ticks = int(data.own_best_ticks) if data.get("own_best_ticks") != null else own_ticks
	if own_ticks > 0:
		var verified_ms: float = own_ticks*1000.0/VehicleSimulation.TICK_RATE
		var found: bool = false
		for marker: Dictionary in markers:
			if marker.label == "YOUR BEST":
				marker.value_ms = mini(int(marker.value_ms),roundi(verified_ms))
				found = true
		if not found: markers.append({"value_ms":roundi(verified_ms),"label":"YOUR BEST","color":Color("b8e3f4")})
	if int(data.get("opponent_count",1)) == 0: counts.clear()
	var minimum: float = float(data.minimum_ticks) if data.get("minimum_ticks") != null else 0.0
	var maximum: float = float(data.maximum_ticks) if data.get("maximum_ticks") != null else 0.0
	chart.snapshot = {"bins":counts,"min_ms":minimum*1000.0/VehicleSimulation.TICK_RATE,"max_ms":maximum*1000.0/VehicleSimulation.TICK_RATE,"player_bin":own_bin,"edges_ms":edges,"markers":markers,"empty_text":"No comparison records","empty_detail":"Other drivers' best times"}
	chart.queue_redraw()
	context.text = ""
	chart.tooltip_text = ""
	var position_label: Label = global_rank if chart == race_chart else lap_population
	position_label.text = _position_text(data.get("comparison"))
	position_label.tooltip_text = ""
	_update_best_caption(race_best_caption if chart == race_chart else lap_best_caption,markers)

static func _position_text(comparison: Variant) -> String:
	if not comparison is Dictionary or int(comparison.get("population",0)) < 2: return ""
	var position: int = int(comparison.get("position",0))
	if position <= 0: return ""
	return "POSITION %d" % position if position <= 10 else "TOP %d%%" % clampi(int(comparison.get("top_percent",100)),1,100)

func _update_best_caption(caption: Label, markers: Array) -> void:
	caption.text = ""
	for marker: Dictionary in markers:
		if marker.label == "YOUR BEST": caption.text = "PB "+MenuStyle.time_text(float(marker.value_ms)/1000.0)

func _apply_comparison(data: Dictionary) -> bool:
	if data.get("population_scope","") != comparison_scope or not data.get("race") is Dictionary or not data.get("best_lap") is Dictionary: return false
	if not _valid_distribution(data.race,"race",str(data.get("board_id",""))) or not _valid_distribution(data.best_lap,"best_lap",str(data.get("board_id",""))): return false
	if data == last_comparison: return true
	# Both charts are committed in this synchronous callback. No intermediate
	# local/public/test frame can be drawn while the network request is pending.
	_show_distribution(race_chart,data.race,race_context)
	_show_distribution(lap_chart,data.best_lap,lap_context)
	last_comparison = data.duplicate(true)
	return true

static func _valid_distribution(data: Dictionary, metric: String, board: String) -> bool:
	if board.is_empty() or data.get("metric","") != metric or str(data.get("board_id","")) != board or not data.get("bins") is Array: return false
	var bins: Array = data.bins
	if bins.size() > COMPARISON_BINS: return false
	var count: int = 0
	var previous_edge: int = -1
	for bin: Variant in bins:
		if not bin is Dictionary: return false
		var low: int = int(bin.get("from_ticks",0))
		var high: int = int(bin.get("to_ticks_exclusive",0))
		if low <= 0 or high <= low or int(bin.get("count",-1)) < 0 or (previous_edge >= 0 and previous_edge != low): return false
		count += int(bin.count)
		previous_edge = high
	return count == int(data.get("population",-1)) and (bins.is_empty() or (data.get("minimum_ticks") != null and data.get("maximum_ticks") != null))

func _queue_comparison_refresh() -> void:
	if standings_busy:
		refresh_again = true
	elif is_instance_valid(comparison_refresh):
		comparison_refresh.start()

static func _section(parent: Control, padding: int) -> VBoxContainer:
	var body: VBoxContainer = RaceResults._card(parent,padding)
	(body.get_parent() as PanelContainer).add_theme_stylebox_override("panel",RaceResults._panel_style(padding))
	return body

func _refresh_rank() -> void:
	if not is_instance_valid(global_rank) or cloud_client == null: return
	if standings_busy:
		refresh_again = true
		return
	if not cloud_client.signed_in():
		_comparison_unavailable("Sign in to compare")
		return
	standings_busy = true
	var path: String = "/track-versions/"+cloud_version+"/results-comparison?vehicle_id="+vehicle_id.uri_encode()+"&bins=%d" % COMPARISON_BINS
	if results.total > 0: path += "&race_ticks=%d" % roundi(results.total*VehicleSimulation.TICK_RATE)
	var flying: float = float(facts.get("flying",0))
	if flying > 0: path += "&lap_ticks=%d" % roundi(flying*VehicleSimulation.TICK_RATE)
	var response: Dictionary = await cloud_client.request_api(path,HTTPClient.METHOD_GET,{},"",true)
	if not is_inside_tree(): return
	if not response.ok or not _apply_comparison(response.data): _comparison_unavailable("Comparison unavailable")
	standings_busy = false
	if refresh_again:
		refresh_again = false
		_queue_comparison_refresh()

func _comparison_unavailable(message: String) -> void:
	# A transient error keeps the last complete, correctly scoped comparison.
	if not last_comparison.is_empty(): return
	for chart: TrackDistribution in [race_chart,lap_chart]:
		chart.snapshot.empty_text = message
		chart.snapshot.empty_detail = "Other drivers' best times"
		chart.queue_redraw()
	global_rank.text = ""
	lap_population.text = ""

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

extends VBoxContainer
var ranking_client: Node
## Championship awards with verified facts and unchanged detail/continue actions.
signal track_requested(index: int)
signal continue_requested
signal share_requested
const AwardArt = preload("res://ui/rivalry_award_art.gd")
const VictoryCar = preload("res://ui/rivalry_victory_car.gd")
const Badge = preload("res://ui/biome_badge.gd")
var model: WeeklyRivalry
var busy: bool = false
var error: String = ""
var livery: Dictionary = {}
var customisation: Dictionary = {}
var condition: Dictionary = {}
var summary: Dictionary
var hero: Control
var hero_copy: VBoxContainer
var ornament: Control
var vehicle: Control
var metrics: HBoxContainer
var title: Label
var track_buttons: Array[Button] = []
var columns: HBoxContainer
var actions: HBoxContainer
var standings_scroll: ScrollContainer
var player_row: Control
var summary_band: PanelContainer

class RouteThumbnail extends Control:
	var entry: Dictionary = {}
	var minimum_height: float = 44
	var route := PackedVector2Array()
	var bounds: Rect2
	func _ready() -> void:
		clip_contents = true
		custom_minimum_size = Vector2(70,minimum_height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for point: Array in entry.get("points",[]): route.append(Vector2(point[0],point[1]))
		if not route.is_empty():
			bounds = Rect2(route[0],Vector2.ZERO)
			for point: Vector2 in route: bounds = bounds.expand(point)
		resized.connect(queue_redraw)
	func _draw() -> void:
		draw_texture_rect(TrackTile.scenery_texture(str(entry.get("theme","pine"))),Rect2(Vector2.ZERO,size),false)
		if route.size() < 2: return
		var scale_value: float = minf((size.x-12)/maxf(1,bounds.size.x),(size.y-12)/maxf(1,bounds.size.y))
		var points := PackedVector2Array()
		for point: Vector2 in route: points.append(size*0.5+(point-bounds.get_center())*scale_value)
		points.append(points[0])
		draw_polyline(points,Color("101b27"),4,true)
		draw_polyline(points,Color("f1f0d9"),1.5,true)
		draw_circle(points[0],2,MenuStyle.ACCENT)

func _ready() -> void:
	name = "WeeklyRivalryFinale"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	summary = model.finale_summary()
	_build_hero()
	columns = HBoxContainer.new()
	columns.name = "RivalryAwardsColumns"
	columns.add_theme_constant_override("separation",14)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Only the driver list scrolls. Track results and highlights determine the
	# body minimum, and the hero uses the remaining height above it.
	var body_slot := MarginContainer.new()
	body_slot.name = "RivalryFinaleBody"
	body_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body_slot)
	body_slot.add_child(columns)
	_build_tracks(columns)
	var right := VBoxContainer.new()
	right.name = "RivalryFinaleRightColumn"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.82
	right.add_theme_constant_override("separation",8)
	columns.add_child(right)
	if not model.world_circuit.is_empty() and is_instance_valid(ranking_client):
		var ranking_box: VBoxContainer = _panel(right,"RivalryWorldRankingChange")
		ranking_box.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_label(ranking_box,"WORLD RANKING",18)
		var world: Control = preload("res://ui/world_ranking_week_summary.gd").new()
		world.client = ranking_client
		world.week_start = int(model.world_circuit.get("week_start",0))
		world.compact = true
		ranking_box.add_child(world)
		world.label.add_theme_font_size_override("font_size",14)
	_build_standings(right)
	actions = HBoxContainer.new()
	actions.name = "RivalryFinaleActions"
	actions.add_theme_constant_override("separation",14)
	add_child(actions)
	var share := MenuStyle.button("SHARE RESULTS",func() -> void: share_requested.emit())
	share.name = "RivalryShareResults"
	share.icon = MenuIcon.texture("share")
	share.expand_icon = true
	share.add_theme_constant_override("icon_max_width",25)
	share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share.custom_minimum_size.y = 52
	share.disabled = busy
	actions.add_child(share)
	var next := MenuStyle.button("CONTINUE TO NEXT WEEK   →",func() -> void: continue_requested.emit(),true)
	next.name = "RivalryNextWeek"
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.custom_minimum_size.y = 52
	next.disabled = busy
	actions.add_child(next)
	resized.connect(_layout_hero)
	get_viewport().size_changed.connect(_layout_hero,CONNECT_DEFERRED)
	columns.minimum_size_changed.connect(_layout_hero)
	find_child("RivalryStatusMessage",true,false).visibility_changed.connect(_layout_hero,CONNECT_DEFERRED)
	_layout_hero()

func _label(parent: Control, text: String, font_size: int, color: Color = MenuStyle.TEXT) -> Label:
	var value := MenuStyle.label(text,font_size)
	value.add_theme_color_override("font_color",color)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.clip_text = true
	if text in ["WORLD RANKING","FINAL STANDINGS","YOUR WEEK HIGHLIGHTS"]: value.add_theme_font_override("font",MenuStyle.DISPLAY)
	parent.add_child(value)
	return value

func _panel(parent: Control, id: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = MenuStyle.card(4 if not model.world_circuit.is_empty() else 8)
	style.border_color = Color("526577")
	style.shadow_size = 2
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",4)
	panel.add_child(box)
	return box

func _build_hero() -> void:
	hero = Control.new()
	hero.name = "RivalryAwardsHero"
	hero.custom_minimum_size.y = 94
	add_child(hero)
	ornament = AwardArt.new()
	ornament.name = "RivalryChampionLaurels"
	ornament.tier = summary.tier
	hero.add_child(ornament)
	vehicle = VictoryCar.new()
	vehicle.name = "RivalryVictoryCar"
	vehicle.vehicle_id = model.vehicle_id
	vehicle.livery = livery
	vehicle.customisation = customisation
	vehicle.condition = condition
	vehicle.fit_to_frame = true
	hero.add_child(vehicle)
	hero_copy = VBoxContainer.new()
	hero_copy.add_theme_constant_override("separation",3)
	hero.add_child(hero_copy)
	title = _label(hero_copy,summary.title,52,Color("ffe49a") if summary.tier > 0 else MenuStyle.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.name = "RivalryAwardTitle"
	title.add_theme_font_override("font",MenuStyle.DISPLAY)
	title.add_theme_color_override("font_outline_color",Color("583b12") if summary.tier > 0 else MenuStyle.INK)
	title.add_theme_constant_override("outline_size",2)
	title.add_theme_color_override("font_shadow_color",Color("080d15"))
	title.add_theme_constant_override("shadow_offset_y",3)
	var message: Label = _label(hero,error,13,MenuStyle.MUTED)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message.name = "RivalryStatusMessage"
	message.tooltip_text = error
	message.visible = not error.is_empty()
	metrics = HBoxContainer.new()
	metrics.name = "RivalryFinalSummary"
	metrics.add_theme_constant_override("separation",0)
	summary_band = PanelContainer.new()
	summary_band.name = "RivalrySummaryBand"
	var band_style: StyleBoxFlat = MenuStyle.card(0)
	band_style.border_color = Color("344e5d")
	band_style.shadow_size = 0
	summary_band.add_theme_stylebox_override("panel",band_style)
	hero.add_child(summary_band)
	summary_band.add_child(metrics)
	for fact: Array in [["FINAL POSITION","—" if summary.rank == null else "%d / %d" % [int(summary.rank),summary.drivers],"trophy"],
		["TOTAL POINTS",str(summary.points),"star"],["TRACK VICTORIES","%d / 5" % summary.wins,"flag"]]:
		var card: VBoxContainer = _panel(metrics,"RivalrySummary_"+str(fact[0]).replace(" ","_"))
		card.add_theme_constant_override("separation",2)
		var cell_style: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,6)
		cell_style.set_corner_radius_all(0)
		cell_style.border_color = Color("344e5d")
		cell_style.border_width_left = 0 if str(fact[0]) == "FINAL POSITION" else 1
		card.get_parent().add_theme_stylebox_override("panel",cell_style)
		var number := HBoxContainer.new()
		number.add_theme_constant_override("separation",8)
		card.add_child(number)
		var icon := TextureRect.new()
		icon.texture = MenuIcon.texture(str(fact[2]))
		icon.modulate = MenuStyle.ACCENT
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(23,23)
		number.add_child(icon)
		_label(number,str(fact[1]),28,MenuStyle.ACCENT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(card,str(fact[0]),11,MenuStyle.MUTED)

func _layout_hero() -> void:
	if not is_instance_valid(hero) or not is_instance_valid(actions): return
	var width: float = size.x
	# Containers can retain a larger child minimum after a tall-window resize.
	# Budget against the actual clipping ancestors, so that minimum can shrink.
	var page_height: float = size.y
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			page_height = minf(page_height,ancestor.get_global_rect().end.y-global_position.y)
		ancestor = ancestor.get_parent()
	# Keep one compact summary strip above two equal-height result panels.
	var available: float = page_height-actions.get_combined_minimum_size().y-2*get_theme_constant("separation")-columns.get_combined_minimum_size().y
	var height: float = minf(104,maxf(94,available))
	var copy_top: float = 40 if summary.tier >= 2 else 24
	var font_size: int = 32
	var copy_width: float = width*0.43-128
	while font_size > 22 and MenuStyle.DISPLAY.get_string_size(summary.title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > copy_width: font_size -= 1
	title.add_theme_font_size_override("font_size",font_size)
	height = maxf(height,copy_top+hero_copy.get_combined_minimum_size().y)
	hero.custom_minimum_size.y = height
	hero_copy.position = Vector2(64,copy_top)
	hero_copy.size = Vector2(copy_width,height-copy_top)
	# Center the crown on the rendered words, and fit botanical branches around
	# them rather than using the whole hero column as a decorative frame.
	var text_width: float = MenuStyle.DISPLAY.get_string_size(summary.title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var ornament_width: float = minf(width*0.43-16,text_width+112)
	ornament.position = Vector2(hero_copy.position.x+hero_copy.size.x*0.5-ornament_width*0.5,copy_top)
	ornament.size = Vector2(ornament_width,minf(height-copy_top,MenuStyle.DISPLAY.get_height(font_size)))
	ornament.crown_center_y = hero_copy.position.y-ornament.position.y-26
	ornament.queue_redraw()
	var message: Label = find_child("RivalryStatusMessage",true,false)
	summary_band.position = Vector2(width*0.61,0 if message.visible else (height-72)*0.5)
	summary_band.size = Vector2(width*0.39,72)
	var message_height: float = message.get_combined_minimum_size().y
	message.position = Vector2(width*0.61,height-message_height)
	message.size = Vector2(width*0.39,message_height)
	vehicle.position = Vector2(width*0.43,0)
	vehicle.size = Vector2(width*0.17,height)

func _build_tracks(parent: Control) -> void:
	var list: VBoxContainer = _panel(parent,"RivalryTracksPanel")
	list.get_parent().size_flags_stretch_ratio = 1.30
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",9)
	list.add_child(heading)
	_label(heading,"YOUR TRACK RESULTS",22 if not model.world_circuit.is_empty() else 25).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for field: Array in [["TIME",84],["GAP TO 2ND",80],["POINTS",45]]:
		var caption: Label = _label(heading,str(field[0]),10,MenuStyle.MUTED)
		caption.custom_minimum_size.x = int(field[1])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var inset := Control.new()
	inset.custom_minimum_size.x = 0
	heading.add_child(inset)
	var scroll := ScrollContainer.new()
	scroll.name = "RivalryFinalTrackScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",4)
	scroll.add_child(rows)
	for result: Dictionary in summary.results:
		var slot: int = result.slot
		var track: Dictionary = model.tracks[slot]
		var own: Dictionary = result.own
		var row := MenuStyle.button("",func() -> void: track_requested.emit(slot))
		row.name = "SelectRivalryTrack_"+str(slot)
		row.tooltip_text = "View "+str(track.name)
		row.custom_minimum_size.y = 46 if not model.world_circuit.is_empty() else 50
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var style := MenuStyle.box(Color("182c37"),0)
		style.set_border_width_all(1)
		style.border_color = Color("344e5d")
		style.border_width_left = 2 if result.victory else 1
		row.add_theme_color_override("font_color",MenuStyle.TEXT)
		row.add_theme_stylebox_override("normal",style)
		rows.add_child(row)
		track_buttons.append(row)
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation",9)
		row.add_child(line)
		MenuStyle.fill(line)
		line.offset_left = 8; line.offset_right = -8; line.offset_top = 3; line.offset_bottom = -3
		var rank: Label = _label(line,"—" if own.get("rank") == null else str(int(own.rank)),25,MenuStyle.ACCENT if result.victory else MenuStyle.TEXT)
		rank.custom_minimum_size.x = 25
		rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tile := RouteThumbnail.new()
		tile.name = "RivalryFinalThumbnail_"+str(slot)
		tile.minimum_height = 38 if not model.world_circuit.is_empty() else 44
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.entry = track.get("entry",track.document).duplicate(true)
		tile.entry.theme = track.theme
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.custom_minimum_size.x = 70
		line.add_child(tile)
		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		identity.add_theme_constant_override("separation",0)
		line.add_child(identity)
		_label(identity,str(track.name),20).add_theme_font_override("font",MenuStyle.DISPLAY)
		_label(identity,TrackTheme.title(str(track.theme)),12,Badge.color(str(track.theme)))
		for column: Array in [["TIME","—" if own.get("ms") == null else MenuStyle.time_text(float(own.ms)/1000.0),84],
			["GAP TO 2ND","—" if result.gap_to_second_ms == null else "%+.3f" % (float(result.gap_to_second_ms)/1000.0),80],
			["POINTS",str(int(own.get("points",0))),45]]:
			var field := VBoxContainer.new()
			field.custom_minimum_size.x = column[2]
			field.add_theme_constant_override("separation",0)
			field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(field)
			var value: Label = _label(field,str(column[1]),21,MenuStyle.TEXT)
			value.add_theme_font_override("font",MenuStyle.DISPLAY)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_ignore_children(line)
	# Include every track row in the body budget, even though the inner scroll
	# container normally excludes its children's vertical minimum.
	scroll.custom_minimum_size.y = rows.get_combined_minimum_size().y
	_build_highlights(list)

func _ignore_children(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_children(child)

func _build_standings(parent: Control) -> void:
	var box: VBoxContainer = _panel(parent,"RivalryDriversPanel")
	var heading := HBoxContainer.new()
	box.add_child(heading)
	_label(heading,"FINAL STANDINGS",18 if not model.world_circuit.is_empty() else 25).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(heading,GameText.message("%d DRIVERS") % summary.drivers,13,MenuStyle.MUTED)
	var standings: Array[Dictionary] = model.standing()
	standings_scroll = ScrollContainer.new()
	standings_scroll.name = "RivalryFinalStandingsScroll"
	standings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	standings_scroll.custom_minimum_size.y = 30 if not model.world_circuit.is_empty() else 48
	standings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	standings_scroll.follow_focus = true
	box.add_child(standings_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",4)
	standings_scroll.add_child(rows)
	for driver: Dictionary in standings:
		var panel := PanelContainer.new()
		panel.name = "FinalDriver_"+str(driver.id)
		var own: bool = driver.id == WeeklyRivalry.SELF
		var style: StyleBoxFlat = MenuStyle.box(Color("57481d88") if own else Color("0a172280"),2)
		style.border_color = MenuStyle.ACCENT if own else Color("314755")
		style.set_border_width_all(1 if own else 0)
		panel.add_theme_stylebox_override("panel",style)
		rows.add_child(panel)
		if own: player_row = panel
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",7)
		panel.add_child(line)
		var color: Color = MenuStyle.ACCENT if own else MenuStyle.TEXT
		_label(line,"—" if driver.get("rank") == null else str(int(driver.rank)),17,color).custom_minimum_size.x = 23
		line.add_child(PlayerCountry.flag(str(driver.get("country_code","")),23))
		_label(line,str(driver.name),17,color).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(line,str(int(driver.points)),17,color).custom_minimum_size.x = 36
		var gap: int = int(driver.points)-summary.points
		_label(line,"—" if own or driver.get("rank") == null else "%+d" % gap,16,color if own else MenuStyle.MUTED).custom_minimum_size.x = 35
	_reveal_player.call_deferred()

func _reveal_player() -> void:
	if is_instance_valid(player_row): standings_scroll.ensure_control_visible(player_row)

func _build_highlights(parent: Control) -> void:
	var copy := GridContainer.new()
	copy.name = "RivalryWeeklyHighlights"
	copy.columns = 2
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("h_separation",14)
	copy.add_theme_constant_override("v_separation",1)
	parent.add_child(copy)
	for text: String in summary.highlights:
		_label(copy,"✓  "+text,13,MenuStyle.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if summary.perfect:
		var badge := PanelContainer.new()
		badge.name = "RivalryPerfectWeekBadge"
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var style: StyleBoxFlat = MenuStyle.box(Color("352d16"),0)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.border_color = Color("8b7432")
		style.set_border_width_all(1)
		badge.add_theme_stylebox_override("panel",style)
		copy.add_child(badge)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",5)
		badge.add_child(line)
		var art := TextureRect.new()
		art.name = "RivalryPerfectWeekArt"
		art.texture = AwardArt.CROWN
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(16,16)
		line.add_child(art)
		var label: Label = _label(line,GameText.message("PERFECT\nWEEK").replace("\n"," "),12,MenuStyle.ACCENT)
		label.name = "RivalryPerfectWeekText"
		label.add_theme_font_override("font",MenuStyle.DISPLAY)
		label.custom_minimum_size.x = label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x

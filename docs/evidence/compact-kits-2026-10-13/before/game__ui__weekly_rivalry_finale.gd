extends VBoxContainer
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
var condition: Dictionary = {}
var summary: Dictionary
var hero: Control
var hero_copy: VBoxContainer
var ornament: Control
var vehicle: Control
var metrics: HBoxContainer
var title: Label
var track_buttons: Array[Button] = []

class RouteThumbnail extends Control:
	var entry: Dictionary = {}
	var route := PackedVector2Array()
	var bounds: Rect2
	func _ready() -> void:
		clip_contents = true
		custom_minimum_size = Vector2(70,44)
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
	var columns := HBoxContainer.new()
	columns.name = "RivalryAwardsColumns"
	columns.add_theme_constant_override("separation",14)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The content can scroll if its minimum height exceeds the available space;
	# the action row remains a visible sibling outside this clipping viewport.
	var body_slot := ScrollContainer.new()
	body_slot.name = "RivalryFinaleBody"
	body_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_slot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(body_slot)
	body_slot.add_child(columns)
	_build_tracks(columns)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.82
	right.add_theme_constant_override("separation",8)
	columns.add_child(right)
	_build_standings(right)
	_build_highlights(right)
	var actions := HBoxContainer.new()
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
	_layout_hero()

func _label(parent: Control, text: String, font_size: int, color: Color = MenuStyle.TEXT) -> Label:
	var value := MenuStyle.label(text,font_size)
	value.add_theme_color_override("font_color",color)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.clip_text = true
	parent.add_child(value)
	return value

func _panel(parent: Control, id: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = MenuStyle.card(8)
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
	hero.custom_minimum_size.y = 112
	add_child(hero)
	ornament = AwardArt.new()
	ornament.name = "RivalryChampionLaurels"
	ornament.tier = summary.tier
	hero.add_child(ornament)
	vehicle = VictoryCar.new()
	vehicle.name = "RivalryVictoryCar"
	vehicle.vehicle_id = model.vehicle_id
	vehicle.livery = livery
	vehicle.condition = condition
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
	var subtitle: String = "FIVE TRACKS. FIVE VICTORIES." if summary.perfect else "YOUR CHAMPIONSHIP, CELEBRATED." if summary.champion else "YOUR WEEK ON THE TRACK."
	var subtitle_label: Label = _label(hero_copy,subtitle,17,MenuStyle.TEXT)
	subtitle_label.add_theme_font_override("font",MenuStyle.DISPLAY)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var context: String = "%d points ahead of %s." % [summary.margin,summary.rival] if summary.champion and summary.margin > 0 else "%d of five tracks completed." % summary.completed
	if not error.is_empty(): context = error
	var message: Label = _label(hero_copy,context,14,MenuStyle.MUTED)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.name = "RivalryStatusMessage"
	message.tooltip_text = context
	metrics = HBoxContainer.new()
	metrics.name = "RivalryFinalSummary"
	metrics.add_theme_constant_override("separation",8)
	hero.add_child(metrics)
	for fact: Array in [["FINAL POSITION","—" if summary.rank == null else "%d / %d" % [int(summary.rank),summary.drivers],"trophy"],
		["TOTAL POINTS",str(summary.points),"star"],["TRACK VICTORIES","%d / 5" % summary.wins,"flag"]]:
		var card: VBoxContainer = _panel(metrics,"RivalrySummary_"+str(fact[0]).replace(" ","_"))
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
		_label(number,str(fact[1]),26,MenuStyle.ACCENT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(card,str(fact[0]),12,MenuStyle.MUTED)

func _layout_hero() -> void:
	if not is_instance_valid(hero): return
	var width: float = size.x
	var height: float = clampf(size.y*0.23,112,180)
	hero.custom_minimum_size.y = height
	hero_copy.position = Vector2(56,14 if height < 140 else 22)
	hero_copy.size = Vector2(width*0.53-110,height-hero_copy.position.y)
	var font_size: int = (46 if height < 140 else 56) if not summary.title.begins_with("JOINT") else 40
	while font_size > 28 and MenuStyle.DISPLAY.get_string_size(summary.title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > hero_copy.size.x: font_size -= 1
	title.add_theme_font_size_override("font_size",font_size)
	# Center the crown on the rendered words, and fit botanical branches around
	# them rather than using the whole hero column as a decorative frame.
	var text_width: float = MenuStyle.DISPLAY.get_string_size(summary.title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var ornament_width: float = minf(width*0.53-16,text_width+112)
	ornament.position = Vector2(hero_copy.position.x+hero_copy.size.x*0.5-ornament_width*0.5,8)
	ornament.size = Vector2(ornament_width,minf(height-36,MenuStyle.DISPLAY.get_height(font_size)+MenuStyle.DISPLAY.get_height(17)+6))
	ornament.crown_center_y = hero_copy.position.y-ornament.position.y-26
	ornament.queue_redraw()
	vehicle.position = Vector2(width*0.65,-58)
	vehicle.size = Vector2(width*0.33,height+20)
	metrics.position = Vector2(width*0.55,height-68)
	metrics.size = Vector2(width*0.45,68)

func _build_tracks(parent: Control) -> void:
	var list: VBoxContainer = _panel(parent,"RivalryTracksPanel")
	list.get_parent().size_flags_stretch_ratio = 1.30
	var heading := HBoxContainer.new()
	list.add_child(heading)
	_label(heading,"YOUR TRACK RESULTS",25).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(heading,"%d / 5 WON" % summary.wins,13,MenuStyle.MUTED)
	var scroll := ScrollContainer.new()
	scroll.name = "RivalryFinalTrackScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",4)
	scroll.add_child(rows)
	for result: Dictionary in summary.results:
		var slot: int = result.slot
		var track: Dictionary = model.tracks[slot]
		var own: Dictionary = result.own
		var row := MenuStyle.button("",func() -> void: track_requested.emit(slot))
		row.name = "SelectRivalryTrack_"+str(slot)
		row.tooltip_text = "View "+str(track.name)
		row.custom_minimum_size.y = 52
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := MenuStyle.box(Color("182c37"),0)
		style.set_border_width_all(1)
		style.border_color = Color("977b30") if result.victory else Color("344e5d")
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
			_label(field,str(column[0]),11,MenuStyle.MUTED)
			_label(field,str(column[1]),20,MenuStyle.TEXT).add_theme_font_override("font",MenuStyle.DISPLAY)
		_label(line,"›",26,MenuStyle.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_ignore_children(line)

func _ignore_children(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_children(child)

func _build_standings(parent: Control) -> void:
	var box: VBoxContainer = _panel(parent,"RivalryDriversPanel")
	box.add_theme_constant_override("separation",2)
	box.get_parent().get_theme_stylebox("panel").set_content_margin_all(6)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	_label(heading,"FINAL STANDINGS",25).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(heading,"%d DRIVERS" % summary.drivers,13,MenuStyle.MUTED)
	var standings: Array[Dictionary] = model.standing()
	var own_index: int = 0
	for index: int in range(standings.size()):
		if standings[index].id == WeeklyRivalry.SELF: own_index = index
	var indexes: Array[int] = [0]
	var start: int = clampi(own_index-2,0,maxi(0,standings.size()-5))
	for index: int in range(start,mini(standings.size(),start+5)):
		if not indexes.has(index): indexes.append(index)
	while indexes.size() > 5:
		var remove_at: int = 1 if absi(indexes[1]-own_index) > absi(indexes[-1]-own_index) else indexes.size()-1
		indexes.remove_at(remove_at)
	indexes.sort()
	for index: int in indexes:
		var driver: Dictionary = standings[index]
		var panel := PanelContainer.new()
		panel.name = "FinalDriver_"+str(driver.id)
		var own: bool = driver.id == WeeklyRivalry.SELF
		var style: StyleBoxFlat = MenuStyle.box(Color("57481d88") if own else Color("0a172280"),2)
		style.border_color = MenuStyle.ACCENT if own else Color("314755")
		style.set_border_width_all(1 if own else 0)
		panel.add_theme_stylebox_override("panel",style)
		box.add_child(panel)
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

func _build_highlights(parent: Control) -> void:
	var box: VBoxContainer = _panel(parent,"RivalryWeeklyHighlights")
	box.add_theme_constant_override("separation",2)
	box.get_parent().get_theme_stylebox("panel").set_content_margin_all(6)
	box.get_parent().size_flags_vertical = Control.SIZE_SHRINK_END
	_label(box,"YOUR WEEK HIGHLIGHTS",23)
	var line := HBoxContainer.new()
	box.add_child(line)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation",2)
	line.add_child(copy)
	for text: String in summary.highlights:
		_label(copy,"✓  "+text,15,MenuStyle.POSITIVE)
	if summary.perfect:
		var badge := Control.new()
		badge.name = "RivalryPerfectWeekBadge"
		badge.custom_minimum_size = Vector2(112,72)
		line.add_child(badge)
		var art := AwardArt.new()
		art.name = "RivalryPerfectWeekArt"
		art.tier = 3
		art.badge = true
		badge.add_child(art)
		MenuStyle.fill(art)
		var label: Label = _label(badge,"PERFECT\nWEEK",20,MenuStyle.ACCENT)
		label.name = "RivalryPerfectWeekText"
		label.add_theme_font_override("font",MenuStyle.DISPLAY)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		MenuStyle.fill(label)
		label.offset_top = 22

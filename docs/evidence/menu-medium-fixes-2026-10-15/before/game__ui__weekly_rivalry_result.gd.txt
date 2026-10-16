class_name WeeklyRivalryResult
extends HBoxContainer
## Competition-first rivalry feedback. All scores remain model projections.
signal retry_requested
signal home_requested
var model: WeeklyRivalry
var index: int = 0
var details: Dictionary = {}
var pending: bool = false
var busy: bool = false
var error: String = ""
var scroll: ScrollContainer
var rows: VBoxContainer
const VISIBLE_ROWS: int = 8
const GUTTER: int = 12
const GREEN := Color("49e781")
const Badge = preload("res://ui/biome_badge.gd")
const ModeIcons = preload("res://ui/race_mode_icons.gd")

class PlayerList extends ScrollContainer:
	var pointer: int = -1
	var origin := Vector2.ZERO
	var initial_scroll: int = 0
	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree(): return
		if event is InputEventScreenTouch:
			if event.pressed and pointer == -1 and get_global_rect().has_point(event.position):
				if get_v_scroll_bar().get_global_rect().has_point(event.position): return
				pointer = event.index
				origin = event.position
				initial_scroll = scroll_vertical
			elif not event.pressed and event.index == pointer: pointer = -1
			else: return
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag and event.index == pointer:
			scroll_vertical = roundi(initial_scroll+origin.y-event.position.y)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION and pointer != -1:
			get_viewport().set_input_as_handled()

class TrackPreview extends Control:
	var artwork: Texture2D
	var route := PackedVector2Array()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		resized.connect(queue_redraw)
	func _draw() -> void:
		var factor: float = maxf(size.x/artwork.get_width(),size.y/artwork.get_height())
		var visible: Vector2 = size/factor
		draw_texture_rect_region(artwork,Rect2(Vector2.ZERO,size),Rect2((artwork.get_size()-visible)*0.5,visible))
		# Local title shade keeps the rest of the existing original art bright.
		draw_rect(Rect2(Vector2.ZERO,Vector2(size.x,size.y*0.43)),Color("06131b40"))
		if route.size() < 2: return
		var bounds := Rect2(Vector2(route[0].x,-route[0].y),Vector2.ZERO)
		for point: Vector2 in route: bounds = bounds.expand(Vector2(point.x,-point.y))
		var area := Rect2(Vector2(size.x*0.62,size.y*0.32),Vector2(size.x*0.33,size.y*0.60))
		var scale: float = minf(area.size.x/maxf(bounds.size.x,0.1),area.size.y/maxf(bounds.size.y,0.1))
		var origin: Vector2 = area.position+(area.size-bounds.size*scale)*0.5
		var fitted := PackedVector2Array()
		for point: Vector2 in route: fitted.append(origin+(Vector2(point.x,-point.y)-bounds.position)*scale)
		if fitted[0].distance_to(fitted[-1]) > 0.01: fitted.append(fitted[0])
		draw_polyline(fitted,Color("07151ab0"),6.5,true)
		draw_polyline(fitted,Color("f1f4f3"),3.5,true)

func _ready() -> void:
	name = "RivalryRaceResult"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	_race_details()
	_standings()

func _card(id: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	var style: StyleBoxFlat = MenuStyle.card(16)
	style.border_color = Color("2e495a88")
	style.shadow_size = 3
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	return column

func _label(parent: Control, text: String, font_size: int, color: Color = MenuStyle.TEXT, id: String = "") -> Label:
	var label: Label = MenuStyle.label(text,font_size)
	if not id.is_empty(): label.name = id
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _icon(parent: Control, texture: Texture2D, width: float, color: Color = MenuStyle.MUTED) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(width,width)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)

func _race_details() -> void:
	var column: VBoxContainer = _card("RivalryResultDetails",0.37)
	var track: Dictionary = model.tracks[index]
	var preview := TrackPreview.new()
	preview.name = "RivalryResultPreview"
	preview.artwork = TrackTile.scenery_texture(str(track.theme))
	preview.custom_minimum_size.y = 148
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if details.get("route") is PackedVector2Array: preview.route = details.route
	else:
		for point: Array in track.document.get("points",[]): preview.route.append(Vector2(point[0],point[1]))
	column.add_child(preview)
	var inset := MarginContainer.new()
	preview.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","top","right"]: inset.add_theme_constant_override("margin_"+side,12)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation",6)
	inset.add_child(identity)
	identity.add_child(Badge.view(str(track.theme),16))
	var title: Label = _label(identity,str(track.name).to_upper(),31)
	title.add_theme_color_override("font_shadow_color",Color("061320"))
	title.add_theme_constant_override("shadow_offset_y",2)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	var result_heading := HBoxContainer.new()
	column.add_child(result_heading)
	_label(result_heading,"YOUR RESULT",19).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pending:
		var status := HBoxContainer.new()
		status.name = "RivalryResultProvisional"
		status.add_theme_constant_override("separation",5)
		result_heading.add_child(status)
		_icon(status,MenuIcon.texture("clock"),16)
		_label(status,"PROVISIONAL",14,MenuStyle.MUTED)
	var result: Dictionary = model.last_result
	var time: Label = _label(column,MenuStyle.time_text(int(result.ms)/1000.0) if result.has("ms") else "—",68,MenuStyle.TEXT,"RivalryResultTime")
	time.add_theme_font_override("font",MenuStyle.DISPLAY)
	var previous: float = float(details.get("previous",0.0))
	if not details.has("previous") and result.get("before",{}).get("ms") != null:
		previous = int(result.before.ms)/1000.0
	var improved: bool = bool(details.get("clean",result.get("improved",false))) and result.has("ms") and (previous <= 0.0 or int(result.ms) < roundi(previous*1000.0))
	if improved:
		var personal := HBoxContainer.new()
		personal.add_theme_constant_override("separation",14)
		column.add_child(personal)
		var badge := PanelContainer.new()
		badge.name = "RivalryResultNewPB"
		badge.add_theme_stylebox_override("panel",MenuStyle.box(GREEN,5))
		personal.add_child(badge)
		_label(badge,"NEW PB",19,MenuStyle.INK).add_theme_font_override("font",MenuStyle.DISPLAY)
		if previous > 0.0:
			_label(personal,"-%.3f s" % (previous-int(result.ms)/1000.0),25,GREEN,"RivalryResultImprovement")
	if previous > 0.0:
		_label(column,"Previous best: "+MenuStyle.time_text(previous),17,MenuStyle.MUTED,"RivalryResultPrevious")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.10
	column.add_child(spacer)
	column.add_child(HSeparator.new())
	_track_facts(column,str(details.get("theme",track.theme)))

func _track_facts(parent: Control, theme_id: String) -> void:
	var facts := HBoxContainer.new()
	facts.name = "RivalryResultTrackFacts"
	facts.add_theme_constant_override("separation",12)
	parent.add_child(facts)
	var laps: int = int(details.get("laps",RaceRules.LAPS))
	_fact(facts,MenuIcon.texture("resume"),"%d LAPS" % laps)
	if float(details.get("distance_m",0)) > 0.0:
		_fact(facts,_fact_texture("road"),"%.2f KM" % (float(details.distance_m)/1000.0))
	var weather: String = {"night_city":"NIGHT","storm":"RAIN","winter":"SNOW"}.get(theme_id,"DAYLIGHT")
	_fact(facts,MenuIcon.texture(Badge.icon(theme_id)) if theme_id in ["night_city","storm","winter"] else _fact_texture("sun"),weather)
	var surface: String = {"winter":"ICY","storm":"WET","desert":"PACKED SAND"}.get(theme_id,"DRY")
	_fact(facts,_fact_texture("surface"),surface)

func _fact(parent: Control, texture: Texture2D, text: String) -> void:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation",3)
	parent.add_child(group)
	_icon(group,texture,24)
	var icon: Control = group.get_child(0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label: Label = _label(group,text,14,MenuStyle.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",MenuStyle.DISPLAY)

static func _fact_texture(kind: String) -> Texture2D:
	# Original code-native glyphs on the same grid as the established UI icons.
	var paths: String = {"road":"<path d='M3 22 8 2m13 20L16 2M12 3v3m0 4v4m0 4v4'/>",
		"sun":"<circle cx='12' cy='12' r='5'/><path d='M12 1v3m0 16v3M1 12h3m16 0h3M4 4l2 2m12 12 2 2M4 20l2-2M18 6l2-2'/>",
		"surface":"<path d='M3 8h14c6 0 6-6 2-6m-16 10h18M3 16h12c6 0 6 6 2 6'/>"}[kind]
	var image := Image.new()
	image.load_svg_from_string("<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 24 24'><g fill='none' stroke='white' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round'>"+paths+"</g></svg>")
	return ImageTexture.create_from_image(image)

func _standings() -> void:
	var column: VBoxContainer = _card("RivalryResultStandings",0.63)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",10)
	column.add_child(heading)
	_icon(heading,ModeIcons.texture("flag"),28,MenuStyle.TEXT)
	_label(heading,"TRACK STANDINGS",27)
	scroll = PlayerList.new()
	scroll.name = "RivalryResultStandingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var legend_margin := MarginContainer.new()
	legend_margin.add_theme_constant_override("margin_left",8)
	legend_margin.add_theme_constant_override("margin_right",8+GUTTER+ceili(scroll.get_v_scroll_bar().get_combined_minimum_size().x))
	column.add_child(legend_margin)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation",10)
	legend_margin.add_child(legend)
	_label(legend,"#",14,MenuStyle.MUTED).custom_minimum_size.x = 28
	_label(legend,"PLAYER",14,MenuStyle.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for field: Array in [["TIME",112],["GAP",84]]:
		var label: Label = _label(legend,str(field[0]),14,MenuStyle.MUTED,"RivalryResultColumn_"+str(field[0]))
		label.custom_minimum_size.x = float(field[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_right",GUTTER)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation",2)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(rows)
	var board: Array[Dictionary] = model.result_board(index)
	var own: Dictionary = WeeklyRivalry.self_row(board)
	for driver: Dictionary in board: _driver_row(driver,own)
	scroll.resized.connect(_resize_rows)
	_resize_rows.call_deferred()
	_reveal_player.call_deferred()
	column.add_child(HSeparator.new())
	if not error.is_empty():
		var message: Label = _label(column,error,15,MenuStyle.MUTED,"RivalryResultError")
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",16)
	column.add_child(footer)
	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation",4)
	footer.add_child(summary)
	_summary(summary,board.size())
	var actions := HBoxContainer.new()
	actions.name = "RivalryResultActions"
	actions.add_theme_constant_override("separation",10)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(actions)
	var again: Button = MenuStyle.button("RACE AGAIN",func() -> void: retry_requested.emit())
	again.name = "RivalryRaceAgain"
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.size_flags_stretch_ratio = 0.42
	again.disabled = busy or model.status != "active"
	again.add_theme_font_size_override("font_size",20)
	actions.add_child(again)
	var back: Button = MenuStyle.button("BACK TO RIVALRY  →",func() -> void: home_requested.emit(),true)
	back.name = "RivalryResultHome"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.size_flags_stretch_ratio = 0.58
	back.add_theme_font_size_override("font_size",20)
	back.add_theme_color_override("font_focus_color",MenuStyle.INK)
	actions.add_child(back)

func _driver_row(driver: Dictionary, own: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "RivalryResultDriver_"+str(driver.id)
	var player: bool = driver.id == WeeklyRivalry.SELF
	var style: StyleBoxFlat = MenuStyle.box(Color("ffd34826") if player else Color("20354380") if rows.get_child_count()%2 == 0 else Color("14283366"),0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.border_color = MenuStyle.ACCENT
	if player: style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	rows.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",10)
	panel.add_child(line)
	var color: Color = MenuStyle.ACCENT if player else MenuStyle.TEXT
	var rank: Label = _label(line,str(int(driver.rank)) if driver.get("rank") != null else "—",19,color)
	rank.custom_minimum_size.x = 28
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var identity := HBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation",8)
	line.add_child(identity)
	_icon(identity,MenuIcon.texture("avatar"),23,color)
	identity.add_child(PlayerCountry.flag(str(driver.get("country_code","")),22))
	var display_name: String = str(driver.name)
	if bool(driver.get("is_test_driver",false)):
		var marker: int = display_name.find(" T")
		if marker >= 0 and display_name.substr(marker+2).contains("-"): display_name = display_name.substr(0,marker)
	var name_label: Label = _label(identity,display_name,18,color,"RivalryResultName_"+str(driver.id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	var time: Label = _label(line,MenuStyle.time_text(int(driver.ms)/1000.0) if driver.get("ms") != null else "—",20,color,"RivalryResultTime_"+str(driver.id))
	time.add_theme_font_override("font",MenuStyle.DISPLAY)
	time.custom_minimum_size.x = 112
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gap_text: String = "—"
	if not player and driver.get("ms") != null and own.get("ms") != null:
		gap_text = "%+.3f" % ((int(driver.ms)-int(own.ms))/1000.0)
	var gap: Label = _label(line,gap_text,18,color if player else MenuStyle.MUTED,"RivalryResultGap_"+str(driver.id))
	gap.custom_minimum_size.x = 84
	gap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gap.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _resize_rows() -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(rows): return
	# Containers round each child to whole logical pixels. Distribute the
	# remainder so the eighth row ends exactly at the viewport, without clipping.
	var available: int = maxi(27*VISIBLE_ROWS,floori(scroll.size.y)-2*(VISIBLE_ROWS-1))
	var height: int = available/VISIBLE_ROWS
	var remainder: int = available%VISIBLE_ROWS
	for position: int in range(rows.get_child_count()):
		var row: Control = rows.get_child(position)
		row.custom_minimum_size.y = height+(1 if position%VISIBLE_ROWS < remainder else 0)

func _reveal_player() -> void:
	if is_inside_tree(): get_tree().process_frame.connect(_reveal_after_sort,CONNECT_ONE_SHOT)

func _reveal_after_sort() -> void:
	if is_inside_tree(): get_tree().process_frame.connect(_reveal_after_layout,CONNECT_ONE_SHOT)

func _reveal_after_layout() -> void:
	if not is_inside_tree(): return
	var player: Control = rows.get_node_or_null("RivalryResultDriver_you")
	if player != null: scroll.ensure_control_visible(player)

func _summary(parent: Control, count: int) -> void:
	var result: Dictionary = model.last_result
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",8)
	parent.add_child(line)
	_icon(line,ResultsIcons.texture("bars"),19,MenuStyle.ACCENT)
	_label(line,"TRACK RESULT",17,MenuStyle.MUTED)
	var score := HBoxContainer.new()
	score.add_theme_constant_override("separation",18)
	parent.add_child(score)
	_label(score,WeeklyRivalryPage.rank_text(result.get("after",{})),38,MenuStyle.ACCENT,"RivalryResultPosition")
	_label(score,"/ %d" % count,29)
	score.add_child(VSeparator.new())
	_label(score,"%+d pts" % int(result.points_delta) if result.has("points_delta") else "— pts",29,MenuStyle.ACCENT,"RivalryResultPoints")
	if result.has_all(["overall_before","overall_after"]):
		var progression := HBoxContainer.new()
		progression.add_theme_constant_override("separation",8)
		parent.add_child(progression)
		_label(progression,"Overall rivalry position",14,MenuStyle.MUTED)
		_label(progression,WeeklyRivalryPage.rank_text(result.overall_before)+"  →  "+WeeklyRivalryPage.rank_text(result.overall_after),18,MenuStyle.TEXT,"RivalryResultProgression")
		if result.overall_before.get("rank") != null and result.overall_after.get("rank") != null:
			var delta: int = int(result.overall_before.rank)-int(result.overall_after.rank)
			if delta != 0: _label(progression,("▲ +%d" if delta > 0 else "▼ %d") % delta,17,GREEN if delta > 0 else Color("ed987f"))

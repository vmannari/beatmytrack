class_name WeeklyRivalryPage
extends VBoxContainer
## Championship hub with track details as the race entry point.
signal section_requested(section: String)
signal track_requested(index: int)
signal track_selected(index: int)
signal race_requested(index: int, ghost_choice: int)
signal free_race_requested
signal challenges_requested
signal daily_requested
signal join_requested
signal refresh_requested
signal circuit_requested
signal car_rivalry_requested
var circuit_mode: bool = false
signal continue_requested
signal share_requested
signal retry_requested
var safety_client: Node
var model: WeeklyRivalry
var section: String = "overview"
var selected: int = 0
var busy: bool = false
var background_refresh: bool = false
var error: String = ""
var signed_in: bool = false
var pending_result: bool = false
var race_details: Dictionary = {}
var ghost_choice: int = 0
var clock_label: Label
var standings_identity: String = ""
var standings_scroll_offset: int = -1
var standings_scroll: ScrollContainer
var standings_ready: bool = false
var track_rows: Array[Button] = []
var detail_route: LapRouteView
var finale_livery: Dictionary = {}
var finale_customisation: Dictionary = {}
var finale_condition: Dictionary = {}
var _presented_key: PackedByteArray
var _presented_status: Array = []
var _presented_standings: String = ""
var _presented_topology: PackedByteArray
var _presented_locale: String = ""
var _driver_views: Dictionary = {}
var _driver_rows: VBoxContainer
var _track_views: Array[Dictionary] = []
var content_builds: int = 0
const WINTER_ART: Texture2D = preload("res://assets/menu/rivalry_winter_v1.png")
const STANDINGS_GUTTER: int = 12
const QUIET_BORDER := Color("2e495a88")
const Badge = preload("res://ui/biome_badge.gd")
const TrackAccent = preload("res://ui/rivalry_track_accents.gd")
const LoadingVisual = preload("res://ui/rivalry_loading_visual.gd")

class TrackProfile extends LapRouteView:
	func _draw() -> void:
		if fitted.size() < 2: return
		draw_polyline(fitted,Color("071b29e8"),5.0,true)
		draw_polyline(fitted,Color("f0ede0"),2.0,true)

func _ready() -> void:
	name = "WeeklyRivalryPage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)
	_build_content()
	_presented_key = _content_key()
	_presented_status = [busy,background_refresh,error,model.status,model.completed]
	_presented_standings = standings_identity
	_presented_topology = _score_topology()
	_presented_locale = TranslationServer.get_locale()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(clock_label): refresh_presentation.call_deferred()

func _content_key() -> PackedByteArray:
	var loading_view: bool = (model.tracks.is_empty() or model.empty_completed_week()) and signed_in and error.is_empty() and (busy or model.received_msec == 0)
	return var_to_bytes([circuit_mode,model.world_circuit,section,selected if section in ["detail","result"] else -1,signed_in,pending_result,race_details,standings_identity,loading_view,VehicleCatalog.selected if loading_view and not circuit_mode else "",model.week,model.completed,model.scope,model.sample,model.test_population,model.group_id,model.status,model.placement,model.forming,model.vehicle_id,model.source_self,model.points_policy,model.personal_best_slots,_track_projection(true),model.server_standings,model.recorded_times,model.pb_count,model.last_result,finale_livery,finale_customisation,finale_condition])

func _track_projection(scores: bool) -> Array:
	var values: Array = []
	for track: Dictionary in model.tracks:
		values.append([track.get("id",""),track.name,track.theme,track.get("document",{}),track.get("available",true),track.get("entries",[]) if scores else []])
	return values

func refresh_presentation() -> bool:
	var key: PackedByteArray = _content_key()
	var locale_changed: bool = _presented_locale != TranslationServer.get_locale()
	var rebuilt: bool = key != _presented_key or locale_changed
	if rebuilt:
		if not locale_changed and section=="overview" and not model.completed and not model.tracks.is_empty() and _score_topology()==_presented_topology:
			_update_scores()
			_presented_key = key
			_update_status()
			return false
		var focus: Control = get_viewport().gui_get_focus_owner()
		var focused_name: String = str(focus.name) if focus != null and is_ancestor_of(focus) else ""
		if _presented_standings != standings_identity: standings_scroll_offset = -1
		elif is_instance_valid(standings_scroll): standings_scroll_offset = standings_scroll.scroll_vertical
		for child: Node in get_children():
			remove_child(child)
			child.queue_free()
		standings_scroll = null
		standings_ready = false
		track_rows.clear()
		_track_views.clear()
		_driver_views.clear()
		detail_route = null
		_build_content()
		_presented_key = key
		_presented_standings = standings_identity
		_presented_topology = _score_topology()
		_presented_locale = TranslationServer.get_locale()
		if not focused_name.is_empty():
			var restored: Control = find_child(focused_name,true,false) as Control
			if restored != null: _restore_focus.call_deferred(weakref(restored))
	_update_status()
	return rebuilt

func _restore_focus(target: WeakRef) -> void:
	var control: Control = target.get_ref() as Control
	if control != null and control.is_visible_in_tree() and control.can_process(): control.grab_focus()

func ready_for_display() -> bool:
	if not standings_ready: return false
	if signed_in and error.is_empty() and model.tracks.is_empty() and (busy or model.received_msec == 0): return false
	for car: Node in find_children("*","",true,false):
		if car.get_script() != preload("res://ui/rivalry_victory_car.gd"): continue
		if not car.presentation_ready or car.viewport.size.x <= 1 or car.viewport.size.y <= 1: return false
	return true

func _score_topology() -> PackedByteArray:
	if section!="overview" or model.completed or model.tracks.is_empty(): return PackedByteArray()
	var tracks: Array = _track_projection(false)
	var drivers: Array = []
	var podium: Array = []
	for driver: Dictionary in model.standing():
		drivers.append([driver.id,driver.get("name",""),driver.get("country_code",""),driver.get("appearance",{})])
		if podium.size()<3: podium.append(driver.id)
	drivers.sort_custom(func(a: Array,b: Array) -> bool: return str(a[0])<str(b[0]))
	return var_to_bytes([section,signed_in,standings_identity,model.week,model.group_id,model.status,model.completed,model.vehicle_id,model.forming,model.placement,tracks,drivers,podium,finale_livery,finale_customisation,finale_condition])

func _update_scores() -> void:
	var standings: Array[Dictionary] = model.standing()
	var leader_points: int = int(standings[0].points) if not standings.is_empty() else 0
	for index: int in range(standings.size()):
		var driver: Dictionary = standings[index]
		var view: Dictionary = _driver_views.get(str(driver.id),{})
		if view.is_empty(): continue
		_driver_rows.move_child(view.panel,index)
		var state: PackedByteArray = var_to_bytes([driver,leader_points])
		if view.state == state: continue
		view.state = state
		view.panel.add_theme_stylebox_override("panel",_driver_style(driver))
		view.rank.text = str(int(driver.rank)) if driver.get("rank")!=null else "--"
		view.points.text = str(int(driver.points))
		view.gap.text = "--" if driver.get("rank")==null or int(driver.points)==leader_points else str(int(driver.points)-leader_points)
		var medal: Color = _medal_color(int(driver.rank)-1) if driver.get("rank")!=null and int(driver.rank)<=3 else Color.TRANSPARENT
		view.badge.add_theme_stylebox_override("panel",_badge_style(medal))
	for index: int in range(mini(3,standings.size())):
		var podium_points := find_child("RivalryPodiumPoints_"+str(index+1),true,false) as Label
		var podium_rank := find_child("RivalryPodiumRank_"+str(index+1),true,false) as Label
		if podium_points != null: podium_points.text = str(int(standings[index].points))
		if podium_rank != null: podium_rank.text = rank_text(standings[index])
	_update_position_summary()
	var completed: int = 0
	for index: int in range(_track_views.size()):
		var gap: Dictionary = model.track_summary(index)
		if gap.own.get("ms")!=null: completed += 1
		var view: Dictionary = _track_views[index]
		view.rank.text = rank_text(gap.own)
		view.time.text = _track_time(gap)
		view.delta.text = _track_delta(gap)
		view.delta.add_theme_color_override("font_color",_track_status_color(gap))
		view.rank.add_theme_color_override("font_color",MenuStyle.ACCENT if gap.own.get("rank")==1 else MenuStyle.TEXT)
	_update_track_header()
	var circuit: Label = find_child("WorldCircuitProgress",true,false) as Label
	if circuit != null: circuit.text = GameText.message("CIRCUIT %d/5 · 3 FREE RESUMES") % completed

func _update_status() -> void:
	var state: Array = [busy,background_refresh,error,model.status,model.completed]
	if state == _presented_status: return
	_presented_status = state
	if is_instance_valid(clock_label): clock_label.text = model.countdown()
	for id: String in ["RivalryJoin","RivalryRefresh","RivalryNextWeek","RivalryShareResults"]:
		var button: Button = find_child(id,true,false) as Button
		if button != null: button.disabled = busy
	var again: Button = find_child("RivalryRaceAgain",true,false) as Button
	if again != null: again.disabled = busy or model.status != "active"
	var start: Button = find_child("RivalryStartRace",true,false) as Button
	if start != null and not model.tracks.is_empty():
		var track: Dictionary = model.tracks[selected]
		start.disabled = (busy and not background_refresh) or model.completed or model.status != "active" or not bool(track.get("available",true))
		start.text = "WEEK COMPLETE" if model.completed else "TRACK UNAVAILABLE" if not bool(track.get("available",true)) else ("UPDATING RIVALRY..." if error.is_empty() else "RIVALRY UNAVAILABLE") if busy and not background_refresh else "RIVALRY NOT ACTIVE" if model.status != "active" else "RACE "+str(track.name).to_upper()+"  →"
	var message: Label = find_child("RivalryStatusMessage",true,false) as Label
	if message != null:
		var normal: String = "Choose a track and beat your best time."
		if model.completed and section == "overview":
			normal = ""
			message.visible = not error.is_empty()
		message.text = error if not error.is_empty() else normal
		message.tooltip_text = message.text
	_update_track_header()
	var result_error: Label = find_child("RivalryResultError",true,false) as Label
	if result_error != null:
		result_error.text = error
		result_error.visible = not error.is_empty()
	var empty_message: Label = find_child("RivalryEmptyStatus",true,false) as Label
	if empty_message != null: empty_message.text = error if not error.is_empty() else "Finding this week's rivalry…" if busy else "Race as often as you like. Find your next rival."

func _build_content() -> void:
	content_builds += 1
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var rail := RaceModeRail.new()
	rail.selected = "rivalry"
	rail.mode_requested.connect(func(mode: String) -> void:
		if mode == "free": free_race_requested.emit()
		elif mode == "rivalry":
			if circuit_mode: car_rivalry_requested.emit()
			else: section_requested.emit("overview")
		elif mode == "challenges": challenges_requested.emit()
		elif mode == "daily": daily_requested.emit())
	if section != "result": row.add_child(rail)
	else: rail.free()
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(main)
	var awards: bool = section == "overview" and model.completed
	main.add_theme_constant_override("separation",12)
	var header := HBoxContainer.new()
	header.name = "RivalrySectionNavigation"
	header.add_theme_constant_override("separation",24)
	main.add_child(header)
	if section == "result":
		var trophy := PanelContainer.new()
		trophy.add_theme_stylebox_override("panel",MenuStyle.box(MenuStyle.ACCENT,12))
		trophy.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		header.add_child(trophy)
		var glyph := TextureRect.new()
		glyph.texture = MenuIcon.texture("trophy")
		glyph.modulate = MenuStyle.INK
		glyph.custom_minimum_size = Vector2(34,34)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trophy.add_child(glyph)
	var identity := VBoxContainer.new()
	identity.name = "RivalryIdentity"
	identity.add_theme_constant_override("separation",4)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	var heading := MenuStyle.label("COMPACT CIRCUIT" if circuit_mode else "WEEKLY RIVALRY",38)
	heading.add_theme_color_override("font_shadow_color",Color("061320"))
	heading.add_theme_constant_override("shadow_offset_y",2)
	if section == "overview" and not model.tracks.is_empty():
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation",16)
		identity.add_child(title_row)
		title_row.add_child(heading)
		var summary_frame := PanelContainer.new()
		summary_frame.name = "RivalryPositionBadge"
		summary_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var summary_style: StyleBoxFlat = MenuStyle.box(Color("312910b8"),8)
		summary_style.content_margin_top = 4
		summary_style.content_margin_bottom = 4
		summary_style.border_color = Color("b49a3c")
		summary_style.set_border_width_all(1)
		summary_frame.add_theme_stylebox_override("panel",summary_style)
		title_row.add_child(summary_frame)
		var summary := MenuStyle.label(_position_summary(),16)
		summary.name = "RivalryPositionSummary"
		summary.add_theme_font_override("font",MenuStyle.DISPLAY)
		summary.add_theme_color_override("font_color",Color("ffe39b"))
		summary_frame.add_child(summary)
	else:
		identity.add_child(heading)
	var context := PanelContainer.new()
	context.name = "RivalryWeekAndClock"
	context.visible = model.sample or model.received_msec > 0
	context.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var context_style: StyleBoxFlat = MenuStyle.card(10)
	context_style.content_margin_top = 5
	context_style.content_margin_bottom = 5
	context_style.border_color = QUIET_BORDER
	context_style.shadow_size = 3
	context.add_theme_stylebox_override("panel",context_style)
	header.add_child(context)
	var context_row := HBoxContainer.new()
	context_row.add_theme_constant_override("separation",10)
	context.add_child(context_row)
	var week_label := MenuStyle.label(GameText.message("WEEK %02d") % model.week,21)
	week_label.add_theme_font_override("font",MenuStyle.DISPLAY)
	week_label.add_theme_color_override("font_color",MenuStyle.ACCENT)
	context_row.add_child(week_label)
	var clock_icon := TextureRect.new()
	clock_icon.texture = MenuIcon.texture("clock")
	clock_icon.custom_minimum_size = Vector2(22,22)
	clock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	clock_icon.modulate = MenuStyle.MUTED
	context_row.add_child(clock_icon)
	clock_label = MenuStyle.label(model.countdown(),20)
	GameText.user_text(clock_label)
	clock_label.name = "RivalryCountdown"
	context_row.add_child(clock_label)
	if not model.world_circuit.is_empty():
		var completed_tracks: int = int(model.self_row(model.standing()).get("completed",0))
		var progress_text: String = GameText.message("%d / %d COMPLETED") % [completed_tracks,model.tracks.size()] if awards else GameText.message("CIRCUIT %d/5 · 3 FREE RESUMES") % completed_tracks
		var circuit_progress: Label = MenuStyle.label(progress_text,16,true)
		circuit_progress.name = "WorldCircuitProgress"
		identity.add_child(circuit_progress)
	var timer := Timer.new()
	timer.name = "RivalryCountdownTimer"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func() -> void: clock_label.text = model.countdown())
	add_child(timer)
	var body := HBoxContainer.new()
	body.name = "RivalryBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	# An unresolved membership is not a confirmed invitation to join.
	if model.empty_completed_week():
		var transition: VBoxContainer = _card(body,"",28)
		var status: Label = _copy(transition,"",20,MenuStyle.MUTED)
		status.name = "RivalryEmptyStatus"
		_action(transition,"Refresh","RivalryRefresh",func() -> void: refresh_requested.emit()).disabled = busy
	elif model.tracks.is_empty() and signed_in and error.is_empty() and (busy or model.received_msec == 0): _loading(body)
	elif model.tracks.is_empty(): _empty(body)
	elif section == "result": _result(body)
	elif section == "overview" and model.completed: _finale(body)
	elif section == "detail": _detail(body)
	else: _overview(body)
	if standings_scroll == null: standings_ready = true

func _draw() -> void:
	# Weekly Rivalry shares the garage backdrop supplied by the menu shell.
	if not circuit_mode:
		draw_rect(Rect2(Vector2(-84,-100),size+Vector2(108,124)),Color(0.005,0.012,0.018,0.14))
		return
	var art: Texture2D = WINTER_ART
	var source := Rect2(0,art.get_height()*0.16,art.get_width(),art.get_height()*0.84)
	var factor: float = maxf(size.x/source.size.x,size.y/source.size.y)
	var visible: Vector2 = size/factor
	source.position += (source.size-visible)*0.5
	source.size = visible
	draw_texture_rect_region(art,Rect2(Vector2.ZERO,size),source)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.035,0.05,0.26))


func _card(parent: Control, theme_id: String = "", padding: int = 20) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame: StyleBoxFlat = MenuStyle.card(padding)
	frame.border_color = QUIET_BORDER
	frame.shadow_size = 3
	panel.add_theme_stylebox_override("panel",frame)
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

func _route(parent: Control, index: int, height: int = 82, markers: bool = false) -> void:
	var route := LapRouteView.new()
	route.miniature = true
	route.show_race_markers = markers
	if markers: detail_route = route
	for point: Array in model.tracks[index].document.get("points",[]): route.route.append(Vector2(point[0],point[1]))
	route.custom_minimum_size = Vector2(0,height)
	route.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route.modulate = Color("ffffff")
	parent.add_child(route)

func apply_track_preview(document: Dictionary) -> void:
	if not is_instance_valid(detail_route) or document.is_empty(): return
	var samples: Dictionary = TrackDocument.route_data(document)
	var route: PackedVector2Array = samples.points
	var widths: PackedFloat32Array = samples.widths
	if document.corners[0] == "sharp":
		var offset: int = mini(8,maxi(1,floori(Vector2(document.points[0][0],document.points[0][1]).distance_to(Vector2(document.points[1][0],document.points[1][1]))*0.5)))
		route = route.slice(offset)+route.slice(0,offset)
		widths = widths.slice(offset)+widths.slice(0,offset)
	if document.has("start_line"):
		route = CreatorStartLine.route_from_start(route,widths,document.start_line).points
	detail_route.race_route = route
	detail_route.show_race_markers = true
	detail_route._fit()

func _loading(parent: Control) -> void:
	parent.name = "RivalryLoading"
	parent.add_theme_constant_override("separation",14)
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation",12)
	parent.add_child(field)
	var podium := HBoxContainer.new()
	podium.name = "RivalryLoadingPodium"
	podium.custom_minimum_size.y = 194
	podium.add_theme_constant_override("separation",10)
	field.add_child(podium)
	for position: int in [1,0,2]:
		var card: VBoxContainer = _card(podium,"",0)
		var panel: PanelContainer = card.get_parent()
		panel.name = "RivalryLoadingPodium_"+str(position+1)
		panel.custom_minimum_size.y = 194-position
		panel.size_flags_vertical = Control.SIZE_SHRINK_END
		var color: Color = _medal_color(position)
		var style: StyleBoxFlat = _podium_style(position)
		panel.add_theme_stylebox_override("panel",style)
		card.add_theme_constant_override("separation",0)
		var car: Control = LoadingVisual.new()
		car.name = "RivalryLoadingCar_"+str(position+1)
		car.vehicle_id = "compact" if circuit_mode else VehicleCatalog.selected
		car.podium_color = color
		car.phase = position*0.22
		car.size_flags_vertical = Control.SIZE_EXPAND_FILL
		car.custom_minimum_size.y = 100
		card.add_child(car)
		var footer := PanelContainer.new()
		footer.name = "RivalryLoadingFooter_"+str(position+1)
		footer.custom_minimum_size.y = 56
		footer.add_theme_stylebox_override("panel",_podium_footer_style(style,color))
		card.add_child(footer)
		var identity: Control = LoadingVisual.new()
		identity.kind = LoadingVisual.Kind.IDENTITY
		identity.podium_color = color
		identity.custom_minimum_size.y = 40
		footer.add_child(identity)
		preload("res://ui/rivalry_podium_backdrop.gd").add_to(panel,footer,position)
	var standings: VBoxContainer = _card(field,"",12)
	_copy(standings,"STANDINGS",27)
	var rows: Control = LoadingVisual.new()
	rows.name = "RivalryLoadingStandings"
	rows.kind = LoadingVisual.Kind.STANDINGS
	rows.custom_minimum_size.y = 70
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	standings.add_child(rows)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.13
	right.add_theme_constant_override("separation",6)
	parent.add_child(right)
	var tracks: VBoxContainer = _track_card(right)
	tracks.get_parent().name = "RivalryLoadingTracksPanel"
	var leading: Label = find_child("RivalryTracksLeading",true,false)
	leading.text = GameText.message("%d OF %d LEADING") % [0,5]
	leading.modulate.a = 0.0
	var progress: Label = find_child("RivalryTrackProgress",true,false)
	progress.text = GameText.message("%d / %d COMPLETED") % [0,5]
	progress.modulate.a = 0.0
	find_child("RivalryTrackLeadStrip",true,false).modulate.a = 0.0
	var status: RichTextLabel = find_child("RivalryTracksHint",true,false)
	status.name = "RivalryLoadingTracksStatus"
	status.add_text(GameText.message("Loading tracks…"))
	status.tooltip_text = status.get_parsed_text()
	for slot: int in range(5): _loading_track_row(tracks,slot)

func _loading_track_row(parent: Control, slot: int) -> void:
	var row := Control.new()
	row.name = "RivalryLoadingTrack_"+str(slot)
	row.custom_minimum_size.y = 54
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var art: Control = LoadingVisual.new()
	art.name = "RivalryLoadingTrackArt_"+str(slot)
	art.kind = LoadingVisual.Kind.TRACK
	art.track_slot = slot
	row.add_child(art)
	MenuStyle.fill(art)
	var number := PanelContainer.new()
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number_style: StyleBoxFlat = MenuStyle.box(Color("071b29ed"),1)
	number_style.set_corner_radius_all(0)
	number.add_theme_stylebox_override("panel",number_style)
	number.position = Vector2(6,4)
	number.custom_minimum_size = Vector2(28,24)
	row.add_child(number)
	var label: Label = _copy(number,"%02d" % (slot+1),16,MenuStyle.MUTED)
	label.add_theme_font_override("font",MenuStyle.DISPLAY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _empty(parent: Control) -> void:
	var hero: VBoxContainer = _card(parent,"winter",28)
	_copy(hero,"A SMALL CHAMPIONSHIP.\nA NEW RIVALRY EACH WEEK.",46)
	_copy(hero,"Five tracks. Drivers near your pace.\nYour best result on each track counts.",22,MenuStyle.MUTED)
	_space(hero)
	var status: Label = _copy(hero,error if not error.is_empty() else "Finding this week's rivalry…" if busy else "Race as often as you like. Find your next rival.",20,MenuStyle.MUTED)
	status.name = "RivalryEmptyStatus"
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
	parent.add_theme_constant_override("separation",14)
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = 1.0
	field.add_theme_constant_override("separation",12)
	parent.add_child(field)
	_podium(field)
	_driver_table(field,"FINAL STANDINGS" if finale else "STANDINGS")
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.13
	right.add_theme_constant_override("separation",6)
	parent.add_child(right)
	var tracks: VBoxContainer = _track_card(right,finale)
	track_rows.clear()
	for index: int in range(model.tracks.size()): _track_row(tracks,index)
	if finale and not model.empty_completed_week():
		var actions := HBoxContainer.new()
		actions.name = "RivalryFinaleActions"
		tracks.add_child(actions)
		var share: Button = _action(actions,"SHARE RESULTS","RivalryShareResults",func() -> void: share_requested.emit())
		share.icon = MenuIcon.texture("share")
		share.expand_icon = true
		share.add_theme_constant_override("icon_max_width",20)
		share.clip_text = true
		share.add_theme_font_size_override("font_size",20)
		share.disabled = busy
		var next: Button = _action(actions,"CONTINUE TO NEXT WEEK","RivalryNextWeek",func() -> void: continue_requested.emit(),true)
		next.clip_text = true
		next.add_theme_font_size_override("font_size",20)
		next.disabled = busy
	_update_track_header()
	_select_track(selected)

func _track_card(parent: Control, finale: bool = false) -> VBoxContainer:
	var tracks: VBoxContainer = _card(parent,"",12)
	tracks.get_parent().name = "RivalryTracksPanel"
	_fit_track_spacing(tracks,finale)
	tracks.resized.connect(_fit_track_spacing.bind(tracks,finale))
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",10)
	tracks.add_child(heading)
	_copy(heading,"TRACK RESULTS" if finale else "THIS WEEK'S TRACKS",26).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var strip: Control = TrackAccent.new()
	strip.name = "RivalryTrackLeadStrip"
	strip.custom_minimum_size = Vector2(54,12)
	strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(strip)
	var totals := VBoxContainer.new()
	totals.add_theme_constant_override("separation",0)
	heading.add_child(totals)
	var leading: Label = _copy(totals,"",18,MenuStyle.POSITIVE)
	leading.name = "RivalryTracksLeading"
	leading.autowrap_mode = TextServer.AUTOWRAP_OFF
	leading.add_theme_font_override("font",MenuStyle.DISPLAY)
	leading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var progress: Label = _copy(totals,"",12,MenuStyle.MUTED)
	progress.name = "RivalryTrackProgress"
	progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var subtitle: Label = _copy(tracks,error if not error.is_empty() else "Week complete. Your best results." if finale else "Choose a track and beat your best time.",15,MenuStyle.MUTED)
	subtitle.name = "RivalryStatusMessage"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle.clip_text = true
	subtitle.tooltip_text = subtitle.text
	subtitle.visible = not error.is_empty()
	var hint := RichTextLabel.new()
	hint.name = "RivalryTracksHint"
	hint.fit_content = finale
	if not finale:
		hint.custom_minimum_size.y = ceili(MenuStyle.BODY.get_height(15))
		hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.scroll_active = false
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("normal_font",MenuStyle.BODY)
	hint.add_theme_font_size_override("normal_font_size",15)
	hint.add_theme_color_override("default_color",MenuStyle.MUTED)
	tracks.add_child(hint)
	if finale and not model.world_circuit.is_empty() and is_instance_valid(safety_client):
		var world: Control = preload("res://ui/world_ranking_week_summary.gd").new()
		world.client = safety_client
		world.week_start = int(model.world_circuit.get("week_start",0))
		world.compact = true
		tracks.add_child(world)
		world.label.add_theme_font_size_override("font_size",13)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation",10)
	var legend_margin := MarginContainer.new()
	legend_margin.add_theme_constant_override("margin_left",6)
	legend_margin.add_theme_constant_override("margin_right",6)
	tracks.add_child(legend_margin)
	legend_margin.add_child(legend)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_child(spacer)
	var place_heading: Label = _copy(legend,"PLACE",11,MenuStyle.MUTED)
	place_heading.custom_minimum_size.x = 56
	place_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var divider_space := Control.new()
	divider_space.custom_minimum_size.x = 1
	legend.add_child(divider_space)
	var time_heading: Label = _copy(legend,"YOUR BEST",11,MenuStyle.MUTED)
	time_heading.name = "RivalryTrackTimeHeading"
	time_heading.custom_minimum_size.x = 116
	time_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return tracks

func _fit_track_spacing(tracks: VBoxContainer, finale: bool) -> void:
	var gap: int = 2 if finale else 0 if get_viewport_rect().size.y < 600 else 6
	if tracks.get_theme_constant("separation") != gap:
		tracks.add_theme_constant_override("separation",gap)

func _driver_table(parent: Control, title: String) -> void:
	var table: VBoxContainer = _card(parent,"",12)
	table.get_parent().name = "RivalryDriversPanel"
	table.add_theme_constant_override("separation",7)
	var heading := HBoxContainer.new()
	table.add_child(heading)
	_copy(heading,title,27).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy(heading,GameText.message("%d DRIVERS") % model.standing().size(),14,MenuStyle.MUTED)
	var scroll := ScrollContainer.new()
	standings_scroll = scroll
	scroll.name = "RivalryStandingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var legend_margin := MarginContainer.new()
	legend_margin.name = "RivalryStandingsColumnHeader"
	legend_margin.add_theme_constant_override("margin_left",5)
	legend_margin.add_theme_constant_override("margin_right",ceili(scroll.get_v_scroll_bar().get_combined_minimum_size().x)+STANDINGS_GUTTER+5)
	bar.resized.connect(func() -> void:
		legend_margin.add_theme_constant_override("margin_right",ceili(bar.size.x)+STANDINGS_GUTTER+5))
	table.add_child(legend_margin)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation",9)
	legend_margin.add_child(legend)
	_copy(legend,"#",14,MenuStyle.MUTED).custom_minimum_size.x = 30
	_copy(legend,"DRIVER",14,MenuStyle.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for column: Array in [["POINTS",60],["GAP",54]]:
		var label: Label = _copy(legend,str(column[0]),14,MenuStyle.MUTED)
		label.name = "RivalryColumn_"+str(column[0])
		label.custom_minimum_size.x = int(column[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	table.add_child(scroll)
	var row_margin := MarginContainer.new()
	row_margin.name = "RivalryStandingsScrollGutter"
	row_margin.add_theme_constant_override("margin_right",STANDINGS_GUTTER)
	row_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row_margin)
	var rows := VBoxContainer.new()
	_driver_rows = rows
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",2)
	row_margin.add_child(rows)
	var own_panel: Control
	var standings: Array[Dictionary] = model.standing()
	var leader_points: int = int(standings[0].points)
	for driver: Dictionary in standings:
		var panel := PanelContainer.new()
		panel.name = "Driver_"+str(driver.id)
		panel.custom_minimum_size.y = 38
		panel.add_theme_stylebox_override("panel",_driver_style(driver))
		rows.add_child(panel)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",9)
		panel.add_child(line)
		var own: bool = driver.id == WeeklyRivalry.SELF
		var color: Color = MenuStyle.ACCENT if own else MenuStyle.TEXT
		var badge := PanelContainer.new()
		badge.custom_minimum_size.x = 30
		var podium_color: Color = _medal_color(int(driver.rank)-1) if driver.get("rank") != null and int(driver.rank) <= 3 else Color.TRANSPARENT
		badge.add_theme_stylebox_override("panel",_badge_style(podium_color))
		line.add_child(badge)
		var place: Label = _copy(badge,str(int(driver.rank)) if driver.get("rank") != null else "--",19,color)
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(PlayerCountry.flag(str(driver.get("country_code","")),28))
		var name_label: Label = _copy(line,_display_name(driver),18,color)
		name_label.name = "RivalryPlayerName_"+str(driver.id)
		_profile_name(name_label,driver)
		name_label.add_theme_font_override("font",MenuStyle.DISPLAY)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var points: Label = _copy(line,str(int(driver.points)),18,color)
		points.name = "RivalryPlayerPoints_"+str(driver.id)
		points.custom_minimum_size.x = 60
		points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var gap: Label = _copy(line,"--" if driver.get("rank") == null or int(driver.points) == leader_points else str(int(driver.points)-leader_points),18,color if own else MenuStyle.MUTED)
		gap.name = "RivalryPlayerGap_"+str(driver.id)
		gap.custom_minimum_size.x = 54
		gap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_driver_views[str(driver.id)] = {"panel":panel,"badge":badge,"rank":place,"points":points,"gap":gap,"state":var_to_bytes([driver,leader_points])}
		if own: own_panel = panel
	if standings_scroll_offset >= 0:
		# Seed the real range before its first draw, rather than painting at zero
		# and restoring the remembered rows a few frames later.
		scroll.get_v_scroll_bar().max_value = rows.get_combined_minimum_size().y
		scroll.scroll_vertical = standings_scroll_offset
	if own_panel != null: _reveal_player.call_deferred(scroll,own_panel)

func _reveal_player(scroll: Variant, player: Variant) -> void:
	# One-shot callbacks disconnect when a refresh removes this page.
	if not is_inside_tree(): return
	get_tree().process_frame.connect(_reveal_after_sort.bind(scroll,player),CONNECT_ONE_SHOT)

func _reveal_after_sort(scroll: Variant, player: Variant) -> void:
	if not is_inside_tree() or not is_instance_valid(scroll) or not is_instance_valid(player): return
	get_tree().process_frame.connect(_ensure_player_visible.bind(scroll,player),CONNECT_ONE_SHOT)

func _ensure_player_visible(scroll: Variant, player: Variant) -> void:
	if is_inside_tree() and is_instance_valid(scroll) and is_instance_valid(player):
		if standings_scroll_offset < 0: scroll.ensure_control_visible(player)
		standings_ready = true

func _profile_name(label: Label, driver: Dictionary) -> void:
	GameText.user_text(label)
	if not is_instance_valid(safety_client) or driver.id == WeeklyRivalry.SELF: return
	preload("res://ui/player_profile.gd").bind_name(label,_open_player.bind(driver))

func _open_player(driver: Dictionary) -> void:
	if not is_instance_valid(safety_client) or driver.id == WeeklyRivalry.SELF: return
	var profile: Dictionary = driver.duplicate(true)
	# Track boards omit appearance; the same account's overall row owns its car.
	for row: Dictionary in model.standing():
		if str(row.get("driver_id",row.id)) == str(driver.get("driver_id",driver.id)):
			profile.merge(row,true)
			break
	profile.catalog_creator = str(profile.name)
	profile.name = _display_name(profile)
	preload("res://ui/player_profile.gd").open(self,safety_client,profile,model.vehicle_id)

func _display_name(row: Dictionary) -> String:
	var value: String = str(row.name)
	if bool(row.get("is_test_driver",false)):
		var marker: int = value.find(" T")
		if marker >= 0 and value.substr(marker+2).contains("-"): value = value.substr(0,marker)
	return value

func _position_summary() -> String:
	if model.completed:
		var summary: Dictionary = model.finale_summary()
		return GameText.message("PERFECT\nWEEK").replace("\n"," ") if summary.perfect else GameText.message(summary.title)
	var rows: Array[Dictionary] = model.standing()
	var own: Dictionary = model.self_row(rows)
	if own.get("rank") == null: return GameText.message("UNRANKED OF %d") % rows.size()
	var place: int = int(own.rank)
	var suffix: String = "TH" if place % 100 in [11,12,13] else "ST" if place % 10 == 1 else "ND" if place % 10 == 2 else "RD" if place % 10 == 3 else "TH"
	if not TranslationServer.get_locale().begins_with("en"): suffix = ""
	var position: String = GameText.message("%d%s OF %d") % [place,suffix,rows.size()]
	if rows.size() < 2: return position
	var points: int = int(own.points)
	var leader_points: int = int(rows[0].points)
	if points < leader_points: return position+GameText.message(" · %d PTS TO LEAD") % (leader_points-points)
	var nearest: Dictionary = rows[1] if rows[0].id == WeeklyRivalry.SELF else rows[0]
	if points == int(nearest.points): return position+GameText.message(" · TIED FOR LEAD")
	return position+GameText.message(" · %d PTS AHEAD") % (points-int(nearest.points))

func _update_position_summary() -> void:
	var summary := find_child("RivalryPositionSummary",true,false) as Label
	if summary != null: summary.text = _position_summary()

func _badge_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.box(Color(color,0.38) if color.a > 0.0 else Color.TRANSPARENT,0)
	if color.a > 0.0:
		style.border_color = Color(color,0.7)
		style.set_border_width_all(1)
		style.border_width_top = 2
		style.shadow_color = Color(0,0,0,0.22)
		style.shadow_size = 2
	return style

func _driver_style(row: Dictionary) -> StyleBoxFlat:
	var style := MenuStyle.box(Color("423613a0") if row.id == WeeklyRivalry.SELF else Color("08172055"),5)
	style.border_color = MenuStyle.ACCENT if row.id == WeeklyRivalry.SELF else Color("2c485755")
	if row.id == WeeklyRivalry.SELF:
		style.set_border_width_all(2)
		style.shadow_color = Color("ffd34818")
		style.shadow_size = 3
	else: style.border_width_bottom = 1
	return style

func _medal_color(position: int) -> Color:
	return MenuStyle.ACCENT if position == 0 else Color("c0d4e3") if position == 1 else Color("dc9069")

func _podium_style(position: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.card(1)
	style.bg_color = Color("27220df5") if position == 0 else Color("152b39f5") if position == 1 else Color("302019f5")
	style.border_color = Color("f3c936") if position == 0 else Color("477c98") if position == 1 else Color("b66440")
	style.shadow_color = Color(_medal_color(position),0.15)
	style.shadow_size = 5 if position == 0 else 3
	style.border_width_top = 2
	return style

func _podium_footer_style(style: StyleBoxFlat, color: Color) -> StyleBoxFlat:
	var footer: StyleBoxFlat = MenuStyle.box(style.bg_color.darkened(0.06),12)
	footer.corner_radius_top_left = 0
	footer.corner_radius_top_right = 0
	footer.corner_radius_bottom_left = 4
	footer.corner_radius_bottom_right = 4
	footer.content_margin_top = 7
	footer.content_margin_bottom = 7
	footer.border_width_top = 1
	footer.border_color = Color(color,0.18)
	return footer

func _podium(parent: Control) -> void:
	var podium := HBoxContainer.new()
	podium.name = "RivalryPodium"
	podium.custom_minimum_size.y = 194
	podium.add_theme_constant_override("separation",10)
	parent.add_child(podium)
	var leaders: Array[Dictionary] = []
	for row: Dictionary in model.standing():
		if row.get("rank") != null and leaders.size() < 3: leaders.append(row)
	if leaders.is_empty():
		var intro: VBoxContainer = _card(podium,"winter",12)
		intro.add_theme_constant_override("separation",4)
		if model.completed:
			_copy(intro,"WEEK COMPLETE",24,MenuStyle.ACCENT)
			_copy(intro,GameText.message("%d / %d COMPLETED") % [0,model.tracks.size()],17,MenuStyle.MUTED)
		else:
			_copy(intro,"THE WEEK STARTS HERE",24,MenuStyle.ACCENT)
			_copy(intro,"Five circuits. Unlimited attempts.",17)
			_copy(intro,"Set your first time to join the battle.",16,MenuStyle.MUTED)
		return
	for position: int in [1,0,2]:
		if position >= leaders.size(): continue
		var driver: Dictionary = leaders[position]
		var color: Color = _medal_color(position)
		var card: VBoxContainer = _card(podium,"",0)
		var panel: PanelContainer = card.get_parent()
		panel.name = "RivalryPodium_"+str(position+1)
		panel.custom_minimum_size.y = 194-position
		panel.size_flags_vertical = Control.SIZE_SHRINK_END
		panel.size_flags_stretch_ratio = 1.0
		var style: StyleBoxFlat = _podium_style(position)
		panel.add_theme_stylebox_override("panel",style)
		card.add_theme_constant_override("separation",0)
		var rank_margin := MarginContainer.new()
		rank_margin.add_theme_constant_override("margin_top",5)
		card.add_child(rank_margin)
		var rank := HBoxContainer.new()
		rank.alignment = BoxContainer.ALIGNMENT_CENTER
		rank.add_theme_constant_override("separation",8)
		rank_margin.add_child(rank)
		var icon := TextureRect.new()
		icon.texture = MenuIcon.texture("trophy")
		icon.custom_minimum_size = Vector2(24,26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = color
		rank.add_child(icon)
		_copy(rank,rank_text(driver),30,color).name = "RivalryPodiumRank_"+str(position+1)
		# Absorb the subtle rank steps above the shared car and footer baselines.
		var header_space := Control.new()
		header_space.custom_minimum_size.y = 2-position
		header_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		header_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(header_space)
		var car: Control = preload("res://ui/rivalry_victory_car.gd").new()
		car.name = "RivalryPodiumCar_"+str(position+1)
		car.vehicle_id = model.vehicle_id
		car.simple_model = true
		car.podium_presentation = true
		car.fit_to_frame = true
		var appearance: Variant = driver.get("appearance",{})
		if appearance is Dictionary and appearance.get("vehicle_id") == model.vehicle_id:
			if VehicleLivery.valid(appearance.get("livery")): car.livery = VehicleLivery.normalize(appearance.livery,model.vehicle_id)
			if VehicleCustomisation.valid(appearance.get("customisation")):
				car.customisation = appearance.customisation.duplicate(true)
				car.customisation.version = VehicleCustomisation.VERSION
		if driver.id == WeeklyRivalry.SELF:
			if VehicleLivery.valid(finale_livery): car.livery = finale_livery.duplicate(true)
			if VehicleCustomisation.valid(finale_customisation): car.customisation = finale_customisation.duplicate(true)
		car.custom_minimum_size.y = 88
		card.add_child(car)
		var footer := PanelContainer.new()
		footer.name = "RivalryPodiumFooter_"+str(position+1)
		footer.custom_minimum_size.y = 56
		var footer_style: StyleBoxFlat = _podium_footer_style(style,color)
		footer.add_theme_stylebox_override("panel",footer_style)
		card.add_child(footer)
		preload("res://ui/rivalry_podium_backdrop.gd").add_to(panel,footer,position)
		var identity := HBoxContainer.new()
		identity.name = "RivalryPodiumIdentity_"+str(position+1)
		identity.add_theme_constant_override("separation",6)
		footer.add_child(identity)
		identity.add_child(PlayerCountry.flag(str(driver.get("country_code","")),28))
		var driver_name: Label = _copy(identity,_display_name(driver),20)
		driver_name.name = "RivalryPodiumName_"+str(position+1)
		_profile_name(driver_name,driver)
		driver_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		driver_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		driver_name.add_theme_font_override("font",MenuStyle.DISPLAY)
		driver_name.add_theme_color_override("font_color",MenuStyle.TEXT.lerp(color,0.12))
		driver_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		driver_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		driver_name.clip_text = true
		var score := VBoxContainer.new()
		score.add_theme_constant_override("separation",-2)
		score.custom_minimum_size.x = 30
		score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		identity.add_child(score)
		var points: Label = _copy(score,str(int(driver.points)),22,color)
		points.name = "RivalryPodiumPoints_"+str(position+1)
		points.add_theme_font_override("font",MenuStyle.DISPLAY)
		points.autowrap_mode = TextServer.AUTOWRAP_OFF
		points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var unit: Label = _copy(score,"PTS",11,MenuStyle.MUTED)
		unit.autowrap_mode = TextServer.AUTOWRAP_OFF
		unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _track_time(gap: Dictionary) -> String:
	if not model.completed and gap.get("pending_ms") != null: return MenuStyle.time_text(int(gap.pending_ms)/1000.0)
	if gap.own.get("ms") != null: return MenuStyle.time_text(int(gap.own.ms)/1000.0)
	if model.completed: return "—"
	return MenuStyle.time_text(int(gap.leader.ms)/1000.0) if not gap.leader.is_empty() else "—"

func _track_delta(gap: Dictionary) -> String:
	if model.completed: return GameText.message("POINTS")+" "+str(int(gap.own.get("points",0)))
	if gap.get("pending_ms") != null: return "Verifying..."
	if gap.own.get("rank") == 1: return "Leading"
	if gap.own.get("ms") != null and not gap.leader.is_empty(): return GameText.message("{gap} to lead",{"gap":WeeklyRivalry.gap_text(int(gap.own.ms)-int(gap.leader.ms))})
	return "Leader time" if not gap.leader.is_empty() else "Set a time"

func _track_status_color(gap: Dictionary) -> Color:
	if gap.get("pending_ms") != null: return MenuStyle.MUTED
	if gap.own.get("rank") == 1: return MenuStyle.POSITIVE
	if gap.own.get("ms") != null and not gap.leader.is_empty(): return MenuStyle.ACCENT
	return MenuStyle.MUTED

func _track_header_state() -> Dictionary:
	var result: Dictionary = {"leading":0,"completed":0,"target":-1,"target_gap":0,"states":PackedInt32Array()}
	var closest: int = 2147483647
	for index: int in range(model.tracks.size()):
		var gap: Dictionary = model.track_summary(index)
		var completed: bool = gap.own.get("ms") != null
		var leading: bool = completed and gap.own.get("rank") == 1
		if completed: result.completed += 1
		if leading: result.leading += 1
		result.states.append(2 if leading else 1 if completed else 0)
		if not bool(model.tracks[index].get("available",true)) or gap.get("pending_ms") != null: continue
		if not completed or leading or gap.ahead.get("ms") == null: continue
		var difference: int = int(gap.own.ms)-int(gap.ahead.ms)
		if difference > 0 and difference < closest:
			closest = difference
			result.target = index
			result.target_gap = difference
	return result

func _update_track_header() -> void:
	if model.tracks.is_empty(): return
	var label := find_child("RivalryTracksLeading",true,false) as Label
	if label == null: return
	var state: Dictionary = _track_header_state()
	var total: int = model.tracks.size()
	label.text = GameText.message("%d / 5 WON") % int(model.finale_summary().wins) if model.completed else GameText.message("%d OF %d LEADING") % [state.leading,total]
	(find_child("RivalryTrackProgress",true,false) as Label).text = GameText.message("%d / %d COMPLETED") % [state.completed,total]
	find_child("RivalryTrackLeadStrip",true,false).set("states",state.states)
	var time_heading := find_child("RivalryTrackTimeHeading",true,false) as Label
	time_heading.text = "YOUR BEST" if model.completed or state.completed == total else "BEST / LEADER"
	var message := find_child("RivalryStatusMessage",true,false) as Label
	message.visible = not error.is_empty()
	var hint := find_child("RivalryTracksHint",true,false) as RichTextLabel
	var world: Control = find_child("WorldRankingWeekResult",true,false)
	if world != null: world.visible = error.is_empty()
	hint.visible = error.is_empty() and world == null
	hint.clear()
	if model.completed:
		var highlights: Array = model.finale_summary().highlights
		hint.add_text(" · ".join(highlights.slice(0,2)))
		for index: int in range(_track_views.size()):
			_track_views[index].target.visible = false
			track_rows[index].tooltip_text = "View "+str(model.tracks[index].name)
		return
	elif state.leading == total:
		hint.add_text(tr("You lead every track. "))
		hint.push_color(MenuStyle.POSITIVE)
		hint.add_text(tr("Keep your advantage."))
	elif state.leading > 0:
		hint.add_text(GameText.plural("You lead on {count} track. ","You lead on {count} tracks. ",int(state.leading)))
		hint.push_color(MenuStyle.ACCENT)
		hint.add_text(tr("One more to conquer.") if total-int(state.leading) == 1 else GameText.message("%d more to conquer.") % (total-int(state.leading)))
	else:
		hint.add_text(tr("Set your first time. " if state.completed == 0 else "Your best times are on the board. "))
		hint.push_color(MenuStyle.ACCENT)
		hint.add_text(tr("Pick a track to begin." if state.completed == 0 else "Choose your next target."))
	hint.pop()
	hint.tooltip_text = hint.get_parsed_text()
	for index: int in range(_track_views.size()):
		_track_views[index].target.visible = index == int(state.target)
		track_rows[index].tooltip_text = "View "+str(model.tracks[index].name)
		if index == int(state.target):
			_track_views[index].target.tooltip_text = GameText.message("%s to the driver ahead.") % WeeklyRivalry.gap_text(int(state.target_gap))
			track_rows[index].tooltip_text += " · "+str(_track_views[index].target.tooltip_text)

func _track_row(parent: Control, index: int) -> void:
	var track: Dictionary = model.tracks[index]
	var compact_circuit: bool = model.completed and not model.world_circuit.is_empty()
	var line := HBoxContainer.new()
	line.name = "RivalryTrackRow_"+str(index)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation",6)
	parent.add_child(line)
	var row := MenuStyle.button("",func() -> void: track_requested.emit(index))
	row.name = "SelectRivalryTrack_"+str(index)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0,54)
	row.tooltip_text = "View "+str(track.name)
	row.focus_entered.connect(func() -> void: _select_track(index))
	line.add_child(row)
	track_rows.append(row)
	var neutral: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,0)
	neutral.set_corner_radius_all(0)
	neutral.border_width_bottom = 1
	neutral.border_color = Color("31566a99")
	for state: String in ["normal","hover"]: row.add_theme_stylebox_override(state,neutral)
	var pressed: StyleBoxFlat = neutral.duplicate()
	pressed.bg_color = Color("1b3c4cdb")
	row.add_theme_stylebox_override("pressed",pressed)
	row.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation",10)
	row.add_child(content_row)
	content_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_row.offset_left = 6
	content_row.offset_right = -6
	content_row.offset_top = 4
	content_row.offset_bottom = -4
	var thumbnail := Control.new()
	thumbnail.name = "RivalryTrackThumbnail_"+str(index)
	thumbnail.custom_minimum_size.x = 110
	thumbnail.clip_contents = true
	content_row.add_child(thumbnail)
	var art := TextureRect.new()
	art.texture = TrackTile.scenery_texture(str(track.theme))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumbnail.add_child(art)
	MenuStyle.fill(art)
	var profile := TrackProfile.new()
	profile.name = "RivalryTrackProfile_"+str(index)
	profile.miniature = true
	for point: Array in track.document.get("points",[]): profile.route.append(Vector2(point[0],point[1]))
	thumbnail.add_child(profile)
	MenuStyle.fill(profile)
	# Leave the numbered corner clear while fitting the actual saved route.
	profile.offset_left = 24
	var number := PanelContainer.new()
	number.name = "RivalryTrackNumber_"+str(index)
	var number_style: StyleBoxFlat = MenuStyle.box(Color("071b29ed"),1)
	number_style.set_corner_radius_all(0)
	number_style.set_border_width_all(1)
	number_style.border_color = Color.TRANSPARENT
	number.add_theme_stylebox_override("panel",number_style)
	number.custom_minimum_size = Vector2(28,24)
	number.size = number.custom_minimum_size
	thumbnail.add_child(number)
	var number_label: Label = _copy(number,"%02d" % (index+1),16,MenuStyle.MUTED)
	number_label.add_theme_font_override("font",MenuStyle.DISPLAY)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var focused_number: StyleBoxFlat = number_style.duplicate()
	focused_number.border_color = MenuStyle.MUTED
	row.focus_entered.connect(func() -> void: number.add_theme_stylebox_override("panel",focused_number))
	row.focus_exited.connect(func() -> void: number.add_theme_stylebox_override("panel",number_style))
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation",1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(copy)
	var title: Label = _copy(copy,str(track.name).to_upper(),22 if compact_circuit else 24)
	GameText.user_text(title)
	title.name = "RivalryTrackTitle_"+str(index)
	title.add_theme_font_override("font",MenuStyle.DISPLAY)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	var gap: Dictionary = model.track_summary(index)
	var biome := HBoxContainer.new()
	biome.add_theme_constant_override("separation",5)
	biome.custom_minimum_size.y = 20
	copy.add_child(biome)
	var glyph := TextureRect.new()
	glyph.texture = MenuIcon.texture(Badge.icon(str(track.theme)))
	glyph.modulate = Badge.color(str(track.theme))
	glyph.custom_minimum_size = Vector2(15,15)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	biome.add_child(glyph)
	_copy(biome,"City" if track.theme == "night_city" else TrackTheme.title(str(track.theme)),14,MenuStyle.MUTED)
	var target: Label = _copy(content_row,"NEXT TARGET",16,MenuStyle.INK)
	target.name = "RivalryTrackTarget_"+str(index)
	target.add_theme_font_override("font",MenuStyle.DISPLAY)
	var target_style: StyleBoxFlat = MenuStyle.box(MenuStyle.ACCENT,6)
	target_style.content_margin_top = 4
	target_style.content_margin_bottom = 4
	target.add_theme_stylebox_override("normal",target_style)
	target.custom_minimum_size = Vector2(108,30)
	target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	target.visible = false
	var rank: Control = TrackAccent.new()
	rank.rank_plate = true
	rank.custom_minimum_size = Vector2(56,44)
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(rank)
	var position: Label = _copy(rank,rank_text(gap.own),28,MenuStyle.ACCENT if gap.own.get("rank") == 1 else MenuStyle.TEXT)
	position.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	MenuStyle.fill(position)
	var separator := ColorRect.new()
	separator.color = Color("2c4e6088")
	separator.custom_minimum_size = Vector2(1,40)
	separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_row.add_child(separator)
	var times := VBoxContainer.new()
	times.custom_minimum_size.x = 116
	times.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	times.add_theme_constant_override("separation",1)
	content_row.add_child(times)
	var time: Label = _copy(times,_track_time(gap),24 if compact_circuit else 26)
	time.add_theme_font_override("font",MenuStyle.DISPLAY)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var delta: Label = _copy(times,_track_delta(gap),13,_track_status_color(gap))
	delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_track_views.append({"rank":position,"time":time,"delta":delta,"target":target})
	_ignore_tree(content_row)

func _select_track(index: int) -> void:
	if selected != index: track_selected.emit(index)
	selected = index

func _ignore_tree(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children(): _ignore_tree(child)

func _detail(parent: Control) -> void:
	selected = clampi(selected,0,model.tracks.size()-1)
	var track: Dictionary = model.tracks[selected]
	var layout := VBoxContainer.new()
	layout.name = "RivalryTrackDetail"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation",14)
	parent.add_child(layout)
	var cards := HBoxContainer.new()
	cards.name = "RivalryDetailCards"
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation",14)
	layout.add_child(cards)
	var scene: VBoxContainer = _card(cards,str(track.theme))
	scene.get_parent().name = "RivalryDetailTrackCard"
	scene.add_child(Badge.view(str(track.theme),15))
	_copy(scene,str(track.name).to_upper(),48)
	_route(scene,selected,100,true)
	if model.sample: apply_track_preview(track.document)
	else: detail_route.show_race_markers = false
	_copy(scene,VehicleCatalog.title(model.vehicle_id),18,MenuStyle.MUTED)
	if not bool(track.get("available",true)): _copy(scene,"This track is unavailable for racing.",15,MenuStyle.MUTED)
	if not error.is_empty(): _copy(scene,error,15,MenuStyle.MUTED)
	var board: VBoxContainer = _card(cards,"",14)
	board.get_parent().name = "RivalryDetailStandingsCard"
	board.get_parent().size_flags_stretch_ratio = 1.14
	board.add_theme_constant_override("separation",8)
	_copy(board,"YOUR POSITION",18,MenuStyle.MUTED)
	var gap: Dictionary = model.gaps(selected)
	_rank(board,gap.own,model.board(selected).size(),48)
	var standings := preload("res://ui/rivalry_track_standings.gd").new()
	standings.board = model.board(selected)
	standings.player_requested.connect(_open_player)
	board.add_child(standings)
	# Keep the chosen policy when a field has no recording yet. A later race
	# resolves it again against the current verified standings.
	var actions := HBoxContainer.new()
	actions.name = "RivalryDetailActions"
	actions.add_theme_constant_override("separation",14)
	actions.custom_minimum_size.y = 64
	layout.add_child(actions)
	var back: Button = _action(actions,"←  BACK TO TRACKS","RivalryBackToOverview",func() -> void: section_requested.emit("overview"))
	back.custom_minimum_size.y = 64
	var race: Button = _action(actions,"RACE "+str(track.name).to_upper()+"  →","RivalryStartRace",func() -> void: race_requested.emit(selected,ghost_choice),true)
	race.custom_minimum_size.y = 64
	race.disabled = (busy and not background_refresh) or model.completed or model.status != "active" or not bool(track.get("available",true))
	if model.completed: race.text = "WEEK COMPLETE"
	elif not bool(track.get("available",true)): race.text = "TRACK UNAVAILABLE"
	elif busy and not background_refresh: race.text = "UPDATING RIVALRY..." if error.is_empty() else "RIVALRY UNAVAILABLE"
	elif model.status != "active": race.text = "RIVALRY NOT ACTIVE"

func _result(parent: Control) -> void:
	var result_view := WeeklyRivalryResult.new()
	result_view.model = model
	result_view.index = clampi(selected,0,model.tracks.size()-1)
	result_view.details = race_details
	result_view.pending = pending_result
	result_view.busy = busy
	result_view.error = error
	result_view.retry_requested.connect(func() -> void: retry_requested.emit())
	result_view.home_requested.connect(func() -> void: section_requested.emit("overview"))
	result_view.player_requested.connect(_open_player)
	parent.add_child(result_view)

func _finale(parent: Control) -> void:
	_championship(parent,true)

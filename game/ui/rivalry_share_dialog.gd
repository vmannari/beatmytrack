extends "res://ui/fault_dialog.gd"
## Completed championship preview and clean image export for platform sharing.
signal share_requested
signal save_requested
const VictoryCar = preload("res://ui/rivalry_victory_car.gd")
const Finale = preload("res://ui/weekly_rivalry_finale.gd")
const SHARE_FRAME: Shader = preload("res://ui/rivalry_share.gdshader")
var model: WeeklyRivalry
var livery: Dictionary = {}
var customisation: Dictionary = {}
var condition: Dictionary = {}
var player_name: String = ""
var export_mode: bool = false
var native_sharing: bool = false
var sharing: bool = false
var request_id: String = ""
var prepared_png := PackedByteArray()
var image_renderer: Callable
var summary: Dictionary
var share_text: String = ""
var hero: Control
var hero_heading: Label
var identity: HBoxContainer
var vehicle: Control
var vehicle_label: Label
var right: VBoxContainer
var table_heading: HBoxContainer
var result_rows: Array[Control] = []
var metric_labels: Array[Label] = []
var copied: HBoxContainer
var status_label: Label
var divider: ColorRect

func _ready() -> void:
	name = "RivalryShareDialog"
	title = "Weekly Rivalry results"
	borderless = true
	transparent_bg = true
	transparent = true
	unresizable = true
	exclusive = true
	wrap_controls = false
	min_size = Vector2i(820,560)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	get_label().hide()
	get_ok_button().hide()
	summary = model.finale_summary()
	share_text = model.finale_share_text()
	surface = Control.new()
	surface.name = "ShareSurface"
	surface.theme = MenuStyle.theme()
	add_child(surface)
	MenuStyle.fill(surface)
	art = TextureRect.new()
	art.texture = ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHARE_FRAME
	art.material = material
	surface.add_child(art)
	MenuStyle.fill(art)
	_build_hero()
	_build_results()
	_build_footer()
	if export_mode:
		close_button.hide()
		confirm_button.hide()
		copied.hide()
		divider.hide()
	surface.resized.connect(_layout)
	about_to_popup.connect(_opening)
	visibility_changed.connect(_visibility_changed)
	_layout()

func _label(parent: Control, text: String, font_size: int, color: Color = MenuStyle.TEXT, display: bool = false) -> Label:
	var value := MenuStyle.label(text,font_size)
	value.add_theme_color_override("font_color",color)
	if display: value.add_theme_font_override("font",MenuStyle.DISPLAY)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(value)
	return value

func _build_hero() -> void:
	hero = Control.new()
	hero.name = "ShareHero"
	surface.add_child(hero)
	var event := HBoxContainer.new()
	event.position = Vector2(28,28)
	event.add_theme_constant_override("separation",10)
	hero.add_child(event)
	var icon := TextureRect.new()
	icon.texture = MenuIcon.texture("trophy")
	icon.modulate = MenuStyle.ACCENT
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(23,23)
	event.add_child(icon)
	_label(event,"WEEKLY RIVALRY",23,MenuStyle.TEXT,true)
	var week: Label = _label(hero,GameText.message("WEEK %02d") % model.week,16,MenuStyle.ACCENT,true)
	week.position = Vector2(28,67)
	hero_heading = _label(hero,summary.title.replace("WEEK COMPLETE","WEEK\nCOMPLETE").replace("PODIUM FINISH","PODIUM\nFINISH").replace("WEEKLY CHAMPION","WEEKLY\nCHAMPION"),58,Color("ffe4a0") if summary.tier > 0 else MenuStyle.TEXT,true)
	hero_heading.name = "ShareAwardTitle"
	hero_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var own: Dictionary = WeeklyRivalry.self_row(model.standing())
	identity = HBoxContainer.new()
	identity.add_theme_constant_override("separation",10)
	hero.add_child(identity)
	identity.add_child(PlayerCountry.flag(str(own.get("country_code","")),24))
	var driver: Label = _label(identity,player_name if not player_name.is_empty() else str(own.get("name","")),19)
	driver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	driver.clip_text = true
	driver.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vehicle = VictoryCar.new()
	vehicle.name = "ShareEventCar"
	vehicle.vehicle_id = model.vehicle_id
	vehicle.livery = livery
	vehicle.customisation = customisation
	vehicle.condition = condition
	vehicle.podium_presentation = true
	vehicle.fit_to_frame = true
	hero.add_child(vehicle)
	vehicle_label = _label(hero,VehicleCatalog.title(model.vehicle_id),18,MenuStyle.TEXT,true)
	vehicle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if summary.perfect:
		var perfect: Label = _label(hero,"PERFECT WEEK",16,MenuStyle.ACCENT,true)
		perfect.name = "SharePerfectWeek"
		perfect.position = Vector2(28,94)
	var brand: Label = _label(hero,"BEAT MY TRACK",14,MenuStyle.MUTED,true)
	brand.name = "ShareBrand"

func _build_results() -> void:
	right = VBoxContainer.new()
	right.name = "ShareResults"
	right.add_theme_constant_override("separation",16)
	surface.add_child(right)
	heading = _label(right,"YOUR RESULTS",30,MenuStyle.TEXT,true)
	heading.name = "ShareHeading"
	var metrics := HBoxContainer.new()
	metrics.name = "ShareMetrics"
	metrics.add_theme_constant_override("separation",24)
	right.add_child(metrics)
	var position: String = "—" if summary.rank == null else "%02d / %d" % [int(summary.rank),int(summary.drivers)]
	for fact: Array in [[position,"FINAL POSITION"],[str(summary.points),"TOTAL POINTS"],["%d / 5" % summary.wins,"TRACK VICTORIES"]]:
		var field := VBoxContainer.new()
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.add_theme_constant_override("separation",0)
		metrics.add_child(field)
		var value: Label = _label(field,str(fact[0]),40,MenuStyle.ACCENT if summary.tier > 0 else MenuStyle.TEXT,true)
		metric_labels.append(value)
		_label(field,str(fact[1]),12,MenuStyle.MUTED)
	var rule := HSeparator.new()
	right.add_child(rule)
	table_heading = HBoxContainer.new()
	table_heading.add_theme_constant_override("separation",12)
	var heading_margin := MarginContainer.new()
	heading_margin.add_theme_constant_override("margin_right",8)
	right.add_child(heading_margin)
	heading_margin.add_child(table_heading)
	for column: Array in [["POS",36],["TRACK",0],["TIME",104],["PTS",42]]:
		var label: Label = _label(table_heading,str(column[0]),12,MenuStyle.MUTED)
		label.custom_minimum_size.x = column[1]
		if column[1] == 0: label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if column[0] in ["TIME","PTS"]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	copy_scroll = ScrollContainer.new()
	copy_scroll.name = "ShareTrackScroll"
	copy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(copy_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if export_mode: details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",2)
	copy_scroll.add_child(details)
	for result: Dictionary in summary.results: _build_track(result)

func _build_track(result: Dictionary) -> void:
	var track: Dictionary = model.tracks[result.slot]
	var own: Dictionary = result.own
	var row := PanelContainer.new()
	row.name = "ShareTrack_"+str(result.slot)
	row.tooltip_text = str(track.name)
	row.custom_minimum_size.y = 58
	if export_mode: row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := MenuStyle.box(Color("142631") if result.victory else Color("10212c"),0)
	style.set_corner_radius_all(4)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.content_margin_right = 8
	row.add_theme_stylebox_override("panel",style)
	details.add_child(row)
	result_rows.append(row)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",12)
	row.add_child(line)
	var rank: Label = _label(line,"—" if own.get("rank") == null else "%02d" % int(own.rank),25,MenuStyle.ACCENT if result.victory else MenuStyle.MUTED,true)
	rank.name = "TrackPosition"
	rank.custom_minimum_size.x = 36
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var track_copy := HBoxContainer.new()
	track_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_copy.add_theme_constant_override("separation",12)
	line.add_child(track_copy)
	var thumbnail := Finale.RouteThumbnail.new()
	thumbnail.entry = track.get("entry",track.document).duplicate(true)
	thumbnail.entry.theme = track.theme
	thumbnail.custom_minimum_size = Vector2(58,42)
	thumbnail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track_copy.add_child(thumbnail)
	var identity_copy := VBoxContainer.new()
	identity_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity_copy.add_theme_constant_override("separation",0)
	track_copy.add_child(identity_copy)
	var track_name: Label = _label(identity_copy,str(track.name),20,MenuStyle.TEXT,true)
	track_name.name = "TrackName"
	track_name.clip_text = true
	track_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label(identity_copy,TrackTheme.title(str(track.theme)),12,MenuStyle.MUTED)
	var time: Label = _label(line,"—" if own.get("ms") == null else MenuStyle.time_text(float(own.ms)/1000.0),18,MenuStyle.MUTED if own.get("ms") == null else MenuStyle.TEXT)
	time.name = "TrackTime"
	time.custom_minimum_size.x = 104
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var points: Label = _label(line,str(int(own.get("points",0))),25,MenuStyle.ACCENT if result.victory else MenuStyle.TEXT,true)
	points.name = "TrackPoints"
	points.custom_minimum_size.x = 42
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _build_footer() -> void:
	divider = ColorRect.new()
	divider.color = Color("2c414f")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(divider)
	copied = HBoxContainer.new()
	copied.name = "ShareCopied"
	copied.add_theme_constant_override("separation",9)
	surface.add_child(copied)
	var check_icon := TextureRect.new()
	check_icon.texture = MenuIcon.texture("share" if native_sharing else "check")
	check_icon.modulate = MenuStyle.MUTED if native_sharing else MenuStyle.POSITIVE
	check_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check_icon.custom_minimum_size = Vector2(20,20)
	copied.add_child(check_icon)
	status_label = _label(copied,"Ready to share" if native_sharing else "Results copied",17,MenuStyle.MUTED if native_sharing else MenuStyle.POSITIVE)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close_button = MenuStyle.button("",_cancel)
	close_button.name = "ShareClose"
	close_button.icon = MenuIcon.texture("close")
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.tooltip_text = "Close"
	close_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,0))
	surface.add_child(close_button)
	confirm_button = MenuStyle.button("SHARE" if native_sharing else "SAVE IMAGE",_primary_action,true)
	confirm_button.name = "ShareDone"
	confirm_button.add_theme_color_override("font_focus_color",MenuStyle.INK)
	confirm_button.add_theme_color_override("font_pressed_color",MenuStyle.INK)
	surface.add_child(confirm_button)

func _layout() -> void:
	if not is_instance_valid(right): return
	var hero_width: float = clampf(surface.size.x*0.32,260,360)
	var inset: float = hero_width+32
	var width: float = surface.size.x-inset-32
	var compact: bool = surface.size.y < 600 and not export_mode
	(art.material as ShaderMaterial).set_shader_parameter("panel_size",surface.size)
	(art.material as ShaderMaterial).set_shader_parameter("hero_width",hero_width)
	hero.size = Vector2(hero_width,surface.size.y)
	hero_heading.position = Vector2(28,123 if summary.perfect else 108)
	hero_heading.size = Vector2(hero_width-50,160)
	hero_heading.add_theme_font_size_override("font_size",48 if summary.title.begins_with("JOINT") else 58)
	identity.position = Vector2(28,290)
	identity.size = Vector2(hero_width-56,28)
	vehicle.position = Vector2(8,325)
	vehicle.size = Vector2(hero_width-16,maxf(120,surface.size.y-(414 if export_mode else 430)))
	vehicle_label.position = Vector2(28,surface.size.y-(63 if export_mode else 93))
	vehicle_label.size = Vector2(hero_width-56,28)
	var brand: Label = hero.get_node("ShareBrand")
	brand.position = Vector2(28,surface.size.y-(28 if export_mode else 42))
	right.add_theme_constant_override("separation",10 if compact else 16)
	heading.add_theme_font_size_override("font_size",26 if compact else 30)
	for label: Label in metric_labels: label.add_theme_font_size_override("font_size",30 if compact else 40)
	for row: Control in result_rows:
		row.custom_minimum_size.y = 56 if compact else 58
		var style: StyleBoxFlat = row.get_theme_stylebox("panel")
		style.content_margin_top = 4 if compact else 6
		style.content_margin_bottom = 4 if compact else 6
	right.position = Vector2(inset,24 if compact else 28)
	right.size = Vector2(width,surface.size.y-(44 if export_mode else 116 if compact else 124))
	close_button.position = Vector2(surface.size.x-64,12)
	close_button.size = Vector2(52,52)
	divider.position = Vector2(inset,surface.size.y-88)
	divider.size = Vector2(width,1)
	copied.position = Vector2(inset,surface.size.y-63)
	copied.size = Vector2(maxf(80,width-184),32)
	confirm_button.position = Vector2(surface.size.x-200,surface.size.y-73)
	confirm_button.size = Vector2(168,52)

func _primary_action() -> void:
	if sharing: return
	if native_sharing: share_requested.emit()
	else: save_requested.emit()

func _confirm() -> void:
	_primary_action()

func set_sharing(active: bool, message: String = "") -> void:
	sharing = active
	confirm_button.disabled = active
	if not message.is_empty():
		status_label.text = message
		status_label.tooltip_text = message

func image_values() -> Dictionary:
	return {"model":model,"player_name":player_name,"livery":livery,"customisation":customisation,"condition":condition}

extends CanvasLayer
## Race preparation overlay. Uses existing menu art and the actual route only.

var surface: Control
var scenery: TextureRect
var panel: PanelContainer
var title_label: Label
var facts_label: Label
var status_label: Label
var route_view: Control
var route: PackedVector2Array = []
var activity: ProgressBar
var _profile: bool = OS.is_debug_build() and (OS.get_environment("BMT_RACE_LOAD_PROFILE") == "1" or "--profile-race-load" in OS.get_cmdline_user_args())
var _profile_start: int = Time.get_ticks_usec()
var _stage_start: int = _profile_start
var _stage_name: String = "Opening"

func _profile_stage(next: String) -> void:
	if _profile:
		var now: int = Time.get_ticks_usec()
		print("RACE_LOAD_STAGE ",JSON.stringify({"load":get_instance_id(),"stage":_stage_name,"stage_ms":(now-_stage_start)/1000.0,"total_ms":(now-_profile_start)/1000.0,"next":next}))
	_stage_start = Time.get_ticks_usec()
	_stage_name = next

func _exit_tree() -> void:
	_profile_stage("Closed")

func _ready() -> void:
	layer = 80
	surface = Control.new()
	surface.name = "RaceLoadingScreen"
	surface.theme = MenuStyle.theme()
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(surface)
	MenuStyle.fill(surface)
	var background := ColorRect.new()
	background.color = MenuStyle.INK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(background)
	MenuStyle.fill(background)
	scenery = TextureRect.new()
	scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(scenery)
	MenuStyle.fill(scenery)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.045, 0.065, 0.7)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(shade)
	MenuStyle.fill(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuStyle.card(32))
	surface.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var heading := MenuStyle.label("LOADING TRACK", 20)
	heading.add_theme_color_override("font_color", MenuStyle.ACCENT)
	column.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	column.add_child(row)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(details)
	title_label = MenuStyle.label("", 48)
	title_label.name = "LoadingTrackTitle"
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(title_label)
	facts_label = MenuStyle.label("", 17, true)
	facts_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(facts_label)
	route_view = Control.new()
	route_view.name = "LoadingRoute"
	route_view.custom_minimum_size = Vector2(230, 144)
	route_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(route_view)
	route_view.draw.connect(_draw_route)
	route_view.resized.connect(route_view.queue_redraw)
	activity = ProgressBar.new()
	activity.name = "LoadingActivity"
	activity.custom_minimum_size.y = 5
	activity.show_percentage = false
	activity.indeterminate = true
	column.add_child(activity)
	status_label = MenuStyle.label("Preparing race…", 18, true)
	status_label.name = "LoadingStatus"
	column.add_child(status_label)
	surface.resized.connect(_layout)
	_layout()

func configure(title: String, theme_id: String, points: PackedVector2Array, practice: bool = false) -> void:
	title_label.text = title
	scenery.texture = TrackTile.scenery_texture(theme_id)
	facts_label.text = TrackTheme.title(theme_id) + "  ·  " + ("Practice (untimed)" if practice else "5 laps") + "  ·  " + VehicleCatalog.title()
	route = points
	route_view.queue_redraw()

func stage(text: String) -> void:
	_profile_stage(text)
	status_label.text = text

func _layout() -> void:
	var width: float = minf(900.0, maxf(280.0, surface.size.x - 80.0))
	panel.size = Vector2(width, panel.get_combined_minimum_size().y)
	panel.position = (surface.size - panel.size) * 0.5
	route_view.visible = width >= 650.0
	title_label.add_theme_font_size_override("font_size", 48 if width >= 760.0 else 36)

func _draw_route() -> void:
	if route.size() < 2: return
	var bounds := Rect2(route[0], Vector2.ZERO)
	for point: Vector2 in route: bounds = bounds.expand(point)
	var scale_factor: float = minf((route_view.size.x - 24.0) / maxf(1.0, bounds.size.x), (route_view.size.y - 24.0) / maxf(1.0, bounds.size.y))
	var path := PackedVector2Array()
	for point: Vector2 in route:
		var offset: Vector2 = (point - bounds.get_center()) * scale_factor
		path.append(route_view.size * 0.5 + Vector2(offset.x, -offset.y))
	path.append(path[0])
	route_view.draw_polyline(path, MenuStyle.INK, 9.0, true)
	route_view.draw_polyline(path, MenuStyle.TEXT, 4.0, true)
	route_view.draw_circle(path[0], 6.0, MenuStyle.ACCENT, true, -1, true)

func _input(_event: InputEvent) -> void:
	# Keep preparation taps/keys from reaching menus or the race HUD.
	get_viewport().set_input_as_handled()

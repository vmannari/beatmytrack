extends Control
## Supplied raster race gantry and original vector waving cloth; no scored state.

const START_LIGHTS_ATLAS: Texture2D = preload("res://assets/hud/start_lights_atlas_v1.png")
const RACE_COMPLETE_PANEL: Texture2D = preload("res://assets/hud/race_complete_panel_v1.png")
const START_FRAME_SIZE := Vector2(544.0, 120.0)

var stage: int = -1 # Number of illuminated red lights; zero is lights-out.
var finish_progress: float = -1.0
var cue_alpha: float = 1.0
var exit_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset() -> void:
	rating_confirming = false
	if rating_confirmation != null: rating_confirmation.kill()
	if rating_reveal != null: rating_reveal.kill()
	if is_instance_valid(rating_panel):
		remove_child(rating_panel)
		rating_panel.queue_free()
		rating_panel = null
	if exit_tween != null: exit_tween.kill()
	modulate.a = 1.0
	visible = false
	stage = -1
	finish_progress = -1.0

func reveal_results() -> void:
	if is_instance_valid(rating_panel): rating_panel.hide()
	exit_tween = create_tween()
	exit_tween.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	exit_tween.tween_callback(hide)

func show_start(ticks_left: int, race_tick: int) -> void:
	visible = ticks_left > 0 or race_tick < 60
	# Five half-second steps, then a half-second all-red hold. Extinguish together.
	stage = mini(5, 1 + (360 - ticks_left) / 60) if ticks_left > 0 else 0
	cue_alpha = 1.0 if ticks_left > 0 else 1.0 - smoothstep(18.0, 60.0, float(race_tick))
	finish_progress = -1.0
	queue_redraw()

func show_finish(progress: float) -> void:
	visible = true
	finish_progress = progress
	queue_redraw()

func _draw() -> void:
	if finish_progress >= 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.05, 0.07, smoothstep(0.45, 1.0, finish_progress) * 0.85))
	var scale_factor: float = minf(1.0, size.x / 900.0)
	var center := Vector2(size.x * 0.5, size.y * 0.5 - 125.0 * scale_factor)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	if finish_progress >= 0.0:
		_draw_race_complete()
	else:
		_draw_lights()
	draw_set_transform(Vector2.ZERO)

func _draw_lights() -> void:
	# Six precomposited frames keep the supplied artwork to one canvas draw call.
	var frame_index: int = clampi(stage, 0, 5)
	var source := Rect2(Vector2(START_FRAME_SIZE.x * frame_index, 0.0), START_FRAME_SIZE)
	var destination := Rect2(-START_FRAME_SIZE * 0.5, START_FRAME_SIZE)
	draw_texture_rect_region(START_LIGHTS_ATLAS, destination, source, Color(1.0, 1.0, 1.0, cue_alpha))

func _draw_race_complete() -> void:
	# The supplied panel replaces the tessellated flag with one static canvas draw.
	var reveal: float = smoothstep(0.0, 0.12, finish_progress)
	var panel_width: float = minf(820.0, size.x * 0.78)
	var panel_size := Vector2(panel_width, panel_width * 341.0 / 1024.0)
	var destination := Rect2(-panel_size * 0.5 + Vector2(0.0, (1.0 - reveal) * 18.0), panel_size)
	draw_texture_rect(RACE_COMPLETE_PANEL, destination, false, Color(1.0, 1.0, 1.0, reveal))

func _panel(box: Rect2, fill: Color, border: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill, cue_alpha)
	style.border_color = Color(border, cue_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.3 * cue_alpha)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 4)
	draw_style_box(style, box)

func _text(value: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var font: Font = RaceHUDStyle.DISPLAY
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, baseline - Vector2(width * 0.5, -2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.02, 0.03, 0.04, color.a))
	draw_string(font, baseline - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

var rating_panel: PanelContainer
var rating_reveal: Tween
var rating_confirmation: Tween
var rating_confirming: bool = false

func prepare_rating(store: LocalRecords, id: String, proceed: Callable) -> void:
	rating_confirming = false
	if is_instance_valid(rating_panel):
		remove_child(rating_panel)
		rating_panel.queue_free()
	rating_panel = PanelContainer.new()
	rating_panel.name = "FinishRating"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b0e0ef5")
	style.border_color = Color("d8b45c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0.93,0.65,0.18,0.15)
	style.shadow_size = 6
	rating_panel.add_theme_stylebox_override("panel",style)
	add_child(rating_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	rating_panel.add_child(body)
	var title := MenuStyle.label("RATE THIS TRACK",26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("f4e7c6"))
	body.add_child(title)
	var row := TrackRating.new()
	row.records = store
	row.track_id = id
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	row.caption.hide()
	row.save_failed.connect(func() -> void: title.text = "COULDN'T SAVE — TRY AGAIN")
	for star: Button in row.stars:
		star.custom_minimum_size = Vector2(64,56)
		star.add_theme_constant_override("icon_max_width",36)
		star.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		star.add_theme_color_override("icon_normal_color",Color("e6c578"))
		_finish_button_style(star)
	var skip := MenuStyle.button("SKIP",proceed)
	skip.name = "SkipRating"
	skip.custom_minimum_size.y = 44
	skip.add_theme_color_override("font_color",Color("dbc58e"))
	skip.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	_finish_button_style(skip)
	body.add_child(skip)
	row.rated.connect(func() -> void:
		if rating_confirming: return
		rating_confirming = true
		row.locked = true
		if rating_reveal != null: rating_reveal.kill()
		rating_panel.modulate.a = 1.0
		title.text = "YOU RATED THIS TRACK %d / 5" % row.value()
		for star: Button in row.stars:
			star.disabled = true
			star.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
		skip.disabled = true
		skip.modulate.a = 0.0
		rating_confirmation = create_tween()
		rating_confirmation.tween_interval(0.7)
		rating_confirmation.tween_property(self,"modulate:a",0.0,0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		rating_confirmation.tween_callback(func() -> void:
			rating_confirming = false
			proceed.call()))
	rating_panel.hide()
	_layout_rating()
	if not resized.is_connected(_layout_rating): resized.connect(_layout_rating)

func _layout_rating() -> void:
	if not is_instance_valid(rating_panel): return
	var factor: float = minf(1.0,size.x/900.0)
	var banner_height: float = minf(820.0,size.x*0.78)*341.0/1024.0*factor
	var width: float = minf(520.0,size.x-40.0)
	rating_panel.size = Vector2(width,0)
	rating_panel.position = Vector2((size.x-width)*0.5,size.y*0.5-125.0*factor+banner_height*0.5+4.0)

func show_rating() -> void:
	if not is_instance_valid(rating_panel) or rating_panel.visible: return
	rating_panel.show()
	rating_panel.modulate.a = 0.0
	rating_reveal = create_tween()
	rating_reveal.tween_property(rating_panel,"modulate:a",1.0,0.25)

func _finish_button_style(button: Button) -> void:
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("30291b")
	hover.border_color = Color("d8b45c")
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(8)
	for state: String in ["hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,hover)
	for state: String in ["hover","pressed","focus"]:
		button.add_theme_color_override("icon_"+state+"_color",Color("ffe2a0"))

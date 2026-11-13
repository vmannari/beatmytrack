extends HBoxContainer
## Featured daily event; the backend owns selection and the ordinary race boundary.
signal mode_requested(mode: String)
signal race_requested(entry: Dictionary)
signal vehicle_selected(index: int)
signal track_loaded(state: Dictionary)
signal track_invalidated
const Badge = preload("res://ui/biome_badge.gd")
var client: Node
var cloud: Node
var records: LocalRecords
var _week_strip: PanelContainer
var _header_row: HBoxContainer
var _header_identity: VBoxContainer
var page_preview: bool = false
var cached_state: Dictionary = {}
var entry: Dictionary = {}
var _ends_at: int = 0
var _server_now: int = 0
var _sample_msec: int = 0
var _busy: bool = false
var _expired_refresh: bool = false
var _retry_msec: int = 0
var _last_second: int = -1
var _status: Label
var _countdown: Label
var _countdown_panel: PanelContainer
var _card_slot: VBoxContainer
var _race: Button
var _retry: Button
var _stage: Control
var _hero: PanelContainer
var _state: VBoxContainer
var _race_panel: PanelContainer
var _rating: Label
var _rating_row: HBoxContainer
var _race_heading: Label
var _standings_button: Button
var _standings: AcceptDialog

func _ready() -> void:
	name = "TrackOfDayPage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",20)
	var rail := RaceModeRail.new()
	rail.selected = "daily"
	rail.mode_requested.connect(func(mode: String) -> void: mode_requested.emit(mode))
	add_child(rail)
	var scroll := ScrollContainer.new()
	scroll.name = "DailyScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	_build_header(column)
	_stage = Control.new()
	_stage.name = "DailyEvent"
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_stage)
	_build_hero()
	_build_race_panel()
	_week_strip = preload("res://ui/daily_week.gd").new()
	_week_strip.name = "DailyWeek"
	_stage.add_child(_week_strip)
	_stage.resized.connect(_arrange)
	_race_panel.minimum_size_changed.connect(_arrange.call_deferred)
	_arrange.call_deferred()
	if not _restore_cached_track() and not page_preview: refresh()

func _restore_cached_track() -> bool:
	var cached_entry: Dictionary = cached_state.get("entry",{})
	var ends: int = int(cached_state.get("ends_at",0))
	var now: int = int(cached_state.get("server_now",0))
	var sampled: int = int(cached_state.get("sample_msec",0))
	if sampled <= 0 or Time.get_ticks_msec() < sampled or ends <= now + int((Time.get_ticks_msec()-sampled)/1000): return false
	if not cloud._valid_entry(cached_entry) or not cloud._allowed(cached_entry): return false
	entry = cached_entry.duplicate(true)
	_ends_at = ends
	_server_now = now
	_sample_msec = sampled
	_show_track()
	_process(0.0)
	return true

func _build_header(parent: Control) -> void:
	var header := HBoxContainer.new()
	_header_row = header
	header.add_theme_constant_override("separation",24)
	parent.add_child(header)
	var identity := VBoxContainer.new()
	_header_identity = identity
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation",4)
	header.add_child(identity)
	var title: Label = MenuStyle.label("Track of the day",38)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(title)
	var subtitle: Label = MenuStyle.label("One track. Everyone. A new pick every day.",18,true)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(subtitle)
	_countdown_panel = PanelContainer.new()
	_countdown_panel.name = "DailyCountdown"
	_countdown_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_countdown_panel.add_theme_stylebox_override("panel",_panel_style(16))
	header.add_child(_countdown_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	_countdown_panel.add_child(row)
	row.add_child(_icon("clock",24,MenuStyle.ACCENT))
	_countdown = MenuStyle.label("",20)
	GameText.user_text(_countdown)
	row.add_child(_countdown)
	_countdown_panel.hide()

func _build_hero() -> void:
	_hero = PanelContainer.new()
	_hero.name = "DailyFeature"
	_hero.clip_contents = true
	_hero.add_theme_stylebox_override("panel",_panel_style(0))
	_stage.add_child(_hero)
	_card_slot = VBoxContainer.new()
	_card_slot.name = "DailyTrack"
	_hero.add_child(_card_slot)
	_state = VBoxContainer.new()
	_state.name = "DailyState"
	_state.alignment = BoxContainer.ALIGNMENT_CENTER
	_state.add_theme_constant_override("separation",24)
	var padding := MarginContainer.new()
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left","right"]: padding.add_theme_constant_override("margin_"+side,48)
	_hero.add_child(padding)
	padding.add_child(_state)
	var emblem := TextureRect.new()
	emblem.texture = preload("res://ui/race_mode_icons.gd").texture("sun")
	emblem.custom_minimum_size = Vector2(88,88)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.modulate = Color("b2a46c")
	_state.add_child(emblem)
	_status = MenuStyle.label("Loading today's track…",28,true)
	_status.name = "DailyStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state.add_child(_status)

func _build_race_panel() -> void:
	var card := preload("res://ui/daily_result_card.gd").new()
	card.client = client
	card.records = records
	card.vehicle = VehicleCatalog.selected
	card.preview = page_preview
	_stage.add_child(card)
	_race_panel = card
	_race = card.race_button
	_standings_button = card.standings_button
	_race_heading = card._heading
	card.race_requested.connect(_request_race)
	card.standings_requested.connect(_open_standings)
	card.vehicle_selected.connect(func(index: int) -> void:
		vehicle_selected.emit(index)
		_update_week())
	# Retain the existing error/retry boundary while the result panel is loading.
	_retry = MenuStyle.button("Retry",refresh,true)
	_retry.name = "DailyRetry"
	card.get_child(0).add_child(_retry)
	_retry.hide()
	_rating_row = HBoxContainer.new()
	_rating = MenuStyle.label("",18)
	_rating_row.add_child(_rating)
	card.get_child(0).add_child(_rating_row)
	_rating_row.hide()

func _update_week() -> void:
	if not is_instance_valid(_week_strip): return
	_week_strip.entries = preload("res://persistence/daily_progress.gd").load_entries(records)
	_week_strip.day = _server_now/86400
	_week_strip.vehicle = VehicleCatalog.selected
	_week_strip.refresh()

func _arrange() -> void:
	if not is_instance_valid(_race_panel) or not is_instance_valid(_week_strip): return
	var width: float = _stage.size.x
	var compact_header: bool = width < 620
	var timer_parent: Node = _header_identity if compact_header else _header_row
	if _countdown_panel.get_parent() != timer_parent:
		_countdown_panel.reparent(timer_parent)
	_countdown_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if compact_header else Control.SIZE_FILL
	_countdown_panel.add_theme_stylebox_override("panel",_panel_style(8 if compact_header else 16))
	_countdown.add_theme_font_size_override("font_size",16 if compact_header else 20)
	var height: float = maxf(440,_race_panel.get_combined_minimum_size().y)
	var stacked: bool = width < 740
	var side_width: float = minf(340,width*0.34)
	var left_width: float = width if stacked else maxf(200,width-side_width-18)
	var hero_height: float = clampf(left_width*0.9,320,440) if stacked else height-104
	_stage.custom_minimum_size.y = hero_height+104+height+18 if stacked else height
	_hero.position = Vector2.ZERO
	_hero.size = Vector2(left_width,hero_height)
	_week_strip.position = Vector2(0,hero_height+12)
	_week_strip.size = Vector2(left_width,92)
	_race_panel.position = Vector2(0,hero_height+122) if stacked else Vector2(width-side_width,0)
	_race_panel.size = Vector2(width if stacked else side_width,height)

func _panel_style(padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.box(Color("0b1a26f5"),padding)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color("3b5362")
	return style

func _icon(kind: String, extent: int, color: Color) -> TextureRect:
	var glyph := TextureRect.new()
	glyph.texture = MenuIcon.texture(kind,true)
	glyph.custom_minimum_size = Vector2(extent,extent)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.modulate = color
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph

func _show_track() -> void:
	var card := preload("res://ui/track_of_day_art.gd").new()
	card.name = "DailyTrackCard"
	card.entry = entry
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.pressed.connect(_request_race)
	_card_slot.add_child(card)
	card.custom_minimum_size = Vector2(160,220)
	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+side,28)
	card.add_child(inset)
	MenuStyle.fill(inset)
	var overlay := VBoxContainer.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_constant_override("separation",6)
	inset.add_child(overlay)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(top)
	top.add_child(Badge.view(str(entry.theme),18))
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var day: Label = MenuStyle.label(Time.get_date_string_from_unix_time(_server_now),16)
	GameText.user_text(day)
	top.add_child(day)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay.add_child(space)
	var caption := VBoxContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_constant_override("separation",6)
	overlay.add_child(caption)
	var title: Label = MenuStyle.user_label(str(entry.name),46)
	title.name = "DailyTrackName"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.tooltip_text = str(entry.name)
	caption.add_child(title)
	var creator: Label = MenuStyle.label("",20,true)
	GameText.bind(creator,"by {creator}",{"creator":str(entry.creator)})
	creator.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	creator.tooltip_text = str(entry.creator)
	caption.add_child(creator)
	caption.resized.connect(func() -> void: card.reserve_caption(caption.size.y))
	_update_rating()
	_rating_row.hide()
	_card_slot.show()
	_week_strip.show()
	_state.hide()
	_countdown_panel.show()
	_status.hide()
	_race.disabled = false
	_standings_button.disabled = false
	_race_panel.client = client
	_race_panel.records = records
	_race_panel.configure(_server_now/86400,str(entry.version_id),_ends_at)
	_update_week()
	_arrange.call_deferred()

func _update_rating() -> void:
	_rating.text = "%.1f (%d)" % [float(entry.rating_average),int(entry.rating_count)] if entry.get("rating_average") != null else tr("Unrated (0)")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_last_second = -1
		if is_instance_valid(_rating) and not entry.is_empty(): _update_rating()

func _exit_tree() -> void:
	if is_instance_valid(client): client.cancel_public_reads(get_instance_id())

func activate() -> void:
	page_preview = false
	var cars: OptionButton = find_child("DailyCar",true,false)
	if cars != null: cars.select(VehicleCatalog.IDS.find(VehicleCatalog.selected))
	_race_panel.preview = false
	_race_panel.vehicle = VehicleCatalog.selected
	if not entry.is_empty():
		_race_panel.refresh()
		_update_week()
	if entry.is_empty() and not _busy: refresh()

func refresh() -> void:
	if _busy or not is_inside_tree(): return
	track_invalidated.emit()
	_busy = true
	_retry_msec = 0
	_ends_at = 0
	_last_second = -1
	_race.disabled = true
	_race_panel.invalidate()
	_week_strip.hide()
	_standings_button.disabled = true
	_retry.hide()
	_card_slot.hide()
	_rating_row.hide()
	_countdown_panel.hide()
	_state.show()
	_status.show()
	_status.text = "Loading today's track…"
	var response: Dictionary = await client.request_api("/track-of-the-day",HTTPClient.METHOD_GET,{},"",true) if client.signed_in() else await client.request_public("/track-of-the-day",get_instance_id())
	if not is_inside_tree(): return
	_busy = false
	entry = {}
	for child: Node in _card_slot.get_children():
		_card_slot.remove_child(child)
		child.queue_free()
	if not response.get("ok",false):
		_status.text = "Today's track is not available yet. Try again shortly."
		_retry.show()
		if int(response.get("status",0)) == 503: _retry_msec = Time.get_ticks_msec()+30000
		return
	var data: Dictionary = response.get("data",{})
	_ends_at = int(data.get("ends_at",0))
	_server_now = int(data.get("server_now",0))
	_sample_msec = Time.get_ticks_msec()
	_expired_refresh = false
	if data.get("track") is not Dictionary or _ends_at <= _server_now:
		_status.text = "No track is available today. Check back tomorrow."
		_retry.show()
		return
	entry = cloud.entry_from_metadata(data.track)
	if not cloud._valid_entry(entry) or not cloud._allowed(entry):
		entry = {}
		_status.text = "No track is available today. Check back tomorrow."
		return
	_show_track()
	_process(0.0)
	track_loaded.emit({"entry":entry.duplicate(true),"ends_at":_ends_at,"server_now":_server_now,"sample_msec":_sample_msec})

func _process(_delta: float) -> void:
	if not page_preview and not _busy and _retry_msec > 0 and Time.get_ticks_msec() >= _retry_msec: refresh()
	if _ends_at <= 0: return
	var remaining: int = maxi(0,_ends_at-_server_now-int((Time.get_ticks_msec()-_sample_msec)/1000))
	if remaining != _last_second:
		_last_second = remaining
		_countdown.text = tr("Next track in %s") % ("%02d:%02d:%02d" % [remaining/3600,(remaining/60)%60,remaining%60])
	if remaining == 0:
		_race.disabled = true
		if not _busy and not _expired_refresh and not page_preview:
			_expired_refresh = true
			refresh()

func _request_race() -> void:
	if _busy or entry.is_empty(): return
	# Recheck rollover, blocks and moderation immediately before ordinary racing.
	var version: String = str(entry.version_id)
	await refresh()
	if not entry.is_empty() and str(entry.version_id) == version:
		var requested: Dictionary = entry.duplicate(true)
		requested["daily_day"] = _server_now/86400
		race_requested.emit(requested)

func _open_standings() -> void:
	if _busy or entry.is_empty() or _ends_at <= _server_now: return
	if is_instance_valid(_standings):
		_standings.popup_centered()
		return
	var dialog := preload("res://ui/daily_standings.gd").new()
	dialog.flying_laps = true
	dialog.client = client
	dialog.cloud = cloud
	dialog.version = str(entry.version_id)
	dialog.vehicle = VehicleCatalog.selected
	dialog.track_name = str(entry.name)
	dialog.day = _server_now/86400
	dialog.ends_at = _ends_at
	dialog.server_now = _server_now+int((Time.get_ticks_msec()-_sample_msec)/1000)
	dialog.vehicle_selected.connect(func(index: int) -> void:
		vehicle_selected.emit(index)
		_race_panel.vehicle = VehicleCatalog.IDS[index]
		_race_panel.refresh()
		_update_week())
	dialog.day_changed.connect(refresh)
	_standings = dialog
	add_child(dialog)
	dialog.popup_centered()

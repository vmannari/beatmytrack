extends VBoxContainer
## A visible, direct-play track list with a persistent now-playing transport.
const Library = preload("res://soundtrack/record_library.gd")
const Hardware = preload("res://ui/garage_audio_style.gd")
signal changed
signal save_failed
signal browsed(index: int)
signal flipping(position: float)
var records: LocalRecords
var browse_index: int = 0
var display_position: float = 0.0:
	set(value):
		display_position = value
		flipping.emit(value)
var flip_motion: Tween
var status: Label
var now_title: Label
var now_cover: TextureRect
var transport: Button
var skip_previous: Button
var skip_next: Button
var volume: HSlider
var volume_value: Label
var save_timer: Timer
var track_scroll: ScrollContainer
var track_rows: Array[Button] = []
var track_states: Array[Label] = []
var playlist_checks: Array[CheckBox] = []
var playlist_heading: Label
var playlist_count: Label
var track_panels: Array[PanelContainer] = []

func _ready() -> void:
	display_position = float(browse_index)
	name = "GarageRecordsWorkbench"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	var heading := HBoxContainer.new()
	add_child(heading)
	var title: Label = MenuStyle.label(tr("YOUR RECORDS"),24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var count := MenuStyle.label("%02d %s" % [Library.CATALOG.size(),tr("TRACKS")],12,true)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(count)
	var playing := HBoxContainer.new()
	playing.add_theme_constant_override("separation",10)
	add_child(playing)
	now_cover = TextureRect.new()
	now_cover.name = "GarageNowPlayingCover"
	now_cover.custom_minimum_size = Vector2(60,60)
	now_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	now_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	playing.add_child(now_cover)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation",1)
	playing.add_child(details)
	status = MenuStyle.label("",12,true)
	status.name = "GarageRecordStatus"
	details.add_child(status)
	now_title = MenuStyle.label("",20)
	now_title.name = "GarageNowPlayingTitle"
	now_title.add_theme_font_override("font",MenuStyle.DISPLAY)
	now_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(now_title)
	var playback := HBoxContainer.new()
	playback.alignment = BoxContainer.ALIGNMENT_CENTER
	playback.add_theme_constant_override("separation",10)
	add_child(playback)
	skip_previous = _transport_button("GaragePreviousRecording","skip_previous",func() -> void: _skip_record(-1))
	playback.add_child(skip_previous)
	transport = _transport_button("GarageRecordTransport","pause",_toggle_play)
	playback.add_child(transport)
	skip_next = _transport_button("GarageNextRecording","skip_next",func() -> void: _skip_record(1))
	playback.add_child(skip_next)
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation",6)
	add_child(volume_row)
	var speaker := TextureRect.new()
	speaker.texture = Hardware.texture("speaker")
	speaker.custom_minimum_size = Vector2(24,24)
	speaker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	speaker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	volume_row.add_child(speaker)
	volume = preload("res://ui/garage_record_volume.gd").new()
	volume.name = "GarageRecordVolume"
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.value = GameSoundtrack.preference(records.settings,"music_volume")*100
	volume_row.add_child(volume)
	volume_value = MenuStyle.label("",14,true)
	volume_value.custom_minimum_size.x = 38
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	volume_row.add_child(volume_value)
	volume.value_changed.connect(_preview_volume)
	var list_heading := HBoxContainer.new()
	add_child(list_heading)
	playlist_heading = MenuStyle.label(tr("PLAYLIST"),13,true)
	playlist_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_heading.add_child(playlist_heading)
	playlist_count = MenuStyle.label("",12,true)
	playlist_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	list_heading.add_child(playlist_count)
	track_scroll = preload("res://ui/vertical_swipe_scroll.gd").new()
	track_scroll.name = "GarageTrackList"
	track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	track_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_scroll.custom_minimum_size.y = 104
	track_scroll.follow_focus = true
	add_child(track_scroll)
	var tracks := VBoxContainer.new()
	tracks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks.add_theme_constant_override("separation",3)
	track_scroll.add_child(tracks)
	for index: int in range(Library.CATALOG.size()):
		var item: Dictionary = Library.CATALOG[index]
		var panel := PanelContainer.new()
		panel.name = "GarageRecordRow_" + item.id
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tracks.add_child(panel)
		track_panels.append(panel)
		var track := HBoxContainer.new()
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.add_theme_constant_override("separation",0)
		panel.add_child(track)
		var row := Button.new()
		row.name = "GarageTrack_" + item.id
		row.custom_minimum_size.y = 52
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.pressed.connect(_select_record.bind(index))
		track.add_child(row)
		var included: CheckBox = preload("res://ui/garage_playlist_toggle.gd").new()
		included.name = "GaragePlaylist_" + item.id
		included.custom_minimum_size = Vector2(52,52)
		included.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		included.toggled.connect(_set_in_playlist.bind(item.id))
		track.add_child(included)
		playlist_checks.append(included)
		var content := HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 6
		content.offset_right = -8
		content.offset_top = 4
		content.offset_bottom = -4
		content.add_theme_constant_override("separation",8)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(content)
		var art := TextureRect.new()
		art.texture = Library.cover(item.id)
		art.custom_minimum_size = Vector2(44,44)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(art)
		var name_label := MenuStyle.label(item.title,16)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(name_label)
		var state := MenuStyle.label("",11,true)
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(state)
		track_rows.append(row)
		track_states.append(state)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.25
	add_child(save_timer)
	save_timer.timeout.connect(_save_volume)
	GameSoundtrack.instance().record_advanced.connect(_record_advanced)
	visibility_changed.connect(_visibility_changed)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()
	_refresh()

func _transport_button(node_name: String, icon_name: String, action: Callable) -> Button:
	var button: Button = MenuStyle.button("",action)
	button.name = node_name
	button.icon = Hardware.texture(icon_name)
	Hardware.button(button,node_name == "GarageRecordTransport",true)
	button.custom_minimum_size = Vector2(48,48)
	return button

func _fit_layout() -> void:
	var compact: bool = get_viewport_rect().size.y < 650
	add_theme_constant_override("separation",4 if compact else 6)
	now_cover.custom_minimum_size = Vector2(48,48) if compact else Vector2(60,60)
	track_scroll.custom_minimum_size.y = 76 if compact else 104

func _record_advanced(id: String) -> void:
	for index: int in range(Library.CATALOG.size()):
		if Library.CATALOG[index].id == id:
			_browse_to(index)
			break
	_refresh()

func _refresh() -> void:
	var current: Dictionary = Library.selected(records.settings)
	var playlist: Array[Dictionary] = Library.playlist(records.settings)
	var included_ids: Array[String] = []
	for item: Dictionary in playlist: included_ids.append(item.id)
	playlist_heading.text = tr("PLAYLIST")
	playlist_count.text = "%02d / %02d" % [included_ids.size(),Library.CATALOG.size()]
	var enabled: bool = records.settings.get("music_enabled",true)
	now_cover.texture = Library.cover(current.id)
	now_title.text = current.title
	status.text = tr("NOW PLAYING" if enabled else "PAUSED")
	transport.icon = Hardware.texture("pause" if enabled else "play")
	transport.tooltip_text = GameText.message("Pause {title}" if enabled else "Play {title}",{"title":current.title})
	transport.accessibility_name = transport.tooltip_text
	for button: Button in [skip_previous,skip_next]:
		button.tooltip_text = tr("Previous recording") if button == skip_previous else tr("Next recording")
		button.accessibility_name = button.tooltip_text
	for index: int in range(track_rows.size()):
		var item: Dictionary = Library.CATALOG[index]
		var selected: bool = item.id == current.id
		var included: CheckBox = playlist_checks[index]
		included.set_pressed_no_signal(item.id in included_ids)
		included.disabled = included.button_pressed and included_ids.size() == 1
		included.accessibility_name = GameText.message("Include {title} in playlist",{"title":item.title})
		included.tooltip_text = tr("Keep at least one track in the playlist.") if included.disabled else included.accessibility_name
		included.queue_redraw()
		var row: Button = track_rows[index]
		row.accessibility_name = GameText.message("Playing · {title}" if selected and enabled else "Play {title}",{"title":item.title})
		row.tooltip_text = row.accessibility_name
		track_states[index].text = ("●" if enabled else "Ⅱ") if selected else "▶"
		track_states[index].add_theme_color_override("font_color",MenuStyle.ACCENT if selected else MenuStyle.MUTED)
		var surface := MenuStyle.box(Color("1b2e35") if selected else Color("101f28"),0)
		surface.set_corner_radius_all(5)
		surface.border_color = Color("c3a568") if selected else Color("263740")
		surface.border_width_left = 2 if selected else 0
		surface.border_width_bottom = 0 if selected else 1
		track_panels[index].add_theme_stylebox_override("panel",surface)
		for state: String in ["normal","hover","pressed","focus"]:
			var fill := Color(0.65,0.77,0.80,0.06) if state == "hover" else Color(0.65,0.77,0.80,0.10) if state == "pressed" else Color.TRANSPARENT
			var box := MenuStyle.box(fill,0)
			box.set_corner_radius_all(4)
			if state == "focus":
				box.border_color = Color("9b895e")
				box.set_border_width_all(1)
				box.set_expand_margin_all(-2)
			row.add_theme_stylebox_override(state,box)
	_update_volume_caption()
	changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(status): _refresh.call_deferred()

func _select_record(index: int) -> void:
	var item: Dictionary = Library.CATALOG[index]
	if not Library.playable(item.id): return
	if Library.selected(records.settings).id != item.id or not records.settings.get("music_enabled",true):
		records.settings.music_record = item.id
		records.settings.music_enabled = true
		if not _commit(): return
	_browse_to(index)

func _browse_to(index: int) -> void:
	browse_index = index
	browsed.emit(index)
	if flip_motion != null: flip_motion.kill()
	# Retarget from the visible pose, including during rapid track changes.
	var duration: float = clampf(absf(float(index)-display_position)*0.14,0.40,1.10)
	flip_motion = create_tween()
	flip_motion.tween_property(self,"display_position",float(index),duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flip_motion.tween_callback(func() -> void: flip_motion = null)

func _skip_record(direction: int) -> void:
	var next: Dictionary = Library.next_record(records.settings,Library.selected(records.settings).id,direction)
	for index: int in range(Library.CATALOG.size()):
		if Library.CATALOG[index].id == next.id:
			_select_record(index)
			return

func _set_in_playlist(included: bool, id: String) -> void:
	var ids: Array[String] = []
	for item: Dictionary in Library.playlist(records.settings):
		if item.id != id or included: ids.append(item.id)
	if included and id not in ids: ids.append(id)
	if ids.is_empty():
		_refresh()
		return
	records.settings.music_playlist = ids
	_commit()

func _commit() -> bool:
	if records.save_records() != OK:
		GameSoundtrack.instance().apply_settings(records.settings)
		_refresh()
		status.text = "Could not save. Please try again."
		save_failed.emit()
		return false
	GameSoundtrack.instance().apply_settings(records.settings)
	_refresh()
	return true

func _toggle_play() -> void:
	records.settings.music_enabled = not records.settings.get("music_enabled",true)
	_commit()

func _preview_volume(value: float) -> void:
	records.settings.music_volume = value/100.0
	GameSoundtrack.instance().apply_settings(records.settings)
	_update_volume_caption()
	save_timer.start()

func _update_volume_caption() -> void:
	volume_value.text = "%d%%" % roundi(GameSoundtrack.preference(records.settings,"music_volume")*100)
	volume.tooltip_text = "Music volume · "+volume_value.text
	volume.accessibility_name = "Music volume"

func _save_volume() -> void: _commit()

func finish() -> void:
	if flip_motion != null:
		flip_motion.kill()
		flip_motion = null
		display_position = float(browse_index)
	if not save_timer.is_stopped():
		save_timer.stop()
		_save_volume()

func _visibility_changed() -> void:
	if not is_visible_in_tree(): finish()

extends VBoxContainer
const Library = preload("res://soundtrack/record_library.gd")
const Hardware = preload("res://ui/garage_audio_style.gd")
signal changed
signal save_failed
signal browsed(index: int)
signal flipping(position: float)
var records: LocalRecords
var browse_index: int = 0
var crate: Control
var album_counter: Label
var status: Label
var play_button: Button
var transport: Button
var previous_button: Button
var next_button: Button
var skip_previous: Button
var skip_next: Button
var volume: HSlider
var volume_value: Label
var save_timer: Timer

func _ready() -> void:
	name = "GarageRecordsWorkbench"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	var heading := HBoxContainer.new()
	add_child(heading)
	var title: Label = MenuStyle.label("LP BOX",24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	album_counter = MenuStyle.label("",13,true)
	album_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	previous_button = MenuStyle.button("",func() -> void: crate.flip_by(-1))
	previous_button.name = "GaragePreviousLP"
	previous_button.icon = Hardware.texture("previous")
	previous_button.tooltip_text = "Browse previous sleeve"
	previous_button.accessibility_name = "Browse previous sleeve"
	Hardware.button(previous_button,false,true)
	heading.add_child(previous_button)
	heading.add_child(album_counter)
	next_button = MenuStyle.button("",func() -> void: crate.flip_by(1))
	next_button.name = "GarageNextLP"
	next_button.icon = Hardware.texture("next")
	next_button.tooltip_text = "Browse next sleeve"
	next_button.accessibility_name = "Browse next sleeve"
	Hardware.button(next_button,false,true)
	heading.add_child(next_button)
	crate = preload("res://ui/garage_lp_box.gd").new()
	crate.browse_index = clampi(browse_index,0,Library.CATALOG.size()-1)
	crate.browsed.connect(_browsed)
	crate.activated.connect(func(_id: String) -> void: _play_browsed())
	crate.flipping.connect(func(position: float) -> void: flipping.emit(position))
	add_child(crate)
	status = MenuStyle.label("",14,true)
	status.name = "GarageRecordStatus"
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(status)
	# Explicitly playing a browsed release is separate from the stable transport.
	# This action appears when another authored playable release is selected.
	play_button = MenuStyle.button("",_play_browsed)
	play_button.name = "GaragePlayLP"
	Hardware.button(play_button)
	add_child(play_button)
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
	var playback := HBoxContainer.new()
	playback.add_theme_constant_override("separation",16)
	playback.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(playback)
	skip_previous = MenuStyle.button("",func() -> void: _skip_record(-1))
	skip_previous.name = "GaragePreviousRecording"
	skip_previous.icon = Hardware.texture("skip_previous")
	Hardware.button(skip_previous,false,true)
	playback.add_child(skip_previous)
	transport = MenuStyle.button("",_toggle_play)
	transport.name = "GarageRecordTransport"
	Hardware.button(transport,true)
	playback.add_child(transport)
	skip_next = MenuStyle.button("",func() -> void: _skip_record(1))
	skip_next.name = "GarageNextRecording"
	skip_next.icon = Hardware.texture("skip_next")
	Hardware.button(skip_next,false,true)
	playback.add_child(skip_next)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.25
	add_child(save_timer)
	save_timer.timeout.connect(_save_volume)
	visibility_changed.connect(_visibility_changed)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()
	_refresh()

func _fit_layout() -> void:
	var compact: bool = get_viewport_rect().size.y < 650
	add_theme_constant_override("separation",6 if compact else 8)
	crate.custom_minimum_size.y = 116 if compact else 190
	transport.custom_minimum_size = Vector2(52,52) if compact else Vector2(60,60)

func _browsed(index: int) -> void:
	browse_index = index
	if status != null: _refresh()
	browsed.emit(index)

func _refresh() -> void:
	var item: Dictionary = Library.CATALOG[browse_index]
	var current: Dictionary = Library.selected(records.settings)
	var enabled: bool = records.settings.get("music_enabled",true)
	crate.accessibility_name = "LP collection · "+item.title
	crate.tooltip_text = item.title+" · "+("Available" if Library.playable(item.id) else "Music coming later")
	album_counter.text = "%02d / %02d" % [browse_index+1,Library.CATALOG.size()]
	previous_button.disabled = browse_index==0
	next_button.disabled = browse_index==Library.CATALOG.size()-1
	var available: bool = Library.playable(item.id)
	play_button.disabled = not available
	play_button.text = "Music coming later" if not available else "Play "+item.title
	play_button.visible = available and current.id!=item.id
	play_button.icon = Hardware.texture("play")
	play_button.tooltip_text = "Play "+item.title
	play_button.accessibility_name = play_button.tooltip_text
	transport.icon = Hardware.texture("pause" if enabled else "play")
	transport.tooltip_text = ("Pause " if enabled else "Play ")+current.title
	transport.accessibility_name = transport.tooltip_text
	status.text = ("Playing · " if enabled else "Paused · ")+current.title
	status.tooltip_text = status.text
	var has_other_record: bool = Library.entries().any(func(release: Dictionary) -> bool: return release.id!=current.id and Library.playable(release.id))
	for button: Button in [skip_previous,skip_next]:
		button.disabled = not has_other_record
		button.tooltip_text = ("Previous recording" if button==skip_previous else "Next recording") if has_other_record else "No other recordings available yet"
		button.accessibility_name = button.tooltip_text
	_update_volume_caption()
	changed.emit()

func _play_browsed() -> void:
	var item: Dictionary = Library.CATALOG[browse_index]
	if not Library.playable(item.id): return
	var current: Dictionary = Library.selected(records.settings)
	if current.id==item.id and records.settings.get("music_enabled",true):
		_toggle_play()
		return
	records.settings.music_record = item.id
	records.settings.music_enabled = true
	_commit()

func _skip_record(direction: int) -> void:
	var current: Dictionary = Library.selected(records.settings)
	var collection: Array[Dictionary] = Library.entries()
	var current_index: int = 0
	for index: int in range(collection.size()):
		if collection[index].id==current.id: current_index = index
	for offset: int in range(1,collection.size()):
		var index: int = posmod(current_index+direction*offset,collection.size())
		if not Library.playable(collection[index].id): continue
		records.settings.music_record = collection[index].id
		records.settings.music_enabled = true
		crate.flip_to(index)
		_commit()
		return

func _commit() -> bool:
	if records.save_records() != OK:
		GameSoundtrack.instance().apply_settings(records.settings)
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
	crate.finish()
	if not save_timer.is_stopped():
		save_timer.stop()
		_save_volume()

func _visibility_changed() -> void:
	if not is_visible_in_tree(): finish()

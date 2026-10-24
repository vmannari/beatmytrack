extends VBoxContainer
const Library = preload("res://soundtrack/record_library.gd")
signal changed
signal save_failed
signal browsed(index: int)
signal flipping(position: float)
var records: LocalRecords
var browse_index: int = 0
var crate: Control
var album_title: Label
var album_counter: Label
var status: Label
var play_button: Button
var transport: Button
var previous_button: Button
var next_button: Button
var volume: HSlider
var save_timer: Timer

func _ready() -> void:
	name = "GarageRecordsWorkbench"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	add_child(MenuStyle.label("LP BOX",24))
	add_child(MenuStyle.label("Flip through the sleeves.",15,true))
	crate = preload("res://ui/garage_lp_box.gd").new()
	crate.browse_index = clampi(browse_index,0,Library.CATALOG.size()-1)
	crate.browsed.connect(_browsed)
	crate.activated.connect(func(_id: String) -> void: _play_browsed())
	crate.flipping.connect(func(position: float) -> void: flipping.emit(position))
	add_child(crate)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation",8)
	add_child(navigation)
	previous_button = MenuStyle.button("‹",func() -> void: crate.flip_by(-1))
	previous_button.name = "GaragePreviousLP"
	previous_button.custom_minimum_size = Vector2(52,52)
	previous_button.tooltip_text = "Previous LP"
	navigation.add_child(previous_button)
	var caption := VBoxContainer.new()
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	navigation.add_child(caption)
	album_title = MenuStyle.label("",20)
	album_title.name = "GarageLPTitle"
	album_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	album_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_child(album_title)
	album_counter = MenuStyle.label("",14,true)
	album_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_child(album_counter)
	next_button = MenuStyle.button("›",func() -> void: crate.flip_by(1))
	next_button.name = "GarageNextLP"
	next_button.custom_minimum_size = Vector2(52,52)
	next_button.tooltip_text = "Next LP"
	navigation.add_child(next_button)
	status = MenuStyle.label("",14,true)
	status.name = "GarageRecordStatus"
	add_child(status)
	volume = HSlider.new()
	volume.name = "GarageRecordVolume"
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.custom_minimum_size.y = 30
	volume.value = GameSoundtrack.preference(records.settings,"music_volume")*100
	add_child(volume)
	volume.value_changed.connect(_preview_volume)
	var playback := HBoxContainer.new()
	playback.add_theme_constant_override("separation",8)
	add_child(playback)
	play_button = MenuStyle.button("",_play_browsed,true)
	play_button.name = "GaragePlayLP"
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playback.add_child(play_button)
	transport = MenuStyle.button("",_toggle_play)
	transport.name = "GarageRecordTransport"
	transport.custom_minimum_size = Vector2(52,52)
	playback.add_child(transport)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.25
	add_child(save_timer)
	save_timer.timeout.connect(_save_volume)
	visibility_changed.connect(_visibility_changed)
	_refresh()

func _browsed(index: int) -> void:
	browse_index = index
	if album_title != null: _refresh()
	browsed.emit(index)

func _refresh() -> void:
	var item: Dictionary = Library.CATALOG[browse_index]
	var current: Dictionary = Library.selected(records.settings)
	var enabled: bool = records.settings.get("music_enabled",true)
	album_title.text = item.title
	album_counter.text = "%02d / %02d" % [browse_index+1,Library.CATALOG.size()]
	previous_button.disabled = browse_index==0
	next_button.disabled = browse_index==Library.CATALOG.size()-1
	var available: bool = Library.playable(item.id)
	play_button.disabled = not available
	play_button.text = "Music coming later" if not available else "Stop music" if enabled and current.id==item.id else "Play LP"
	transport.visible = not available
	transport.text = "■" if enabled else "▶"
	transport.tooltip_text = ("Stop " if enabled else "Play ")+current.title
	status.text = ("Playing · " if enabled else "Stopped · ")+current.title+" · %d%%" % roundi(GameSoundtrack.preference(records.settings,"music_volume")*100)
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
	status.text = ("Playing · " if records.settings.get("music_enabled",true) else "Stopped · ")+Library.selected(records.settings).title+" · %d%%" % roundi(value)
	save_timer.start()

func _save_volume() -> void: _commit()

func finish() -> void:
	crate.finish()
	if not save_timer.is_stopped():
		save_timer.stop()
		_save_volume()

func _visibility_changed() -> void:
	if not is_visible_in_tree(): finish()

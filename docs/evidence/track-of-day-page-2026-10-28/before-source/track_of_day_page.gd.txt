extends HBoxContainer
## A single backend-selected revision, with no client-side random fallback.
signal mode_requested(mode: String)
signal race_requested(entry: Dictionary)
signal vehicle_selected(index: int)
var client: Node
var cloud: Node
var page_preview: bool = false
var entry: Dictionary = {}
var _ends_at: int = 0
var _server_now: int = 0
var _sample_msec: int = 0
var _busy: bool = false
var _expired_refresh: bool = false
var _retry_msec: int = 0
var _status: Label
var _countdown: Label
var _card_slot: VBoxContainer
var _race: Button
var _retry: Button

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
	var title: Label = MenuStyle.label("Track of the day",32)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var subtitle: Label = MenuStyle.label("One track. Everyone. A new pick every day.",20,true)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	_countdown = MenuStyle.label("",20,true)
	column.add_child(_countdown)
	_status = MenuStyle.label("Loading today's track…",22,true)
	_status.name = "DailyStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_card_slot = VBoxContainer.new()
	_card_slot.name = "DailyTrack"
	column.add_child(_card_slot)
	var cars := OptionButton.new()
	cars.name = "DailyCar"
	cars.custom_minimum_size.y = 48
	cars.tooltip_text = "Choose car"
	for title_text: String in VehicleCatalog.NAMES: cars.add_item(title_text)
	cars.select(VehicleCatalog.IDS.find(VehicleCatalog.selected))
	cars.item_selected.connect(func(index: int) -> void: vehicle_selected.emit(index))
	column.add_child(cars)
	_race = MenuStyle.button("Race",_request_race,true)
	_race.name = "DailyRace"
	_race.custom_minimum_size.y = 56
	_race.disabled = true
	column.add_child(_race)
	_retry = MenuStyle.button("Retry",refresh)
	_retry.name = "DailyRetry"
	column.add_child(_retry)
	_retry.hide()
	if not page_preview: refresh()

func _exit_tree() -> void:
	if is_instance_valid(client): client.cancel_public_reads(get_instance_id())

func activate() -> void:
	page_preview = false
	var cars: OptionButton = find_child("DailyCar",true,false)
	if cars != null: cars.select(VehicleCatalog.IDS.find(VehicleCatalog.selected))
	if entry.is_empty() and not _busy: refresh()

func refresh() -> void:
	if _busy or not is_inside_tree(): return
	_busy = true
	_retry_msec = 0
	_race.disabled = true
	_retry.hide()
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
	var card := TrackTile.new()
	card.name = "DailyTrackCard"
	card.entry = entry
	card.pressed.connect(_request_race)
	_card_slot.add_child(card)
	card.get_node("ToggleFavorite").hide()
	card.custom_minimum_size.y = 260
	_status.hide()
	_race.disabled = false

func _process(_delta: float) -> void:
	if not page_preview and not _busy and _retry_msec > 0 and Time.get_ticks_msec() >= _retry_msec: refresh()
	if _ends_at <= 0: return
	var remaining: int = maxi(0,_ends_at-_server_now-int((Time.get_ticks_msec()-_sample_msec)/1000))
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
		race_requested.emit(entry.duplicate(true))

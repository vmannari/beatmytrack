extends "res://core/app.gd"

func _garage(parent: Control = null) -> void:
	if parent == null: parent = content
	if is_instance_valid(_retained_garage) and _retained_garage.records != records:
		_retained_garage.get_parent().remove_child(_retained_garage)
		_retained_garage.queue_free()
		_retained_garage = null
	if is_instance_valid(_retained_garage) and _retained_garage.records == records:
		if _retained_garage.get_parent() != parent: _retained_garage.reparent(parent,false)
		_retained_garage.refresh_selection()
		_retained_garage.circuit_title = track_title(selected_track).to_upper()
		return
	var page := preload("res://tests/fixtures/parking_hall_before/garage_page.gd").new()
	_retained_garage = page
	page.achievements = achievements
	page.news_client = online.client.news
	page.account_requested.connect(_open_account)
	page.records = records
	page.economy = cosmetic_economy
	page.circuit_title = track_title(selected_track).to_upper()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.vehicle_selected.connect(_select_vehicle)
	page.race_requested.connect(func() -> void: _start_race(selected_track,false))
	page.news_race_requested.connect(_race_news_story)
	page.news_share_requested.connect(_share_track_link)
	page.circuit_requested.connect(_open_library.bind("all"))
	page.save_failed.connect(func() -> void: _notice("Garage changes could not be saved. Check free storage space."))
	parent.add_child(page)


extends "res://ui/garage_page.gd"
## Captured task-original presentation methods; all legacy assertions retained.

func _show_section(next: String) -> void:
	if next == "car": next = "customise"
	if next not in ["cars", "customise", "care", "tuning", "trophies", "records", "news", "achievements"]: return
	_finish_tools()
	_customisation_locked = next in ["customise","tuning"] and not _clean_for_customisation()
	if not _customisation_locked and next=="customise" and section=="customise" and is_instance_valid(livery_menu) and _retained_livery_vehicle==vehicle_id:
		livery_menu.show_tab(_customise_tab)
		return
	_prepare_menu_move()
	_set_customise_layout(next in ["customise","tuning","records"])
	section = next
	_update_wash_status()
	# The newspaper takes the desk. Keep the live car attached and dormant so
	# leaving News restores the same car, camera, condition and reflection rig.
	preview.visible = next not in ["news","achievements"]
	_preview_slot.visible = next not in ["news","achievements"]
	_actions_slot.visible = next not in ["news","achievements"]
	actions.visible = next not in ["news","achievements"]
	_tools_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL if next in ["news","achievements"] or is_instance_valid(customise_layout) else Control.SIZE_FILL
	tools.size_flags_vertical = Control.SIZE_EXPAND_FILL if next in ["news","achievements"] or is_instance_valid(customise_layout) else Control.SIZE_FILL
	if next == "news": tools_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	elif next == "achievements": tools_panel.add_theme_stylebox_override("panel",MenuStyle.card(8))
	if next == "cars": _car_menu_open = false
	elif next not in ["trophies","records","news","achievements"]: _car_menu_open = true
	showroom.set_trophy_view(next == "trophies")
	showroom.set_record_view(next == "records")
	heading.text = "RECORD PLAYER" if next == "records" else "TROPHY WALL" if next == "trophies" else VehicleCatalog.title(vehicle_id)
	preview.get_node("GarageViewControls").visible = next not in ["trophies","records"]
	preview.get_node("GarageViewControls/GarageTopView").visible = next in ["customise","tuning"]
	pickers.clear()
	wash_button = null
	_presets = null
	_sticker_board = null
	_sticker_choice = null
	_sticker_sliders.clear()
	_sticker_values.clear()
	livery_menu = null
	select_button = null
	records_menu = null
	gallery_slot.visible = section == "cars"
	tools_panel.visible = section not in ["cars", "care", "trophies"]
	_build_rail()
	if section == "cars":
		_refresh_thumbnails()
		select_button = MenuStyle.button("SELECT", _confirm_car, true)
		select_button.name = "GarageSelectCar"
		select_button.icon = MenuIcon.texture("arrow")
		select_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for state: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
			select_button.add_theme_color_override(state, MenuStyle.INK)
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_button.custom_minimum_size.y = 60
		select_button.add_theme_color_override("font_focus_color", MenuStyle.INK)
		select_button.add_theme_color_override("font_pressed_color", MenuStyle.INK)
		actions.add_child(select_button)
		_start_menu_move()
		return
	if section not in ["customise","tuning","records","news","achievements"]: tools.add_child(MenuStyle.label(section.to_upper(), 20))
	var back := MenuStyle.button("Trophy Room" if section == "achievements" else "Back to cars", _show_section.bind("trophies" if section == "achievements" else "cars"))
	back.name = "GarageBack"
	back.custom_minimum_size = Vector2(240, 60)
	actions.add_child(back)
	if _customisation_locked:
		_build_wash_requirement()
	elif section == "customise":
		_build_customise()
	elif section == "care":
		wash_button = MenuStyle.button("Wash", _toggle_wash, true)
		wash_button.name = "GarageWash"
		wash_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wash_button.custom_minimum_size.y = 60
		wash_button.add_theme_color_override("font_focus_color", MenuStyle.INK)
		wash_button.add_theme_color_override("font_pressed_color", MenuStyle.INK)
		actions.add_child(wash_button)
	elif section == "trophies":
		_achievement_button = MenuStyle.button("Achievements",_show_section.bind("achievements"),true)
		_achievement_button.name = "GarageAchievements"
		_achievement_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(_achievement_button)
		_achievements_changed()
	elif section == "achievements":
		if achievements != null:
			var album := preload("res://ui/achievements_menu.gd").new()
			album.service = achievements
			album.trophy_room_requested.connect(_show_section.bind("trophies"))
			tools.add_child(album)
	elif section == "tuning":
		_build_tuning()
	elif section == "news":
		var news_menu := preload("res://ui/garage_news_menu.gd").new()
		news_menu.page = self
		news_menu.service = news_client
		tools.add_child(news_menu)
	elif section == "records":
		records_menu = preload("res://ui/garage_records_menu.gd").new()
		records_menu.records = records
		records_menu.browse_index = record_browse_index
		records_menu.changed.connect(func() -> void: showroom.update_records(records.settings))
		records_menu.browsed.connect(func(index: int) -> void: record_browse_index = index)
		records_menu.flipping.connect(showroom.browse_records)
		records_menu.save_failed.connect(func() -> void: save_failed.emit())
		tools.add_child(records_menu)
	else:
		tools.add_child(MenuStyle.label("Coming later", 18, true))
	_start_menu_move()

func _present_menu_layout() -> void:
	if size.x <= 0 or main.size.x <= 0: return
	if preview.visible: _place_menu_panel(preview,_slot_rect(_preview_slot),"")
	_place_menu_panel(rail,_slot_rect(_rail_slot),"left")
	if tools_panel.visible: _place_menu_panel(tools_panel,_slot_rect(_tools_slot),"right")
	_place_menu_panel(actions,_slot_rect(_actions_slot),"bottom")
	if section == "cars":
		var target: Rect2 = _slot_rect(gallery_slot)
		target.position.x += (target.size.x-gallery.size.x)*0.5
		target.size = gallery.size
		_place_menu_panel(gallery,target,"bottom")
	elif _gallery_departing:
		var target: Rect2 = _menu_starts[gallery]
		target.position.y = size.y+16
		_place_menu_panel(gallery,target,"bottom")
	for entry: Dictionary in _departures:
		entry.panel.position = entry.start.position.lerp(entry.finish.position,minf(1.0,_menu_weight/0.45))
	_layout_presented = true


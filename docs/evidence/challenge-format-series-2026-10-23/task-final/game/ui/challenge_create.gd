class_name ChallengeCreate
extends VBoxContainer
## Card-first creation. Completed tickets, verification and supported rules stay authoritative.
signal race_to_set_requested(entry: Dictionary, vehicle_id: String, duration_seconds: int, attempt_limit: int, configuration: Dictionary)
signal confirmed
signal canceled
const FORMAT_TITLES: Dictionary = {"duel":"One-to-one","group":"Group race","three":"3×3","custom":"Custom challenge"}
const FormatCard = preload("res://ui/challenge_format_card.gd")
var adapter: ChallengesClient
var entries: Array[Dictionary] = []
var initial_version: String = ""
var initial_vehicle: String = ""
var initial_ticket: String = ""
var initial_duration: int = 604800
var initial_attempt_limit: int = 0
var initial_configuration: Dictionary = {}
var selected_format: String = "duel"
var attempt_limit: int = 0
var result_context: Dictionary = {}
var created_callback: Callable
var mode: int = 0
var duration: int = 604800
var _track: OptionButton
var _vehicle: OptionButton
var _source: Dictionary = {}
var _notice: Label
var _race: Button
var _create_button: Button
var _retry: Button
var _time: Label
var _serial: int = 0
var _checking: bool = false
var _submitting: bool = false
var _next_check: int = 0
var _search: LineEdit
var _search_timer: Timer
var _search_serial: int = 0
var _base_entries: Array[Dictionary] = []
var _searching: bool = false
var _panel: PanelContainer
var _close_button: Button
var _source_scope: String = ""
var _track_creator: Label
var _time_caption: Label
var _target_panel: PanelContainer
var _status: HBoxContainer
var _preview_art: TextureRect
var _preview_route: LapRouteView
var _preview_title: Label
var _car_art: TextureRect
var _summary_car: Label
var _summary_time: Label
var _tries_note: Label
var _formats: GridContainer
var _format_buttons: Array[FormatCard] = []
var _rule_title: Label
var _rule_details: Label
var _rules_button: Button
var _action_layout: BoxContainer
var _ticket_row: BoxContainer
var _context_buttons: Array[Button] = []
var _track_picker: AcceptDialog
var _car_picker: AcceptDialog
var _step: int = 0
var _format_page: VBoxContainer
var _track_page: VBoxContainer
var _heading: Label
var _custom_button: Button
var _track_cards: HBoxContainer
var _slot_row: HBoxContainer
var _chosen_entries: Array[Dictionary] = []
var _active_slot: int = 0
var _browse_offset: int = 0
var _browse_next: Button
var _browse_previous: Button
var _rules_dialog: ConfirmationDialog

func locked_result() -> bool: return not initial_ticket.is_empty() or not result_context.is_empty()

func _ready() -> void:
	name = "ChallengeCreate"
	theme = MenuStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	_source_scope = str(result_context.get("scope",adapter.scope()))
	duration = initial_duration
	attempt_limit = initial_attempt_limit
	_base_entries = entries.duplicate(true)
	if initial_configuration.has("mode"): mode = int(initial_configuration.mode)
	selected_format = str(initial_configuration.get("format","duel" if mode == 0 and attempt_limit == 0 else "three" if mode == 1 and attempt_limit == 3 else "group" if mode == 1 and attempt_limit == 0 else "custom"))
	var scroll := ScrollContainer.new()
	scroll.name = "ChallengeCreationScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "ChallengeCreationBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	var header := HBoxContainer.new()
	header.name = "ChallengeCreateHeader"
	body.add_child(header)
	var title := MenuStyle.label("CHOOSE YOUR CHALLENGE",36)
	_heading = title
	title.name = "ChallengeCreateTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)
	_close_button = MenuStyle.button("Back",_back)
	_close_button.name = "CloseChallengeCreate"
	_close_button.custom_minimum_size = Vector2(80,52)
	_close_button.add_theme_font_size_override("font_size",20)
	_close_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,4))
	header.add_child(_close_button)
	_format_page = VBoxContainer.new()
	_format_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_format_page.add_theme_constant_override("separation",12)
	body.add_child(_format_page)
	_formats = GridContainer.new()
	_formats.name = "ChallengeFormats"
	_formats.columns = 3
	_formats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_formats.add_theme_constant_override("h_separation",16)
	_formats.add_theme_constant_override("v_separation",12)
	_format_page.add_child(_formats)
	for key: String in ["duel","group","three"]:
		var card := FormatCard.new()
		card.format_id = key
		card.caption = FORMAT_TITLES[key]
		card.description = {"duel":PackedStringArray(["One rival. Your time to beat."]),"group":PackedStringArray(["Get the crew on the same grid."]),"three":PackedStringArray(["Three tracks. Three tries on each."])}[key]
		card.audience = "You + one rival" if key == "duel" else "Up to 20 drivers"
		card.tries = "3 tracks · 3 tries each" if key == "three" else "1 track · Unlimited tries"
		card.scenery = TrackTile.scenery_texture({"duel":"pine","group":"desert","three":"winter"}[key])
		card.name = "ChallengeFormat_"+key
		card.pressed.connect(_choose_format.bind(key))
		_formats.add_child(card)
		_format_buttons.append(card)
	_custom_button = MenuStyle.button("Create custom challenge  ›",_open_rules)
	_custom_button.name = "ChallengeCreateCustom"
	_custom_button.custom_minimum_size.y = 52
	_custom_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_custom_button.add_theme_font_size_override("font_size",20)
	_custom_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,6))
	_format_page.add_child(_custom_button)
	_track_page = VBoxContainer.new()
	_track_page.name = "ChallengeTrackPage"
	_track_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track_page.add_theme_constant_override("separation",12)
	body.add_child(_track_page)
	# Retain the exact receipt preview fields without placing a track ahead of format selection.
	_build_race_ticket(_track_page)
	_panel.hide()
	_slot_row = HBoxContainer.new()
	_slot_row.name = "ChallengeTrackSlots"
	_slot_row.add_theme_constant_override("separation",12)
	_track_page.add_child(_slot_row)
	_build_pickers()
	_track_cards = HBoxContainer.new()
	_track_cards.name = "ChallengeTrackPosters"
	_track_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track_cards.add_theme_constant_override("separation",16)
	_track_page.add_child(_track_cards)
	var browsing := HBoxContainer.new()
	browsing.add_theme_constant_override("separation",10)
	_track_page.add_child(browsing)
	_browse_previous = MenuStyle.button("‹ Previous",func() -> void: _browse_offset = maxi(0,_browse_offset-3); _refresh_tracks())
	browsing.add_child(_browse_previous)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browsing.add_child(space)
	_browse_next = MenuStyle.button("Next ›",func() -> void: _browse_offset += 3; _refresh_tracks())
	browsing.add_child(_browse_next)
	_status = HBoxContainer.new()
	add_child(_status)
	_notice = MenuStyle.label("",17,true)
	_notice.name = "ChallengeSourceStatus"
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_child(_notice)
	_retry = MenuStyle.button("Retry",_check_source)
	_retry.name = "RetryChallengeSource"
	_retry.custom_minimum_size.y = 52
	_status.add_child(_retry)
	var actions: HBoxContainer = _build_rule_summary()
	_race = MenuStyle.button("Race to set a time",_race_to_set,true)
	_race.name = "RaceToSetChallenge"
	_race.custom_minimum_size = Vector2(260,56)
	actions.add_child(_race)
	_create_button = MenuStyle.button("Choose track  ›",_advance,true)
	_create_button.icon = MenuIcon.texture("share")
	_create_button.add_theme_color_override("font_focus_color",MenuStyle.INK)
	_create_button.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	_create_button.add_theme_color_override("icon_hover_color",MenuStyle.INK)
	_create_button.name = "ConfirmChallengeCreate"
	_create_button.custom_minimum_size = Vector2(260,56)
	actions.add_child(_create_button)

	confirmed.connect(_create)
	resized.connect(_layout_cards)
	_layout_cards.call_deferred()
	if initial_configuration.get("tracks") is Array:
		for entry: Dictionary in initial_configuration.tracks: _chosen_entries.append(entry.duplicate(true))
	if locked_result():
		var opening: Dictionary = result_context.get("entry",{})
		if opening.is_empty():
			for entry: Dictionary in entries:
				if str(entry.get("version_id","")) == initial_version: opening = entry
		if not opening.is_empty():
			if _chosen_entries.is_empty(): _chosen_entries.append(opening)
			else: _chosen_entries[0] = opening
	_refresh_tracks()
	_check_source()

func _advance() -> void:
	if _step == 0:
		_step = 1
		if locked_result() and selected_format == "three": _active_slot = 1
		if _chosen_entries.is_empty() and _track.selected >= 0 and _track.selected < entries.size() and selected_format != "three":
			_chosen_entries.append(entries[_track.selected].duplicate(true))
		_refresh_tracks()
		_check_source()
	else: confirmed.emit()

func _back() -> void:
	if _submitting: return
	if _step == 1:
		_step = 0
		_update()
	else: close()

func _required_tracks() -> int: return 3 if selected_format == "three" else 1

func _select_track(entry: Dictionary) -> void:
	if _submitting or (locked_result() and _active_slot == 0): return
	for index: int in range(_chosen_entries.size()):
		if index != _active_slot and str(_chosen_entries[index].get("track_id",_chosen_entries[index].get("version_id",""))) == str(entry.get("track_id",entry.version_id)): return
	if _active_slot < _chosen_entries.size(): _chosen_entries[_active_slot] = entry.duplicate(true)
	else: _chosen_entries.append(entry.duplicate(true))
	if _chosen_entries.size() < _required_tracks(): _active_slot = _chosen_entries.size()
	_refresh_tracks()
	_check_source()

func _refresh_tracks() -> void:
	if _track_cards == null: return
	for child: Node in _track_cards.get_children(): _track_cards.remove_child(child); child.queue_free()
	for child: Node in _slot_row.get_children(): _slot_row.remove_child(child); child.queue_free()
	_active_slot = mini(_active_slot,_required_tracks()-1)
	for index: int in range(_required_tracks()):
		var title: String = str(_chosen_entries[index].name) if index < _chosen_entries.size() else "Choose track"
		var slot := MenuStyle.button("0"+str(index+1)+"  "+title,func() -> void: _active_slot = index; _refresh_tracks())
		slot.name = "ChallengeTrackSlot_"+str(index)
		slot.custom_minimum_size.y = 52
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot.clip_text = true
		_selection(slot,index == _active_slot)
		_slot_row.add_child(slot)
	for index: int in range(_browse_offset,mini(entries.size(),_browse_offset+3)):
		var entry: Dictionary = entries[index]
		var card := preload("res://ui/challenge_track_card.gd").new()
		card.entry = entry
		card.chosen = _chosen_entries.any(func(item: Dictionary) -> bool: return item.version_id == entry.version_id)
		card.disabled = _submitting or (locked_result() and _active_slot == 0)
		card.pressed.connect(_select_track.bind(entry))
		_track_cards.add_child(card)
	_browse_previous.disabled = _browse_offset <= 0
	_browse_next.disabled = _browse_offset+3 >= entries.size()
	_update()

func _build_race_ticket(parent: Control) -> void:
	_panel = PanelContainer.new()
	_panel.name = "ChallengeCreatePanel"
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override("panel",MenuStyle.card(12))
	parent.add_child(_panel)
	_preview_art = TextureRect.new()
	_preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_preview_art)
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.07,0.10,0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(shade)
	_ticket_row = BoxContainer.new()
	_ticket_row.add_theme_constant_override("separation",18)
	_panel.add_child(_ticket_row)
	_preview_route = LapRouteView.new()
	_preview_route.name = "ChallengeFinishedRoute"
	_preview_route.miniature = true
	_preview_route.custom_minimum_size = Vector2(140,96)
	_preview_route.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ticket_row.add_child(_preview_route)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",3)
	_ticket_row.add_child(details)
	var kicker := MenuStyle.label("YOUR RACE. THEIR CHALLENGE." if locked_result() else "GIVE THEM SOMETHING TO CHASE",12,true)
	kicker.add_theme_font_override("font",MenuStyle.DISPLAY)
	details.add_child(kicker)
	_preview_title = MenuStyle.label("",29)
	_preview_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(_preview_title)
	_summary_car = MenuStyle.label("",15,true)
	_summary_car.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(_summary_car)
	_track_creator = MenuStyle.label("",12,true)
	_track_creator.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(_track_creator)
	if locked_result():
		var lock := MenuStyle.label("Track & car fixed to this race",12,true)
		lock.add_theme_color_override("font_color",MenuStyle.POSITIVE)
		details.add_child(lock)
	else:
		var edit := HBoxContainer.new()
		edit.add_theme_constant_override("separation",14)
		edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_ticket_row.add_child(edit)
		for item: Array in [["Circuit","track"],["Car","car"]]:
			var control := MenuStyle.button(str(item[0])+"  ›",_open_picker.bind(str(item[1])))
			control.name = "ChallengePick_"+str(item[1])
			control.custom_minimum_size = Vector2(80,52)
			control.add_theme_font_size_override("font_size",17)
			var context_style := MenuStyle.box(Color("0a202acc"),10)
			context_style.border_color = Color("4c6370")
			context_style.set_border_width_all(1)
			control.add_theme_stylebox_override("normal",context_style)
			edit.add_child(control)
			_context_buttons.append(control)
	_target_panel = PanelContainer.new()
	var target_style := MenuStyle.box(Color("071820bd"),0)
	target_style.content_margin_left = 20
	target_style.content_margin_right = 10
	target_style.border_width_left = 1
	target_style.border_color = Color("49616b")
	_target_panel.add_theme_stylebox_override("panel",target_style)
	_ticket_row.add_child(_target_panel)
	var target := VBoxContainer.new()
	target.add_theme_constant_override("separation",2)
	_target_panel.add_child(target)
	_time_caption = MenuStyle.label("",12,true)
	_time_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	target.add_child(_time_caption)
	_time = MenuStyle.label("",54)
	_time.name = "ChallengeFinishedTime"
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time.add_theme_color_override("font_color",MenuStyle.ACCENT)
	target.add_child(_time)
	_summary_time = MenuStyle.label("",13,true)
	_summary_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	target.add_child(_summary_time)

func _build_rule_summary() -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "ChallengeCreateActions"
	var dock_style := MenuStyle.card(14)
	dock_style.bg_color = Color("091d28")
	dock_style.border_color = Color("4b6470")
	panel.add_theme_stylebox_override("panel",dock_style)
	add_child(panel)
	_action_layout = BoxContainer.new()
	_action_layout.add_theme_constant_override("separation",20)
	panel.add_child(_action_layout)
	var row := HBoxContainer.new()
	row.name = "ChallengeRuleSummary"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",14)
	_action_layout.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",3)
	row.add_child(text)
	_rule_title = MenuStyle.label("CHALLENGE RULES",12,true)
	_rule_title.add_theme_font_override("font",MenuStyle.DISPLAY)
	text.add_child(_rule_title)
	_rule_details = MenuStyle.label("",17)
	_rule_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_rule_details)
	_tries_note = MenuStyle.label("Each start uses a try, including restarts.",12,true)
	_tries_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tries_note.add_theme_color_override("font_color",Color("dfcb98"))
	text.add_child(_tries_note)
	_rules_button = MenuStyle.button("Edit rules  ›",_open_rules)
	_rules_button.name = "ChallengeAdjustRules"
	_rules_button.custom_minimum_size = Vector2(120,52)
	_rules_button.add_theme_font_size_override("font_size",18)
	_rules_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,2))
	row.add_child(_rules_button)
	var actions := HBoxContainer.new()
	_action_layout.add_child(actions)
	return actions

func _build_pickers() -> void:
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	_track_page.add_child(content)
	_search = LineEdit.new()
	_search.name = "ChallengeTrackSearch"
	_search.placeholder_text = "Find a track or creator"
	_search.max_length = 80
	_search.custom_minimum_size.y = 52
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_search)
	var car_button := MenuStyle.button("Car  ›",_open_picker.bind("car"))
	car_button.name = "ChallengePickCar"
	car_button.custom_minimum_size = Vector2(100,52)
	car_button.disabled = locked_result()
	content.add_child(car_button)
	_track = OptionButton.new()
	_track.hide()
	content.add_child(_track)
	for index: int in range(entries.size()):
		_track.add_item(str(entries[index].name),index)
		if str(entries[index].version_id) == initial_version: _track.select(index)
	_track.item_selected.connect(func(index: int) -> void: _select_track(entries[index]))
	_search_timer = Timer.new()
	_search_timer.wait_time = 0.35
	_search_timer.one_shot = true
	_search_timer.timeout.connect(_find_tracks)
	add_child(_search_timer)
	_search.text_changed.connect(func(_text: String) -> void:
		_search_serial += 1
		_searching = true
		_update()
		_search_timer.start())
	_car_picker = AcceptDialog.new()
	_car_picker.title = "Choose your car"
	_car_picker.ok_button_text = "Keep this car"
	add_child(_car_picker)
	preload("res://ui/popup_style.gd").watch(_car_picker)
	var choices := VBoxContainer.new()
	_car_picker.add_child(choices)
	_car_art = TextureRect.new()
	_car_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_car_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_car_art.custom_minimum_size = Vector2(minf(330,get_viewport_rect().size.x-96),160)
	choices.add_child(_car_art)
	_vehicle = OptionButton.new()
	_vehicle.name = "ChallengeCarChoice"
	_vehicle.custom_minimum_size.y = 52
	choices.add_child(_vehicle)
	for title: String in VehicleCatalog.NAMES: _vehicle.add_item(title)
	_vehicle.select(VehicleCatalog.IDS.find(VehicleCatalog.valid_id(initial_vehicle)))
	_vehicle.item_selected.connect(func(_index: int) -> void: _check_source())

func _open_picker(kind: String) -> void:
	if locked_result() or _submitting: return
	if kind == "track":
		_step = 1
		_update()
		_search.grab_focus()
		return
	_car_art.custom_minimum_size.x = minf(330,get_viewport_rect().size.x-96)
	_car_art.visible = get_viewport_rect().size.y >= 500
	_car_picker.popup_centered(Vector2i(mini(520,int(get_viewport_rect().size.x)-32),300))

func _choose_format(key: String) -> void:
	if _submitting or not FORMAT_TITLES.has(key): return
	if key == "custom":
		_open_rules()
		return
	selected_format = key
	mode = 0 if key == "duel" else 1
	attempt_limit = 3 if key == "three" else 0
	if key != "three" and _chosen_entries.size() > 1: _chosen_entries.resize(1)
	_active_slot = mini(_active_slot,_required_tracks()-1)
	_refresh_tracks()

func _open_rules() -> void:
	if _submitting or is_instance_valid(_rules_dialog): return
	var draft: Dictionary = {"mode":mode,"duration":duration,"tries":attempt_limit,"visibility":adapter.creation_visibility}
	_rules_dialog = ConfirmationDialog.new()
	_rules_dialog.name = "ChallengeCustomRules"
	_rules_dialog.title = "Make it your challenge"
	_rules_dialog.ok_button_text = "Keep these rules"
	_rules_dialog.cancel_button_text = "Cancel"
	add_child(_rules_dialog)
	preload("res://ui/popup_style.gd").watch(_rules_dialog)
	var scroll := ScrollContainer.new()
	scroll.name = "ChallengeCustomRulesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(minf(500,get_viewport_rect().size.x-96),mini(450,int(get_viewport_rect().size.y)-220))
	_rules_dialog.add_child(scroll)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation",12)
	scroll.add_child(fields)
	_rule_choices(fields,"Who’s racing?",[[0,"One-to-one"],[1,"Group race"]],draft,"mode","ChallengeCustomMode_")
	_rule_choices(fields,"Time to take the challenge",[[86400,"24 hours"],[259200,"3 days"],[604800,"7 days"]],draft,"duration","ChallengeDuration_")
	_rule_choices(fields,"Tries per driver",[[0,"Unlimited"],[1,"1"],[3,"3"],[5,"5"]],draft,"tries","ChallengeTries_")
	if adapter.discovery_supported(): _rule_choices(fields,"Who can join?",[["public","Public · Discover"],["private","Invitation only"]],draft,"visibility","ChallengeCustomVisibility_")
	var note := MenuStyle.label("Best time wins. Each start uses a try, including restarts and abandoned races. Ordinary Free Race stays unlimited.",15,true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(note)
	_rules_dialog.confirmed.connect(func() -> void:
		if not _submitting and adapter.scope() == _source_scope:
			mode = int(draft.mode)
			duration = int(draft.duration)
			attempt_limit = int(draft.tries)
			adapter.creation_visibility = str(draft.visibility)
			selected_format = "custom"
			_step = 1
			if _chosen_entries.size() > 1: _chosen_entries.resize(1)
			_active_slot = 0
			_refresh_tracks()
			_check_source()
		_dismiss_rules())
	_rules_dialog.canceled.connect(_dismiss_rules)
	_rules_dialog.popup_centered(Vector2i(mini(620,int(get_viewport_rect().size.x)-32),mini(650,int(get_viewport_rect().size.y)-32)))
	_fit_rules_heading.call_deferred()

func _fit_rules_heading() -> void:
	if not is_instance_valid(_rules_dialog) or size.x >= 600: return
	var chrome: Node = _rules_dialog.get_node_or_null("PopupStyle")
	if chrome != null and is_instance_valid(chrome.header): chrome.header.add_theme_font_size_override("font_size",24)

func _rule_choices(parent: Control, caption: String, values: Array, draft: Dictionary, key: String, prefix: String) -> void:
	parent.add_child(MenuStyle.label(caption,21))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	parent.add_child(row)
	for item: Array in values:
		var button: Button = _segment(row,str(item[1]),func() -> void: pass)
		button.name = prefix+str(item[0])
		button.set_meta("rule_value",item[0])
		button.pressed.connect(func() -> void:
			draft[key] = item[0]
			for peer: Node in row.get_children(): _selection(peer as Button,peer.get_meta("rule_value") == draft[key]))
		_selection(button,draft[key] == item[0])

func _dismiss_rules() -> void:
	if not is_instance_valid(_rules_dialog): return
	_rules_dialog.hide()
	_rules_dialog.queue_free()
	_rules_dialog = null
	_rules_button.grab_focus()

func _layout_cards() -> void:
	if _formats == null: return
	_formats.columns = 3 if size.x >= 720 else 1
	_ticket_row.vertical = size.x < 740
	_preview_route.visible = size.x >= 740
	_time.add_theme_font_size_override("font_size",60 if size.x >= 850 else 44)
	var narrow: bool = size.x < 600
	_action_layout.vertical = size.x < 740
	(_create_button.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL if _action_layout.vertical else Control.SIZE_SHRINK_END
	_create_button.custom_minimum_size.x = 210 if narrow else 260
	_race.custom_minimum_size.x = _create_button.custom_minimum_size.x
	_create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_END
	_race.size_flags_horizontal = _create_button.size_flags_horizontal

func _icon(glyph: String, extent: int = 24) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = MenuIcon.texture(glyph)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(extent,extent)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _segment(parent: Control, caption: String, action: Callable) -> Button:
	var button := MenuStyle.button(caption,action)
	button.add_theme_font_size_override("font_size",20)
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button

func _choose_attempt_limit(value: int) -> void:
	attempt_limit = value
	selected_format = "custom"
	_update()

func _refresh_preview() -> void:
	if _preview_art == null: return
	var entry: Dictionary = _entry()
	_preview_art.texture = TrackTile.scenery_texture(str(entry.get("theme","pine")))
	_track_creator.text = "By "+str(entry.get("creator","")) if not entry.get("creator","").is_empty() else ""
	_preview_title.text = str(entry.get("name","Choose a circuit"))
	_preview_route.route.clear()
	for point: Array in entry.get("points",[]): _preview_route.route.append(Vector2(point[0],point[1]))
	_preview_route._fit()
	var car: String = _vehicle_id()
	if _car_art != null: _car_art.texture = VehicleCatalog.artwork(car)
	_summary_car.text = VehicleCatalog.title(car)+" · 5 laps"
	var total: float = float(result_context.get("total",0.0)) if locked_result() else 0.0
	if _source.get("status") == "verified": total = float(_source.get("ms",0))/1000.0
	_time.text = MenuStyle.time_text(total) if total > 0.0 else "Your next drive"
	_time.visible = mode == 0 or locked_result()
	_time_caption.text = "CAN THEY BEAT" if mode == 0 and total > 0 else "FIRST, SET THE TARGET" if mode == 0 else "YOUR OPENING TIME" if locked_result() else "BRING THE CREW"
	_summary_time.text = "Your exact finish time" if locked_result() else "Your verified best" if mode == 0 and total > 0 else "Five laps. Then invite your rival." if mode == 0 else "Fastest time wins"
	var duration_text: String = "24 hours" if duration == 86400 else "3 days" if duration == 259200 else "7 days"
	var tries_text: String = "Unlimited tries" if attempt_limit == 0 else str(attempt_limit)+(" try" if attempt_limit == 1 else " tries")+" per driver"
	_rule_details.text = duration_text+" · "+tries_text+" · Best time wins"
	if selected_format == "custom": _rule_details.text = ("You + one rival" if mode == 0 else "Up to 20 drivers")+" · "+_rule_details.text
	if adapter.discovery_supported(): _rule_details.text += " · "+("Public" if adapter.creation_visibility == "public" else "Invitation only")
	if selected_format == "three": _rule_details.text = "3 tracks · 3 tries on each · Lowest total time wins"
	if _step == 0:
		_rule_title.text = FORMAT_TITLES[selected_format].to_upper()
		_rule_details.text = {"duel":"One rival. Your time to beat.  ·  Unlimited tries","group":"One track. The whole crew.  ·  Unlimited tries","three":"Three tracks. Three tries on each.  ·  Lowest total time wins","custom":"Your format, your rules."}[selected_format]
	else:
		_rule_title.text = FORMAT_TITLES[selected_format].to_upper()+"  ·  "+str(_chosen_entries.size())+" / "+str(_required_tracks())+" TRACKS"
		_rule_details.text += " · "+VehicleCatalog.title(_vehicle_id())
		if locked_result(): _rule_details.text += " · Opening time "+_time.text
		elif mode == 0 and _source.get("status") == "verified": _rule_details.text += " · Target "+_time.text
	_tries_note.visible = _step == 1 and attempt_limit > 0
	_rules_button.visible = _step == 1 and selected_format != "three"
	for card: FormatCard in _format_buttons:
		card.chosen = card.format_id == selected_format

		card.disabled = _submitting
		if card.format_id == "custom" and selected_format == "custom":
			card.audience = "You + one rival" if mode == 0 else "Up to 20 drivers"
			card.tries = tries_text
		elif card.format_id == "custom":
			card.audience = "Choose the format"
			card.tries = "Duration, tries & who can join"
		card.refresh()

func _entry() -> Dictionary:
	return _chosen_entries[0] if not _chosen_entries.is_empty() else {}

func _vehicle_id() -> String:
	return VehicleCatalog.valid_id(initial_vehicle) if locked_result() or _vehicle == null else VehicleCatalog.IDS[_vehicle.selected]

func _choose_mode(index: int) -> void:
	mode = index
	selected_format = "custom"
	_update()

func _choose_duration(seconds: int) -> void:
	duration = seconds
	selected_format = "custom"
	_update()

func popup_centered(_size: Vector2i = Vector2i.ZERO) -> void:
	show()
	set_process_input(true)

func get_ok_button() -> Button: return _create_button

func close() -> void:
	if _submitting: return
	_dismiss_rules()
	if _track_picker != null: _track_picker.hide()
	if _car_picker != null: _car_picker.hide()
	_serial += 1
	_search_serial += 1
	hide()
	set_process_input(false)
	canceled.emit()

func _input(event: InputEvent) -> void:
	if is_instance_valid(_rules_dialog) or (_track_picker != null and _track_picker.visible) or (_car_picker != null and _car_picker.visible): return
	if visible and event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _check_source() -> void:
	_serial += 1
	var serial: int = _serial
	_source = {}
	_checking = false
	var entry: Dictionary = _entry()
	if entry.is_empty() or (mode == 1 and not locked_result()):
		_update()
		return
	if adapter.scope() != _source_scope:
		_next_check = Time.get_ticks_msec()+3000
		_source = {"status":"unavailable","error":"Sign in again to create this challenge."}
		_update()
		return
	_checking = true
	_next_check = Time.get_ticks_msec()+3000
	_update()
	var ticket: String = initial_ticket if locked_result() else ""
	var value: Dictionary = await adapter.source(str(entry.version_id),_vehicle_id(),ticket)
	if not is_instance_valid(self) or serial != _serial: return
	_checking = false
	_source = value
	_next_check = Time.get_ticks_msec()+3000
	_update()

func _update() -> void:
	if _create_button == null: return
	var verified: bool = _source.get("status") == "verified"
	var has_entry: bool = not _entry().is_empty()
	var pending: bool = _source.get("status") in ["not_set","queued","verifying"]
	_create_button.disabled = _checking or _searching or _submitting or not has_entry or (not verified and (locked_result() or mode == 0)) or adapter.scope() != _source_scope
	if _step == 0: _create_button.disabled = _submitting or adapter.scope() != _source_scope
	elif _chosen_entries.size() != _required_tracks(): _create_button.disabled = true
	elif selected_format == "three" and not adapter.series_supported(): _create_button.disabled = true
	_format_page.visible = _step == 0
	_track_page.visible = _step == 1
	_heading.text = "CHOOSE YOUR CHALLENGE" if _step == 0 else "CHOOSE THREE TRACKS" if selected_format == "three" else "CHOOSE YOUR TRACK"
	_create_button.text = ("Choose tracks  ›" if selected_format == "three" else "Choose track  ›") if _step == 0 else "Create & share"
	_create_button.icon = null if _step == 0 else MenuIcon.texture("share")
	_race.visible = _step == 1 and not locked_result() and mode == 0 and has_entry and _source.get("status") == "not_set" and not _checking
	_create_button.visible = not _race.visible
	_race.disabled = _submitting or _searching
	_close_button.disabled = _submitting
	_retry.visible = _source.get("status") == "unavailable" and not _checking and not _submitting
	_notice.text = "Creating…" if _submitting else "Finding tracks…" if _searching else "Verifying result…" if locked_result() and (_checking or pending) else "Checking time…" if _checking else str(_source.get("error","")) if _source.has("error") else "This result was not verified." if locked_result() and not verified else "Choose a published track." if not has_entry else ""
	if _step == 0: _notice.text = ""
	elif selected_format == "three" and not adapter.series_supported(): _notice.text = "3×3 needs the updated online service."
	_notice.visible = not _notice.text.is_empty()
	_status.visible = _notice.visible or _retry.visible
	_refresh_preview()
	if _track != null: _track.disabled = _submitting
	if _custom_button != null: _custom_button.disabled = _submitting
	if _vehicle != null: _vehicle.disabled = _submitting
	if _search != null: _search.editable = not _submitting
	_rules_button.disabled = _submitting
	for control: Button in _context_buttons: control.disabled = _submitting

func _selection(button: Button, chosen: bool) -> void:
	var style := MenuStyle.box(MenuStyle.ACCENT if chosen else Color("152c3b"),10)
	style.border_color = MenuStyle.ACCENT if chosen else Color("2b4657")
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal",style)
	for key: String in ["font_color","font_focus_color","font_hover_color"]: button.add_theme_color_override(key,MenuStyle.INK if chosen else MenuStyle.TEXT)
	button.disabled = _submitting

func _create() -> void:
	if _step != 1 or _create_button.disabled: return
	_submitting = true
	_update()
	if adapter.discovery_supported() and adapter.creation_visibility == "public":
		if not await preload("res://ui/community_safety_ui.gd").ensure_terms(self,adapter.client):
			_submitting = false
			_update()
			_notice.text = "Accept the public sharing rules to list this challenge."
			_notice.show()
			return
		if adapter.scope() != _source_scope:
			_submitting = false
			_update()
			return
	var entry: Dictionary = _entry()
	var payload: Dictionary = {"version_id":str(entry.version_id),"vehicle_id":_vehicle_id(),"mode":"group" if mode == 1 else "beat","duration_seconds":duration}
	if selected_format == "three":
		payload.mode = "3x3"
		payload.version_ids = []
		for item: Dictionary in _chosen_entries: payload.version_ids.append(str(item.version_id))
	if adapter.discovery_supported(): payload.visibility = adapter.creation_visibility
	if attempt_limit > 0: payload.attempt_limit = attempt_limit
	if locked_result():
		if initial_ticket.is_empty():
			_submitting = false
			_source = {"status":"unavailable","error":"Could not recover this result."}
			_update()
			return
		payload.source_ticket_id = initial_ticket
	elif _source.get("status") == "verified" and mode == 0: payload.source_run_id = str(_source.run_id)
	await adapter.create_challenge(payload)
	if not is_instance_valid(self): return
	_submitting = false
	if adapter.error.is_empty() and not adapter.selected.is_empty():
		hide()
		if created_callback.is_valid(): created_callback.call()
	else:
		_update()
		_notice.text = adapter.error
		_notice.show()
		_status.show()

func _race_to_set() -> void:
	if locked_result() or _entry().is_empty() or _submitting or adapter.scope() != _source_scope: return
	hide()
	race_to_set_requested.emit(_entry(),_vehicle_id(),duration,attempt_limit,{"mode":mode,"format":selected_format,"tracks":_chosen_entries.duplicate(true)})

func _find_tracks() -> void:
	var serial: int = _search_serial
	var query: String = _search.text.strip_edges()
	_searching = true
	_update()
	var results: Array[Dictionary] = []
	if query.is_empty(): results = _base_entries.duplicate(true)
	else:
		var payload: Dictionary = preload("res://backend/discovery_pages.gd").payload({"search":query,"section":"all"})
		var response: Dictionary = await adapter.client.request_discovery(payload,get_instance_id())
		if not is_instance_valid(self) or serial != _search_serial or adapter.scope() != _source_scope: return
		if not response.ok:
			_searching = false
			_update()
			_notice.text = "Track search is busy. Retry or narrow your search." if int(response.get("status",0)) in [429,503] else "Could not search tracks. Retry when connected."
			_notice.show()
			return
		if not response.get("ok",false) or not response.data.get("items") is Array:
			_searching = false
			_checking = false
			entries.clear()
			_track.clear()
			_source = {"status":"unavailable","error":"Could not find tracks. Try again."}
			_update()
			return
		for entry: Variant in response.data.items:
			if entry is Dictionary and adapter.cloud._valid_entry(entry): results.append(entry)
	if serial != _search_serial: return
	entries = results
	_track.clear()
	for index: int in range(entries.size()): _track.add_item(str(entries[index].name),index)
	if not entries.is_empty(): _track.select(0)
	_searching = false
	_checking = false
	_browse_offset = 0
	_refresh_tracks()
	if entries.is_empty():
		_notice.text = "No matching tracks."
		_notice.show()

func _process(_delta: float) -> void:
	if visible and not _checking and not _submitting and (locked_result() and _source.get("status") in ["not_set","queued","verifying","unavailable"] or _source.get("status") in ["queued","verifying"]):
		if Time.get_ticks_msec() >= _next_check: _check_source()

func _exit_tree() -> void:
	if adapter != null: adapter.client.cancel_public_reads(get_instance_id())

class_name ChallengeCreate
extends VBoxContainer
## Format -> tracks -> car, with authoritative completed results and supported rules.
signal race_to_set_requested(entry: Dictionary, vehicle_id: String, duration_seconds: int, attempt_limit: int, configuration: Dictionary)
signal confirmed
signal canceled
const FORMAT := 0
const TRACKS := 1
const CAR := 2
const RULES := 3
const RESULT := 4
const FORMAT_TITLES: Dictionary = {"duel":"One-to-one","group":"Group race","three":"3×3","custom":"Custom challenge"}
const FormatCard = preload("res://ui/challenge_format_card.gd")
const POSTERS: Dictionary = {"duel":"res://assets/menu/challenges/one-to-one-v3.png","group":"res://assets/menu/challenges/group-race-v3.png","three":"res://assets/menu/challenges/three-by-three-v9.png"}
var adapter: ChallengesClient
var entries: Array[Dictionary] = []
var library: TrackLibrary
var records: LocalRecords
var selected_track: NativeTrack
var browser_state: Dictionary = {}
var initial_version: String = ""
var initial_vehicle: String = ""
var initial_ticket: String = ""
var initial_duration: int = 604800
var initial_attempt_limit: int = 0
var initial_configuration: Dictionary = {}
var selected_format: String = "duel"
var custom_track_count: int = 1
var attempt_limit: int = 0
var result_context: Dictionary = {}
var results_only: bool = false
var created_callback: Callable
var start_after_create: bool = false
var mode: int = 0
var duration: int = 604800
var _step: int = FORMAT
var _rules_return: int = FORMAT
var _draft_rules: Dictionary = {}
var _source_scope: String = ""
var _source: Dictionary = {}
var _serial: int = 0
var _checking: bool = false
var _submitting: bool = false
var _next_check: int = 0
var _chosen_entries: Array[Dictionary] = []
var _active_slot: int = 0
var _chosen_car: String = "compact"
var _heading: Label
var _format_page: VBoxContainer
var _track_page: VBoxContainer
var _car_page: VBoxContainer
var _custom_page: VBoxContainer
var _rules_fields: GridContainer
var _result_rule_rows: Array[BoxContainer] = []
var _formats: GridContainer
var _format_buttons: Array[FormatCard] = []
var _custom_button: Button
var _slot_row: GridContainer
var _browser: TrackBrowser
var _car_stage: Control
var _car_art: CarShowroom
var _car_models: Dictionary = {}
var _car_scroll: ScrollContainer
var _car_cards: Array[Button] = []
var _time: Label
var _summary_time: Label
var _notice: Label
var _status: HBoxContainer
var _retry: Button
var _race: Button
var _share: Button
var _create_button: Button
var _close_button: Button
var _rule_title: Label
var _rule_details: Label
var _tries_note: Label
var _rules_button: Button
var _action_layout: BoxContainer
var _final_actions: BoxContainer

func locked_result() -> bool: return not initial_ticket.is_empty() or not result_context.is_empty()
func _required_tracks() -> int: return 1 if results_only else 3 if selected_format == "three" else custom_track_count if selected_format == "custom" else 1
func _entry() -> Dictionary: return _chosen_entries[0] if not _chosen_entries.is_empty() else {}
func _vehicle_id() -> String: return VehicleCatalog.valid_id(initial_vehicle) if locked_result() else _chosen_car

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(_create_button): _update.call_deferred()

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
	mode = int(initial_configuration.get("mode",0))
	selected_format = str(initial_configuration.get("format","duel" if mode == 0 and attempt_limit == 0 else "three" if mode == 1 and attempt_limit == 3 else "group" if mode == 1 and attempt_limit == 0 else "custom"))
	custom_track_count = clampi(int(initial_configuration.get("track_count",1)),1,5)
	_chosen_car = VehicleCatalog.valid_id(initial_vehicle)
	if initial_configuration.get("tracks") is Array:
		for entry: Dictionary in initial_configuration.tracks: _chosen_entries.append(entry.duplicate(true))
	if locked_result():
		var opening: Dictionary = result_context.get("entry",{})
		if opening.is_empty():
			for entry: Dictionary in entries:
				if str(entry.get("version_id","")) == initial_version: opening = entry
		if not opening.is_empty():
			if _chosen_entries.is_empty(): _chosen_entries.append(opening.duplicate(true))
			else: _chosen_entries[0] = opening.duplicate(true)
	_step = CAR if int(initial_configuration.get("step",FORMAT)) == CAR and not _chosen_entries.is_empty() else FORMAT
	if results_only:
		_step = RESULT
		selected_format = "duel" if mode == 0 else "group"
		if _chosen_entries.size() > 1: _chosen_entries.resize(1)
	var header := HBoxContainer.new()
	header.name = "ChallengeCreateHeader"
	add_child(header)
	_heading = MenuStyle.label("CHOOSE YOUR CHALLENGE",36)
	_heading.name = "ChallengeCreateTitle"
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_heading)
	_close_button = _button(header,"Back",_back,"CloseChallengeCreate")
	# Reserve the same padding as hover/pressed so the caption stays fully visible.
	_close_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT))
	var scroll := ScrollContainer.new()
	scroll.name = "ChallengeCreationScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_format_page = _page(body,"ChallengeFormatPage")
	_track_page = _page(body,"ChallengeTrackPage")
	_car_page = _page(body,"ChallengeCarPage")
	_custom_page = _page(body,"ChallengeCustomRulesPage")
	_build_formats()
	_slot_row = GridContainer.new()
	_slot_row.name = "ChallengeTrackSlots"
	_slot_row.add_theme_constant_override("h_separation",12)
	_slot_row.add_theme_constant_override("v_separation",8)
	_track_page.add_child(_slot_row)
	_build_cars()
	_rules_fields = GridContainer.new()
	_rules_fields.name = "ChallengeRulesFields"
	_rules_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rules_fields.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rules_fields.add_theme_constant_override("h_separation",20)
	_rules_fields.add_theme_constant_override("v_separation",16)
	_custom_page.add_child(_rules_fields)
	var note := MenuStyle.label("Best time wins. Each start uses a try, including restarts.",16,true)
	note.visible = not results_only
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_custom_page.add_child(note)
	_status = HBoxContainer.new()
	add_child(_status)
	_notice = MenuStyle.label("",16,true)
	_notice.name = "ChallengeSourceStatus"
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_child(_notice)
	_retry = _button(_status,"Retry",_check_source,"RetryChallengeSource")
	_build_actions()
	if results_only:
		_draft_rules = {"mode":mode,"duration":duration,"tries":attempt_limit}
		_rule_choices("Who's racing?",[[0,"One-to-one"],[1,"Group race"]],"mode","ChallengeResultMode_")
		_rule_choices("Challenge duration",[[86400,"24 hours"],[259200,"3 days"],[604800,"7 days"]],"duration","ChallengeDuration_")
		_rule_choices("Tries per driver",[[0,"Unlimited"],[1,"1"],[3,"3"],[5,"5"]],"tries","ChallengeTries_")
	confirmed.connect(_create)
	resized.connect(_layout_cards)
	_layout_cards.call_deferred()
	if _step == CAR or locked_result(): _check_source()
	_refresh_tracks()
	_update()

func _page(parent: Control, identity: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = identity
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation",12)
	parent.add_child(page)
	return page

func _button(parent: Control, caption: String, action: Callable, identity: String, primary: bool = false) -> Button:
	var button := MenuStyle.button(caption,action,primary)
	button.name = identity
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size",21)
	parent.add_child(button)
	return button

func _build_formats() -> void:
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
		card.scenery = load(POSTERS[key]) as Texture2D
		card.name = "ChallengeFormat_"+key
		card.pressed.connect(_choose_format.bind(key))
		_formats.add_child(card)
		_format_buttons.append(card)
	_custom_button = _button(_format_page,"Create custom challenge  ›",_open_rules,"ChallengeCreateCustom")
	_custom_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_custom_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,6))

func _ensure_browser() -> void:
	if results_only: return
	if _browser != null: return
	var live: bool = library != null and records != null and adapter.client.has_method("request_discovery")
	if library == null: library = TrackLibrary.new(adapter.cloud.cache_root().path_join("challenge-picker"))
	if records == null: records = LocalRecords.new(adapter.cloud.cache_root().path_join("challenge-picker-records.json"))
	_browser = TrackBrowser.new()
	_browser.name = "ChallengeTrackBrowser"
	_browser.selection_only = true
	_browser.library = library
	_browser.records = records
	_browser.selected_track = selected_track if selected_track != null else NativeTrack.read("res://resources/tracks/ellipse.json")
	_browser.state = browser_state.duplicate(true)
	_browser.state.erase("random_on_open")
	_browser.state.erase("focus_track")
	_browser.catalog = TrackCatalog.new(library)
	_browser.catalog.indexed_revision = library.revision
	if live: _browser.cloud = adapter.cloud
	else:
		for entry: Dictionary in entries:
			var metadata: Dictionary = entry.duplicate(true)
			metadata.id = "cloud_"+str(entry.get("track_id",entry.version_id))
			metadata.source = "cloud"
			metadata.read_only = true
			_browser.catalog.entries.append(metadata)
	_browser.entry_chosen.connect(_select_track)
	_browser.notice.connect(_show_notice)
	_track_page.add_child(_browser)
	_refresh_tracks()

func _refresh_tracks() -> void:
	if _slot_row == null: return
	for child: Node in _slot_row.get_children(): _slot_row.remove_child(child); child.queue_free()
	_active_slot = mini(_active_slot,_required_tracks()-1)
	_slot_row.visible = _required_tracks() > 1
	_slot_row.columns = _required_tracks() if size.x >= 720 else mini(2,_required_tracks())
	if _required_tracks() > 1:
		for index: int in range(_required_tracks()):
			var title: String = str(_chosen_entries[index].name) if index < _chosen_entries.size() else "Choose track"
			var slot := _button(_slot_row,"",func() -> void: _active_slot = index; _refresh_tracks(),"ChallengeTrackSlot_"+str(index))
			GameText.bind(slot,"{index}  {title}",{"index":index+1,"title":title if index < _chosen_entries.size() else tr("Choose track")})
			slot.tooltip_text = GameText.message("Choose the track for slot {index}",{"index":index+1})
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.clip_text = true
			slot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var style := MenuStyle.box(Color("10232fe8"),10)
			style.set_corner_radius_all(0)
			style.border_color = MenuStyle.ACCENT if index == _active_slot else MenuStyle.BORDER
			style.border_width_bottom = 3 if index == _active_slot else 1
			slot.add_theme_stylebox_override("normal",style)
			slot.add_theme_color_override("font_color",MenuStyle.ACCENT if index == _active_slot else MenuStyle.TEXT)
	if _browser != null:
		_browser.selected_versions.clear()
		for entry: Dictionary in _chosen_entries: _browser.selected_versions.append(str(entry.version_id))
		_browser._render_list(true)
	_update()

func _select_track(entry: Dictionary) -> void:
	if _submitting or results_only: return
	if locked_result() and _active_slot == 0: _show_notice("The opening track is fixed to your finished race."); return
	for index: int in range(_chosen_entries.size()):
		if index != _active_slot and str(_chosen_entries[index].get("track_id",_chosen_entries[index].version_id)) == str(entry.get("track_id",entry.version_id)):
			_show_notice("Choose a different track for each slot.")
			return
	if _active_slot < _chosen_entries.size(): _chosen_entries[_active_slot] = entry.duplicate(true)
	else: _chosen_entries.append(entry.duplicate(true))
	if _chosen_entries.size() < _required_tracks(): _active_slot = _chosen_entries.size()
	_source.clear()
	_refresh_tracks()

func _build_cars() -> void:
	_car_stage = Control.new()
	_car_stage.name = "ChallengeCarHero"
	_car_stage.custom_minimum_size.y = 180
	_car_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_car_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_car_page.add_child(_car_stage)
	_car_scroll = preload("res://ui/track_carousel.gd").new()
	_car_scroll.name = "ChallengeCarCarousel"
	_car_scroll.custom_minimum_size.y = 140
	_car_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_car_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_car_scroll.follow_focus = false
	_car_scroll.resized.connect(_layout_car_cards)
	_car_page.add_child(_car_scroll)
	# The shared carousel animates its inner row, beneath the scroll-owned strip.
	var strip := Control.new()
	strip.name = "ChallengeCarStrip"
	strip.custom_minimum_size.y = 140
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_car_scroll.add_child(strip)
	var cards := HBoxContainer.new()
	cards.name = "ChallengeCarRow"
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation",12)
	strip.add_child(cards)
	for id: String in VehicleCatalog.IDS:
		var card := _button(cards,"",_select_car.bind(id),"ChallengeCar_"+id)
		card.tooltip_text = VehicleCatalog.title(id)
		card.custom_minimum_size = Vector2(216,140)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.clip_contents = true
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation",0)
		MenuStyle.fill(content)
		card.add_child(content)
		var art := Control.new()
		art.name = "ChallengeCarModelSlot_"+id
		art.custom_minimum_size.y = 100
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(art)
		var title := MenuStyle.label(VehicleCatalog.title(id),21)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(title)
		_car_cards.append(card)

func _car_model(id: String) -> CarShowroom:
	var model := CarShowroom.new()
	model.name = "ChallengeCarModel_"+id
	model.vehicle_id = id
	model.read_only = true
	model.garage_mode = true
	model.framing_scale = 0.84
	var settings: Dictionary = records.settings if records != null else {}
	model.livery = VehicleLivery.for_car(settings,id)
	model.customisation = VehicleCustomisation.for_car(settings,id)
	model.condition = VehicleCondition.read(records,id)
	return model

func _update_car_models() -> void:
	# Prepare menu worlds only on the car step; unchanged source checks reuse them.
	if _step != CAR: return
	var id: String = _vehicle_id()
	if _car_art == null:
		_car_art = _car_model(id)
		_car_art.framing_scale = 0.96
		_car_stage.add_child(_car_art)
		MenuStyle.fill(_car_art)
	elif _car_art.vehicle_id != id:
		var settings: Dictionary = records.settings if records != null else {}
		_car_art.replace_car(id,VehicleLivery.for_car(settings,id),VehicleCondition.read(records,id),VehicleCustomisation.for_car(settings,id))
	if locked_result() or not _car_models.is_empty(): return
	for index: int in range(_car_cards.size()):
		var car_id: String = VehicleCatalog.IDS[index]
		var slot: Control = _car_cards[index].find_child("ChallengeCarModelSlot_"+car_id,true,false)
		var model: CarShowroom = _car_model(car_id)
		slot.add_child(model)
		MenuStyle.fill(model)
		_car_models[car_id] = model

func _select_car(id: String) -> void:
	if locked_result() or _submitting: return
	_chosen_car = VehicleCatalog.valid_id(id)
	_check_source()

func _open_rules() -> void:
	if _submitting or results_only: return
	_rules_return = _step
	_draft_rules = {"mode":mode,"duration":duration,"tries":attempt_limit,"visibility":adapter.creation_visibility,"tracks":custom_track_count}
	for child: Node in _rules_fields.get_children(): _rules_fields.remove_child(child); child.queue_free()
	_rule_choices("Who's racing?",[[0,"One-to-one"],[1,"Group race"]],"mode","ChallengeCustomMode_")
	_rule_choices("Number of tracks",[[1,"1"],[2,"2"],[3,"3"],[4,"4"],[5,"5"]],"tracks","ChallengeTrackCount_")
	_rule_choices("Challenge duration",[[86400,"24 hours"],[259200,"3 days"],[604800,"7 days"]],"duration","ChallengeDuration_")
	_rule_choices("Tries per track",[[0,"Unlimited"],[1,"1"],[3,"3"],[5,"5"]],"tries","ChallengeTries_")
	if adapter.discovery_supported(): _rule_choices("Who can join?",[["public","Public"],["private","Invitation only"]],"visibility","ChallengeCustomVisibility_")
	_step = RULES
	_update()

func _rule_choices(caption: String, values: Array, key: String, prefix: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",MenuStyle.card(8 if results_only else 20))
	_rules_fields.add_child(panel)
	var fields := BoxContainer.new()
	fields.vertical = not results_only or size.x < 650
	fields.add_theme_constant_override("separation",8 if results_only else 16)
	fields.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_child(fields)
	var label := MenuStyle.label(caption,22 if results_only else 26)
	fields.add_child(label)
	if results_only:
		_result_rule_rows.append(fields)
		label.custom_minimum_size.x = 180 if size.x >= 650 else 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(row)
	for value: Array in values:
		var button := _button(row,str(value[1]),func() -> void: pass,prefix+str(value[0]))
		button.set_meta("rule_value",value[0])
		button.custom_minimum_size.y = 52 if results_only else 56
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			if _submitting or adapter.scope() != _source_scope: return
			_draft_rules[key] = value[0]
			for peer: Node in row.get_children(): _selection(peer as Button,peer.get_meta("rule_value") == _draft_rules[key])
			if results_only:
				mode = int(_draft_rules.mode)
				duration = int(_draft_rules.duration)
				attempt_limit = int(_draft_rules.tries)
				selected_format = "duel" if mode == 0 else "group"
				_update())
		_selection(button,_draft_rules[key] == value[0])

func _dismiss_rules() -> void:
	if _step != RULES: return
	_draft_rules.clear()
	_step = _rules_return
	_update()

func _commit_rules() -> void:
	if adapter.scope() != _source_scope or _submitting: return
	mode = int(_draft_rules.mode)
	duration = int(_draft_rules.duration)
	attempt_limit = int(_draft_rules.tries)
	adapter.creation_visibility = str(_draft_rules.visibility)
	selected_format = "custom"
	custom_track_count = int(_draft_rules.tracks)
	if _chosen_entries.size() > custom_track_count: _chosen_entries.resize(custom_track_count)
	_active_slot = 0
	_draft_rules.clear()
	_step = CAR if _rules_return == CAR and _chosen_entries.size() == _required_tracks() else TRACKS
	if _step == TRACKS: _ensure_browser()
	_refresh_tracks()
	if _step == CAR: _check_source()

func _build_actions() -> void:
	var panel := PanelContainer.new()
	panel.name = "ChallengeCreateActions"
	panel.add_theme_stylebox_override("panel",MenuStyle.card(14))
	add_child(panel)
	_action_layout = BoxContainer.new()
	_action_layout.add_theme_constant_override("separation",16)
	panel.add_child(_action_layout)
	var summary := HBoxContainer.new()
	summary.name = "ChallengeRuleSummary"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation",12)
	_action_layout.add_child(summary)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation",3)
	summary.add_child(copy)
	_rule_title = MenuStyle.label("",13,true)
	copy.add_child(_rule_title)
	_rule_details = MenuStyle.label("",17)
	_rule_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_rule_details)
	_tries_note = MenuStyle.label("Each start uses a try, including restarts.",12,true)
	_tries_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_tries_note)
	var source_time := HBoxContainer.new()
	source_time.name = "ChallengeTimeSource"
	source_time.custom_minimum_size.y = 24
	source_time.add_theme_constant_override("separation",12)
	copy.add_child(source_time)
	_summary_time = MenuStyle.label("",16,true)
	source_time.add_child(_summary_time)
	_time = MenuStyle.label("",20)
	_time.name = "ChallengeFinishedTime"
	_time.add_theme_color_override("font_color",MenuStyle.ACCENT)
	source_time.add_child(_time)
	_rules_button = _button(summary,"Edit rules  ›",_open_rules,"ChallengeAdjustRules")
	_rules_button.add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT,4))
	var actions := BoxContainer.new()
	_final_actions = actions
	actions.add_theme_constant_override("separation",12)
	_action_layout.add_child(actions)
	_race = _button(actions,"Race to set a time",_race_to_set,"RaceToSetChallenge",true)
	_share = _button(actions,"Create & share",func() -> void: _create(false),"ChallengeCreateAndShare")
	_create_button = _button(actions,"Next",_advance,"ConfirmChallengeCreate",true)
	for button: Button in [_race,_share,_create_button]: button.custom_minimum_size = Vector2(210,60)

func _advance() -> void:
	if _create_button.disabled: return
	if _step == RESULT: _create(false)
	elif _step == FORMAT:
		_step = TRACKS
		if locked_result() and _required_tracks() > 1: _active_slot = 1
		_ensure_browser()
		_refresh_tracks()
	elif _step == TRACKS:
		_step = CAR
		_check_source()
	elif _step == RULES: _commit_rules()
	else: _create(mode == 1)
	_update()

func _back() -> void:
	if _submitting: return
	if results_only: close()
	elif _step == RULES: _dismiss_rules()
	elif _step == CAR: _step = TRACKS; _ensure_browser(); _update()
	elif _step == TRACKS: _step = FORMAT; _update()
	else: close()

func _choose_format(key: String) -> void:
	if _submitting or results_only or not FORMAT_TITLES.has(key): return
	if key == "custom": _open_rules(); return
	selected_format = key
	mode = 0 if key == "duel" else 1
	attempt_limit = 3 if key == "three" else 0
	if _chosen_entries.size() > _required_tracks(): _chosen_entries.resize(_required_tracks())
	_active_slot = mini(_active_slot,_required_tracks()-1)
	_refresh_tracks()

func _check_source() -> void:
	_serial += 1
	var serial: int = _serial
	_source.clear()
	_checking = false
	if _entry().is_empty() or (selected_format == "three" and not locked_result()): _update(); return
	if adapter.scope() != _source_scope:
		_source = {"status":"unavailable","error":"Sign in again to create this challenge."}
		_update()
		return
	_checking = true
	_update()
	var source: Dictionary = await adapter.source(str(_entry().version_id),_vehicle_id(),initial_ticket if locked_result() else "")
	if not is_instance_valid(self) or serial != _serial: return
	_checking = false
	_source = source
	_next_check = Time.get_ticks_msec()+3000
	_update()

func _update() -> void:
	if _create_button == null: return
	if results_only:
		_update_result()
		return
	_format_page.visible = _step == FORMAT
	_track_page.visible = _step == TRACKS
	_car_page.visible = _step == CAR
	_custom_page.visible = _step == RULES
	_heading.text = "CHOOSE YOUR CHALLENGE" if _step == FORMAT else "CUSTOM CHALLENGE" if _step == RULES else "CHOOSE YOUR CAR" if _step == CAR else "CHOOSE THREE TRACKS" if selected_format == "three" else "CHOOSE YOUR TRACKS" if _required_tracks() > 1 else "CHOOSE YOUR TRACK"
	var current: bool = adapter.scope() == _source_scope
	var verified: bool = _source.get("status") == "verified"
	var ready: bool = _chosen_entries.size() == _required_tracks()
	_create_button.disabled = _submitting or not current or (_step in [TRACKS,CAR] and not ready)
	if _step == CAR:
		_create_button.disabled = _create_button.disabled or ((locked_result() or mode == 0) and (_checking or not verified)) or ((_required_tracks() > 1) and not (adapter.series_supported() if selected_format == "three" else adapter.custom_tracks_supported()))
	var personal_best: bool = _step == CAR and not locked_result() and selected_format != "three" and verified
	_create_button.text = "Next" if _step != CAR else "Create & race" if mode == 1 else "Create & share" if locked_result() else "Use personal best"
	_create_button.icon = MenuIcon.texture("arrow") if _step != CAR or mode == 1 else MenuIcon.texture("share")
	_create_button.add_theme_color_override("icon_normal_color",MenuStyle.INK)
	_create_button.add_theme_color_override("icon_hover_color",MenuStyle.INK)
	_race.visible = _step == CAR and not locked_result() and mode == 0 and ready
	_race.text = "Race again" if verified else "Race to set a time"
	_race.disabled = _submitting or not current or _checking
	_create_button.visible = true
	_share.visible = _step == CAR and mode == 1
	_share.text = "Use personal best" if personal_best or (_checking and not locked_result()) else "Create & share"
	_share.disabled = _create_button.disabled or (_checking and not locked_result())
	_close_button.disabled = _submitting
	_rules_button.visible = _step == CAR and selected_format != "three"
	_rules_button.disabled = _submitting
	_custom_button.disabled = _submitting
	var total: float = float(result_context.get("total",0.0)) if locked_result() else 0.0
	if verified: total = float(_source.get("ms",0))/1000.0
	_time.text = MenuStyle.time_text(total) if total > 0 else ""
	_time.visible = _step == CAR and not _time.text.is_empty()
	_summary_time.text = "Your exact finish time" if locked_result() else "Personal best" if personal_best or mode == 0 else "Fastest time wins"
	_summary_time.visible = _time.visible
	_summary_time.get_parent().visible = _step == CAR and (locked_result() or selected_format != "three")
	_update_car_models()
	_car_scroll.visible = not locked_result()
	for index: int in range(_car_cards.size()): _selection(_car_cards[index],VehicleCatalog.IDS[index] == _vehicle_id())
	for card: FormatCard in _format_buttons:
		card.chosen = selected_format == card.format_id
		card.disabled = _submitting
		card.refresh()
	GameText.bind_upper(_rule_title,"Custom challenge" if _step == RULES else FORMAT_TITLES[selected_format])
	var days: String = tr("24 hours" if duration == 86400 else "3 days" if duration == 259200 else "7 days")
	var tries: String = tr("Unlimited tries") if attempt_limit == 0 else GameText.plural("{count} try per driver","{count} tries per driver",attempt_limit)
	_rule_details.text = {"duel":"One rival. Your time to beat.  ·  Unlimited tries","group":"One track. The whole crew.  ·  Unlimited tries","three":"Three tracks. Three tries on each.  ·  Lowest total time wins","custom":"Your format, your rules."}[selected_format]
	if _step == TRACKS:
		GameText.bind(_rule_details,"{selected} / {count} track selected",{"selected":_chosen_entries.size()},"{selected} / {count} tracks selected",_required_tracks())
		if _required_tracks() == 1 and not _entry().is_empty(): GameText.bind(_rule_details,"{title}",{"title":str(_entry().name)})
	elif _step == CAR:
		if _required_tracks() > 1: tries = GameText.plural("{count} try on each track","{count} tries on each track",3 if selected_format == "three" else attempt_limit) if selected_format == "three" or attempt_limit > 0 else tr("Unlimited tries")
		var rules: String = GameText.message("{duration} · {tries} · {scoring}",{"duration":days,"tries":tries,"scoring":tr("Lowest total time wins" if _required_tracks() > 1 else "Best time wins")})
		if adapter.discovery_supported(): rules = GameText.message("{rules} · {visibility}",{"rules":rules,"visibility":tr("Public" if adapter.creation_visibility == "public" else "Invitation only")})
		GameText.bind(_rule_details,"{rules}",{"rules":rules})
	elif _step == RULES: GameText.bind(_rule_details,"Choose your rules, then your track and car.")
	else: GameText.bind(_rule_details,{"duel":"One rival. Your time to beat.  ·  Unlimited tries","group":"One track. The whole crew.  ·  Unlimited tries","three":"Three tracks. Three tries on each.  ·  Lowest total time wins","custom":"Your format, your rules."}[selected_format])
	_tries_note.visible = _step == CAR and attempt_limit > 0
	_notice.text = ""
	if not current: _notice.text = "Sign in again to create this challenge."
	elif _submitting: _notice.text = "Creating…"
	elif _step == CAR:
		if _checking: _notice.text = "Verifying result…" if locked_result() else ""
		elif _source.get("status") in ["queued","verifying"]: _notice.text = "Verifying result…" if locked_result() else ""
		elif _source.has("error"): _notice.text = str(_source.error)
		elif locked_result() and not verified: _notice.text = "This result was not verified."
		if _required_tracks() > 1 and not (adapter.series_supported() if selected_format == "three" else adapter.custom_tracks_supported()): _notice.text = "Multi-track challenges need the updated online service."
	_retry.visible = _step == CAR and _source.get("status") == "unavailable" and not _checking and not _submitting
	_notice.visible = not _notice.text.is_empty()
	_status.visible = _notice.visible or _retry.visible

func _update_result() -> void:
	_format_page.hide()
	_track_page.hide()
	_car_page.hide()
	_custom_page.show()
	_heading.text = "CREATE CHALLENGE"
	var current: bool = adapter.scope() == _source_scope
	var verified: bool = _source.get("status") == "verified"
	_create_button.text = "Create & share"
	_create_button.icon = MenuIcon.texture("share")
	_create_button.disabled = _submitting or not current or _checking or not verified or _entry().is_empty()
	_share.hide()
	_race.hide()
	_rules_button.hide()
	_close_button.disabled = _submitting
	for button: Node in _rules_fields.find_children("*","Button",true,false):
		(button as Button).disabled = _submitting or not current
	GameText.bind(_rule_title,"{title}",{"title":str(_entry().get("name",""))})
	GameText.bind(_rule_details,VehicleCatalog.title(_vehicle_id()))
	var total: float = float(result_context.get("total",0.0))
	if verified: total = float(_source.get("ms",0))/1000.0
	_time.text = MenuStyle.time_text(total) if total > 0 else ""
	_time.visible = not _time.text.is_empty()
	_summary_time.text = "Your finished time"
	_summary_time.visible = _time.visible
	_summary_time.get_parent().show()
	_tries_note.visible = attempt_limit > 0
	_notice.text = ""
	if not current: _notice.text = "Sign in again to create this challenge."
	elif _submitting: _notice.text = "Creating…"
	elif _checking or _source.get("status") in ["queued","verifying"]: _notice.text = "Verifying result…"
	elif _source.has("error"): _notice.text = str(_source.error)
	elif not verified: _notice.text = "This result was not verified."
	_retry.visible = current and _source.get("status") == "unavailable" and not _checking and not _submitting
	_notice.visible = not _notice.text.is_empty()
	_status.visible = _notice.visible or _retry.visible

func _show_notice(message: String) -> void:
	_notice.text = message
	_notice.show()
	_status.show()

func _selection(button: Button, chosen: bool) -> void:
	var style := MenuStyle.box(Color("172d3b"),8)
	style.border_color = MenuStyle.ACCENT if chosen else MenuStyle.BORDER
	style.set_border_width_all(2 if chosen else 1)
	button.add_theme_stylebox_override("normal",style)
	button.add_theme_color_override("font_color",MenuStyle.ACCENT if chosen else MenuStyle.TEXT)
	button.disabled = _submitting

func _layout_cards() -> void:
	if _formats == null: return
	_formats.columns = 3 if size.x >= 720 else 1
	_slot_row.columns = _required_tracks() if size.x >= 720 else mini(2,_required_tracks())
	_rules_fields.columns = 1 if results_only else 2 if size.x >= 850 else 1
	for row: BoxContainer in _result_rule_rows:
		row.vertical = size.x < 650
		(row.get_child(0) as Control).custom_minimum_size.x = 0 if row.vertical else 180
	_action_layout.vertical = size.x < (650 if results_only else 850)
	_final_actions.vertical = size.x < 560
	for button: Button in [_race,_share,_create_button]: button.custom_minimum_size.x = 180 if size.x < 1100 else 210
	_layout_car_cards()

func _layout_car_cards() -> void:
	if _car_scroll == null or _car_scroll.size.x <= 0: return
	var slots: int = clampi(floori((_car_scroll.size.x+12.0)/228.0),1,VehicleCatalog.IDS.size())
	var stride: float = (_car_scroll.size.x+12.0)/slots
	var usable: int = floori(_car_scroll.size.x)-12*(slots-1)
	var width: int = floori(float(usable)/slots)
	var remainder: int = usable-width*slots
	_car_scroll.call("_stop_snap")
	_car_scroll.set("snap_stride",roundi(stride))
	var total_width: int = 12*maxi(0,_car_cards.size()-1)
	for index: int in range(_car_cards.size()):
		var card_width: int = width+(1 if index%slots < remainder else 0)
		_car_cards[index].custom_minimum_size.x = card_width
		total_width += card_width
	var strip: Control = _car_scroll.get_child(0)
	strip.custom_minimum_size.x = total_width
	(strip.get_child(0) as Control).size = Vector2(total_width,140)

func _create(and_race: bool = false) -> void:
	if _step not in [CAR,RESULT] or _create_button.disabled or _submitting: return
	start_after_create = and_race and mode == 1 and not results_only
	_submitting = true
	_update()
	if adapter.discovery_supported() and adapter.creation_visibility == "public":
		if not await preload("res://ui/community_safety_ui.gd").ensure_terms(self,adapter.client):
			_submitting = false
			_update()
			_show_notice("Accept the public sharing rules to list this challenge.")
			return
		if adapter.scope() != _source_scope:
			_submitting = false
			_update()
			return
	var payload: Dictionary = {"version_id":str(_entry().version_id),"vehicle_id":_vehicle_id(),"mode":"3x3" if selected_format == "three" else "group" if mode == 1 else "beat","duration_seconds":duration}
	if _required_tracks() > 1:
		payload.version_ids = []
		for entry: Dictionary in _chosen_entries: payload.version_ids.append(str(entry.version_id))
	if adapter.discovery_supported(): payload.visibility = adapter.creation_visibility
	if attempt_limit > 0: payload.attempt_limit = attempt_limit
	if locked_result():
		if initial_ticket.is_empty():
			_submitting = false
			_source = {"status":"unavailable","error":"Could not recover this result."}
			_update()
			return
		payload.source_ticket_id = initial_ticket
	elif not and_race and selected_format != "three" and _source.get("status") == "verified": payload.source_run_id = str(_source.run_id)
	await adapter.create_challenge(payload)
	if not is_instance_valid(self): return
	_submitting = false
	if adapter.error.is_empty() and not adapter.selected.is_empty():
		hide()
		if created_callback.is_valid(): created_callback.call()
	else:
		_update()
		_show_notice(adapter.error)

func _race_to_set() -> void:
	if _step != CAR or locked_result() or _entry().is_empty() or _submitting or adapter.scope() != _source_scope: return
	hide()
	race_to_set_requested.emit(_entry(),_vehicle_id(),duration,attempt_limit,{"mode":mode,"format":selected_format,"tracks":_chosen_entries.duplicate(true),"track_count":custom_track_count,"step":CAR})

func popup_centered(_size: Vector2i = Vector2i.ZERO) -> void: show(); set_process_input(true)
func get_ok_button() -> Button: return _create_button
func close() -> void:
	if _submitting: return
	_serial += 1
	hide()
	set_process_input(false)
	canceled.emit()

func _input(event: InputEvent) -> void:
	if _browser != null and ((_browser.filter_dialog != null and _browser.filter_dialog.visible) or (_browser.search_dialog != null and _browser.search_dialog.visible)): return
	if visible and event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if visible and not _checking and not _submitting and (locked_result() or _step == CAR) and _source.get("status") in ["not_set","queued","verifying","unavailable"]:
		if (locked_result() or _source.get("status") != "not_set") and Time.get_ticks_msec() >= _next_check: _check_source()

func _exit_tree() -> void:
	if adapter != null: adapter.client.cancel_public_reads(get_instance_id())

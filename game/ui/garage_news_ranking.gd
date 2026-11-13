extends VBoxContainer
## One published page, read only while the newspaper's ranking section is open.
const Adapter = preload("res://backend/world_ranking_client.gd")
const SCOPES: Array[String] = ["world","country","friends","season"]
var newspaper: Control
var client: Node
var _adapter: Node
var _scope: String = ""
var _request: int = 0
var _busy: bool = false
var _cursor: String = ""
var _next: String = ""
var _history: Array[String] = []
var _around: bool = false
var summary: Label
var status: Label
var rows: VBoxContainer
var selector: OptionButton
var car_selector: OptionButton
var vehicle_id: String = "overall"
var _profile_data: Dictionary = {}
var circuit: Button
var previous: Button
var next: Button
var around: Button
var details: Button

func _ready() -> void:
	name = "NewspaperWorldRanking"
	add_theme_constant_override("separation",2)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",8)
	add_child(heading)
	summary = newspaper._text(heading,"World Ranking",22,newspaper.INK,true)
	summary.name = "NewspaperRankingSummary"
	var actions: HFlowContainer = newspaper._ranking_footer
	selector = OptionButton.new()
	selector.name = "NewspaperRankingScope"
	selector.custom_minimum_size.y = 52
	_style_scope_selector()
	for caption: String in ["World","Country","Friends","Season"]: selector.add_item(caption)
	selector.item_selected.connect(func(_index: int) -> void:
		_cursor = ""
		_history.clear()
		_around = false
		_load_page())
	actions.add_child(selector)
	car_selector = OptionButton.new()
	car_selector.name = "NewspaperRankingCar"
	car_selector.custom_minimum_size.y = 52
	car_selector.add_item("Overall")
	for car: String in VehicleCatalog.IDS: car_selector.add_item(VehicleCatalog.title(car))
	car_selector.visible = Adapter.multi_supported(client)
	car_selector.item_selected.connect(func(index: int) -> void:
		vehicle_id = "overall" if index == 0 else VehicleCatalog.IDS[index-1]
		_cursor = ""
		_history.clear()
		_around = false
		refresh())
	_style_scope_selector(car_selector)
	heading.add_child(car_selector)
	circuit = newspaper._button("Compact Circuit",func() -> void:
		if _active() and Adapter.circuit_open(client):
			if _circuit_car().is_empty(): return
			_adapter.circuit_vehicle = _circuit_car()
			_adapter.circuit_requested.emit())
	circuit.name = "WorldCircuitEntry"
	actions.add_child(circuit)
	details = newspaper._button("Details",func() -> void:
		if _active(): preload("res://ui/world_ranking.gd").open(self,client,"",vehicle_id))
	details.name = "NewspaperRankingResults"
	actions.add_child(details)
	newspaper._rule(self,2)
	var titles: HBoxContainer = _line()
	titles.custom_minimum_size.y = 28
	_cell(titles,"POS.",80)
	_cell(titles,"DRIVER")
	status = newspaper._text(titles,"Loading published ranking…",16,newspaper.MUTED)
	status.name = "NewspaperRankingStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cell(titles,"POINTS",85)
	rows = VBoxContainer.new()
	rows.name = "NewspaperRankingRows"
	rows.add_theme_constant_override("separation",0)
	add_child(rows)
	previous = newspaper._button("Previous",_previous)
	next = newspaper._button("Next",_forward)
	around = newspaper._button("Near me",func() -> void:
		_around = not _around
		_cursor = ""
		_history.clear()
		_load_page())
	for button: Button in [previous,next,around]: actions.add_child(button)
	if is_instance_valid(client):
		_adapter = Adapter.for_client(client)
		if client.has_signal("identity_changed"): client.identity_changed.connect(_invalidate)
		if is_instance_valid(client.get("safety")): client.safety.changed.connect(_invalidate)
	visibility_changed.connect(func() -> void:
		if not _active(): _invalidate())
	_controls()
	refresh.call_deferred()

func _style_scope_selector(control: OptionButton = null) -> void:
	var target: OptionButton = control if control != null else selector
	# Style the closed control in every state before it enters the tree. Loading
	# temporarily disables it, so that state must use the same paper and ink.
	target.add_theme_font_override("font",MenuStyle.DISPLAY)
	target.add_theme_font_size_override("font_size",21)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color","font_disabled_color"]:
		target.add_theme_color_override(state,newspaper.INK)
	target.add_theme_stylebox_override("normal",newspaper._box(Color("e3dbc6")))
	target.add_theme_stylebox_override("disabled",newspaper._box(Color("e3dbc6")))
	target.add_theme_stylebox_override("hover",newspaper._box(Color("d8cfb8")))
	target.add_theme_stylebox_override("pressed",newspaper._box(Color("d0c6ad")))
	var focus: StyleBoxFlat = newspaper._box(Color.TRANSPARENT)
	focus.border_color = newspaper.RED
	focus.set_border_width_all(2)
	target.add_theme_stylebox_override("focus",focus)
	target.add_theme_constant_override("modulate_arrow",1)
	var popup: PopupMenu = target.get_popup()
	# App's global popup watcher runs when the selector is attached. Mark this
	# popup first so it keeps its newspaper chrome rather than the dark menu.
	popup.set_meta("menu_popup_custom",true)
	var paper: StyleBoxFlat = newspaper._box(Color("eee7d4"),10)
	paper.border_color = Color("8a8675")
	paper.set_border_width_all(1)
	paper.shadow_color = Color(0,0,0,0.25)
	paper.shadow_size = 6
	popup.add_theme_stylebox_override("panel",paper)
	popup.add_theme_stylebox_override("hover",newspaper._box(Color("d8cfb8"),6))
	popup.add_theme_font_override("font",MenuStyle.DISPLAY)
	popup.add_theme_font_size_override("font_size",21)
	popup.add_theme_color_override("font_color",newspaper.INK)
	popup.add_theme_color_override("font_hover_color",newspaper.INK)
	popup.add_theme_color_override("font_disabled_color",newspaper.MUTED)
	popup.add_theme_color_override("font_accelerator_color",newspaper.MUTED)
	popup.add_theme_constant_override("v_separation",26)
	popup.about_to_popup.connect(_fit_scope_popup.bind(target).call_deferred)

func _fit_scope_popup(target: OptionButton) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree(): return
	var popup: PopupMenu = target.get_popup()
	if not popup.visible: return
	var window: Window = target.get_window()
	if window == null or not window.gui_embed_subwindows: return
	var limit: Vector2i = window.size-popup.size-Vector2i(8,8)
	popup.position = Vector2i(clampi(popup.position.x,8,maxi(8,limit.x)),clampi(popup.position.y,8,maxi(8,limit.y)))

func _active() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and newspaper._active() and newspaper._tab == "ranking"

func _valid(request: int) -> bool:
	return _active() and request == _request and is_instance_valid(client) and client.signed_in() and _scope == _adapter.scope()

func _invalidate() -> void:
	_request += 1
	_busy = false
	_profile_data.clear()
	_clear()
	summary.text = "World Ranking"
	status.text = "Refresh to load the current ranking."
	_next = ""
	_history.clear()
	_controls()

func _controls() -> void:
	var available: bool = is_instance_valid(client) and client.signed_in() and Adapter.supported(client)
	selector.disabled = _busy or not available
	car_selector.disabled = _busy or not available
	circuit.disabled = not available or not Adapter.circuit_open(client) or _circuit_car().is_empty()
	if Adapter.multi_supported(client): circuit.text = GameText.message("Circuit preparing") if _circuit_car().is_empty() else GameText.message("%s Circuit") % VehicleCatalog.title(_circuit_car())
	if Adapter.multi_supported(client): newspaper._status.text = GameText.message("All cars").to_upper() if vehicle_id == "overall" else (GameText.message("%s Circuit") % VehicleCatalog.title(vehicle_id)).to_upper()
	previous.disabled = _busy or _history.is_empty() or not available
	next.disabled = _busy or _next.is_empty() or _history.size() >= 8 or not available
	around.disabled = _busy or not available
	around.text = "Top" if _around else "Near me"
	details.disabled = not available

func _circuit_car() -> String:
	if not Adapter.multi_supported(client): return "compact"
	var preferred: String = vehicle_id if vehicle_id != "overall" else VehicleCatalog.selected
	var available: Array = _profile_data.get("circuit_cars",VehicleCatalog.IDS)
	return preferred if preferred in available else str(available[0]) if vehicle_id == "overall" and not available.is_empty() else ""

func refresh() -> void:
	if not _active() or _busy: return
	_controls()
	if not is_instance_valid(client) or not client.signed_in():
		_clear()
		summary.text = "World Ranking"
		status.text = "Sign in to see World Ranking."
		return
	if not Adapter.supported(client):
		_clear()
		summary.text = "World Ranking"
		status.text = "World Ranking is unavailable on this server."
		return
	_scope = _adapter.scope()
	_busy = true
	_request += 1
	var request: int = _request
	_controls()
	var response: Dictionary = await _adapter.profile("",true,vehicle_id)
	if not _valid(request): return
	_busy = false
	if response.ok:
		var data: Dictionary = response.data
		_profile_data = data
		summary.text = GameText.message("World #%d · %d points") % [int(data.world_rank),int(data.points)] if data.get("world_rank") != null else "World Ranking"
		if data.get("movement") != null: summary.text += GameText.message(" · %+d places") % int(data.movement)
		if Adapter.multi_supported(client):
			if vehicle_id != "overall": summary.text = VehicleCatalog.title(vehicle_id)+" · "+summary.text
	else: summary.text = "World Ranking"
	_cursor = ""
	_history.clear()
	_load_page()

func _load_page() -> void:
	if not _active() or _busy or not is_instance_valid(client) or not client.signed_in() or not Adapter.supported(client): return
	_scope = _adapter.scope()
	_busy = true
	_request += 1
	var request: int = _request
	_next = ""
	_clear()
	_controls()
	status.text = "Loading published ranking…"
	var endpoint: String = "/ranking?scope="+SCOPES[selector.selected]
	if Adapter.multi_supported(client): endpoint += "&vehicle_id="+vehicle_id.uri_encode()
	if not _cursor.is_empty(): endpoint += "&cursor="+_cursor.uri_encode()
	if _around: endpoint += "&around=true"
	var response: Dictionary = await client.request_api(endpoint,HTTPClient.METHOD_GET,{},"",true)
	if not _valid(request): return
	if not response.ok or not Adapter.valid_page(response.data) or (response.data.get("policy") == "multi-car-circuit-v2" and response.data.get("car") != vehicle_id):
		_busy = false
		status.text = "Ranking unavailable. Refresh to retry."
		_controls()
		return
	var data: Dictionary = response.data
	_next = str(data.next_cursor)
	status.text = GameText.message("Published %s UTC") % Time.get_date_string_from_unix_time(int(data.get("published_at",0)))
	if data.get("state") == "not_started":
		status.text = "Complete five weekly Circuit tracks with a car to earn its ranking."
		if int(data.get("launch_week",0)) > 0: status.text = GameText.message("Circuit opens %s UTC.") % Time.get_date_string_from_unix_time(int(data.launch_week))
	elif data.get("state") == "country_required": status.text = "Choose your country in your account profile."
	elif data.items.is_empty(): status.text = "No ranked drivers in this view yet."
	for index: int in range(data.items.size()):
		var row: Dictionary = data.items[index]
		var line: HBoxContainer = _line(rows)
		_cell(line,"#%d" % int(row.rank),80)
		var identity: Label = _cell(line,str(row.name))
		_cell(line,str(int(row.get("season_points",0)) if selector.selected == 3 else int(row.points)),85)
		if str(row.player_id) == str(client.player.get("id","")): identity.add_theme_color_override("font_color",newspaper.RED)
		if not str(row.player_id).is_empty():
			preload("res://ui/player_profile.gd").bind_name(identity,_open_player.bind(row))
		if (index+1)%10 == 0:
			await get_tree().process_frame
			if not _valid(request): return
	_busy = false
	_controls()

func _open_player(row: Dictionary) -> void:
	if _active(): preload("res://ui/player_profile.gd").open(self,client,{"id":row.player_id,"name":row.name,"country_code":row.get("country","")},vehicle_id if vehicle_id != "overall" else VehicleCatalog.selected)

func _line(parent: Node = null) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.custom_minimum_size.y = 44
	line.add_theme_constant_override("separation",10)
	(parent if parent != null else self).add_child(line)
	return line

func _cell(line: Control, value: String, width: int = 0) -> Label:
	var label: Label = newspaper._text(line,value,19,newspaper.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = width
	if width > 0: label.size_flags_horizontal = Control.SIZE_FILL
	return label

func _clear() -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if is_instance_valid(newspaper._scroll): newspaper._scroll.scroll_vertical = 0

func _forward() -> void:
	if _busy or _next.is_empty() or _history.size() >= 8: return
	_history.append(_cursor)
	_cursor = _next
	_load_page()

func _previous() -> void:
	if _busy or _history.is_empty(): return
	_cursor = _history.pop_back()
	_load_page()

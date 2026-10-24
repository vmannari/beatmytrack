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
var circuit: Button
var previous: Button
var next: Button
var around: Button
var details: Button

func _ready() -> void:
	name = "NewspaperWorldRanking"
	add_theme_constant_override("separation",4)
	summary = newspaper._text(self,"World Ranking",22,newspaper.INK,true)
	summary.name = "NewspaperRankingSummary"
	var actions: HFlowContainer = newspaper._ranking_footer
	selector = OptionButton.new()
	selector.name = "NewspaperRankingScope"
	selector.custom_minimum_size.y = 52
	selector.add_theme_color_override("font_color",newspaper.INK)
	selector.add_theme_stylebox_override("normal",newspaper._box(Color("e3dbc6")))
	for caption: String in ["World","Country","Friends","Season"]: selector.add_item(caption)
	selector.item_selected.connect(func(_index: int) -> void:
		_cursor = ""
		_history.clear()
		_around = false
		_load_page())
	actions.add_child(selector)
	circuit = newspaper._button("Compact Circuit",func() -> void:
		if _active() and Adapter.circuit_open(client): _adapter.circuit_requested.emit())
	circuit.name = "WorldCircuitEntry"
	actions.add_child(circuit)
	details = newspaper._button("Details",func() -> void:
		if _active(): preload("res://ui/world_ranking.gd").open(self,client))
	details.name = "NewspaperRankingResults"
	actions.add_child(details)
	status = newspaper._text(self,"Loading published ranking…",16,newspaper.MUTED)
	status.name = "NewspaperRankingStatus"
	newspaper._rule(self,2)
	var titles: HBoxContainer = _line()
	titles.custom_minimum_size.y = 28
	_cell(titles,"POS.",80)
	_cell(titles,"DRIVER")
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
	refresh.call_deferred()

func _active() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and newspaper._active() and newspaper._tab == "ranking"

func _valid(request: int) -> bool:
	return _active() and request == _request and is_instance_valid(client) and client.signed_in() and _scope == _adapter.scope()

func _invalidate() -> void:
	_request += 1
	_busy = false
	_clear()
	summary.text = "World Ranking"
	status.text = "Refresh to load the current ranking."
	_next = ""
	_history.clear()
	_controls()

func _controls() -> void:
	var available: bool = is_instance_valid(client) and client.signed_in() and Adapter.supported(client)
	selector.disabled = _busy or not available
	circuit.disabled = not available or not Adapter.circuit_open(client)
	previous.disabled = _busy or _history.is_empty() or not available
	next.disabled = _busy or _next.is_empty() or _history.size() >= 8 or not available
	around.disabled = _busy or not available
	around.text = "Top" if _around else "Near me"
	details.disabled = not available

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
	var response: Dictionary = await _adapter.profile("",true)
	if not _valid(request): return
	_busy = false
	if response.ok:
		var data: Dictionary = response.data
		summary.text = "World #%d · %d points" % [int(data.world_rank),int(data.points)] if data.get("world_rank") != null else "World Ranking"
		if data.get("movement") != null: summary.text += " · %+d places" % int(data.movement)
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
	if not _cursor.is_empty(): endpoint += "&cursor="+_cursor.uri_encode()
	if _around: endpoint += "&around=true"
	var response: Dictionary = await client.request_api(endpoint,HTTPClient.METHOD_GET,{},"",true)
	if not _valid(request): return
	if not response.ok or not Adapter.valid_page(response.data):
		_busy = false
		status.text = "Ranking unavailable. Refresh to retry."
		_controls()
		return
	var data: Dictionary = response.data
	_next = str(data.next_cursor)
	status.text = "Published %s UTC" % Time.get_date_string_from_unix_time(int(data.get("published_at",0)))
	if data.get("state") == "not_started":
		status.text = "Complete five Compact Circuit tracks to earn a ranking."
		if int(data.get("launch_week",0)) > 0: status.text = "Circuit opens %s UTC." % Time.get_date_string_from_unix_time(int(data.launch_week))
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
	if _active(): preload("res://ui/player_profile.gd").open(self,client,{"id":row.player_id,"name":row.name,"country_code":row.get("country","")},"compact")

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

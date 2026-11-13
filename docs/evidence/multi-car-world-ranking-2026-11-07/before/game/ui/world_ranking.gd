extends AcceptDialog
## Bounded native ranking pages. Close/navigation remain available during requests.
const Adapter = preload("res://backend/world_ranking_client.gd")
var client: Node
var player_id: String = ""
var adapter: Node
var account_scope: String = ""
var summary: Label
var detail: Label
var status: Label
var list: VBoxContainer
var selector: OptionButton
var next_button: Button
var previous_button: Button
var around_button: Button
var refresh_button: Button
var _profile: Dictionary = {}
var _cursor: String = ""
var _next: String = ""
var _history: Array[String] = []
var _busy: bool = false
var _request: int = 0
var _around: bool = false
var bounds := Vector2i(920,680)
const SCOPES: Array[String] = ["world","country","friends","season","results"]

static func open(parent: Node, backend: Node, target_id: String = "") -> Node:
	var popup: Node = load("res://ui/world_ranking.gd").new()
	popup.client = backend
	popup.player_id = target_id
	popup.bounds = Vector2i(parent.get_viewport().get_visible_rect().size-Vector2(32,32)).min(Vector2i(920,680))
	parent.add_child(popup)
	popup.popup_centered(popup.bounds)
	return popup

func _ready() -> void:
	name = "WorldRanking"
	title = "World Ranking"
	theme = MenuStyle.theme()
	preload("res://ui/popup_style.gd").watch(self)
	ok_button_text = "Close"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	adapter = Adapter.for_client(client)
	account_scope = adapter.scope()
	if client.has_signal("identity_changed"):
		client.identity_changed.connect(func() -> void:
			if adapter.scope() != account_scope: queue_free())
	if is_instance_valid(client.get("safety")):
		client.safety.changed.connect(func() -> void: queue_free())
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	body.custom_minimum_size.x = maxi(240,bounds.x-64)
	var outer := ScrollContainer.new()
	outer.name = "WorldRankingBodyScroll"
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.custom_minimum_size = Vector2(maxi(240,bounds.x-64),maxi(120,bounds.y-180))
	outer.add_child(body)
	add_child(outer)
	summary = MenuStyle.label("WORLD RANKING",28)
	summary.name = "WorldRankingSummary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(summary)
	detail = MenuStyle.label("Best 12 results from 26 weeks · Compact Circuit",17,true)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail)
	selector = OptionButton.new()
	selector.name = "WorldRankingScope"
	selector.custom_minimum_size.y = 48
	for caption: String in ["World","Country","Friends","Season","My results"]: selector.add_item(caption)
	if not player_id.is_empty(): selector.set_item_text(4,"Player results")
	selector.item_selected.connect(func(_index: int) -> void:
		_cursor = ""
		_history.clear()
		_around = false
		_load_page())
	body.add_child(selector)
	var circuit: Button = MenuStyle.button("Race the weekly Compact Circuit",func() -> void:
		adapter.circuit_requested.emit()
		queue_free())
	circuit.name = "WorldCircuitEntry"
	circuit.disabled = not Adapter.circuit_open(client)
	if circuit.disabled: circuit.text = "Compact Circuit opens at the announced launch"
	circuit.custom_minimum_size.y = 48
	body.add_child(circuit)
	var scroll := ScrollContainer.new()
	scroll.name = "WorldRankingScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = maxi(90,bounds.y-480)
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.name = "WorldRankingRows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",6)
	scroll.add_child(list)
	status = MenuStyle.label("Loading published ranking…",17,true)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	var actions := GridContainer.new()
	actions.columns = 2 if bounds.x < 600 else 4
	actions.add_theme_constant_override("separation",8)
	body.add_child(actions)
	previous_button = MenuStyle.button("Previous",_previous)
	next_button = MenuStyle.button("Next",_forward)
	around_button = MenuStyle.button("Near me",func() -> void:
		_around = not _around
		_cursor = ""
		_history.clear()
		_load_page())
	refresh_button = MenuStyle.button("Refresh",_refresh)
	for button: Button in [previous_button,next_button,around_button,refresh_button]:
		button.custom_minimum_size = Vector2(0,48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	_refresh.call_deferred()

func _valid(request: int) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and _request == request and account_scope == adapter.scope()

func _controls() -> void:
	selector.disabled = _busy
	previous_button.disabled = _busy or _history.is_empty()
	next_button.disabled = _busy or _next.is_empty() or _history.size() >= 8
	around_button.disabled = _busy or selector.selected == 4
	around_button.text = "Top" if _around else "Near me"
	refresh_button.disabled = _busy

func _refresh() -> void:
	if _busy: return
	_busy = true
	_controls()
	_request += 1
	var request: int = _request
	var result: Dictionary = await adapter.profile(player_id,true)
	if not _valid(request): return
	_busy = false
	if result.ok:
		_profile = result.data
		var rank_text: String = "Unranked" if _profile.get("world_rank") == null else "#%d" % int(_profile.world_rank)
		var movement: String = ""
		if _profile.get("movement") != null and int(_profile.movement) != 0: movement = GameText.message(" · %+d places") % int(_profile.movement)
		summary.text = rank_text+GameText.message("  ·  %d POINTS") % int(_profile.points)+movement
		detail.text = GameText.message("Best 12 / 26 weeks · %d earned · %+d total · %d points at risk next week") % [int(_profile.get("earned",0)),int(_profile.get("net_change",0)),int(_profile.get("points_at_risk",0))]
	else:
		status.text = "Ranking unavailable. Refresh to retry."
		_controls()
		return
	_cursor = ""
	_history.clear()
	_load_page()

func _load_page() -> void:
	if _busy: return
	_next = ""
	if selector.selected == 4:
		_show_results()
		_controls()
		return
	_busy = true
	_controls()
	_request += 1
	var request: int = _request
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
	_clear_rows()
	var data: Dictionary = response.data
	_next = str(data.next_cursor)
	if data.get("state") == "not_started":
		status.text = "Complete the five weekly Compact Circuit tracks to earn a World Ranking."
		if int(data.get("launch_week",0)) > 0: status.text = "Circuit opens "+_date(int(data.launch_week))+" UTC. "+status.text
	elif data.get("state") == "country_required":
		status.text = "Choose your country in your account profile."
	else:
		status.text = "Published "+_date(int(data.get("published_at",0)))+GameText.message(" UTC · %d ranked drivers") % int(data.get("ranked_count",0))
		if data.items.is_empty(): status.text += " · No ranked drivers in this view yet."
	var built: int = 0
	for row: Dictionary in data.items:
		var line := HBoxContainer.new()
		line.custom_minimum_size.y = 44
		line.add_theme_constant_override("separation",10)
		list.add_child(line)
		var rank: Label = MenuStyle.label("#%d" % int(row.rank),20)
		rank.custom_minimum_size.x = 80
		line.add_child(rank)
		var identity: Label = MenuStyle.user_label(str(row.name),20)
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.clip_text = true
		line.add_child(identity)
		var score: int = int(row.get("season_points",0)) if selector.selected == 3 else int(row.points)
		line.add_child(MenuStyle.label(str(score),20))
		if str(row.get("player_id","")) == str(client.player.get("id","")): identity.modulate = MenuStyle.ACCENT
		if not str(row.get("player_id","")).is_empty():
			preload("res://ui/player_profile.gd").bind_name(identity,_open_player.bind(row))
		built += 1
		if built % 10 == 0:
			await get_tree().process_frame
			if not _valid(request): return
	_busy = false
	_controls()

func _open_player(row: Dictionary) -> void:
	preload("res://ui/player_profile.gd").open(self,client,{"id":row.player_id,"name":row.name,"country_code":row.get("country","")},"compact")

func _clear_rows() -> void:
	var scroll: ScrollContainer = list.get_parent() as ScrollContainer
	if scroll != null: scroll.scroll_vertical = 0
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()

func _show_results() -> void:
	_clear_rows()
	for row: Dictionary in _profile.get("results",[]):
		var label: Label = MenuStyle.label(GameText.message("%s · #%d · %d points · %s") % [_date(int(row.week_start)),int(row.weekly_place),int(row.points),"Counting" if row.counting else "Reserve"],18)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(label)
	var career: Dictionary = _profile.get("career",{})
	status.text = "Finish all five tracks for one weekly ranking result."
	if not career.is_empty(): status.text = GameText.message("Best #%d among %d drivers (%s) · %d weeks in Top 100 · %d weeks at No. 1 · %d Circuit wins · %d season titles") % [int(career.peak_rank),int(career.peak_field),_date(int(career.peak_week)),int(career.weeks_top100),int(career.weeks_no1),int(career.victories),int(career.season_titles)]

func _forward() -> void:
	if _busy or _next.is_empty() or _history.size() >= 8: return
	_history.append(_cursor)
	_cursor = _next
	_load_page()

func _previous() -> void:
	if _busy or _history.is_empty(): return
	_cursor = _history.pop_back()
	_load_page()

static func _date(stamp: int) -> String:
	var value: Dictionary = Time.get_datetime_dict_from_unix_time(stamp)
	return "%04d-%02d-%02d" % [int(value.year),int(value.month),int(value.day)]

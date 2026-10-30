extends VBoxContainer
signal honors_loaded(career: Dictionary)
var show_honors: bool = false
## One cached, account-fenced read when this visible menu summary is created.
const Adapter = preload("res://backend/world_ranking_client.gd")
var client: Node
var player_id: String = ""
var _scope: String = ""
var _label: Label
var _button: Button
var _adapter: Node
var _request: int = 0

func _ready() -> void:
	name = "WorldRankingSummaryBlock"
	_adapter = Adapter.for_client(client)
	_scope = _adapter.scope()
	_button = MenuStyle.button("World Ranking",func() -> void: preload("res://ui/world_ranking.gd").open(self,client,player_id))
	_button.custom_minimum_size = Vector2(140,48)
	add_child(_button)
	_label = MenuStyle.label("Published weekly · Compact Circuit",16,true)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.y = 44
	add_child(_label)
	if client.has_signal("identity_changed"): client.identity_changed.connect(_identity_changed)
	if is_instance_valid(client.get("safety")): client.safety.changed.connect(_identity_changed)
	_load.call_deferred()

func _identity_changed() -> void:
	_request += 1
	honors_loaded.emit({})
	_label.text = "Published weekly · Compact Circuit"
	if _scope != _adapter.scope():
		_button.disabled = true
		return
	if not player_id.is_empty() and is_instance_valid(client.get("safety")) and client.safety.is_blocked(player_id):
		_label.text = "Ranking hidden"
		return
	_load.call_deferred()

func _load() -> void:
	_request += 1
	var request: int = _request
	var response: Dictionary = await _adapter.profile(player_id)
	if not is_inside_tree() or is_queued_for_deletion() or request != _request or _scope != _adapter.scope(): return
	if response.ok and response.data.get("world_rank") != null:
		_label.text = "World #%d · %d points" % [int(response.data.world_rank),int(response.data.points)]
		var career: Dictionary = response.data.get("career",{})
		if not career.is_empty(): _label.text += "\nBest #%d · %d Circuit wins" % [int(career.peak_rank),int(career.victories)]
	elif response.ok and response.data.get("state") == "unranked":
		_label.text = "Unranked · Finish five Circuit tracks"
	if response.ok and show_honors:
		var career: Dictionary = response.data.get("career",{})
		honors_loaded.emit(career)
		if not career.is_empty():
			_label.text += "\n%d Top 100 weeks · %d No. 1 weeks · %d season titles" % [int(career.get("weeks_top100",0)),int(career.get("weeks_no1",0)),int(career.get("season_titles",0))]

extends VBoxContainer
## Completed-week facts only; navigation lives in the Garage newspaper.
const Adapter = preload("res://backend/world_ranking_client.gd")
var client: Node
var week_start: int = 0
var vehicle_id: String = "overall"
var compact: bool = false
var label: Label
var _adapter: Node
var _scope: String
var _request: int = 0

func _ready() -> void:
	name = "WorldRankingWeekResult"
	label = MenuStyle.label("World Ranking updating…",18,true)
	label.name = "WorldRankingWeekChange"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	_adapter = Adapter.for_client(client)
	_scope = _adapter.scope()
	if client.has_signal("identity_changed"): client.identity_changed.connect(_invalidate)
	if is_instance_valid(client.get("safety")): client.safety.changed.connect(_invalidate)
	_load.call_deferred()

func _invalidate() -> void:
	_request += 1
	label.text = "World Ranking unavailable."

static func describe(data: Dictionary, week: int) -> String:
	if int(data.get("week_start",0)) < week: return "World Ranking updating…"
	var text: String = "This week did not earn ranking points."
	for result: Dictionary in data.get("results",[]):
		if int(result.week_start) == week:
			text = GameText.message("Circuit #%d · %d points earned · %s") % [int(result.weekly_place),int(result.points),"Counting" if result.counting else "Reserve"]
			break
	if data.get("world_rank") != null:
		text += GameText.message("\nWorld #%d · %d points") % [int(data.world_rank),int(data.points)]
	# Movement belongs to the latest publication, never a different ceremony.
	if int(data.get("week_start",0)) == week:
		text += GameText.message(" · %+d points") % int(data.get("net_change",0))
		if data.get("movement") != null:
			var movement: int = int(data.movement)
			text += GameText.message("\nUp %d places") % movement if movement > 0 else GameText.message("\nDown %d places") % absi(movement) if movement < 0 else "\nPosition unchanged"
		elif data.get("world_rank") != null: text += "\nNew World Ranking entry"
	return text

func _load() -> void:
	_request += 1
	var request: int = _request
	var response: Dictionary = await _adapter.profile("",false,vehicle_id)
	if not is_inside_tree() or is_queued_for_deletion() or request != _request or _scope != _adapter.scope(): return
	label.text = describe(response.data,week_start) if response.ok else "World Ranking unavailable. Check the Garage newspaper."
	if response.ok and response.data.get("policy") == "multi-car-circuit-v2" and vehicle_id != "overall":
		label.text = VehicleCatalog.title(vehicle_id)+" · "+label.text
	if compact: label.text = label.text.replace("\n"," · ")

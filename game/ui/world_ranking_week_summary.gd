extends VBoxContainer
## Official ceremony read: no rank projection and no periodic requests.
var client: Node
var week_start: int = 0
var label: Label

func _ready() -> void:
	name = "WorldRankingWeekResult"
	label = MenuStyle.label("World Ranking updating…",18,true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 64
	add_child(label)
	var button: Button = MenuStyle.button("World Ranking",func() -> void: preload("res://ui/world_ranking.gd").open(self,client))
	add_child(button)
	_load.call_deferred()

func _load() -> void:
	var adapter: Node = preload("res://backend/world_ranking_client.gd").for_client(client)
	var scope: String = adapter.scope()
	var response: Dictionary = await adapter.profile()
	if not is_inside_tree() or is_queued_for_deletion() or scope != adapter.scope(): return
	if not response.ok: return
	var data: Dictionary = response.data
	if int(data.get("week_start",0)) < week_start: return
	label.text = "This week did not earn ranking points."
	for result: Dictionary in data.results:
		if int(result.week_start) == week_start:
			label.text = "Circuit #%d · %d points earned · %s" % [int(result.weekly_place),int(result.points),"Counting" if result.counting else "Reserve"]
			break
	if data.get("world_rank") != null:
		label.text += "\nCurrent World #%d · %d points" % [int(data.world_rank),int(data.points)]
	if int(data.get("week_start",0)) == week_start:
		label.text += " · %+d total" % int(data.get("net_change",0))
		if data.get("movement") != null: label.text += " · %+d places" % int(data.movement)

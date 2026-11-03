extends SceneTree
const Card = preload("res://ui/daily_result_card.gd")
var failures: int = 0
class Feed extends Node:
	signal identity_changed
	var player: Dictionary = {}
	var calls: int = 0
	var preparing: bool = true
	var broken: bool = false
	func signed_in() -> bool: return false
	func base_url() -> String: return "http://fixture.invalid"
	func cancel_public_reads(_owner: int) -> void: pass
	func request_public(path: String, _owner: int) -> Dictionary:
		calls += 1
		if broken: return {"ok":false,"status":500,"error":"SERVER_ERROR"}
		if preparing: return {"ok":false,"status":503,"error":"LAP_STANDINGS_PREPARING","retry_after":1}
		var limits: Array = []
		for percentile: int in [75,60,50,40,30,20,10,5,1]: limits.append({"percentile":percentile,"lap_ticks":1800})
		return {"ok":true,"data":{"day":20759,"version_id":"fixture","vehicle_id":"kart" if path.contains("vehicle_id=kart") else "compact","ends_at":20760*86400,"server_now":20759*86400+1,"population":1,"items":[],"cutoffs":limits}}
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var feed := Feed.new()
	root.add_child(feed)
	var card := Card.new()
	card.client = feed
	card.records = LocalRecords.new("user://daily-preparing-unused.json")
	root.add_child(card)
	card.configure(20759,"fixture",20760*86400)
	check(card._loading and not card._failed and not card._retry.visible,"preparation stays loading without warning")
	feed.preparing = false
	await create_timer(1.2).timeout
	check(feed.calls == 2 and not card._loading and not card.summary.is_empty(),"preparation automatically recovers")
	feed.preparing = true
	card.refresh()
	card.vehicle = "kart"
	feed.preparing = false
	card.refresh()
	var calls: int = feed.calls
	await create_timer(1.2).timeout
	check(feed.calls == calls and card.summary.vehicle_id == "kart","old car retry cannot run after switch")
	feed.preparing = true
	card.refresh()
	await create_timer(3.5).timeout
	check(feed.calls == calls+4 and card._failed and card._retry.visible,"persistent preparation stops after bounded retries")
	feed.preparing = false
	feed.broken = true
	calls = feed.calls
	card.refresh()
	check(feed.calls == calls+1 and card._failed,"real failures still show retry immediately")
	card.queue_free()
	feed.queue_free()
	await process_frame
	print("DAILY_STANDINGS_PREPARING: 5 checks, %d failures" % failures)
	quit(1 if failures else 0)

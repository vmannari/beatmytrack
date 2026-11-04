extends SceneTree
## Actual card, synthetic public responses; isolated user directory, no network.
const Card = preload("res://ui/daily_result_card.gd")
var measurements: Array[Dictionary] = []

class TimedCard extends "res://ui/daily_result_card.gd":
	var render_us: int = 0
	var renders: int = 0
	func _render() -> void:
		var start: int = Time.get_ticks_usec()
		super._render()
		render_us += Time.get_ticks_usec()-start
		renders += 1

class Feed extends Node:
	signal identity_changed
	var failures_left: int = 0
	var request_ms: float = 0.0
	var calls: int = 0
	var player: Dictionary = {}
	func signed_in() -> bool: return false
	func base_url() -> String: return "http://daily-profile.invalid"
	func cancel_public_reads(_owner: int) -> void: pass
	func request_public(_path: String, _owner: int) -> Dictionary:
		calls += 1
		var start: int = Time.get_ticks_usec()
		await get_tree().create_timer(0.2).timeout
		request_ms += (Time.get_ticks_usec()-start)/1000.0
		if failures_left > 0:
			failures_left -= 1
			return {"ok":false,"status":503,"error":"LAP_STANDINGS_PREPARING","retry_after":5}
		var cutoffs: Array = []
		for percentile: int in [75,60,50,40,30,20,10,5,1]: cutoffs.append({"percentile":percentile,"lap_ticks":1800})
		var items: Array = []
		for index: int in range(6): items.append({"player_id":str(index),"display_name":"Fixture driver","rank":index+1,"time_ticks":1800+index*60,"country_code":"FI"})
		return {"ok":true,"data":{"day":20761,"version_id":"fixture","vehicle_id":"compact","ends_at":20762*86400,"server_now":20761*86400+1,"population":6,"items":items,"cutoffs":cutoffs}}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	create_timer(60).timeout.connect(func() -> void: push_error("Daily latency profile deadline"); quit(1))
	root.size = Vector2i(1280,720)
	for scenario: Dictionary in [{"name":"ready","preparing":0},{"name":"one_preparing","preparing":1},{"name":"three_preparing","preparing":3}]:
		var feed := Feed.new()
		feed.failures_left = int(scenario.preparing)
		root.add_child(feed)
		var card := TimedCard.new()
		card.client = feed
		card.records = LocalRecords.new("user://daily-latency-empty.json")
		card.position = Vector2(300,20)
		card.size = Vector2(600,660)
		root.add_child(card)
		var start: int = Time.get_ticks_usec()
		card.configure(20761,"fixture",20762*86400)
		var dispatch_ms: float = (Time.get_ticks_usec()-start)/1000.0
		while card._loading: await process_frame
		var total_ms: float = (Time.get_ticks_usec()-start)/1000.0
		if card._failed or card.summary.is_empty() or feed.calls != int(scenario.preparing)+1:
			push_error("Unexpected profile response/state"); quit(1); return
		var row: Dictionary = {"scenario":scenario.name,"requests":feed.calls,"dispatch_ms":dispatch_ms,"request_ms":feed.request_ms,"total_ms":total_ms,"retry_and_frame_ms":total_ms-feed.request_ms,"render_ms":card.render_us/1000.0,"renders":card.renders}
		measurements.append(row)
		print("DAILY_LATENCY ",JSON.stringify(row))
		start = Time.get_ticks_usec()
		card.refresh()
		if card.summary.is_empty(): push_error("Matching cache was not restored"); quit(1); return
		print("DAILY_LATENCY_CACHE visible_ms=",(Time.get_ticks_usec()-start)/1000.0)
		while card._loading: await process_frame
		card.queue_free()
		feed.queue_free()
		await process_frame
	var path: String = OS.get_environment("BMT_DAILY_LATENCY_OUTPUT")
	if not path.is_empty():
		var output := FileAccess.open(path,FileAccess.WRITE)
		output.store_string(JSON.stringify(measurements,"\t"))
		output.close()
	print("DAILY_LATENCY: 3 scenarios passed")
	quit()

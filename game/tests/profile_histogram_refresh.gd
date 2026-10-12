extends SceneTree
## Read-only mock-network review. No gameplay, uploads, user saves or server writes.
class ProbeClient extends Node:
	var requests: int = 0
	var packet: Dictionary = {}
	var player: Dictionary = {"id":"review-probe"}
	var _capabilities: Dictionary = {}
	var hold: bool = false
	func base_url() -> String: return "http://127.0.0.1:9"
	func signed_in() -> bool: return true
	func request_api(_path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		requests += 1
		while hold: await get_tree().process_frame
		return {"ok":true,"data":packet,"error":""}

var cloud: Node
var client: ProbeClient
var page: RaceComplete
var draws: int = 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var file: String = "res://../docs/evidence/histogram-grid-2026-10-09/verified-silmukka-histograms.json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	client = ProbeClient.new()
	client.packet = data.packet
	client.hold = true
	root.add_child(client)
	cloud = preload("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "res://../build/histogram-review-2026-10-10/client-empty-outbox"
	root.add_child(cloud)
	var result := RaceResults.new()
	result.circuit = "Review fixture"
	result.total = 86.184
	result.best = 86.130
	result.laps = [19.828,16.959,16.808,16.350,16.239]
	result.clean = true
	page = RaceComplete.new()
	page.results = result
	page.facts = {"flying":15.881}
	page.cloud_version = "review-only-fixture"
	page.cloud_client = client
	page.cloud_sync = cloud
	root.add_child(page)
	page.race_chart.draw.connect(func() -> void: draws += 1)
	await create_timer(0.1).timeout
	for iteration: int in range(3): await cloud.flush_outbox()
	client.hold = false
	await create_timer(0.5).timeout
	var initial: int = client.requests
	var initial_draws: int = draws
	var race_before: Dictionary = page.race_chart.snapshot.duplicate(true)
	var lap_before: Dictionary = page.lap_chart.snapshot.duplicate(true)
	client.packet = client.packet.duplicate(true)
	for metric: String in ["race","best_lap"]:
		client.packet[metric].bins[0].count += 1
		client.packet[metric].population += 1
	for iteration: int in range(6):
		await cloud.flush_outbox()
		await create_timer(1.0).timeout
	var idle: int = client.requests-initial
	var idle_draws: int = draws-initial_draws
	page.hide()
	var hidden_start: int = client.requests
	for iteration: int in range(3):
		await cloud.flush_outbox()
		await create_timer(1.0).timeout
	var report: Dictionary = {"idle_polls":6,"comparison_requests_during_idle":idle,
		"chart_draws_during_idle":idle_draws,"hidden_polls":3,"comparison_requests_while_hidden":client.requests-hidden_start,
		"initial_requests":initial,"race_snapshot_frozen":page.race_chart.snapshot == race_before,
		"lap_snapshot_frozen":page.lap_chart.snapshot == lap_before}
	var passed: bool = initial == 1 and idle == 0 and idle_draws == 0 and client.requests == hidden_start and report.race_snapshot_frozen and report.lap_snapshot_frozen
	print("HISTOGRAM_REFRESH_PROBE "+JSON.stringify(report))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var output := FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			output.store_string(JSON.stringify(report));output.close()
	page.queue_free();cloud.queue_free();client.queue_free();result.free()
	await process_frame
	quit(0 if passed else 1)

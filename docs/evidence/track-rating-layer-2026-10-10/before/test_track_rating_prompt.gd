extends SceneTree
const Prompt = preload("res://ui/track_rating_prompt.gd")
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
var capture_dir: String = ""

class VoteClient extends Client:
	var score: int = 0
	var eligible: bool = false
	var hold: bool = false
	var fail_save: bool = false
	var reads: int = 0
	var keys: Array[String] = []
	func signed_in() -> bool: return not player.is_empty()
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		reads += 1
		var reply: Dictionary = {"ok":true,"data":{"score":score,"eligible":eligible}}
		while hold: await get_tree().process_frame
		if not path.ends_with("/rating"): return {"ok":false,"error":"unexpected route"}
		return reply
	func rate_track(_version: String, value: int, key: String) -> Dictionary:
		keys.append(key)
		await get_tree().process_frame
		if fail_save: return {"ok":false,"error":"Unavailable"}
		score = value
		return {"ok":true,"data":{"score":score}}

class Sync extends Node:
	signal changed
	var status: String = "Race verified"

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)
func frames() -> void:
	for i: int in range(5): await process_frame
func prompt(client: Node, sync: Node) -> Node:
	var node := Prompt.new()
	node.cloud_client = client
	node.cloud_sync = sync
	node.cloud_version = "fictional-version"
	root.add_child(node)
	return node
func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-rating="): capture_dir = argument.trim_prefix("--capture-rating=")
	var client := VoteClient.new()
	client.configure("http://127.0.0.1:18181")
	client.player = {"id":"fictional-player"}
	root.add_child(client)
	var sync := Sync.new()
	root.add_child(sync)
	var background := ColorRect.new()
	background.color = MenuStyle.INK
	MenuStyle.fill(background)
	root.add_child(background)
	var results := RaceResults.new()
	results.circuit = "Pine circuit"
	results.vehicle_name = "Compact"
	results.total = 69.0
	results.clean = true
	results.saved = true
	results.laps.assign([14.0,13.8,13.7,13.9,13.6])
	results.position = Vector2(32,16)
	results.size = Vector2(1216,688)
	root.add_child(results)
	var first := prompt(client,sync)
	await frames()
	check(results.visible and not first.overlay.visible,"normal results available while first completion awaits verification")
	check(first.row.locked,"server qualification gates rating")
	# Status already said Race verified for an older job: the next emission must still refresh.
	client.eligible = true
	sync.changed.emit()
	await create_timer(0.8).timeout
	check(first.overlay.visible and not first.row.locked,"newly verified unrated cloud track opens prompt even with repeated status")
	check(first.row.caption.text == "Rate the track" and first.title.text == "Rate the track","requested action caption")
	await capture("cloud-rating-prompt-1280x720")
	first.skip.pressed.emit()
	await frames()
	check(not is_instance_valid(first) and client.score == 0,"Skip leaves server vote unset")
	var again := prompt(client,sync)
	await create_timer(0.8).timeout
	check(again.overlay.visible,"skipped cloud track is offered on a later race")
	root.size = Vector2i(960,540)
	await frames()
	check(again.row.get_global_rect().end.x <= 960 and again.skip.get_global_rect().end.y <= 540,"prompt fits compact landscape")
	await capture("cloud-rating-prompt-960x540")
	root.size = Vector2i(1280,720)
	client.fail_save = true
	again.row.stars[3].pressed.emit()
	await frames()
	check(again.overlay.visible and again.row.caption.visible and not again.row.locked,"failed save stays actionable without confirming a vote")
	client.fail_save = false
	again.row.stars[3].pressed.emit()
	var before_reads: int = client.reads
	sync.changed.emit()
	check(again.row.locked and client.reads == before_reads,"background verification cannot unlock a vote while it saves")
	await frames()
	check(client.score == 4 and again.title.text == "You rated this track 4 / 5","successful server rating confirms chosen stars")
	check(client.keys.size() == 2 and client.keys[0] == client.keys[1] and not client.keys[0].is_empty(),"retry preserves idempotency key")
	await capture("cloud-rating-saved-1280x720")
	await create_timer(0.8).timeout
	check(not is_instance_valid(again),"saved prompt dismisses after confirmation")
	var rated := prompt(client,sync)
	await create_timer(0.8).timeout
	check(not rated.overlay.visible and rated.row.value() == 4,"existing cloud vote suppresses prompt independently of local ratings")
	rated.queue_free()
	await frames()
	client.score = 0
	client.eligible = false
	var owner := prompt(client,sync)
	await create_timer(0.8).timeout
	check(not owner.overlay.visible,"ineligible/self-owned track does not prompt")
	owner.queue_free()
	await frames()
	# Verification can finish while the first eligibility request is still returning false.
	client.hold = true
	var pending := prompt(client,sync)
	client.eligible = true
	sync.changed.emit()
	client.hold = false
	await create_timer(0.8).timeout
	check(pending.overlay.visible,"verification during an eligibility read triggers a follow-up read")
	pending.queue_free()
	await frames()
	client.hold = true
	var switched := prompt(client,sync)
	client.player = {"id":"another-fictional-player"}
	client.identity_changed.emit()
	client.hold = false
	await frames()
	check(not is_instance_valid(switched),"account switch closes pending prompt and discards stale response")
	var away := prompt(client,sync)
	away.queue_free()
	await frames()
	check(sync.changed.get_connections().is_empty(),"departed prompts disconnect verification listeners")
	client.hold = false
	var directory: String = "user://rating_prompt_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var store := LocalRecords.new(directory.path_join("records.json"))
	var local_row := TrackRating.new()
	local_row.records = store
	local_row.track_id = "local-fixture"
	root.add_child(local_row)
	check(local_row.caption.text == "Rate the track","local inline rating uses requested caption")
	local_row.choose(3)
	check(local_row.value() == 3 and local_row.caption.text == "Rate the track","local vote persists with action caption")
	local_row.queue_free()
	results.hide()
	var complete := RaceComplete.new()
	complete.results = results
	complete.rating_records = store
	complete.rating_track_id = "local-fixture"
	complete.facts = {"complete":true,"total":69.0,"previous":70.0,"previous_lap":14.0,"flying":13.6,"incident_free":true}
	complete.position = Vector2(32,16)
	complete.size = Vector2(1216,688)
	complete.theme = MenuStyle.theme()
	root.add_child(complete)
	await frames()
	var inline: TrackRating = complete.find_child("TrackRating",true,false)
	check(inline.caption.text == "Rate the track" and inline.value() == 3,"actual Race Complete page shows action caption with stored stars")
	await capture("race-complete-label-1280x720")
	complete.queue_free()
	results.queue_free()
	background.queue_free()
	sync.queue_free()
	client.queue_free()
	await frames()
	print("TRACK_RATING_PROMPT_TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

extends SceneTree
## Ratings belong to the account/version while race completion can span cars.
const Vote = preload("res://backend/finish_rating.gd")
var checks: int = 0
var failures: int = 0

class RatingClient extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"shared-rating-player"}
	var score: int = 0
	var eligible: bool = false
	var hold_read: bool = false
	var saves: int = 0
	func signed_in() -> bool: return true
	func base_url() -> String: return "http://127.0.0.1:18181"
	func new_idempotency_key() -> String: return "shared-rating-choice-%d" % saves
	func request_api(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _key: String, _authenticated: bool) -> Dictionary:
		var response: Dictionary = {"ok":true,"data":{"score":score,"eligible":eligible}}
		while hold_read: await get_tree().process_frame
		return response
	func rate_track(_version: String, value: int, _key: String) -> Dictionary:
		saves += 1
		score = value
		return {"ok":true,"data":{"score":score}}

class RaceSync extends Node:
	signal changed
	signal race_verified
	var status: String = "Race uploaded — awaiting server verification"

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	for frame: int in range(8): await process_frame

func attempt(client: Node, sync: Node) -> Node:
	var vote := Vote.new()
	vote.client = client
	vote.sync = sync
	vote.version = "shared-track-version"
	sync.add_child(vote)
	return vote

func run() -> void:
	var original_vehicle: String = VehicleCatalog.selected
	var client := RatingClient.new()
	var sync := RaceSync.new()
	root.add_child(client)
	root.add_child(sync)
	VehicleCatalog.selected = "compact"
	var first: Variant = attempt(client,sync)
	check(first.should_prompt(),"first completion offers a previously unrated track")
	first.choose(4)
	VehicleCatalog.selected = "kart"
	var next: Node = attempt(client,sync)
	check(not next.should_prompt(),"switching cars preserves the in-flight track choice")
	# A different pending upload can leave the generic status at 'awaiting'.
	# The dedicated completion event still means eligibility must be refreshed.
	client.eligible = true
	sync.race_verified.emit()
	await settle()
	check(client.saves == 1 and client.score == 4,"completion saves the first-car choice despite another pending upload")
	check(not is_instance_valid(first),"confirmed vote releases its transient service")
	check(next.score == 4 and not next.should_prompt(),"next-car attempt receives the confirmed rating")
	next.abandon()
	await settle()
	check(sync.get_signal_connection_list("race_verified").is_empty(),"completed and abandoned attempts disconnect completion listeners")
	sync.status = "Race verified"
	sync.changed.emit()
	await settle()
	check(client.saves == 1,"later generic completion feedback cannot submit a second vote")
	for vehicle: String in VehicleCatalog.IDS:
		VehicleCatalog.selected = vehicle
		next = attempt(client,sync)
		check(next.score == 4 and not next.should_prompt(),vehicle+" restores the same saved track rating")
		next.abandon()
		await settle()
	# A completion during an old eligibility read must schedule a fresh read.
	client.score = 0
	client.eligible = false
	sync.status = "Race uploaded — awaiting server verification"
	first = attempt(client,sync)
	first.choose(3)
	client.hold_read = true
	first._load()
	client.eligible = true
	sync.race_verified.emit()
	client.hold_read = false
	await settle()
	check(client.saves == 2 and client.score == 3,"completion during a stale read refreshes eligibility and saves once")
	check(not is_instance_valid(first),"vote saved after a stale read releases its service")
	sync.queue_free()
	client.queue_free()
	VehicleCatalog.selected = original_vehicle
	await settle()
	print("SHARED_TRACK_RATING_TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

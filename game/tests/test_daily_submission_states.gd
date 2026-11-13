extends SceneTree
## Exercise actual results status against account-scoped durable upload states.
const Board = preload("res://ui/daily_results_standings.gd")
var checks: int = 0
var failures: int = 0

class Service extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"owner","country_code":"FI"}
	var authenticated: bool = true
	var job: Dictionary = {}
	var reads: Array[String] = []
	func signed_in() -> bool: return authenticated
	func base_url() -> String: return "http://daily-submission.invalid"
	func cancel_public_reads(_owner: int) -> void: pass
	func upload_job(ticket: String) -> Dictionary:
		reads.append(ticket)
		return job.duplicate(true)
	func request_api(_path: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		return {"ok":false,"status":503}
	func request_public(_path: String, _owner: int) -> Dictionary:
		return {"ok":false,"status":503}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var service := Service.new()
	root.add_child(service)
	var board := Board.new()
	board.client = service
	board.cloud = service
	board.day = 20764
	board.version = "daily-submission"
	board.vehicle = "electric"
	board.ticket_id = "owned-daily-ticket"
	root.add_child(board)
	await process_frame
	check(board._submission.text == "Waiting for verification","a durable ticket remains pending until accepted")
	check(service.reads == ["owned-daily-ticket"],"status reads only the original Daily ticket")
	service.job = {"done":true}
	board._update_submission()
	check(board._submission.text == "Verified","accepted upload reports verification")
	service.job = {"failure":"GATES_MISSED"}
	board._update_submission()
	check(board._submission.text == "Verification failed","rejected evidence is not reported as verified")
	service.job = {}
	board._update_submission()
	check(board._submission.text == "Waiting for verification","an unavailable upload journal cannot claim verification")
	var reads: int = service.reads.size()
	service.player = {"id":"other"}
	service.identity_changed.emit()
	board._update_submission()
	check(service.reads.size() == reads,"switching account never reads the previous driver's ticket")
	check(board._submission.text != "Verified","new account cannot borrow previous acceptance")
	service.authenticated = false
	service.identity_changed.emit()
	board._update_submission()
	check(board._submission.text == "Sign in to record a verified time.","guest has an actionable recording state")
	check(service.reads.size() == reads,"guest never queries private upload history")
	service.authenticated = true
	service.player = {"id":"owner"}
	board.ticket_id = ""
	board._update_submission()
	check(board._submission.text == "Saved on this device","older servers without Daily upload retain the local result")
	for label: Node in board.find_children("*","Label",true,false):
		check("Not submitted to the verified leaderboard" not in label.text,"submitted attempts have no contradictory local-only caption")
	board.queue_free()
	service.queue_free()
	await process_frame
	print("DAILY_SUBMISSION_STATES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends Node
## Ephemeral, best-effort vote. Never delays finish/results or enters the race outbox.
signal changed
var client: Node
var sync: Node
var rivalry_sync: Node
var version: String
var creator_id: String = ""
var score: int = 0
var known: bool = false
var eligible: bool = false
var selected_score: int = 0
var loading: bool = false
var reload_pending: bool = false
var sending: bool = false
var account_id: String
var origin: String
var key: String

func _ready() -> void:
	account_id = str(client.player.get("id",""))
	origin = str(client.base_url())
	sync.changed.connect(_sync_changed)
	if is_instance_valid(rivalry_sync): rivalry_sync.changed.connect(_rivalry_changed)
	if client.has_signal("identity_changed"): client.identity_changed.connect(_identity_changed)
	_load()

func _exit_tree() -> void:
	if is_instance_valid(rivalry_sync) and rivalry_sync.changed.is_connected(_rivalry_changed): rivalry_sync.changed.disconnect(_rivalry_changed)
	if is_instance_valid(sync) and sync.changed.is_connected(_sync_changed): sync.changed.disconnect(_sync_changed)
	if is_instance_valid(client) and client.has_signal("identity_changed") and client.identity_changed.is_connected(_identity_changed): client.identity_changed.disconnect(_identity_changed)

func _same_account() -> bool:
	return is_instance_valid(client) and client.signed_in() and str(client.player.get("id","")) == account_id and str(client.base_url()) == origin

func should_prompt() -> bool:
	if not (known and score == 0 and selected_score == 0 and _same_account() and creator_id != account_id): return false
	# A selected vote survives its race view while verification/PUT completes.
	# Do not ask again on a retry while that same account/version is in flight.
	for sibling: Node in sync.get_children():
		if sibling != self and sibling.get_script() == get_script() and sibling.version == version and sibling.account_id == account_id and sibling.origin == origin and sibling.selected_score > 0 and not sibling.is_queued_for_deletion(): return false
	return true

func _rivalry_changed() -> void:
	if selected_score == 0 or sending or str(rivalry_sync.result_state) != "verified": return
	if loading: reload_pending = true
	else: _load()

func choose(value: int) -> void:
	if not should_prompt() or value < 1 or value > 5: return
	selected_score = value
	key = client.new_idempotency_key()
	changed.emit()
	# First-race eligibility follows the independent durable race upload.
	if eligible: _send.call_deferred()
	get_tree().create_timer(120.0).timeout.connect(abandon_selected)

func abandon() -> void:
	if selected_score == 0: queue_free()

func abandon_selected() -> void:
	queue_free()

func _identity_changed() -> void:
	if not _same_account(): queue_free()

func _sync_changed() -> void:
	if selected_score == 0 or sending or not str(sync.status).begins_with("Race verified"): return
	if loading: reload_pending = true
	else: _load()

func _confirm_score(value: Variant) -> void:
	if not (value is int or value is float) or not is_finite(float(value)): return
	if float(value) != floorf(float(value)) or value < 1 or value > 5: return
	# A retry may have prefetched zero before this vote was saved. Hand the
	# server-confirmed score to every matching attempt before this node exits.
	for sibling: Node in sync.get_children():
		if sibling.get_script() == get_script() and sibling.version == version and sibling.account_id == account_id and sibling.origin == origin and not sibling.is_queued_for_deletion():
			sibling.known = true
			sibling.score = int(value)
			sibling.changed.emit()

func _load() -> void:
	if loading or sending or not _same_account(): return
	loading = true
	var response: Dictionary = await client.request_api("/track-versions/"+version.uri_encode()+"/rating",HTTPClient.METHOD_GET,{},"",true)
	if not is_inside_tree() or not _same_account(): return
	loading = false
	var data: Variant = response.get("data", {})
	if not response.get("ok", false) or not data is Dictionary or not data.has_all(["score", "eligible"]):
		if selected_score > 0: queue_free()
		return
	known = true
	# A GET started before a successful PUT may return its old zero afterwards.
	# It must not undo a confirmed score handed off by the saving attempt.
	_confirm_score(data.score)
	eligible = bool(response.data.eligible)
	changed.emit()
	if selected_score > 0:
		if score > 0: queue_free()
		elif eligible: _send.call_deferred()
	if reload_pending:
		reload_pending = false
		_load.call_deferred()

func _send() -> void:
	if sending or not eligible or selected_score == 0 or not _same_account(): return
	sending = true
	# One request only. Server authority/idempotency remain; failure stays unrated.
	var response: Dictionary = await client.rate_track(version,selected_score,key)
	if is_inside_tree() and _same_account() and response.get("ok",false) and response.get("data") is Dictionary:
		_confirm_score(response.data.get("score"))
	if is_inside_tree(): queue_free()

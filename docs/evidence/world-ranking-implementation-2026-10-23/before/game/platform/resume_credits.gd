extends Node
## Credits are outside the canonical simulation. Signed-in balances are server owned.
const Client = preload("res://backend/backend_client.gd")
const TEMPORARY_AD_RESUMES: bool = true
var client: Node
var guest_path: String = "user://guest_resumes.json"
var wallet: Dictionary = {}
var race_id: String = ""
var race_key: String = ""
var ticket_id: String = ""
var owner_id: String = ""
var pending: Dictionary = {}
var busy: bool = false
var used: int = 0
var show_ads: bool = false
var ad_adapter: Node
var _completed_ad: Dictionary = {}
var _journal: Dictionary = {}

func _exit_tree() -> void:
	if is_instance_valid(client) and is_instance_valid(client.get("resume_recovery")):
		client.resume_recovery.leave_race(race_key)

func _ready() -> void:
	ad_adapter = preload("res://platform/admob_test_ads.gd").new()
	add_child(ad_adapter)

func begin(ticket: String = "") -> void:
	if is_instance_valid(client) and is_instance_valid(client.get("resume_recovery")):
		client.resume_recovery.leave_race(race_key)
	race_id = ""
	race_key = client.new_operation_key() if is_instance_valid(client) and client.has_method("new_operation_key") else Client.new_idempotency_key()
	ticket_id = ticket
	owner_id = str(client.player.get("id","")) if client != null else ""
	pending = {}
	used = 0
	wallet = {}
	_completed_ad = {}
	_journal = {}
	if is_instance_valid(client) and is_instance_valid(client.get("resume_recovery")): client.resume_recovery.register_race(race_key)

func _guest_data() -> Dictionary:
	if not FileAccess.file_exists(guest_path): return {"day":-1}
	var file := FileAccess.open(guest_path,FileAccess.READ)
	if file == null: return {"day":9223372036854775807}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary and data.has("day") else {"day":9223372036854775807}

func refresh() -> Dictionary:
	if client != null and client.signed_in():
		var response: Dictionary = await client.request_api("/resumes",HTTPClient.METHOD_GET,{},"",true)
		if not response.ok: return response
		wallet = response.data
	else:
		var day: int = int(Time.get_unix_time_from_system()) / 86400
		wallet = {"free":int(int(_guest_data().day) < day),"balance":0,"reset_at":(day+1)*86400,"ads_available":false,"ad_preview_available":TEMPORARY_AD_RESUMES,"purchases_available":false}
	return {"ok":true,"data":wallet}

func consume(from_tick: int, to_tick: int, input_offset: int) -> Dictionary:
	if busy: return {"ok":false,"error":"Please wait for the resume request."}
	if used >= 3 or from_tick-to_tick < 1 or from_tick-to_tick > RewindHistory.WINDOW_TICKS: return {"ok":false,"error":"Resume limit reached."}
	if client != null and str(client.player.get("id","")) != owner_id: return {"ok":false,"error":"Account changed. Start a new race."}
	busy = true
	var ad_selection: Dictionary = {"race":race_key,"ordinal":used+1,"from_tick":from_tick,"to_tick":to_tick,"input_offset":input_offset}
	# Test SDK completion gates only the existing temporary resume path. It is
	# never provider proof for a banked grant, and cannot bypass bank/daily order.
	if OS.is_debug_build() and show_ads and pending.is_empty() and _completed_ad != ad_selection:
		var race_generation: String = race_key
		var checked: Dictionary = await refresh()
		if not checked.ok:
			busy = false
			return checked
		if not bool(wallet.get("free_rewinds",false)) and int(wallet.get("balance",0)) == 0 and int(wallet.get("free",0)) == 0:
			if not bool(wallet.get("ad_preview_available", false)):
				busy = false
				return {"ok":false,"error":"Test-ad resumes are not enabled on this backend."}
			var ad_result: Dictionary = await ad_adapter.show_rewarded()
			if not ad_result.ok:
				busy = false
				return ad_result
			_completed_ad = ad_selection
		if race_key != race_generation or (client != null and str(client.player.get("id","")) != owner_id):
			busy = false
			return {"ok":false,"error":"Race or account changed. Start a new race."}
	var response: Dictionary = await _consume(from_tick,to_tick,input_offset)
	busy = false
	if response.ok:
		used += 1
		wallet = response.data.wallet
		pending = {}
		_completed_ad = {}
	return response

func _consume(from_tick: int, to_tick: int, input_offset: int) -> Dictionary:
	if not owner_id.is_empty():
		if not client.signed_in(): return {"ok":false,"error":"Sign in again to use a resume."}
		var body: Dictionary = {"ordinal":used+1,"from_tick":from_tick,"to_tick":to_tick,"input_offset":input_offset}
		var recoverable: bool = (bool(client.get("_capabilities").get("resume_recovery",false)) if client.get("_capabilities") is Dictionary else false) or pending.get("body",{}).get("recovery") == "v1"
		if recoverable: body.recovery = "v1"
		if pending.is_empty(): pending = {"body":body,"key":client.new_operation_key() if client.has_method("new_operation_key") else Client.new_idempotency_key()}
		if pending.body != body: return {"ok":false,"error":"Retry the pending resume before changing its position."}
		if recoverable:
			_journal = {"owner":owner_id,"origin":client.base_url(),"begin_key":race_key,
				"consume_key":pending.key,"selection":body,"ticket_id":ticket_id,"race_id":race_id,"stage":"pending"}
			if not is_instance_valid(client.resume_recovery) or not client.resume_recovery.save(_journal):
				return {"ok":false,"error":"Could not save resume recovery. Free storage and retry.","status":0}
		if race_id.is_empty():
			var beginning: Dictionary = {}
			if not ticket_id.is_empty(): beginning.ticket_id = ticket_id
			var started: Dictionary = await client.request_api("/resume-races",HTTPClient.METHOD_POST,beginning,race_key,true)
			if not started.ok:
				if recoverable: client.resume_recovery.discard(_journal)
				pending = {} # Begin cannot spend a resource; only consumption needs a fixed position.
				return started
			race_id = str(started.data.race_id)
		if recoverable:
			_journal.race_id = race_id
			if not client.resume_recovery.save(_journal): return {"ok":false,"error":"Could not save resume recovery. Free storage and retry.","status":0}
		var result: Dictionary = await client.request_api("/resume-races/"+race_id+"/resumes",HTTPClient.METHOD_POST,body,str(pending.key),true)
		if result.ok and recoverable:
			# Persist knowledge of delivery before applying the rewind. Background
			# confirmation is idempotent and cannot block the canonical simulation.
			_journal.stage = "confirm"
			if not client.resume_recovery.save(_journal): return {"ok":false,"error":"Could not save resume recovery. Free storage and retry.","status":0}
		# Definitive rejection spends nothing. Ambiguous transport failures retain the key.
		if not result.ok and int(result.get("status",0)) in [400,401,403,404,409,410,422] and not (recoverable and str(result.get("error","")) == "INVALID_INPUT"): pending = {}
		return result
	var data: Dictionary = _guest_data()
	var day: int = int(Time.get_unix_time_from_system()) / 86400
	if int(data.day) >= day:
		if not TEMPORARY_AD_RESUMES: return {"ok":false,"error":"Daily free resume used. Resets at 00:00 UTC."}
		return {"ok":true,"data":{"receipt_id":Client.new_idempotency_key().left(36),"wallet":{"free":0,"balance":0,"ads_available":false,"ad_preview_available":true,"purchases_available":false}}}
	# A guest's local allowance cannot authorize an online leaderboard receipt.
	var file := FileAccess.open(guest_path+".tmp",FileAccess.WRITE)
	if file == null: return {"ok":false,"error":"Could not save the daily resume allowance."}
	file.store_string(JSON.stringify({"day":day}))
	file.flush()
	var saved: bool = file.get_error() == OK
	file.close()
	if not saved or DirAccess.rename_absolute(guest_path+".tmp",guest_path) != OK: return {"ok":false,"error":"Could not save the daily resume allowance."}
	return {"ok":true,"data":{"receipt_id":Client.new_idempotency_key().left(36),"wallet":{"free":0,"balance":0,"ads_available":false,"ad_preview_available":TEMPORARY_AD_RESUMES,"purchases_available":false}}}

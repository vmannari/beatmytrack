extends Node
## Credits are outside the canonical simulation. Signed-in balances are server owned.
const Client = preload("res://backend/backend_client.gd")
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

func begin(ticket: String = "") -> void:
	race_id = ""
	race_key = Client.new_idempotency_key()
	ticket_id = ticket
	owner_id = str(client.player.get("id","")) if client != null else ""
	pending = {}
	used = 0
	wallet = {}

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
		wallet = {"free":int(int(_guest_data().day) < day),"balance":0,"reset_at":(day+1)*86400,"ads_available":false,"purchases_available":false}
	return {"ok":true,"data":wallet}

func consume(from_tick: int, to_tick: int, input_offset: int) -> Dictionary:
	if busy: return {"ok":false,"error":"Please wait for the resume request."}
	if used >= 3 or from_tick-to_tick < 1 or from_tick-to_tick > RewindHistory.WINDOW_TICKS: return {"ok":false,"error":"Resume limit reached."}
	if client != null and str(client.player.get("id","")) != owner_id: return {"ok":false,"error":"Account changed. Start a new race."}
	busy = true
	var response: Dictionary = await _consume(from_tick,to_tick,input_offset)
	busy = false
	if response.ok:
		used += 1
		wallet = response.data.wallet
		pending = {}
	return response

func _consume(from_tick: int, to_tick: int, input_offset: int) -> Dictionary:
	if not owner_id.is_empty():
		if not client.signed_in(): return {"ok":false,"error":"Sign in again to use a resume."}
		if race_id.is_empty():
			var body: Dictionary = {}
			if not ticket_id.is_empty(): body.ticket_id = ticket_id
			var started: Dictionary = await client.request_api("/resume-races",HTTPClient.METHOD_POST,body,race_key,true)
			if not started.ok: return started
			race_id = str(started.data.race_id)
		var body: Dictionary = {"ordinal":used+1,"from_tick":from_tick,"to_tick":to_tick,"input_offset":input_offset}
		if pending.is_empty(): pending = {"body":body,"key":Client.new_idempotency_key()}
		if pending.body != body: return {"ok":false,"error":"Retry the pending resume before changing its position."}
		var result: Dictionary = await client.request_api("/resume-races/"+race_id+"/resumes",HTTPClient.METHOD_POST,body,str(pending.key),true)
		# Definitive rejection spends nothing. Ambiguous transport failures retain the key.
		if not result.ok and int(result.get("status",0)) in [400,401,403,404,409,410,422]: pending = {}
		return result
	var data: Dictionary = _guest_data()
	var day: int = int(Time.get_unix_time_from_system()) / 86400
	if int(data.day) >= day: return {"ok":false,"error":"Daily free resume used. Resets at 00:00 UTC."}
	# A guest's local allowance cannot authorize an online leaderboard receipt.
	var file := FileAccess.open(guest_path+".tmp",FileAccess.WRITE)
	if file == null: return {"ok":false,"error":"Could not save the daily resume allowance."}
	file.store_string(JSON.stringify({"day":day}))
	file.flush()
	var saved: bool = file.get_error() == OK
	file.close()
	if not saved or DirAccess.rename_absolute(guest_path+".tmp",guest_path) != OK: return {"ok":false,"error":"Could not save the daily resume allowance."}
	return {"ok":true,"data":{"receipt_id":Client.new_idempotency_key().left(36),"wallet":{"free":0,"balance":0,"ads_available":false,"purchases_available":false}}}

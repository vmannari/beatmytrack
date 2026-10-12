extends "res://tests/test_race_ticket_priority.gd"
## An already completed credential renewal must unblock race authorization,
## even while the refresh owner's non-race retry is still waiting for data.
class HeldReadAPI extends API:
	signal release_initial_ticket
	signal release_read
	var ticket_started: bool = false
	var read_retry_started: bool = false
	var reply_mode: String = "normal"
	func _send(path: String, method: HTTPClient.Method, payload: Dictionary, auth: bool, key: String = "", headers: PackedStringArray = [], owner: int = 0) -> Dictionary:
		if path == "/me":
			if _access_token != "replacement-access": return {"ok":false,"status":401,"data":{},"error":"INVALID_SESSION"}
			read_retry_started = true
			await release_read
			return {"ok":true,"status":200,"data":{"id":"fictional-player"},"error":""}
		if Client._race_ticket_path(path):
			calls.append(path);keys.append(key)
			if not ticket_started:
				ticket_started = true
				await release_initial_ticket
				return {"ok":false,"status":401,"data":{},"error":"INVALID_SESSION"}
			await get_tree().process_frame
			if reply_mode == "account": clear_session()
			return {"ok":true,"status":201,"data":{"ticket_id":"fictional-fresh-ticket","manifest":manifest},"error":""}
		return await super._send(path,method,payload,auth,key,headers,owner)
func read(api: Node, result: Dictionary) -> void:
	result.value = await api.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	result.done = true
func wait_non_ticket(api: Node, result: Dictionary) -> void:
	result.value = await api._renew_session(api._session_generation,"/non-race-observer",HTTPClient.METHOD_GET,{},"non-race-key","fictional-expired-access")
	result.done = true
func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	for case: Dictionary in [{"path":"/run-tickets","mode":"normal"},{"path":"/rivalry/fictional-group/tickets","mode":"normal"},{"path":"/challenges/fictional-code/tickets","mode":"normal"},{"path":"/run-tickets","mode":"account"}]:
		var path: String = case.path
		var api := HeldReadAPI.new();root.add_child(api)
		api.configure("http://127.0.0.1:18181")
		api.reply_mode = case.mode
		api._access_token = "fictional-expired-access";api._refresh_token = "r".repeat(64)
		api.player = {"id":"fictional-player"}
		api.manifest = TrackLifecycle._contract(fixture.document,"compact");api.manifest.laps = RaceRules.LAPS
		ticket_done = false
		request_ticket(api,path)
		var reading: Dictionary = {"done":false}
		read(api,reading)
		while not api.read_retry_started: await process_frame
		var observer: Dictionary = {"done":false}
		if case.mode == "normal": wait_non_ticket(api,observer)
		api.release_initial_ticket.emit()
		for frame: int in range(12): await process_frame
		check(ticket_done and not reading.done,"already refreshed ticket completes before the stalled read: "+path)
		if case.mode == "normal": check(not observer.done,"early retry remains restricted to actual race tickets")
		check(api._refresh_busy and api._busy,"the read retains its own credential and mutation locks")
		api.release_read.emit()
		while not ticket_done or not reading.done: await process_frame
		if case.mode == "account":
			check(not ticket_response.ok and ticket_response.error == "ACCOUNT_CHANGED" and not reading.value.ok and not api.signed_in(),"account change rejects the early retry and old read without restoring credentials")
		else: check(ticket_response.ok and reading.value.ok and api.refreshes == 1,"one credential renewal supports both operations")
		if case.mode == "normal":
			while not observer.done: await process_frame
			check(observer.value.ok,"non-race observer completes after the owner releases its lock")
		check(api.keys.count("ticket-key") == 2,"exact ticket key is retained through the early retry")
		check(not api._refresh_busy and not api._busy,"only the owner releases its locks")
		api.free()
	print("REFRESHED_TICKET_PRIORITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

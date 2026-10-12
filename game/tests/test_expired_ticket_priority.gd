extends "res://tests/test_race_ticket_priority.gd"
## Expired race authorization must also bypass a held durable score upload.

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	for path: String in ["/run-tickets", "/rivalry/fictional-group/tickets", "/challenges/fictional-code/tickets"]:
		var api: API = fixture_api(fixture)
		api.mode = "expired"
		api._refresh_token = "r".repeat(64)
		ticket_done = false
		upload_done = false
		request_upload(api)
		while not api.upload_started: await process_frame
		request_ticket(api, path)
		for frame: int in range(25): await process_frame
		check(ticket_done and not upload_done, path + " expired ticket refresh completes before upload release")
		check(api._busy, "refresh never releases the upload's lock")
		api.release_upload.emit()
		while not upload_done or not ticket_done: await process_frame
		check(ticket_response.ok and upload_response.ok and api.refreshes == 1, "upload and refreshed ticket survive independently")
		check(api.keys.count("ticket-key") == 2 and api.keys.count("upload-key") == 1, "refresh retains exact operation keys")
		check(not api._busy, "upload releases its own lock")
		api.free()
	var concurrent: API = fixture_api(fixture)
	concurrent.mode = "expired"
	concurrent._refresh_token = "r".repeat(64)
	ticket_done = false
	upload_done = false
	request_upload(concurrent)
	while not concurrent.upload_started: await process_frame
	request_ticket(concurrent, "/run-tickets")
	var second: Dictionary = await concurrent.request_api("/rivalry/fictional-group/tickets", HTTPClient.METHOD_POST, {}, "second-key", true)
	while not ticket_done: await process_frame
	check(second.ok and ticket_response.ok and concurrent.refreshes == 1 and not upload_done, "simultaneous expired tickets share one rotation before upload release")
	check(concurrent._busy and not concurrent._refresh_busy, "credential lock releases independently while upload remains serialized")
	check(concurrent.keys.count("ticket-key") == 2 and concurrent.keys.count("second-key") == 2, "simultaneous refresh retains both exact ticket keys")
	concurrent.release_upload.emit()
	while not upload_done: await process_frame
	check(upload_response.ok and not concurrent._busy, "upload survives concurrent credential rotation")
	concurrent.free()
	print("EXPIRED_TICKET_PRIORITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

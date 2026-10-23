extends "res://tests/test_rivalry_feedback.gd"
## A completed PB reaches the overview before verification/full-board refresh.

class CachedClient extends ResultClient:
	var cached: Dictionary = {}
	func recent_run(_ticket: String) -> Dictionary: return cached

func run() -> void:
	root.size = Vector2i(1280,720)
	snapshot = fixture()
	for track: Dictionary in snapshot.tracks:
		for row: Dictionary in track.entries:
			if row.id == snapshot.self_id:
				row.ms = null; row.ticks = null; row.rank = null; row.points = 0
	for row: Dictionary in snapshot.standings:
		if row.id == snapshot.self_id: row.points = 0; row.rank = null; row.completed = 0
	snapshot.standings.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.points) > int(b.points))
	var client := CachedClient.new()
	root.add_child(client)
	var adapter := Adapter.new()
	adapter.client = client
	root.add_child(adapter)
	adapter.model.apply_snapshot(snapshot)
	adapter.snapshot_scope = adapter.scope()
	adapter.result_ticket = "first-finish"
	client.response = {"ok":true,"data":{"status":"queued","poll_after_ms":2500}}
	await adapter.poll_result()
	var original: String = JSON.stringify([adapter.model.tracks,adapter.model.server_standings])
	var outcome: Dictionary = adapter.model.preview_result(0,11940,99.5).duplicate(true)
	var page := WeeklyRivalryPage.new()
	page.model = adapter.model
	page.signed_in = true
	root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame: int in range(6): await process_frame
	check(page._track_views[0].time.text == MenuStyle.time_text(99.5),"first completed time appears in This week's tracks immediately")
	check(page._track_views[0].delta.text == "Verifying...","unverified time is labelled in its own row")
	check(page._track_views[0].rank.text == WeeklyRivalryPage.rank_text({}),"pending time does not invent a verified rank")
	check(page.find_child("RivalryTrackProgress",true,false).text == "0 / 5 COMPLETED","pending race does not count as verified completion")
	check(JSON.stringify([adapter.model.tracks,adapter.model.server_standings]) == original,"immediate overview time preserves server standings")
	await capture_overview("pending")
	var row_control: Control = page.track_rows[0]
	outcome.erase("provisional")
	adapter._next_poll_msec = Time.get_ticks_msec()+10000
	client.cached = {"status":"verified","slot":0,"outcome":{}}
	var requests_before_receipt: int = client.requests
	await adapter.poll_result()
	check(adapter.result_state == "queued" and client.requests == requests_before_receipt,"malformed cached proof cannot bypass the result-poll deadline")
	client.cached = {"status":"verified","slot":0,"outcome":outcome}
	client.board_response = {"ok":true,"data":snapshot}
	client.board_delay = 0.4
	var requests: int = client.requests
	adapter.changed.connect(page.refresh_presentation)
	adapter.poll_result()
	await create_timer(0.05).timeout
	check(adapter.result_state == "verified","upload confirmation bypasses the next result-poll deadline")
	check(client.requests == requests+1,"cached confirmation only requests the full board, with no duplicate result read")
	check(page._track_views[0].time.text == MenuStyle.time_text(99.5) and page._track_views[0].delta.text == "Leading","confirmed time and rank appear while full-board request is still pending")
	check(page._track_views[0].rank.text == "#1" and page.find_child("RivalryTrackProgress",true,false).text == "1 / 5 COMPLETED","only confirmed proof updates row rank and completion")
	check(page.track_rows[0] == row_control,"verification updates the retained overview row")
	await capture_overview("confirmed")
	await create_timer(0.45).timeout
	check(page._track_views[0].time.text == MenuStyle.time_text(99.5),"an older full-board response cannot erase the confirmed time")
	check(JSON.stringify([adapter.model.tracks,adapter.model.server_standings]) == original,"presentation does not write projected weekly points into server data")
	adapter.model.last_result = {"ms":99500}
	page.refresh_presentation()
	check(page._track_views[0].delta.text == "Leader time","rejected or unavailable proof removes its pending time")
	adapter.model.preview_result(1,12000,100.0)
	page.refresh_presentation()
	check(page._track_views[0].delta.text == "Leader time" and page._track_views[1].delta.text == "Verifying...","pending time belongs to its exact track slot")
	adapter.model.apply_snapshot(fixture())
	adapter.model.preview_result(2,11940,99.5)
	page.refresh_presentation()
	check(page._track_views[2].time.text == MenuStyle.time_text(99.5) and page._track_views[2].delta.text == "Verifying...","a faster retry shows its new time immediately")
	adapter.model.preview_result(2,13200,110.0)
	page.refresh_presentation()
	check(page._track_views[2].time.text == MenuStyle.time_text(102.0) and page._track_views[2].delta.text != "Verifying...","a slower retry retains the verified weekly best")
	adapter.reset()
	page.model = adapter.model
	page.refresh_presentation()
	check(page._track_views.is_empty(),"account reset removes all prior result rows")
	page.queue_free()
	adapter.queue_free()
	client.queue_free()
	await process_frame
	print("RIVALRY_TRACK_TIME_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture_overview(state: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var directory: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): directory = ProjectSettings.globalize_path(argument.trim_prefix("--evidence="))
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		for frame: int in range(4): await process_frame
		var page: WeeklyRivalryPage = root.find_child("WeeklyRivalryPage",true,false)
		check(root.get_visible_rect().encloses(page._track_views[0].time.get_global_rect()) and root.get_visible_rect().encloses(page._track_views[0].delta.get_global_rect()),"new time and status fit the overview at "+str(dimensions))
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory.path_join(state+"-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"native overview capture saves: "+state)
	root.size = Vector2i(1280,720)

extends SceneTree
## Immediate previews never change verified standings; confirmation is automatic.
const Adapter = preload("res://backend/weekly_rivalry_client.gd")
var checks: int = 0
var failures: int = 0
var snapshot: Dictionary

class ResultClient extends Node:
	var player: Dictionary = {"id":"driver_02"}
	var response: Dictionary = {}
	var board_response: Dictionary = {}
	var result_delay: float = 0.0
	var board_delay: float = 0.0
	var requests: int = 0
	func base_url() -> String: return "http://fixture"
	func signed_in() -> bool: return true
	func recent_run(_ticket: String) -> Dictionary: return {}
	func request_api(path: String, _method: int, _payload: Dictionary, _key: String, _auth: bool) -> Dictionary:
		requests += 1
		var board: bool = not path.ends_with("/result")
		var value: Dictionary = (board_response if board else response).duplicate(true)
		await get_tree().create_timer(board_delay if board else result_delay).timeout
		return value

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+description)

func fixture() -> Dictionary:
	var result: Dictionary = {"state":"active","group_id":"fixture","self_id":"driver_02","week":40,
		"ends_at":604800,"server_now":0,"vehicle_id":"compact","tracks":[],"standings":[],
		"points_policy":[30,26,23,20,18,16,14,12,10,8,6,4,2,1,1,1,1,1,1,1]}
	var menu := WeeklyRivalry.new(true)
	for driver: int in range(20):
		result.standings.append({"id":"driver_%02d" % driver,"name":"Driver %02d" % driver,
			"rank":driver+1,"points":int(result.points_policy[driver])*5,"completed":5})
	for slot: int in range(5):
		var entries: Array = []
		for driver: int in range(20):
			entries.append({"id":"driver_%02d" % driver,"name":"Driver %02d" % driver,
				"ticks":12000+driver*120,"ms":100000+driver*1000,"rank":driver+1,"points":result.points_policy[driver]})
		result.tracks.append({"board_id":"board_%d" % slot,"entries":entries,
			"entry":{"name":menu.tracks[slot].name,"theme":menu.tracks[slot].theme,"creator":"Beat my track",
			"track_id":"track_%d" % slot,"version_id":"version_%d" % slot,"content_hash":"a".repeat(64),"points":menu.tracks[slot].document.points}})
	return result

func run() -> void:
	snapshot = fixture()
	check(Adapter.valid_snapshot(snapshot),"preview uses a real-shaped twenty-driver server snapshot")
	var model := WeeklyRivalry.new()
	model.apply_snapshot(snapshot)
	var original: String = JSON.stringify([model.tracks,model.server_standings])
	var started: int = Time.get_ticks_usec()
	var preview: Dictionary = model.preview_result(0,11940,99.5)
	var preview_usec: int = Time.get_ticks_usec()-started
	check(preview.provisional and not preview.valid,"immediate feedback explicitly remains unverified")
	check(preview.before.rank == 3 and preview.after.rank == 1 and preview.points_delta == 7,"projected PB moves from third to first with seven points")
	check(preview.overall_after.points == 122 and preview.overall_after.rank == 3,"projection recomputes all drivers' overall points")
	check(preview.beaten.size() == 2 and preview.beaten[-1].ms == 101000,"preview identifies the nearest newly beaten rival")
	check(JSON.stringify([model.tracks,model.server_standings]) == original and model.pb_count == 0,"preview never writes verified standings or PBs")
	check(model.preview_result(0,12600,105.0).points_delta == 0,"a slower retry leaves projected points unchanged")
	preview = model.preview_result(0,12120,101.0)
	check(preview.after.rank == 2 and preview.after.points == 26 and preview.points_delta == 3,"equal canonical ticks share rank and points")
	var unplayed: Dictionary = snapshot.duplicate(true)
	for track: Dictionary in unplayed.tracks:
		for row: Dictionary in track.entries:
			if row.id == unplayed.self_id:
				row.ticks = null; row.ms = null; row.rank = null; row.points = 0
	for row: Dictionary in unplayed.standings:
		if row.id == unplayed.self_id: row.rank = null; row.points = 0; row.completed = 0
	model.apply_snapshot(unplayed)
	preview = model.preview_result(0,15000,125.0)
	check(preview.before.rank == null and preview.after.rank == 20 and preview.points_delta == 1,"first finish and the twentieth scoring position are projected")
	check(preview.overall_after.completed == 1 and preview.overall_after.rank == 20,"first finish receives a projected overall rank")
	check(model.preview_result(0,12000,NAN).is_empty(),"a nonfinite time cannot enter the preview")
	model.apply_snapshot(snapshot)
	var client := ResultClient.new()
	root.add_child(client)
	var adapter := Adapter.new()
	adapter.client = client
	root.add_child(adapter)
	adapter.model = model
	adapter.snapshot_scope = adapter.scope()
	adapter.result_ticket = "one"
	client.result_delay = 0.1
	client.response = {"ok":true,"data":{"status":"queued"}}
	adapter.poll_result()
	adapter.poll_result()
	check(adapter.result_polling and not adapter.busy and client.requests == 1,"only one poll runs while race actions remain usable")
	await create_timer(0.15).timeout
	await adapter.poll_result()
	check(client.requests == 1,"rapid callers respect the bounded poll interval")
	adapter.result_ticket = "two"
	model.preview_result(0,11940,99.5)
	client.response = {"ok":true,"data":{"status":"rejected"}}
	await adapter.poll_result()
	check(not model.last_result.has("provisional") and not model.last_result.has("after"),"a rejected replay discards its projected award")
	var confirmed: Dictionary = model.preview_result(0,11940,99.5).duplicate(true)
	confirmed.erase("provisional")
	client.response = {"ok":true,"data":{"status":"verified","outcome":confirmed,"slot":0}}
	client.board_response = {"ok":true,"data":snapshot}
	client.board_delay = 0.3
	adapter.result_ticket = "three"
	adapter.poll_result()
	await create_timer(0.15).timeout
	check(model.last_result.valid and not model.last_result.has("provisional") and adapter.busy,"confirmation appears before the full standings request completes")
	await create_timer(0.35).timeout
	model.preview_result(0,11940,99.5)
	adapter.result_ticket = "old"
	adapter.poll_result()
	adapter.result_ticket = "new"
	await create_timer(0.15).timeout
	check(model.last_result.get("provisional",false) and not adapter.result_polling,"a replaced race fences stale verification without stranding polling")
	client.response = {"ok":false,"retry_after":10,"data":{}}
	adapter.result_ticket = "offline"
	await adapter.poll_result()
	var requests: int = client.requests
	await adapter.poll_result()
	check(client.requests == requests and adapter.error.contains("Reconnect"),"connection failure backs off without hiding the immediate result")
	client.response = {"ok":true,"data":{"status":"rejected"}}
	adapter.result_ticket = "signout"
	adapter.poll_result()
	adapter.reset()
	await create_timer(0.15).timeout
	check(adapter.result_state.is_empty() and adapter.model.last_result.is_empty() and not adapter.result_polling,"account reset fences pending confirmation")
	model.preview_result(0,11940,99.5)
	await visuals(model)
	adapter.queue_free()
	client.queue_free()
	await process_frame
	print("RIVALRY_FEEDBACK_TIMING: preview_usec=%d" % preview_usec)
	print("RIVALRY_FEEDBACK_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func visuals(model: WeeklyRivalry) -> void:
	if DisplayServer.get_name() == "headless": return
	var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-feedback-speed-2026-10-04")
	DirAccess.make_dir_recursive_absolute(evidence)
	OS.set_environment("BMT_API_URL","")
	var folder: String = "user://feedback_capture_"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.rivalry.model = model
	app.rivalry_section = "result"
	app.rivalry_result_pending = true
	app._show_screen("rivalry")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		app._rivalry()
		for _frame: int in range(5): await process_frame
		var page: Control = app.root_ui.find_child("WeeklyRivalryPage",true,false)
		check(has_text(page,"TRACK STANDINGS") and page.find_child("RivalryResultProvisional",true,false) != null,"pending screen displays standings and a compact provisional status immediately")
		var race: Button = page.find_child("RivalryRaceAgain",true,false)
		check(race != null and not race.disabled and root.get_visible_rect().encloses(race.get_global_rect()),"Race Again remains available inside the compact screen")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(evidence.path_join("provisional-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"provisional screenshot saves")
	app.queue_free()
	await process_frame

func has_text(node: Node, value: String) -> bool:
	if node is Label and node.text == value: return true
	for child: Node in node.get_children():
		if has_text(child,value): return true
	return false

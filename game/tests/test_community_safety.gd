extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const UI = preload("res://ui/community_safety_ui.gd")
var checks: int = 0
var failures: int = 0
var folder: String

func capture(name_value: String) -> void:
	var output: String = OS.get_environment("BMT_COMMUNITY_CAPTURE")
	if output.is_empty(): return
	for _frame: int in range(6): await process_frame
	for child: Node in root.get_children():
		if child is AcceptDialog and child.visible:
			check(child.position.x >= 0 and child.position.y >= 0 and child.position.x+child.size.x <= root.get_visible_rect().size.x and child.position.y+child.size.y <= root.get_visible_rect().size.y,"native "+name_value+" stays inside viewport")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name_value+".png")) == OK,"native "+name_value+" capture")

class MockClient extends Client:
	var calls: Array[Dictionary] = []
	var remote_blocks: Dictionary = {}
	var remote_reports: Dictionary = {}
	var lose_report: bool = false
	var lose_block: bool = false
	var accepted: bool = false
	var switch_account: bool = false
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		calls.append({"path":path,"method":method,"payload":payload.duplicate(true)})
		var data: Dictionary = {}
		if switch_account:
			player = {"id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}
			safety.identity_changed()
			switch_account = false
		if path == "/community/terms":
			if method == HTTPClient.METHOD_POST: accepted = true
			data = {"version":"bmt-community-2026-10-16","text":"Public sharing rules\nNo harassment or hateful, sexual, illegal or private content. Report and block in the game.","accepted":accepted,"accepted_at":1 if accepted else null}
		elif path == "/community/blocks":
			data.items = []
			for id: String in remote_blocks: data.items.append({"player_id":id,"display_name":remote_blocks[id]})
		elif path.begins_with("/community/blocks/"):
			if lose_block: return _failure("NETWORK_ERROR")
			var id: String = path.get_file()
			if method == HTTPClient.METHOD_PUT: remote_blocks[id] = "Reported author"
			else: remote_blocks.erase(id)
			data = {"player_id":id,"blocked":method == HTTPClient.METHOD_PUT}
		elif path == "/reports" and method == HTTPClient.METHOD_POST:
			if not remote_reports.has(payload.command_id): remote_reports[payload.command_id] = {"id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","status":"open"}
			if lose_report: return _failure("NETWORK_ERROR")
			data = remote_reports[payload.command_id]
		elif path == "/reports": data = {"items":[],"has_more":false}
		else: return _failure("UNEXPECTED_REQUEST")
		return {"ok":true,"status":200,"error":"","data":data}

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func make_client() -> MockClient:
	var client := MockClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client.session_path = folder.path_join("session.cfg")
	client.player = {"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}
	client.safety.identity_changed()
	client._access_token = "fixture-access"
	return client

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../temp/community-safety-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,800)
	if OS.get_environment("BMT_COMMUNITY_SIZE") == "960x540": root.size = Vector2i(960,540)
	root.gui_embed_subwindows = true
	var client := make_client()
	var creator: String = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
	var entry: Dictionary = {"creator_id":creator,"version_id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"}
	client.lose_block = true
	var blocked: Dictionary = await client.safety.set_block(creator,"Reported author",true)
	check(not blocked.ok and client.safety.is_blocked(creator),"offline block immediately hides content and retains a sync operation")
	check(not client.safety.allows(entry) and client.safety.pending_blocks.has(creator),"cached track guard and pending operation share identity")
	var cloud := preload("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = folder.path_join("catalog-fixture")
	root.add_child(cloud)
	var metadata: Dictionary = {"creator_id":creator,"creator":"Reported author","name":"Public loop",
		"version_id":entry.version_id,"track_id":"ffffffff-ffff-4fff-8fff-ffffffffffff","content_hash":"a".repeat(64),
		"points":[],"rating_average":null,"rating_count":0}
	check(cloud._write(cloud.cache_root().path_join("index.json"),{"entries":[metadata]}) and cloud._retain_metadata(metadata),"actual offline catalog and favorite metadata fixture is durable")
	cloud.load_cached()
	check(cloud.entries.is_empty() and cloud.retained_entry("cloud_"+str(metadata.track_id)).is_empty(),"actual offline catalog and retained favorites hide blocked creator")
	var requests_before: int = client.calls.size()
	check((await cloud.download_document(cloud.entry_from_metadata(metadata))).is_empty() and client.calls.size() == requests_before,"blocked cached launch is rejected before any download")
	cloud.queue_free()
	await process_frame
	var restored := make_client()
	check(restored.safety.is_blocked(creator),"private block survives a process restart")
	await restored.safety.refresh()
	check(restored.remote_blocks.has(creator) and restored.safety.pending_blocks.is_empty(),"reconnect syncs pending block before fetching server list")
	var rows: Array = [{"player_id":creator,"display_name":"Abusive name","rank":2,"time_ticks":1200},
		{"id":creator,"name":"Abusive name","appearance":{"vehicle_id":"compact"},"points":20}]
	restored.safety.mask_public(rows)
	check(rows[0].display_name == "Blocked player" and rows[0].rank == 2 and rows[0].time_ticks == 1200,"blocking hides public identity while retaining historical rank and time")
	check(rows[1].name == "Blocked player" and not rows[1].has("appearance") and rows[1].points == 20,"blocked podium cosmetics are suppressed without score changes")
	check((await restored.safety.set_block(creator,"Reported author",false)).ok and restored.safety.allows(entry),"acknowledged unblock restores the author's content")
	var body: Dictionary = {"reported_player_id":creator,"reason":"harassment","text":"Abusive public name"}
	client.lose_report = true
	var sent: Dictionary = await client.safety.report(body)
	check(not sent.ok and client.safety.pending_reports.size() == 1 and client.remote_reports.size() == 1,"lost receipt preserves report after server acceptance")
	var request_id: String = str(client.safety.pending_reports.values()[0].command_id)
	check(RegEx.create_from_string("^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$").search(request_id) != null,"report command uses the backend's UUID contract")
	var retry := make_client()
	retry.remote_reports = client.remote_reports
	await retry.safety.refresh()
	check(retry.remote_reports.size() == 1 and retry.safety.pending_reports.is_empty(),"restart reuses exact report command and clears only acknowledged recovery")
	check(retry.calls.any(func(item: Dictionary) -> bool: return item.path == "/reports" and item.payload.command_id == request_id),"report retry preserves its original command ID")
	var terms: Dictionary = (await retry.safety.terms()).data
	var capture_dir: String = OS.get_environment("BMT_COMMUNITY_CAPTURE")
	if not capture_dir.is_empty():
		var full_terms: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_dir.path_join("terms.json")))
		if full_terms is Dictionary: terms = full_terms
	check(Client.valid_response("/community/terms",HTTPClient.METHOD_GET,{"version":terms.version,"accepted":false,"text":"x".repeat(3000)}),"complete policy text has a bounded contract distinct from short IDs")
	var sheet: Node = UI.open(root,retry,"terms",terms)
	check(sheet.find_child("AcceptCommunityTerms",true,false) != null and sheet.get_ok_button().disabled,"terms acceptance is never preselected")
	await capture("terms")
	sheet.consent.button_pressed = true
	await sheet._submit()
	check(retry.accepted and retry.calls[-1].payload == {"version":terms.version,"accepted":true},"accept records precisely the displayed rules version")
	await process_frame
	var report: Node = UI.open(root,retry,"report",{"reported_player_id":creator,"name":"Public loop","track_id":"ffffffff-ffff-4fff-8fff-ffffffffffff","version_id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"})
	report.details.text = ""
	var before: int = retry.calls.size()
	await report._submit()
	check(retry.calls.size() == before and report.status.text.contains("1–2000"),"blank reports fail before network submission")
	report.details.text = "Harassment in the track name"
	report.details.text_changed.emit()
	check(report.status.text.is_empty(),"editing report details clears the prior validation message")
	report.reasons.select(1)
	await capture("report")
	await report._submit()
	check(retry.calls[-1].payload.reason == "hate" and report.status.text.begins_with("Report sent."),"selected reason is submitted and success includes case reference")
	report.queue_free()
	await process_frame
	retry.safety.blocked[creator] = "Reported author"
	var manage: Node = UI.open(root,retry)
	check(manage.title == "Community safety","native account safety entry opens")
	await capture("blocked-players")
	manage.queue_free()
	await process_frame
	var signed_out := MockClient.new()
	root.add_child(signed_out)
	var guest: Node = UI.open(root,signed_out,"report",{})
	check(guest.body.get_child(0).text.contains("Sign in"),"guest reporting gives actionable sign-in guidance")
	guest.queue_free()
	await process_frame
	var fenced := make_client()
	fenced.switch_account = true
	var outcome: Dictionary = await fenced.safety.report(body)
	check(not outcome.ok and outcome.error == "ACCOUNT_CHANGED" and fenced.safety.pending_reports.is_empty(),"late report reply cannot modify another account's recovery")
	for node: Node in [client,restored,retry,signed_out,fenced]: node.queue_free()
	await process_frame
	print("COMMUNITY_SAFETY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

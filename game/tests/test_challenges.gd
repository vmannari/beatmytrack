extends SceneTree
## Isolated adapter boundaries and real menu layouts; all displayed times are fixtures.
var checks: int = 0
var failures: int = 0
var capture_directory: String = ""

class StubClient extends Node:
	var player: Dictionary = {"id":"self"}
	var answer: Dictionary = {}
	var delay: float = 0.0
	var calls: int = 0
	var keys: Array[String] = []
	var last_path: String = ""
	var last_payload: Dictionary = {}
	func cancel_public_reads(_owner: int) -> void: pass
	func base_url() -> String: return "http://fixture"
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "fixture-operation-"+str(Time.get_ticks_usec())
	func request_api(_path: String, method: int, _payload: Dictionary, key: String, _auth: bool) -> Dictionary:
		calls += 1
		last_path = _path
		last_payload = _payload.duplicate(true)
		if method == HTTPClient.METHOD_POST: keys.append(key)
		var response: Dictionary = answer.duplicate(true)
		if delay > 0.0: await get_tree().create_timer(delay).timeout
		return response

func _initialize() -> void: call_deferred("run")

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+detail)

func fixture(group: bool = false) -> Dictionary:
	var value: Dictionary = {"id":"challenge","code":"AB12CD34EF56AB78","mode":"group" if group else "beat","state":"active",
		"creator_id":"rival","creator":"Mika","self_id":"self","joined":true,"vehicle_id":"compact",
		"created_at":0,"ends_at":604800,"server_now":432000,"remaining_seconds":172800,
		"manifest":{"laps":5,"tick_rate":120},"target_ms":98250 if not group else null,"target_ticks":11790 if not group else null,
		"entry":{"name":"Forest Run","creator":"Beat my track","theme":"pine","version_id":"00000000-0000-0000-0000-000000000001","track_id":"00000000-0000-0000-0000-000000000002","content_hash":"a".repeat(64),"points":[[0,0],[100,0],[120,70],[40,90],[-10,30]]},
		"share_url":"https://fixture/c/AB12CD34EF56AB78","standings":[]}
	for i: int in range(20 if group else 2):
		value.standings.append({"id":"self" if i == 1 else "rival" if i == 0 else "driver_%02d" % i,
			"name":"You" if i == 1 else "Mika" if i == 0 else "Driver %02d" % i,
			"country_code":"FI","rank":i+1,"ticks":11790+i*120,"ms":98250+i*1000,"run_id":"run_%d" % i})
	return value

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	capture_directory = OS.get_environment("BMT_CHALLENGE_CAPTURE_DIR")
	var sample: Dictionary = fixture()
	check(ChallengesClient.valid_snapshot(sample),"two-player invitation validates")
	check(ChallengesClient.valid_snapshot(fixture(true)),"twenty-driver group validates")
	check(ChallengesClient.code_from("https://fixture/c/AB12CD34EF56AB78?x=1") == sample.code,"HTTPS invitation code opens")
	check(ChallengesClient.code_from("beatmytrack://challenge/ab12cd34ef56ab78") == sample.code,"native invitation code opens")
	check(ChallengesClient.code_from("AB12-CD34-EF56-AB78") == sample.code,"readable grouped code opens")
	for bad: String in ["", "abc", "../../secrets", "AB12CD34EF56AB7Z", "0xAB12CD34EF56AB78"]:
		check(ChallengesClient.code_from(bad).is_empty(),"malformed code is rejected: "+bad)
	for mutation: String in ["duplicate","nonfinite","overflow","laps","unknown_car","joined"]:
		var bad: Dictionary = sample.duplicate(true)
		match mutation:
			"duplicate": bad.standings.append(bad.standings[0])
			"nonfinite": bad.entry.points[0][0] = NAN
			"overflow": bad.standings[0].ticks = 216001
			"laps": bad.manifest.laps = 3
			"unknown_car": bad.vehicle_id = "external"
			"joined": bad.joined = false
		check(not ChallengesClient.valid_snapshot(bad),"invalid server snapshot rejected: "+mutation)
	for limit: Variant in [null,1,3,5]:
		var limited: Dictionary = sample.duplicate(true)
		limited.attempt_limit = limit
		limited.attempts_used = 1
		limited.attempts_remaining = null if limit == null else int(limit)-1
		check(ChallengesClient.valid_snapshot(limited),"valid remaining tries are accepted")
		limited.attempts_remaining = 9
		check(not ChallengesClient.valid_snapshot(limited),"inconsistent remaining tries are rejected")
	await _adapter_tests(sample)
	await _finished_sheet_tests(sample)
	await _page_tests()
	print("CHALLENGES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _adapter_tests(sample: Dictionary) -> void:
	var client := StubClient.new()
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://challenge_adapter_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	client.answer = {"ok":false,"error":"NETWORK_ERROR"}
	var payload: Dictionary = {"version_id":sample.entry.version_id,"vehicle_id":"compact","mode":"group"}
	await adapter.create_challenge(payload)
	await adapter.create_challenge(payload)
	check(client.keys.size() == 2 and client.keys[0] == client.keys[1],"creation reconnect retries use the same persisted operation key")
	client.answer = {"ok":true,"data":sample}
	await adapter.create_challenge(payload)
	check(adapter.selected.code == sample.code and not adapter.busy,"successful creation selects actual server invitation")
	await adapter.create_challenge(payload)
	check(client.keys[-1] != client.keys[-2],"a second deliberate creation gets a new operation key")
	var newer: Dictionary = sample.duplicate(true)
	newer.standings[1].ticks = 11700
	newer.standings[1].ms = 97500
	newer.standings[1].rank = 1
	client.answer = {"ok":true,"data":{"items":[newer],"next_cursor":null}}
	await adapter.refresh()
	check(adapter.selected.standings[1].ms == 97500 and adapter.selected.target_ticks == sample.target_ticks,"menu refresh reveals new verified standings while retaining the frozen target")
	client.answer = {"ok":true,"data":sample}
	client.delay = 0.03
	adapter.open(sample.code)
	adapter.reset()
	await create_timer(0.06).timeout
	check(adapter.selected.is_empty(),"stale invitation response cannot cross an account generation")
	client.delay = 0.0
	adapter.selected = sample
	adapter.begin_result("ticket")
	client.answer = {"ok":true,"data":{"status":"verified","outcome":{"counted":true,"beaten":true},"challenge":sample}}
	await adapter.poll_result()
	check(adapter.result_state == "verified" and adapter.outcome.beaten,"verified feedback replaces pending result")
	var requests: int = client.calls
	await adapter.poll_result()
	check(client.calls == requests,"terminal verification stops polling")
	adapter.begin_result("next_ticket")
	client.answer = {"ok":false,"error":"NETWORK_ERROR"}
	await adapter.poll_result()
	requests = client.calls
	await adapter.poll_result()
	check(client.calls == requests and adapter.result_state == "upload_pending","connection failure backs off without inventing results")
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame

func _finished_sheet_tests(sample: Dictionary) -> void:
	var client := StubClient.new()
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://challenge_sheet_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	var ticket: String = "12345678-1234-1234-1234-123456789abc"
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await process_frame
		client.answer = {"ok":false,"error":"Not Found"}
		var sheet := ChallengeCreate.new()
		sheet.adapter = adapter
		sheet.initial_version = str(sample.entry.version_id)
		sheet.initial_vehicle = "compact"
		sheet.initial_ticket = ticket
		sheet.result_context = {"entry":sample.entry.duplicate(true),"vehicle_id":"compact","ticket_id":ticket,"total":88.110,"laps":5,"scope":adapter.scope()}
		root.add_child(sheet)
		MenuStyle.fill(sheet)
		sheet.popup_centered()
		while sheet._checking: await process_frame
		await process_frame
		check(sheet.locked_result() and sheet._track == null and sheet._vehicle == null and sheet._search == null,"post-race sheet has no track/car/search selectors")
		check(not sheet._race.visible and sheet.get_ok_button().disabled,"missing service retains the finished result without offering a rerace")
		check(sheet._time.text == MenuStyle.time_text(88.110),"post-race sheet immediately displays the exact finish instead of a PB")
		check("ticket_id="+ticket in client.last_path,"source request always identifies the completed ticket")
		client.answer = {"ok":true,"data":{"status":"verifying","run_id":null,"ms":null}}
		await sheet._check_source()
		check(not sheet._race.visible and sheet.get_ok_button().disabled,"verification stays pending without falling back to an earlier time")
		client.answer = {"ok":true,"data":{"status":"verified","run_id":"finished","ms":88110}}
		await sheet._check_source()
		check(not sheet.get_ok_button().disabled and sheet._time.text == MenuStyle.time_text(88.110),"verification enables creation for this completed race")
		var rect: Rect2 = sheet._panel.get_global_rect()
		check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= root.get_visible_rect().size.x+1 and rect.end.y <= root.get_visible_rect().size.y+1,"custom sheet stays within the viewport")
		check(sheet.get_parent() == root,"creation is an embedded menu control")
		sheet._choose_attempt_limit(3)
		check(sheet._summary_tries.text == "3","summary reflects selected tries")
		await _capture("finished-page",dimensions)
		client.answer = {"ok":false,"error":"NETWORK_ERROR"}
		await sheet._create()
		check(sheet._notice.is_visible_in_tree() and not sheet._notice.text.is_empty(),"failed creation keeps its actionable error visible")
		client.answer = {"ok":true,"data":sample}
		await sheet._create()
		check(client.last_payload.get("source_ticket_id") == ticket and not client.last_payload.has("source_run_id"),"creation submits the exact finished ticket and never a PB fallback")
		check(client.last_payload.get("attempt_limit") == 3,"selected tries are submitted with the exact result")
		sheet.queue_free()
		await process_frame
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame

func _page_tests() -> void:
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await process_frame
		var folder: String = "user://challenge_menu_"+TrackLibrary.unique_id()
		DirAccess.make_dir_recursive_absolute(folder)
		var app: Node = load("res://core/app.tscn").instantiate()
		app.records = LocalRecords.new(folder.path_join("records.json"))
		app.library = TrackLibrary.new(folder.path_join("tracks"))
		app.cloud_root_override = folder.path_join("cloud")
		root.add_child(app)
		while not app.startup_complete: await process_frame
		app.online.client.player = {"id":"self"}
		app.online.client._access_token = "fixture"
		app.challenges.reset()
		app.challenges.items.assign([fixture(),fixture(true)])
		app.challenges.items[1].code = "BC23DE45FA67BC89"
		app.challenges.selected = fixture()
		app.challenges.busy = true # Isolate presentation from external services.
		app._open_challenges()
		app.challenges.busy = false
		app._challenges()
		await process_frame
		await process_frame
		var page: ChallengesPage = app.root_ui.find_child("ChallengesPage",true,false)
		check(page != null and app.screen == "challenges" and app.race_area_mode == "challenges","target icon opens Challenges within Race")
		check((page.find_child("Mode_target",true,false) as Button).disabled == false,"Challenges rail button is enabled")
		check((page.find_child("ChallengeRace",true,false) as Button).disabled == false,"joined recipient can race")
		check(page.find_child("ChallengeRoute",true,false) != null,"invitation shows actual route geometry")
		_bounds(page,"ChallengeActions",dimensions)
		_bounds(page,"ChallengeHeader",dimensions)
		await _capture("received",dimensions)
		app.challenges.selected = fixture(true)
		app.challenges.selected.code = app.challenges.items[1].code
		app._challenges()
		await process_frame
		await process_frame
		page = app.root_ui.find_child("ChallengesPage",true,false)
		var scroll: ScrollContainer = page.find_child("ChallengeStandingsScroll",true,false)
		check(scroll.get_v_scroll_bar().max_value > scroll.size.y,"twenty-driver standings scroll within the detail panel")
		check((page.find_child("ChallengeDriver_self",true,false) as PanelContainer).get_theme_stylebox("panel").bg_color == MenuStyle.ACCENT,"player row uses the established yellow highlight")
		await _capture("group",dimensions)
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await process_frame
		await _capture("group-bottom",dimensions)
		app.challenges.selected.attempt_limit = 3
		app.challenges.selected.attempts_used = 3
		app.challenges.selected.attempts_remaining = 0
		app._challenges()
		await process_frame
		page = app.root_ui.find_child("ChallengesPage",true,false)
		check((page.find_child("ChallengeRace",true,false) as Button).disabled,"exhausted challenge disables a new race")
		app._create_challenge_dialog()
		await process_frame
		await process_frame
		var create: ChallengeCreate = app.root_ui.find_child("ChallengeCreate",true,false)
		check(create != null and app.screen == "challenge_create" and create.get_parent() == app.content,"general creation occupies the menu page")
		check(app.root_ui.find_child("MenuHeader",true,false) != null,"creation keeps the original top navigation")
		create._source = {"status":"verified","run_id":"fixture","ms":88110}
		create._checking = false
		create._choose_attempt_limit(3)
		create._update()
		await process_frame
		await process_frame
		_bounds(create,"ChallengeCreateActions",dimensions)
		_bounds(create,"ChallengeCreatePanel",dimensions)
		var choices_scroll: ScrollContainer = create.find_child("ChallengeSettingsScroll",true,false)
		check(choices_scroll.get_v_scroll_bar().max_value <= choices_scroll.size.y+1,"all default setting rows are immediately visible")
		var aligned_x: float = -1.0
		for caption: String in ["TRACK","CHALLENGETYPE","CAR","TARGETTIME","NUMBEROFTRIES","DURATION"]:
			var choices: Control = create.find_child("ChallengeChoices_"+caption,true,false)
			if aligned_x < 0.0: aligned_x = choices.global_position.x
			check(absf(choices.global_position.x-aligned_x) <= 1.0,"creation control column aligns: "+caption)
		var summary_x: float = create._summary_car.global_position.x
		for value: Label in [create._summary_time,create._summary_tries,create._summary_duration]:
			check(absf(value.global_position.x-summary_x) <= 1.0,"preview values share one left edge")
		var header: Control = create.find_child("ChallengeCreateHeader",true,false)
		check(absf(header.global_position.y-create._panel.global_position.y) <= 1.0,"preview starts alongside the heading")
		check(absf(choices_scroll.get_global_rect().end.y-create._panel.get_global_rect().end.y) <= 1.0,"settings and preview share a bottom edge")
		create._choose_mode(1)
		check(create._summary_time.text == "Fastest time wins" and not create._time.visible,"group preview has no timed target")
		await _capture("menu-create-group",dimensions)
		create._choose_mode(0)
		await process_frame
		await _capture("menu-create",dimensions)
		create.close()
		await process_frame
		check(app.screen == "challenges","Cancel returns to Challenges")
		app.challenge_result_view = true
		app.challenges.result_state = "upload_pending"
		app._challenges()
		await process_frame
		page = app.root_ui.find_child("ChallengesPage",true,false)
		check((page.find_child("ChallengeResultFeedback",true,false) as Label).text == "Verifying","pending challenge results remain honest")
		app.challenges.result_state = "verified"
		app.challenges.outcome = {"counted":true,"beaten":true,"gap_ms":-370}
		app.challenges.selected = fixture()
		app.challenges.selected.standings[1].ticks = 11700
		app.challenges.selected.standings[1].rank = 1
		app._challenges()
		await process_frame
		page = app.root_ui.find_child("ChallengesPage",true,false)
		check("-0.370" in (page.find_child("ChallengeResultFeedback",true,false) as Label).text,"verified target result shows signed time gap")
		_bounds(page,"ChallengeActions",dimensions)
		await _capture("result",dimensions)
		app.challenge_result_view = false
		app._show_screen("tracks")
		check(app.root_ui.find_child("Mode_target",true,false) != null,"Free Race keeps the shared challenge entry point")
		app.queue_free()
		await process_frame
		await process_frame

func _bounds(page: Control, name: String, dimensions: Vector2i) -> void:
	var node: Control = page.find_child(name,true,false)
	var rectangle: Rect2 = node.get_global_rect()
	check(rectangle.position.x >= -1 and rectangle.position.y >= -1 and rectangle.end.x <= root.get_visible_rect().size.x+1 and rectangle.end.y <= root.get_visible_rect().size.y+1,"%s stays inside %s" % [name,str(dimensions)])

func _capture(label: String, dimensions: Vector2i) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	var path: String = capture_directory.path_join("%s-%dx%d.png" % [label,dimensions.x,dimensions.y])
	check(root.get_texture().get_image().save_png(path) == OK,"capture saved: "+label)

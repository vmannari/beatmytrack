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
	func base_url() -> String: return "http://fixture"
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "fixture-operation-"+str(Time.get_ticks_usec())
	func request_api(_path: String, method: int, _payload: Dictionary, key: String, _auth: bool) -> Dictionary:
		calls += 1
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
	await _adapter_tests(sample)
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
	await RenderingServer.frame_post_draw
	var path: String = capture_directory.path_join("%s-%dx%d.png" % [label,dimensions.x,dimensions.y])
	check(root.get_texture().get_image().save_png(path) == OK,"capture saved: "+label)

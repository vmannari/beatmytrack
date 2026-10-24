extends SceneTree
## Real menu presentation plus discovery/account response fences, with explicit fixtures.
var checks: int = 0
var failures: int = 0
var filters: Array = []
var output: String

class StubClient extends Node:
	var player: Dictionary = {"id":"self"}
	var _capabilities: Dictionary = {"challenge_discovery_version":1}
	var answer: Dictionary = {}
	var delay: float = 0.0
	var authenticated: bool = true
	var paths: Array[String] = []
	func base_url() -> String: return "http://fixture"
	func signed_in() -> bool: return authenticated
	func new_operation_key() -> String: return "fixture-operation-"+str(Time.get_ticks_usec())
	func request_api(path: String, _method: int, _payload: Dictionary, _key: String, _auth: bool) -> Dictionary:
		paths.append(path)
		var response: Dictionary = answer.duplicate(true)
		if delay > 0.0: await get_tree().create_timer(delay).timeout
		return response

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func sample(index: int = 0) -> Dictionary:
	return {"id":"challenge-"+str(index),"code":["AB12CD34EF56AB78","BC23DE45FA67BC89","CD34EF56AB78CD90"][index],
		"mode":"group" if index == 1 else "beat","state":"active","visibility":"public","capacity":20 if index == 1 else 2,
		"creator_id":"rival","creator":["Mika","Elena","Oskar"][index],"self_id":"self","joined":false,"vehicle_id":"compact",
		"created_at":0,"ends_at":604800,"server_now":432000,"manifest":{"laps":5,"tick_rate":120},
		"target_ms":98250 if index != 1 else null,"target_ticks":11790 if index != 1 else null,
		"entry":{"name":["Forest Run","Midnight Circuit","Coastal Sprint"][index],"creator":"Beat my track","theme":["pine","night_city","desert"][index],
		"version_id":"00000000-0000-0000-0000-000000000001","track_id":"00000000-0000-0000-0000-000000000002","content_hash":"a".repeat(64),"points":[[0,0],[100,0],[120,70],[40,90],[-10,30]]},
		"share_url":"https://fixture/c/AB12CD34EF56AB78","standings":[{"id":"rival","name":["Mika","Elena","Oskar"][index],"ticks":11790,"ms":98250,"rank":1,"run_id":"run"}],
		"rewards":{"finish":50,"goal":100,"finish_earned":false,"goal_earned":false,"eligible":true,"daily_limit":3,"remaining_today":3}}

func settle() -> void:
	for tick: int in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func bounds(node: Control, detail: String) -> void:
	var area: Rect2 = node.get_global_rect()
	var viewport: Rect2 = root.get_visible_rect()
	check(area.position.x >= -1 and area.position.y >= -1 and area.end.x <= viewport.end.x+1 and area.end.y <= viewport.end.y+1,detail+" fits "+str(viewport.size))

func adapters() -> void:
	var client := StubClient.new()
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://challenge-discovery-fixture-"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	check(adapter.folder == "discover" and adapter.discovery_supported(),"new clients enter discovery")
	var item: Dictionary = sample()
	check(ChallengesClient.valid_snapshot(item),"reward metadata validates")
	var points: Array = []
	for index: int in range(4096): points.append([index,sin(float(index))])
	var outline: PackedVector2Array = ChallengesPage._card_outline(points)
	check(outline.size() == 96 and outline[0].x == 0 and outline[-1].x == 4095,"card outlines bound work and preserve both ends")
	item.rewards.remaining_today = 4
	check(not ChallengesClient.valid_snapshot(item),"inconsistent reward limits are rejected")
	client.answer = {"ok":true,"data":{"items":[sample()],"next_cursor":null}}
	client.delay = 0.03
	adapter.refresh()
	adapter.set_filters("Night & rain","group","compact","newest")
	await create_timer(0.12).timeout
	for tick: int in range(60):
		if not adapter.busy: break
		await process_frame
	check(client.paths.size() == 2 and "Night%20%26%20rain" in client.paths[-1] and "mode=group" in client.paths[-1],"in-flight refresh drains the latest search and filters")
	check(not adapter.busy and not adapter.items.is_empty(),"latest discovery response settles")
	client.authenticated = false
	adapter.reset()
	await adapter.refresh()
	check(client.paths[-1].begins_with("/challenges/discover?"),"guest discovery uses the public route")
	adapter.select_folder("friends")
	check(adapter.error.begins_with("Sign in"),"private folders explain the sign-in requirement")
	adapter.folder = "discover"
	client.authenticated = true
	adapter.reset()
	adapter.refresh()
	adapter.reset()
	await create_timer(0.06).timeout
	check(adapter.items.is_empty() and adapter.selected.is_empty(),"late discovery cannot cross account reset")
	client._capabilities.clear()
	adapter.selected = sample()
	var calls: int = client.paths.size()
	await adapter.refresh()
	check(client.paths.size() == calls and adapter.error.contains("updated online service"),"older services get actionable discovery availability")
	check(not adapter.selected.is_empty(),"older services retain a directly opened private invitation")
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_CHALLENGE_DISCOVERY_OUTPUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../docs/evidence/challenge-rework-2026-10-16/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	await adapters()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		var app: Node = load("res://core/app.tscn").instantiate()
		var folder: String = "user://challenge-rework-"+TrackLibrary.unique_id()
		app.records = LocalRecords.new(folder.path_join("records.json"))
		app.library = TrackLibrary.new(folder.path_join("tracks"))
		app.cloud_root_override = folder.path_join("cloud")
		root.add_child(app)
		while not app.startup_complete: await process_frame
		app.online.client.player = {"id":"self"}
		app.online.client._access_token = "fixture"
		app.online.client._capabilities.challenge_discovery_version = 1
		app.challenges.reset()
		app.challenges.items.assign([sample(),sample(1),sample(2)])
		app.challenges.selected = sample()
		app.challenges.busy = true
		app._open_challenges()
		app.challenges.busy = false
		app._challenges()
		await settle()
		var page: ChallengesPage = app.root_ui.find_child("ChallengesPage",true,false)
		for identity: String in ["ChallengeHeader","ChallengeTab_discover","ChallengeTab_friends","ChallengeTab_received","ChallengeTab_sent","ChallengeSearch","ChallengeActions"]:
			bounds(page.find_child(identity,true,false),identity)
		check(page.find_children("*","Button",true,false).all(func(button: Button) -> bool: return button.text != "Enter code"),"discovery has no code-entry action")
		check((page.find_child("ChallengeRace",true,false) as Button).text == "Join & race","public race joins directly")
		check(page.find_child("ChallengeRewards",true,false) != null,"both concrete reward goals appear")
		check(page._reward_caption(sample()) == "Up to 150 Coins","card reward matches server amounts")
		page.filters_requested.connect(func(query: String, mode: String, car: String, order: String) -> void: filters = [query,mode,car,order])
		page._search.text = "Mika"
		# Disconnect the app callback to keep this explicit presentation fixture offline.
		page.filters_requested.disconnect(app.challenges.set_filters)
		page._apply_filters()
		check(filters == ["Mika","all","","ending"],"find action carries the complete filter intent")
		await capture("discover-%dx%d" % [dimensions.x,dimensions.y])
		var scroll: ScrollContainer = page.find_child("ChallengeDetailScroll",true,false)
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await settle()
		bounds(page.find_child("ChallengeRewards",true,false),"reward goals after scroll")
		await capture("rewards-%dx%d" % [dimensions.x,dimensions.y])
		app.challenges.selected.rewards.finish_earned = true
		app.challenges.selected.rewards.goal_earned = true
		app.challenges.selected.joined = true
		app.challenges.selected.standings[0].rank = 2
		app.challenges.selected.standings.push_front({"id":"self","name":"You","ticks":11500,"ms":95833,"rank":1,"run_id":"self-run"})
		app._challenges()
		await settle()
		page = app.root_ui.find_child("ChallengesPage",true,false)
		check(page._reward_caption(app.challenges.selected) == "Rewards earned","earned progress replaces reward promises")
		app.challenge_result_view = true
		app.challenges.result_state = "verified"
		app.challenges.outcome = {"counted":true,"beaten":true,"gap_ms":-2417}
		app._challenges()
		await settle()
		page = app.root_ui.find_child("ChallengesPage",true,false)
		bounds(page.find_child("ChallengeRewardProgress",true,false),"result reward progress")
		bounds(page.find_child("ChallengeActions",true,false),"result actions")
		await capture("result-%dx%d" % [dimensions.x,dimensions.y])
		app.challenge_result_view = false
		app._challenges()
		app._create_challenge_dialog()
		await settle()
		var create: ChallengeCreate = app.root_ui.find_child("ChallengeCreate",true,false)
		create._source = {"status":"verified","run_id":"fixture","ms":98250}
		create._checking = false
		create._update()
		await settle()
		check(create.find_child("ChallengeVisibility",true,false) != null,"creator explicitly chooses public or private")
		bounds(create.find_child("ChallengeVisibility",true,false),"public/private choice")
		bounds(create.find_child("ChallengeCreateActions",true,false),"creation actions")
		await capture("create-%dx%d" % [dimensions.x,dimensions.y])
		create.close()
		await process_frame
		while not app.online.client._encoding_threads.is_empty(): await process_frame
		app.queue_free()
		await settle()
	print("CHALLENGE DISCOVERY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

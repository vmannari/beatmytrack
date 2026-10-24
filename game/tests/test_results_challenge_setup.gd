extends SceneTree
## Results-only choices, exact receipt authority, request fencing and native layout.
var checks: int = 0
var failures: int = 0
var evidence: String = "res://../docs/evidence/results-challenge-setup-2026-10-24/ui"

class StubClient extends Node:
	signal released
	var player: Dictionary = {"id":"results-fixture"}
	var _capabilities: Dictionary = {"challenge_discovery_version":1,"challenge_series_version":1,"challenge_custom_tracks_version":1}
	var status: Dictionary = {"ok":true,"data":{"status":"verified","run_id":"slower-finish","ms":110000}}
	var hold: bool = false
	var creates: int = 0
	var payload: Dictionary = {}
	var source_path: String = ""
	func base_url() -> String: return "http://results-fixture"
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "results-"+str(Time.get_ticks_usec())
	func cancel_public_reads(_owner: int) -> void: pass
	func request_api(path: String, _method: int, body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		if path.begins_with("/challenges/sources?"):
			source_path = path
			var answer: Dictionary = status.duplicate(true)
			if hold: await released
			return answer
		creates += 1
		payload = body.duplicate(true)
		if hold: await released
		return {"ok":false,"error":"Connection interrupted. Try again."}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+detail)

func settle() -> void:
	for frame: int in range(6): await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var folder: String = evidence.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	check(root.get_texture().get_image().save_png(folder.path_join(label+".png")) == OK,"capture "+label)

func press(page: ChallengeCreate, id: String) -> void:
	(page.find_child(id,true,false) as Button).pressed.emit()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var client := StubClient.new()
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://results-setup-"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	adapter.creation_visibility = "private"
	var entry: Dictionary = {"version_id":"00000000-0000-0000-0000-000000000001","track_id":"00000000-0000-0000-0000-000000000002","name":"Forest Run","creator":"Fixture driver","theme":"pine","content_hash":"a".repeat(64),"points":[[0,0],[100,0],[120,70],[40,90]]}
	var page := ChallengeCreate.new()
	page.adapter = adapter
	page.results_only = true
	page.initial_ticket = "exact-slower-ticket"
	page.initial_vehicle = "pickup"
	page.result_context = {"entry":entry,"total":110.0,"scope":adapter.scope()}
	root.add_child(page)
	MenuStyle.fill(page)
	await settle()
	check(page._step == ChallengeCreate.RESULT and page._custom_page.is_visible_in_tree(),"results open directly on the restricted choices")
	check(page._browser == null and page._car_art == null and page._car_models.is_empty(),"results setup prepares no track browser or car worlds")
	check(page._rules_fields.get_child_count() == 3 and page.find_child("ChallengeTrackCount_1",true,false) == null and page.find_child("ChallengeCustomVisibility_public",true,false) == null,"only mode, duration and tries are selectable")
	check(not page._format_page.is_visible_in_tree() and not page._track_page.is_visible_in_tree() and not page._car_page.is_visible_in_tree(),"main creation steps stay hidden")
	check(page.get_ok_button().text == "Create & share" and not page.get_ok_button().disabled and not page._share.visible and not page._race.visible and not page._rules_button.visible,"one final action creates and shares without an extra race")
	check(client.source_path.contains("ticket_id=exact-slower-ticket") and page._time.text == MenuStyle.time_text(110.0),"source verification and displayed time use the exact slower finish")
	page._choose_format("three")
	page._open_rules()
	page._ensure_browser()
	page._select_track({"version_id":"other","name":"Other track"})
	page._select_car("formula")
	check(page._step == ChallengeCreate.RESULT and page._required_tracks() == 1 and page._entry() == entry and page._vehicle_id() == "pickup" and page._browser == null,"results cannot enter multi-track, track or vehicle selection")
	for mode: int in [0,1]:
		press(page,"ChallengeResultMode_"+str(mode))
		for seconds: int in [86400,259200,604800]:
			press(page,"ChallengeDuration_"+str(seconds))
			for tries: int in [0,1,3,5]:
				press(page,"ChallengeTries_"+str(tries))
				await page._create()
				check(client.payload.get("mode") == ("beat" if mode == 0 else "group") and client.payload.duration_seconds == seconds and int(client.payload.get("attempt_limit",0)) == tries,"selected rules reach the server: "+str([mode,seconds,tries]))
				check(client.payload.source_ticket_id == "exact-slower-ticket" and client.payload.version_id == entry.version_id and client.payload.vehicle_id == "pickup" and not client.payload.has("source_run_id") and not client.payload.has("version_ids") and not page.start_after_create,"every combination retains the single completed race")
	check(page._notice.text.contains("Connection interrupted") and not page.get_ok_button().disabled,"failed creation shows a useful error and allows retry")
	page._update()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390),Vector2i(390,844)]:
		root.size = dimensions
		await settle()
		var dock: Control = page.find_child("ChallengeCreateActions",true,false)
		var scroll: ScrollContainer = page.find_child("ChallengeCreationScroll",true,false)
		check(root.get_visible_rect().encloses(dock.get_global_rect()) and root.get_visible_rect().encloses(page.get_ok_button().get_global_rect()),"final action stays on screen at "+str(dimensions))
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"choices do not overflow horizontally at "+str(dimensions))
		await capture(str(dimensions.x)+"x"+str(dimensions.y))
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await settle()
		check(scroll.get_global_rect().grow(1).encloses((page.find_child("ChallengeTries_5",true,false) as Control).get_global_rect()),"last tries choice is fully reachable at "+str(dimensions))
		await capture(str(dimensions.x)+"x"+str(dimensions.y)+"-tries")
		scroll.scroll_vertical = 0
	client.status = {"ok":true,"data":{"status":"verifying"}}
	page._check_source()
	check(page.get_ok_button().disabled and page._notice.text.contains("Verifying"),"pending verification prevents creation")
	client.status = {"ok":false,"error":"Service unavailable"}
	page._check_source()
	check(page.get_ok_button().disabled and page._retry.visible,"unavailable verification exposes Retry")
	client.status = {"ok":true,"data":{"status":"verified","run_id":"slower-finish","ms":110000}}
	page._retry.pressed.emit()
	check(not page.get_ok_button().disabled,"successful verification retry enables creation")
	client.hold = true
	page._create()
	var admitted: int = client.creates
	page.get_ok_button().pressed.emit()
	press(page,"ChallengeResultMode_0")
	page._back()
	check(client.creates == admitted and page._submitting and page.visible and page.mode == 1,"in-flight creation blocks duplicate requests, rule edits and Back")
	client.hold = false
	client.released.emit()
	await settle()
	client.hold = true
	page._check_source()
	client.player.id = "changed-account"
	client.released.emit()
	await settle()
	var prior: int = page.attempt_limit
	press(page,"ChallengeTries_1")
	check(page.get_ok_button().disabled and page.attempt_limit == prior and page._notice.text.contains("Sign in again"),"late source reply cannot authorize another account or change its rules")
	var canceled: Dictionary = {"count":0}
	page.canceled.connect(func() -> void: canceled.count += 1)
	page._back()
	check(canceled.count == 1 and not page.visible,"Back closes the results setup directly")
	page.queue_free()
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await settle()
	print("RESULTS_CHALLENGE_SETUP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

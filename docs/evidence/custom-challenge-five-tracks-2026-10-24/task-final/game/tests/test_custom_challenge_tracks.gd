extends SceneTree
## Real five-track API receipt, native creation, stage routing and responsive views.
var checks: int = 0
var failures: int = 0
var receipt: Dictionary = {}
var output: String = ""

class StubClient extends Node:
	var player: Dictionary = {"id":"custom-track-fixture"}
	var _capabilities: Dictionary = {"challenge_series_version":1,"challenge_custom_tracks_version":1}
	var snapshot: Dictionary = {}
	var payload: Dictionary = {}
	var path: String = ""
	func base_url() -> String: return "http://custom-track-fixture"
	func server_now() -> int: return 0
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "custom-"+str(Time.get_ticks_usec())
	func cancel_public_reads(_owner: int) -> void: pass
	func request_api(value: String, _method: int, body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		path = value
		payload = body.duplicate(true)
		if value.begins_with("/challenges/sources?"): return {"ok":true,"data":{"status":"verified","run_id":"opening-best","ms":88900}}
		if value.contains("/tickets?"): return {"ok":true,"data":{"expires_at":9999999999,"attempt_limit":5,"attempts_used":1,"attempts_remaining":4}}
		return {"ok":true,"data":snapshot.duplicate(true)}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+detail)

func settle() -> void:
	for frame: int in range(6): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.content_scale_size = Vector2i.ZERO
	output = ProjectSettings.globalize_path("res://../docs/evidence/custom-challenge-five-tracks-2026-10-24/"+DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/custom_challenge_five_tracks_v1.json"))
	check(ChallengesClient.valid_snapshot(snapshot),"native validator accepts actual verified five-track API receipt")
	var duel: Dictionary = snapshot.duplicate(true)
	duel.mode = "beat"
	duel.capacity = 2
	check(ChallengesClient.valid_snapshot(duel),"two-person custom series retains its two-driver capacity")
	var unlimited: Dictionary = snapshot.duplicate(true)
	unlimited.attempt_limit = null
	unlimited.attempts_remaining = null
	for stage: Dictionary in unlimited.stages:
		stage.attempt_limit = null
		stage.attempts_remaining = null
	check(ChallengesClient.valid_snapshot(unlimited),"unlimited tries remain valid on all five tracks")
	for kind: String in ["six","missing","duplicate","budget","sum","count","car"]:
		var bad: Dictionary = snapshot.duplicate(true)
		match kind:
			"six": bad.stages.append(bad.stages[4].duplicate(true))
			"missing": bad.stages.remove_at(4)
			"duplicate": bad.stages[4].entry = bad.stages[3].entry
			"budget": bad.stages[4].attempts_remaining = 6
			"sum": bad.standings[0].ticks += 1
			"count": bad.standings[0].completed_tracks = 4
			"car": bad.stages[4].manifest.vehicle_id = "pickup"
		check(not ChallengesClient.valid_snapshot(bad),"reject malformed custom receipt: "+kind)
	var client := StubClient.new()
	client.snapshot = snapshot
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://custom-tracks-"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	adapter.selected = snapshot.duplicate(true)
	adapter.select_stage(4)
	check(adapter.race_stage().entry == snapshot.stages[4].entry,"fifth track is a real selectable race")
	await adapter.ticket()
	check(client.path.ends_with("/tickets?stage=4"),"fifth-track ticket pins its own track")
	await adapter.ghost()
	check(client.path.ends_with("/ghost?stage=4"),"fifth-track ghost uses its own stage")
	adapter.select_stage(5)
	check(adapter.selected_stage == 4,"sixth-stage selection is rejected")
	adapter.reset()
	var page := ChallengeCreate.new()
	page.adapter = adapter
	page.records = LocalRecords.new(cloud.root_override.path_join("records.json"))
	for stage: Dictionary in snapshot.stages: page.entries.append(stage.entry.duplicate(true))
	root.size = Vector2i(1280,720)
	root.add_child(page)
	MenuStyle.fill(page)
	await settle()
	page._open_rules()
	(page.find_child("ChallengeTrackCount_5",true,false) as Button).pressed.emit()
	page._back()
	check(page.custom_track_count == 1,"Back cancels the track-count draft")
	page._open_rules()
	(page.find_child("ChallengeCustomMode_1",true,false) as Button).pressed.emit()
	(page.find_child("ChallengeTrackCount_5",true,false) as Button).pressed.emit()
	(page.find_child("ChallengeTries_5",true,false) as Button).pressed.emit()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844)]:
		root.size = dimensions
		await settle()
		var scroll: ScrollContainer = page.find_child("ChallengeCreationScroll",true,false)
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"custom rules fit "+str(dimensions))
		await capture("rules-"+str(dimensions.x)+"x"+str(dimensions.y))
	page._advance()
	check(page._required_tracks() == 5 and page._slot_row.get_child_count() == 5,"custom selection provides exactly five slots")
	for index: int in range(5):
		page._select_track(page.entries[index])
		if index == 0:
			page._select_track(page.entries[0])
			check(page._chosen_entries.size() == 1,"duplicate cannot fill the next track slot")
		check(page.get_ok_button().disabled == (index < 4),"Next requires all selected tracks: "+str(index+1))
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(390,844)]:
		root.size = dimensions
		await settle()
		var scroll: ScrollContainer = page.find_child("ChallengeCreationScroll",true,false)
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"five track slots fit "+str(dimensions))
		for slot: Control in page._slot_row.get_children():
			check(slot.size.y >= 52 and slot.get_global_rect().end.x <= root.size.x+1,"track slot remains touchable inside viewport at "+str(dimensions)+": "+str(slot.get_global_rect()))
		await capture("tracks-"+str(dimensions.x)+"x"+str(dimensions.y))
	root.size = Vector2i(1280,720)
	page._advance()
	await settle()
	check(not page.get_ok_button().disabled,"five-track creation is enabled by the advertised API capability")
	client._capabilities.erase("challenge_custom_tracks_version")
	page._update()
	check(page.get_ok_button().disabled,"older API cannot accept an unsupported custom series")
	client._capabilities.challenge_custom_tracks_version = 1
	page._update()
	page.race_to_set_requested.connect(func(entry: Dictionary, car: String, duration: int, limit: int, configuration: Dictionary) -> void: receipt = {"entry":entry,"car":car,"duration":duration,"limit":limit,"configuration":configuration})
	page._race_to_set()
	check(receipt.configuration.track_count == 5 and receipt.configuration.tracks.size() == 5,"source drive retains the five-track configuration")
	page.show()
	await page._create()
	check(client.payload.version_ids.size() == 5 and client.payload.version_ids[4] == snapshot.stages[4].entry.version_id,"creation submits every selected track in order")
	var finished := ChallengeCreate.new()
	finished.adapter = adapter
	finished.entries = page.entries
	finished.records = page.records
	finished.initial_configuration = receipt.configuration
	finished.initial_vehicle = receipt.car
	finished.initial_ticket = "exact-opening-ticket"
	finished.result_context = {"entry":receipt.entry,"scope":adapter.scope(),"total":88.9}
	root.add_child(finished)
	MenuStyle.fill(finished)
	await settle()
	check(finished._required_tracks() == 5 and finished._chosen_entries.size() == 5,"completed source drive restores all five chosen tracks")
	var opening: Dictionary = finished._entry().duplicate(true)
	finished._active_slot = 0
	finished._select_track(finished.entries[4])
	check(finished._entry() == opening,"exact finished opening track remains fixed")
	finished.queue_free()
	page.queue_free()
	await settle()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(390,844)]:
		root.size = dimensions
		var detail := ChallengesPage.new()
		detail.selected = snapshot.duplicate(true)
		detail.selected_stage = 4
		detail.signed_in = true
		root.add_child(detail)
		MenuStyle.fill(detail)
		await settle()
		check(detail.find_child("ChallengeStage_4",true,false) != null,"detail exposes fifth track at "+str(dimensions))
		await capture("detail-"+str(dimensions.x)+"x"+str(dimensions.y))
		detail.queue_free()
		await settle()
		var ready := preload("res://ui/challenge_ready_dialog.gd").new()
		ready.snapshot = snapshot.duplicate(true)
		root.add_child(ready)
		preload("res://ui/popup_style.gd").watch(ready)
		ready.popup_centered(Vector2i(mini(700,dimensions.x-32),mini(600,dimensions.y-32)))
		await settle()
		check(ready.size.x <= dimensions.x and ready.size.y <= dimensions.y,"five-track invitation fits "+str(dimensions))
		check(ready.find_children("*","Label",true,false).any(func(label: Label) -> bool: return label.text == "CUSTOM CHALLENGE"),"custom invitation keeps its own format title")
		await capture("invitation-"+str(dimensions.x)+"x"+str(dimensions.y))
		ready.queue_free()
		await settle()
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame
	print("CUSTOM_CHALLENGE_TRACKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

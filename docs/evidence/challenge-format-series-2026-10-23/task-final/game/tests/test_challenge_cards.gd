extends SceneTree
## Native card input, optional rules transactions, exact receipts and bounded layout.
var checks: int = 0
var failures: int = 0
var output: String
var raced: Dictionary = {}

class StubClient extends Node:
	var player: Dictionary = {"id":"card-fixture"}
	var _capabilities: Dictionary = {"challenge_discovery_version":1,"challenge_series_version":1}
	var answer: Dictionary = {"ok":true,"data":{"status":"verified","run_id":"exact-finish","ms":88900}}
	var payload: Dictionary = {}
	var paths: Array[String] = []
	func base_url() -> String: return "http://card-fixture"
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "card-fixture-operation"
	func cancel_public_reads(_owner: int) -> void: pass
	func request_api(path: String, _method: int, value: Dictionary, _key: String, _auth: bool) -> Dictionary:
		paths.append(path)
		payload = value.duplicate(true)
		return answer.duplicate(true)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+detail)

func entry() -> Dictionary:
	return {"version_id":"00000000-0000-0000-0000-000000000001","track_id":"00000000-0000-0000-0000-000000000002","content_hash":"a".repeat(64),"name":"Forest Run","creator":"Fixture driver","theme":"pine","points":[[0,0],[100,0],[120,70],[40,90],[-10,30]]}

func invitation(group: bool = false) -> Dictionary:
	return {"id":"cards-created","code":"AB12CD34EF56AB78","mode":"group" if group else "beat","state":"active","visibility":"private","creator_id":"card-fixture","creator":"Fixture driver","self_id":"card-fixture","joined":true,"vehicle_id":"compact","created_at":0,"ends_at":259200,"server_now":0,"attempt_limit":3,"target_ms":null if group else 88900,"target_ticks":null if group else 10668,"manifest":{"laps":5,"tick_rate":120},"entry":entry(),"share_url":"https://fixture/c/AB12CD34EF56AB78","standings":[{"id":"card-fixture","name":"Fixture driver","rank":1,"ticks":10668,"ms":88900,"run_id":"exact-finish"}]}

func settle() -> void:
	for frame: int in range(6): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func inside(node: Control, detail: String) -> void:
	var rect: Rect2 = node.get_global_rect()
	var visible: Rect2 = root.get_visible_rect()
	check(rect.position.x >= -1 and rect.end.x <= visible.end.x+1 and rect.position.y >= -1 and rect.end.y <= visible.end.y+1,detail+" is inside viewport")

func click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
	await settle()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.content_scale_size = Vector2i.ZERO
	var evidence_root: String = OS.get_environment("BMT_CHALLENGE_CARDS_OUTPUT")
	if evidence_root.is_empty(): evidence_root = "res://../docs/evidence/challenge-format-series-2026-10-23"
	output = ProjectSettings.globalize_path(evidence_root.path_join(DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(output)
	var client := StubClient.new()
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://series-fixture-"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	adapter.creation_visibility = "private"
	var tracks: Array[Dictionary] = []
	for index: int in range(5):
		var track: Dictionary = entry().duplicate(true)
		track.version_id = "00000000-0000-0000-0000-00000000000"+str(index)
		track.track_id = "10000000-0000-0000-0000-00000000000"+str(index)
		track.name = ["Forest Run","Dune Runner","Winter Loop","Alpine Circuit","Night Shift"][index]
		track.theme = ["pine","desert","winter","alpine","night"][index]
		tracks.append(track)
	var page := ChallengeCreate.new()
	page.adapter = adapter
	page.entries = tracks
	root.add_child(page)
	MenuStyle.fill(page)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		check(page._formats.get_child_count() == 3,"exactly three format posters")
		check(not page._panel.is_visible_in_tree() and not page._search.is_visible_in_tree(),"format precedes every track and time choice")
		check(page.find_child("ChallengeFormat_custom",true,false) == null and page._custom_button.is_visible_in_tree(),"custom is a subtle separate action")
		inside(page.find_child("ChallengeCreateActions",true,false),"format dock "+str(dimensions))
		var creation_scroll: ScrollContainer = page.find_child("ChallengeCreationScroll",true,false)
		check(creation_scroll.get_h_scroll_bar().max_value <= creation_scroll.size.x+1,"format has no horizontal overflow "+str(dimensions))
		await capture("formats-"+str(dimensions.x)+"x"+str(dimensions.y))
	root.size = Vector2i(1280,720)
	await settle()
	page._choose_duration(259200)
	await click(page.find_child("ChallengeFormat_three",true,false))
	check(page.selected_format == "three" and page.attempt_limit == 3,"native click chooses 3×3")
	check(page.duration == 259200 and adapter.creation_visibility == "private","presets retain duration and visibility")
	await click(page.get_ok_button())
	check(page._step == 1 and page._search.is_visible_in_tree() and not page._format_page.is_visible_in_tree(),"Next opens the separate track page")
	check(page._chosen_entries.is_empty() and page.get_ok_button().disabled,"3×3 never silently fills tracks")
	page._select_track(tracks[0])
	page._select_track(tracks[1])
	page._select_track(tracks[1])
	check(page._chosen_entries.size() == 2,"duplicate tracks cannot occupy another slot")
	page._select_track(tracks[2])
	await settle()
	check(page._chosen_entries.size() == 3 and not page.get_ok_button().disabled,"three distinct tracks enable creation")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(960,540)]:
		root.size = dimensions
		await settle()
		inside(page.find_child("ChallengeCreateActions",true,false),"track dock "+str(dimensions))
		for card: Control in page._track_cards.get_children(): inside(card,"track poster "+str(dimensions))
		await capture("tracks-"+str(dimensions.x)+"x"+str(dimensions.y))
	page._back()
	check(page._step == 0 and page._chosen_entries.size() == 3,"Back preserves track choices")
	page._open_rules()
	var draft: ConfirmationDialog = page._rules_dialog
	(draft.find_child("ChallengeTries_1",true,false) as Button).pressed.emit()
	draft.canceled.emit()
	await settle()
	check(page.selected_format == "three" and page.attempt_limit == 3,"custom cancel retains the full previous configuration")
	page._open_rules()
	draft = page._rules_dialog
	(draft.find_child("ChallengeTries_5",true,false) as Button).pressed.emit()
	(draft.find_child("ChallengeCustomMode_0",true,false) as Button).pressed.emit()
	draft.confirmed.emit()
	await settle()
	check(page._step == 1 and page.selected_format == "custom" and page._chosen_entries.size() == 1 and page.attempt_limit == 5,"custom commits supported rules and advances to one-track selection")
	page._open_picker("car")
	page._vehicle.select(1)
	page._vehicle.item_selected.emit(1)
	page._car_picker.hide()
	client.answer = {"ok":true,"data":{"status":"not_set","run_id":null,"ms":null}}
	await page._check_source()
	check(page._race.visible and page.get_ok_button().disabled,"a missing target offers the real source drive")
	page.race_to_set_requested.connect(func(value: Dictionary, car: String, seconds: int, limit: int, config: Dictionary) -> void: raced = {"entry":value,"car":car,"duration":seconds,"limit":limit,"configuration":config})
	page._race_to_set()
	check(raced.car == "pickup" and raced.limit == 5 and raced.configuration.format == "custom" and raced.configuration.tracks.size() == 1,"source drive preserves rules, car and selected tracks")
	page.show()
	page._choose_format("group")
	check(not page.get_ok_button().disabled,"group creation remains target free")
	page.queue_free()
	await settle()
	client.answer = {"ok":true,"data":{"status":"verified","run_id":"exact-finish","ms":88900}}
	var finished := ChallengeCreate.new()
	finished.adapter = adapter
	finished.entries = tracks
	finished.initial_ticket = "exact-slower-ticket"
	finished.initial_vehicle = "compact"
	finished.result_context = {"entry":tracks[0],"total":88.9,"scope":adapter.scope()}
	root.add_child(finished)
	MenuStyle.fill(finished)
	finished._choose_format("three")
	finished._advance()
	await settle()
	check(finished._chosen_entries[0] == tracks[0] and finished._active_slot == 1,"exact finished track is pinned as the opening stage")
	finished._select_track(tracks[1])
	finished._select_track(tracks[2])
	check(finished._time.text == MenuStyle.time_text(88.9),"exact slower finish survives 3×3 selection")
	finished._active_slot = 0
	finished._select_track(tracks[3])
	check(finished._chosen_entries[0] == tracks[0],"completed race cannot be replaced")
	await capture("finished-three-tracks")
	client.answer = {"ok":false,"error":"Fixture offline"}
	await finished._create()
	check(client.payload.mode == "3x3" and client.payload.version_ids == [tracks[0].version_id,tracks[1].version_id,tracks[2].version_id] and client.payload.attempt_limit == 3,"real payload contains exactly three chosen pinned tracks")
	check(client.payload.source_ticket_id == "exact-slower-ticket" and not client.payload.has("source_run_id"),"exact result never falls back to a PB")
	check(finished._notice.is_visible_in_tree(),"creation failure remains actionable")
	client.player.id = "changed-account"
	finished._update()
	check(finished.get_ok_button().disabled,"account changes fence creation")
	client.player.id = "card-fixture"
	finished.queue_free()
	await settle()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(390,844)]:
		root.size = dimensions
		await settle()
		var ready := preload("res://ui/challenge_ready_dialog.gd").new()
		ready.snapshot = invitation()
		var original: String = adapter.scope()
		ready.context_current = func() -> bool: return adapter.scope() == original
		root.add_child(ready)
		preload("res://ui/popup_style.gd").watch(ready)
		ready.popup_centered(Vector2i(mini(700,dimensions.x-32),mini(460,dimensions.y-32)))
		await settle()
		check((ready.find_child("ChallengeReadyTime",true,false) as Label).text == MenuStyle.time_text(88.9),"ready invitation retains its frozen time")
		check(ready.size.x <= dimensions.x and ready.size.y <= dimensions.y,"ready invitation fits "+str(dimensions))
		client.player.id = "changed-account"
		await settle()
		check(not is_instance_valid(ready),"account switch dismisses old sharing receipt")
		client.player.id = "card-fixture"
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await settle()
	print("CHALLENGE_CARDS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

extends SceneTree
## Native card input, optional rules transactions, exact receipts and bounded layout.
var checks: int = 0
var failures: int = 0
var output: String
var raced: Dictionary = {}

class StubClient extends Node:
	var player: Dictionary = {"id":"card-fixture"}
	var _capabilities: Dictionary = {"challenge_discovery_version":1}
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
	# Exercise actual logical sizes instead of comparing window pixels against
	# the project's expanded 1280-unit canvas.
	root.content_scale_size = Vector2i.ZERO
	var evidence_root: String = OS.get_environment("BMT_CHALLENGE_CARDS_OUTPUT")
	if evidence_root.is_empty(): evidence_root = "res://../docs/evidence/challenge-cards-native-2026-10-23"
	output = ProjectSettings.globalize_path(evidence_root.path_join(DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(output)
	var client := StubClient.new()
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://cards-fixture-"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	adapter.creation_visibility = "private"
	root.size = Vector2i(1280,720)
	var page := ChallengeCreate.new()
	page.adapter = adapter
	page.entries.assign([entry()])
	page.initial_vehicle = "compact"
	root.add_child(page)
	MenuStyle.fill(page)
	await settle()
	check(page._format_buttons.size() == 4 and page.selected_format == "duel","four cards open with Head to head selected")
	check(not page._search.is_visible_in_tree() and not page._track.is_visible_in_tree() and not page._vehicle.is_visible_in_tree(),"no form field or dropdown is required on entry")
	check(page._preview_route.route.size() == 5,"ticket displays actual track geometry")
	check(page.get_ok_button().text == "Create & share","one explicit create and share action")
	await capture("menu-head-to-head-1280")
	# Tall windows should spend their space on the cards; the rules and primary
	# action remain one nearby dock rather than two separated footer regions.
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1600,900)]:
		root.size = dimensions
		await settle()
		var dock: Control = page.find_child("ChallengeCreateActions",true,false)
		var summary: Control = page.find_child("ChallengeRuleSummary",true,false)
		var cards_rect: Rect2 = page._formats.get_global_rect()
		inside(dock,"rules/action dock "+str(dimensions))
		check(dock.get_global_rect().encloses(summary.get_global_rect()) and dock.get_global_rect().encloses(page._create_button.get_global_rect()),"rules and primary action occupy one nearby dock")
		check(dock.global_position.y-cards_rect.end.y >= 0 and dock.global_position.y-cards_rect.end.y <= 16,"cards meet their action dock without a dead gap "+str(dimensions))
		for card: Button in page._format_buttons:
			check(card.size.y >= 226 and card.artwork_rect().size.y >= 92,"cards reserve substantial space for format artwork")
		await capture("composition-"+str(dimensions.x)+"x"+str(dimensions.y))
	root.size = Vector2i(1280,720)
	await settle()
	page._choose_duration(259200)
	var identity: Dictionary = page._entry().duplicate(true)
	for key: String in ["group","three","duel"]:
		var card: Button = page.find_child("ChallengeFormat_"+key,true,false)
		await click(card)
		check(page.selected_format == key,"native mouse selects "+key)
		check(page.duration == 259200 and adapter.creation_visibility == "private" and page._entry() == identity,"format switch preserves duration, visibility and circuit")
		check(page.attempt_limit == (3 if key == "three" else 0),"preset carries its advertised tries")
	page._choose_format("three")
	check(page.mode == 1 and page._tries_note.is_visible_in_tree(),"Three tries is a group with visible restart accounting")
	await capture("three-tries-1280")
	await click(page.find_child("ChallengeFormat_custom",true,false))
	check(is_instance_valid(page._rules_dialog) and page._rules_dialog.visible,"Custom rules opens the optional native sheet")
	var draft_window: ConfirmationDialog = page._rules_dialog
	(draft_window.find_child("ChallengeTries_1",true,false) as Button).pressed.emit()
	(draft_window.find_child("ChallengeDuration_86400",true,false) as Button).pressed.emit()
	(draft_window.find_child("ChallengeCustomVisibility_public",true,false) as Button).pressed.emit()
	await settle()
	await capture("custom-rules-1280")
	draft_window.canceled.emit()
	await settle()
	check(page.selected_format == "three" and page.attempt_limit == 3 and page.duration == 259200 and adapter.creation_visibility == "private","Cancel restores the whole rules transaction")
	page._open_rules()
	draft_window = page._rules_dialog
	(draft_window.find_child("ChallengeTries_5",true,false) as Button).pressed.emit()
	(draft_window.find_child("ChallengeDuration_86400",true,false) as Button).pressed.emit()
	(draft_window.find_child("ChallengeCustomMode_0",true,false) as Button).pressed.emit()
	draft_window.confirmed.emit()
	await settle()
	check(page.selected_format == "custom" and page.attempt_limit == 5 and page.duration == 86400 and page.mode == 0,"Keep these rules commits the supported custom configuration")
	check("5 tries per driver" in page._rule_details.text,"custom summary carries the real chosen limit")
	check((page.find_child("ChallengeFormat_custom",true,false) as Button).chosen,"custom choice remains selected")
	await capture("custom-selected-1280")
	page._open_picker("track")
	await settle()
	check(page._search.is_visible_in_tree() and page._track.is_visible_in_tree(),"circuit choice opens directly")
	page._track_picker.hide()
	page._open_picker("car")
	await settle()
	check(page._vehicle.is_visible_in_tree(),"car choice opens directly")
	page._vehicle.select(1)
	page._vehicle.item_selected.emit(1)
	page._car_picker.hide()
	await settle()
	check(page._summary_car.text.contains(VehicleCatalog.title("pickup")),"selected car is reflected in the ticket")
	for dimensions: Vector2i in [Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		for kind: String in ["track","car"]:
			page._open_picker(kind)
			await settle()
			var picker: AcceptDialog = page._track_picker if kind == "track" else page._car_picker
			check(picker.position.x >= -1 and picker.position.y >= -1 and picker.position.x+picker.size.x <= dimensions.x+1 and picker.position.y+picker.size.y <= dimensions.y+1,kind+" picker fits "+str(dimensions))
			picker.hide()
	root.size = Vector2i(1280,720)
	await settle()
	client.answer = {"ok":true,"data":{"status":"not_set","run_id":null,"ms":null}}
	await page._check_source()
	check(page._race.visible and page.get_ok_button().disabled,"no invented or stale target is offered when no result exists")
	page.race_to_set_requested.connect(func(value: Dictionary, car: String, seconds: int, limit: int, configuration: Dictionary) -> void: raced = {"entry":value,"car":car,"duration":seconds,"limit":limit,"configuration":configuration})
	page._race_to_set()
	check(raced.car == "pickup" and raced.duration == 86400 and raced.limit == 5 and raced.configuration == {"mode":0,"format":"custom"},"race-first handoff retains car, rules and the custom card")
	page.show()
	page._choose_format("group")
	check(not page.get_ok_button().disabled and not page._race.visible,"existing target-free group creation remains available")
	page.queue_free()
	await settle()
	client.answer = {"ok":true,"data":{"status":"verified","run_id":"exact-finish","ms":88900}}
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720),Vector2i(844,390),Vector2i(600,800),Vector2i(390,844)]:
		root.size = dimensions
		await settle()
		var finished := ChallengeCreate.new()
		finished.adapter = adapter
		finished.initial_ticket = "exact-slower-ticket"
		finished.initial_vehicle = "compact"
		finished.initial_configuration = {"mode":1,"format":"three"}
		finished.initial_attempt_limit = 3
		finished.result_context = {"entry":entry(),"vehicle_id":"compact","ticket_id":"exact-slower-ticket","total":88.9,"laps":5,"scope":adapter.scope()}
		root.add_child(finished)
		MenuStyle.fill(finished)
		await settle()
		check(finished.mode == 1 and finished.selected_format == "three","race return restores its group format")
		check(finished._track == null and finished._vehicle == null and finished._search == null and not finished._race.visible,"completed race hides every unrelated selector")
		check(finished._time.text == MenuStyle.time_text(88.9),"exact slower finish remains prominent, including group creation")
		inside(finished.find_child("ChallengeCreateActions",true,false),"outside primary action "+str(dimensions))
		var creation_scroll: ScrollContainer = finished.find_child("ChallengeCreationScroll",true,false)
		check(creation_scroll.get_h_scroll_bar().max_value <= creation_scroll.size.x+1,"no horizontal overflow "+str(dimensions))
		creation_scroll.ensure_control_visible(finished._formats)
		await settle()
		for card: Button in finished._format_buttons:
			check(card.size.x >= 180 and card.size.y >= 190,"substantial card targets "+str(dimensions))
		await capture("finished-"+str(dimensions.x)+"x"+str(dimensions.y))
		finished._open_rules()
		await settle()
		var rect := Rect2(Vector2(finished._rules_dialog.position),Vector2(finished._rules_dialog.size))
		check(rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= dimensions.x+1 and rect.end.y <= dimensions.y+1,"custom sheet fits "+str(dimensions)+" actual "+str(rect)+" viewport "+str(root.get_visible_rect().size))
		finished._dismiss_rules()
		await settle()
		if dimensions == Vector2i(1280,720):
			client.answer = {"ok":true,"data":invitation(true)}
			await finished._create()
			check(client.payload.get("source_ticket_id") == "exact-slower-ticket" and not client.payload.has("source_run_id"),"creation submits the exact ticket instead of substituting a PB")
			check(client.payload.mode == "group" and client.payload.attempt_limit == 3,"actual create payload matches the selected group card")
			client.answer = {"ok":true,"data":{"status":"verified","run_id":"exact-finish","ms":88900}}
		finished.queue_free()
		await settle()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(390,844)]:
		root.size = dimensions
		await settle()
		var ready := preload("res://ui/challenge_ready_dialog.gd").new()
		ready.snapshot = invitation()
		var initial_scope: String = adapter.scope()
		ready.context_current = func() -> bool: return adapter.scope() == initial_scope
		root.add_child(ready)
		preload("res://ui/popup_style.gd").watch(ready)
		ready.popup_centered(Vector2i(mini(700,dimensions.x-32),mini(460,dimensions.y-32)))
		await settle()
		check((ready.find_child("ChallengeReadyTime",true,false) as Label).text == MenuStyle.time_text(88.9),"ready invitation carries the frozen exact time")
		if ready.size.x > dimensions.x:
			for control: Node in ready.find_children("*","Control",true,false):
				if (control as Control).get_combined_minimum_size().x > 290: print("READY_MIN: ",control.name," ",control.get_class()," ",control.get_combined_minimum_size())
		check(ready.position.x >= -1 and ready.position.y >= -1 and ready.position.x+ready.size.x <= dimensions.x+1 and ready.position.y+ready.size.y <= dimensions.y+1,"ready invitation fits "+str(dimensions)+" actual "+str(ready.position)+" "+str(ready.size)+" viewport "+str(root.get_visible_rect().size))
		await capture("ready-"+str(dimensions.x))
		client.player.id = "changed-account"
		await settle()
		check(not is_instance_valid(ready),"account changes dismiss the old invitation")
		client.player.id = "card-fixture"
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await settle()
	print("CHALLENGE_CARDS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

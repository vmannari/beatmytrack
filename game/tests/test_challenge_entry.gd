extends SceneTree
## Initial intent, retained navigation, guest gates and direct invitations/results.
var checks: int = 0
var failures: int = 0
var output: String

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
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func click(button: Button) -> void:
	if DisplayServer.get_name() == "headless": button.pressed.emit()
	else:
		var point: Vector2 = button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion,true)
		for down: bool in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			root.push_input(event,true)
	await settle()

func page(app: Node) -> ChallengesPage:
	return app.content.find_child("ChallengesPage",true,false)

func fixture() -> Dictionary:
	return {"id":"entry-fixture","code":"AB12CD34EF56AB78","mode":"group","state":"active","creator":"Mika","creator_id":"rival","self_id":"self","joined":true,"vehicle_id":"compact","target_ms":null,"target_ticks":null,"ends_at":604800,"server_now":432000,"entry":{"name":"Forest Run","theme":"pine","points":[[0,0],[100,0],[120,70],[40,90],[-10,30]],"version_id":"00000000-0000-0000-0000-000000000001"},"standings":[]}

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var capture_root: String = OS.get_environment("BMT_CHALLENGE_ENTRY_OUTPUT")
	if capture_root.is_empty(): capture_root = "res://../docs/evidence/challenge-entry-choice-2026-10-23"
	output = ProjectSettings.globalize_path(capture_root.path_join(DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390),Vector2i(390,844)]:
		root.size = dimensions
		var storage: String = "user://challenge-entry-"+TrackLibrary.unique_id()
		var app: Node = load("res://core/app.tscn").instantiate()
		app.records = LocalRecords.new(storage.path_join("records.json"))
		app.library = TrackLibrary.new(storage.path_join("tracks"))
		app.cloud_root_override = storage.path_join("cloud")
		root.add_child(app)
		while not app.startup_complete: await process_frame
		app.online.client.player = {"id":"self"}
		app.online.client._access_token = "fixture"
		app.challenges.reset()
		app.challenges.selected = fixture()
		app.challenges.items.assign([fixture()])
		app.challenges.busy = true
		app._open_challenges()
		await settle()
		check(page(app).landing_view,"explicit entry presents the intent choice even with a selected challenge")
		check(page(app).find_child("ChallengeSearch",true,false) == null,"browsing begins after Find & play")
		var find: Button = page(app).find_child("ChallengeFindAndPlay",true,false)
		var create: Button = page(app).find_child("ChallengeCreateNew",true,false)
		check(not find.disabled and not create.disabled,"local choices stay usable during a background read")
		var choices: GridContainer = page(app).find_child("ChallengeEntryChoices",true,false)
		var scroll: ScrollContainer = page(app).find_child("ChallengeEntryScroll",true,false)
		check(choices.columns == (2 if scroll.size.x >= 560 else 1),"choice layout follows available width")
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x+1,"entry does not overflow horizontally")
		for choice: Button in [find,create]:
			check(root.get_visible_rect().encloses(choice.get_global_rect()),"both choices fit the initial landscape viewport: "+str(dimensions)+" "+str(choice.get_global_rect())+" page="+str(page(app).get_global_rect()))
		app._challenges_changed()
		await settle()
		check(page(app).landing_view,"late model refresh keeps the intent choice")
		await capture("entry-%dx%d" % [dimensions.x,dimensions.y])
		find = page(app).find_child("ChallengeFindAndPlay",true,false)
		await click(find)
		check(app.challenge_browsing and not page(app).landing_view,"Find & play opens the browser")
		check(page(app).find_child("ChallengeSearch",true,false) != null and page(app).find_child("ChallengeRace",true,false) != null,"existing search and selected challenge actions remain")
		await click(page(app).find_child("ChallengeBrowseBack",true,false))
		check(page(app).landing_view,"browser Back returns to the choice")
		create = page(app).find_child("ChallengeCreateNew",true,false)
		scroll = page(app).find_child("ChallengeEntryScroll",true,false)
		scroll.ensure_control_visible(create)
		await settle()
		check(create.get_global_rect().intersection(scroll.get_global_rect()).size.y >= 52,"create choice is reachable by scrolling")
		await click(create)
		var form: ChallengeCreate = app.content.find_child("ChallengeCreate",true,false)
		check(app.screen == "challenge_create" and form != null and form._step == ChallengeCreate.FORMAT,"Create opens format selection first")
		form.close()
		await settle()
		check(page(app).landing_view,"canceling creation from the choice returns to it")
		app._browse_challenges()
		await settle()
		app._create_challenge_dialog()
		await settle()
		(app.content.find_child("ChallengeCreate",true,false) as ChallengeCreate).close()
		await settle()
		check(not page(app).landing_view,"canceling creation from browsing returns to browsing")
		app._open_challenges()
		await settle()
		check(page(app).landing_view,"repeated Challenges activation resets to the choice")
		app.challenges.folder = "sent"
		app._challenges()
		await settle()
		await click(page(app).find_child("ChallengeFindAndPlay",true,false))
		check(app.challenges.folder == "discover" and page(app).find_child("ChallengeTab_sent",true,false) != null,"Find & play opens discovery with Created available")
		await click(page(app).find_child("ChallengeTab_sent",true,false))
		check(app.challenges.folder == "sent" and not page(app).landing_view,"Created opens your challenges directly from Find & play")
		check((page(app).find_child("ChallengeBrowseTitle",true,false) as Label).text == "YOUR CHALLENGES","Created identifies the management page")
		app.challenges.selected = fixture()
		app.challenges.selected.creator_id = "self"
		app.challenges.items.assign([app.challenges.selected])
		app._challenges()
		await settle()
		await capture("created-%dx%d" % [dimensions.x,dimensions.y])
		await click(page(app).find_child("ChallengeTab_discover",true,false))
		check(app.challenges.folder == "discover" and not page(app).landing_view,"Created returns directly to Discover")
		app.challenges.selected = fixture()
		app.challenges.items.assign([fixture()])
		app._receive_challenge("AB12CD34EF56AB78")
		await settle()
		check(not page(app).landing_view,"invitation links bypass the choice")
		app.challenge_browsing = false
		app.challenge_result_view = true
		app.challenges.result_state = "upload_pending"
		app._challenges()
		await settle()
		check(page(app).find_child("ChallengeResultFeedback",true,false) != null and page(app).find_child("ChallengeEntryChoices",true,false) == null,"results retain their direct feedback view")
		app.challenge_result_view = false
		app.challenge_invitation = ""
		app.online.client.player = {}
		app.online.client._access_token = ""
		app._open_challenges()
		await settle()
		await click(page(app).find_child("ChallengeFindAndPlay",true,false))
		check(app.screen == "challenges" and not page(app).landing_view,"guest can browse without signing in")
		app._open_challenges()
		await settle()
		create = page(app).find_child("ChallengeCreateNew",true,false)
		scroll = page(app).find_child("ChallengeEntryScroll",true,false)
		scroll.ensure_control_visible(create)
		await settle()
		await click(create)
		check(app.screen == "account","guest creation opens existing sign-in flow")
		while not app.online.client._encoding_threads.is_empty(): await process_frame
		app.queue_free()
		await settle()
	# Also exercise stacking without the application's normal canvas scaling.
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(390,844)
	var narrow := ChallengesPage.new()
	narrow.landing_view = true
	root.add_child(narrow)
	MenuStyle.fill(narrow)
	await settle()
	var narrow_choices: GridContainer = narrow.find_child("ChallengeEntryChoices",true,false)
	check(narrow_choices.columns == 1,"narrow page stacks the two choices")
	for choice: Button in narrow_choices.get_children():
		check(root.get_visible_rect().encloses(choice.get_global_rect()),"stacked choice fits the narrow page")
	await capture("entry-stacked-390x844")
	narrow.queue_free()
	await settle()
	print("CHALLENGE ENTRY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

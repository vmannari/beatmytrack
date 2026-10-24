extends SceneTree
## Native result presentation with isolated service snapshots and no transport.
var checks: int = 0
var failures: int = 0
var evidence: String = "res://../docs/evidence/challenge-results-redesign-2026-10-24"
var page: ChallengesPage
var host: MarginContainer

func _initialize() -> void: run.call_deferred()

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+detail)

func settle() -> void:
	for frame: int in range(8): await process_frame

func fixture(count: int = 1) -> Dictionary:
	var value: Dictionary = {"id":"result-fixture","code":"AB12CD34EF56AB78","mode":"group","state":"active","creator":"Ville","creator_id":"self","self_id":"self","joined":true,"vehicle_id":"compact","capacity":20,
		"ends_at":604800,"server_now":0,"attempt_limit":3,"attempts_remaining":0,"target_ms":null,"target_ticks":null,
		"entry":{"name":"Speedy","theme":"desert","points":[[0,0],[80,0],[80,10],[55,10],[55,30],[85,30],[90,40],[85,50],[60,50],[60,65],[100,65],[100,80],[45,80],[35,70],[35,50],[45,45],[50,50],[50,65],[35,70],[10,70],[0,60],[0,15],[10,0]]},
		"rewards":{"finish":50,"goal":50,"finish_earned":true,"goal_earned":false,"eligible":true},"standings":[]}
	for index: int in range(count):
		value.standings.append({"id":"self" if index == 0 else "rival_"+str(index),"name":"Ville" if index == 0 else "Alexandria the remarkably determined racer" if index == 1 else "Driver "+str(index+1),"rank":index+1,"ticks":12762+index*120,"ms":106350+index*1000})
	return value

func mount(snapshot: Dictionary, state: String = "verified", result: Dictionary = {"counted":true,"ms":106350}) -> void:
	if is_instance_valid(page):
		host.remove_child(page)
		page.queue_free()
	page = ChallengesPage.new()
	page.selected = snapshot.duplicate(true)
	page.result_view = true
	page.signed_in = true
	page.result_state = state
	page.outcome = result.duplicate(true)
	host.add_child(page)
	await settle()

func bounds(identity: String) -> void:
	var control: Control = page.find_child(identity,true,false)
	check(control != null,identity+" exists")
	if control == null: return
	var area: Rect2 = control.get_global_rect()
	check(area.position.x >= -1 and area.end.x <= root.size.x+1,identity+" fits width "+str(root.size)+" "+str(area))

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	GameSoundtrack.instance().output_enabled = false
	root.content_scale_size = Vector2i.ZERO
	var background := MenuBackdrop.new()
	root.add_child(background)
	MenuStyle.fill(background)
	host = MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: host.add_theme_constant_override("margin_"+side,20)
	root.add_child(host)
	MenuStyle.fill(host)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,900),Vector2i(960,540),Vector2i(844,390),Vector2i(390,844)]:
		root.size = dimensions
		for count: int in [1,20]:
			await mount(fixture(count))
			check((page.find_child("ChallengeResultTime",true,false) as Label).text == "01:46.350","personal result uses minutes, seconds and milliseconds")
			check((page.find_child("ChallengeTargetTime",true,false) as Label).text == "01:46.350","leader time matches the shared format")
			var own: PanelContainer = page.find_child("ChallengeDriver_self",true,false)
			check((own.get_child(0).get_child(2) as Label).text == "01:46.350","standing uses the same time format")
			check(own.get_theme_stylebox("panel").bg_color == MenuStyle.ACCENT,"player retains established yellow row")
			var race: Button = page.find_child("ChallengeRace",true,false)
			check(race.disabled and race.text == "No tries remaining","exhausted tries have an explicit disabled action")
			for identity: String in ["ChallengeHeader","ChallengeActions","ChallengeResultSummary","ChallengeResultBoardPanel","ChallengeResultTime","ChallengeTargetTime","ChallengeStandingsScroll","ChallengeResultsBack"]: bounds(identity)
			var actions: Control = page.find_child("ChallengeActions",true,false)
			check(actions.get_global_rect().end.y <= root.size.y+1,"actions stay inside the viewport")
			check(race.size.y >= 52,"race action retains its touch height")
			var content: ScrollContainer = page.find_child("ChallengeResultContentScroll",true,false)
			check(content.get_h_scroll_bar().max_value <= content.size.x+1,"result content has no horizontal overflow")
			var gap: Label = page.find_child("ChallengePersonalGap",true,false)
			check(gap.get_line_count() <= 2,"standing comparison stays readable instead of wrapping into a vertical column")
			if dimensions.y >= 720 and dimensions.x >= 960:
				check(content.get_v_scroll_bar().max_value <= content.size.y+1,"ordinary desktop result fits without scrolling the whole debrief")
			if dimensions.y < 450:
				var personal: Control = page.find_child("ChallengeResultTime",true,false)
				check(personal.get_global_rect().end.y <= content.get_global_rect().end.y,"short landscape prioritizes the personal time before the scenery")
			var standings: ScrollContainer = page.find_child("ChallengeStandingsScroll",true,false)
			if count == 20:
				check(standings.get_v_scroll_bar().max_value > standings.size.y,"twenty driver board scrolls")
				standings.scroll_vertical = int(standings.get_v_scroll_bar().max_value)
				await settle()
				var last: Control = page.find_child("ChallengeDriver_rival_19",true,false)
				check(last.get_global_rect().end.y <= standings.get_global_rect().end.y+1,"last standing is reachable")
				standings.scroll_vertical = 0
			if dimensions.x in [1280,844,390]: await capture("group-%d-%dx%d" % [count,dimensions.x,dimensions.y])
	root.size = Vector2i(1280,720)
	var duel: Dictionary = fixture(2)
	duel.mode = "beat"
	duel.creator_id = "rival_1"
	duel.target_ticks = 12762
	duel.target_ms = 106350
	duel.attempts_remaining = 2
	duel.standings[0].ms = 105980
	duel.standings[0].ticks = 12718
	await mount(duel,"verified",{"counted":true,"beaten":true,"ms":105980,"gap_ms":-370})
	check((page.find_child("ChallengeResultFeedback",true,false) as Label).text == "Target beaten  -0.370 s","target success retains its signed comparison")
	check(not (page.find_child("ChallengeRace",true,false) as Button).disabled,"available recipient may retry")
	await capture("duel-beaten")
	await mount(duel,"verified",{"counted":true,"ms":110000,"gap_ms":3650})
	check((page.find_child("ChallengeResultTime",true,false) as Label).text == "01:50.000","slower completed run stays distinct from the saved best")
	check(page.find_children("*","Label",true,false).any(func(label: Label) -> bool: return label.text == "Your best  01:45.980"),"saved best remains visible for a slower finish")
	for state: String in ["upload_pending","retry_pending","rejected","expired"]:
		await mount(duel,state,{})
		var text: String = (page.find_child("ChallengeResultFeedback",true,false) as Label).text
		check(text == ("Not counted" if state in ["rejected","expired"] else "Verifying"),state+" never claims a verified result")
		check((page.find_child("ChallengeResultTime",true,false) as Label).text == "01:45.980","pending and rejected views retain only the official best")
	await capture("not-counted")
	var series: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/challenge_series_v1.json"))
	await mount(series,"verified",{"counted":true,"ms":123456,"stage_index":0})
	check((page.find_child("ChallengeResultTime",true,false) as Label).text == "02:03.456","series result shows this run, separately from the aggregate")
	var series_own: PanelContainer = page.find_child("ChallengeDriver_"+str(series.self_id),true,false)
	check((series_own.get_child(0).get_child(0) as Label).text == "1","JSON numeric ranks display as integers")
	for index: int in range(3): check(page.find_child("ChallengeStage_"+str(index),true,false) != null,"series track remains selectable")
	await capture("series")
	var stage_signal: Dictionary = {"index":-1}
	page.stage_requested.connect(func(index: int) -> void: stage_signal.index = index)
	(page.find_child("ChallengeStage_2",true,false) as Button).pressed.emit()
	check(stage_signal.index == 2,"stage selector forwards the correct stage")
	var completed: Dictionary = fixture()
	completed.state = "complete"
	await mount(completed)
	check((page.find_child("ChallengeRace",true,false) as Button).disabled,"completed challenge cannot start another race")
	var signals: Dictionary = {"back":0,"race":0,"cancel":0,"share":0}
	page.back_requested.connect(func() -> void: signals.back += 1)
	page.race_requested.connect(func() -> void: signals.race += 1)
	page.share_requested.connect(func() -> void: signals.share += 1)
	await click((page.find_child("ChallengeResultsBack",true,false) as Button).get_global_rect().get_center())
	check(signals.back == 1 and signals.race == 0,"visible Back action emits only navigation")
	await click((page.find_child("ChallengeRace",true,false) as Button).get_global_rect().get_center())
	check(signals.race == 0,"disabled race rejects pointer input")
	await mount(fixture(),"verified",{"counted":true,"ms":106350})
	page.share_requested.connect(func() -> void: signals.share += 1)
	var share: Button
	for button: Node in page.find_children("*","Button",true,false):
		if button.text == "Share": share = button
	await click(share.get_global_rect().get_center())
	check(signals.share == 1,"Share action forwards once without a service call")
	root.remove_child(host)
	host.queue_free()
	background.queue_free()
	await settle()
	await app_view()
	print("CHALLENGE_RESULT_VIEW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

func app_view() -> void:
	root.size = Vector2i(1280,720)
	var app: Node = load("res://core/app.tscn").instantiate()
	var directory: String = "user://result-view-app-"+TrackLibrary.unique_id()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.online.client.player = {"id":"self"}
	app.online.client._access_token = "fixture"
	app.challenges.reset()
	app.challenges.busy = true
	app.challenge_browsing = true
	app.challenge_result_view = true
	app.challenges.selected = fixture()
	app.challenges.result_state = "verified"
	app.challenges.outcome = {"counted":true,"ms":106350}
	app._show_screen("challenges")
	await settle()
	app.challenges.busy = false
	app.challenges.error = ""
	app._challenges()
	await settle()
	page = app.root_ui.find_child("ChallengesPage",true,false)
	check(page != null and app.root_ui.find_child("MenuHeader",true,false) != null,"result view composes with the real app header")
	var time: Label = page.find_child("ChallengeResultTime",true,false)
	var scroll: ScrollContainer = page.find_child("ChallengeResultContentScroll",true,false)
	check(time.text == "01:46.350" and time.get_global_rect().end.y <= scroll.get_global_rect().end.y,"real app keeps the personal result visible before scrolling")
	check(scroll.get_v_scroll_bar().max_value <= scroll.size.y+1,"normal app menu fits the complete group debrief")
	bounds("ChallengeActions")
	await capture("app-result-1280x720")
	app.queue_free()
	await settle()

func click(position: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func capture(caption: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	var path: String = evidence.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	check(root.get_texture().get_image().save_png(path.path_join(caption+".png")) == OK,"capture "+caption)

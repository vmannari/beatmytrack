extends SceneTree
## Presentation and action gates for the Race tab; no external services/player data.
var checks: int = 0
var failures: int = 0
var selection: String = ""
var races: int = 0

func _initialize() -> void: call_deferred("run")

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+detail)

func fixture(group: bool = false) -> Dictionary:
	var value: Dictionary = {"code":"AB12CD34EF56AB78","mode":"group" if group else "beat","state":"active","creator":"Mika","creator_id":"rival","self_id":"self","joined":true,"vehicle_id":"compact","target_ms":98250 if not group else null,"target_ticks":11790 if not group else null,"ends_at":604800,"server_now":432000,"entry":{"name":"Forest Run","theme":"pine","points":[[0,0],[100,0],[120,70],[40,90],[-10,30]]},"standings":[]}
	for index: int in range(20 if group else 2):
		value.standings.append({"id":"self" if index == 1 else "rival" if index == 0 else "driver_%d" % index,"name":"You" if index == 1 else "Mika" if index == 0 else "Driver %d" % index,"rank":index+1,"ms":98250+index*1000,"ticks":11790+index*120})
	return value

func page_for(value: Dictionary, signed_in: bool = true, busy: bool = false) -> ChallengesPage:
	var page := ChallengesPage.new()
	page.signed_in = signed_in
	page.busy = busy
	page.selected = value.duplicate(true)
	if not value.is_empty(): page.items.assign([value.duplicate(true)])
	page.selected_requested.connect(func(code: String) -> void: selection = code)
	page.race_requested.connect(func() -> void: races += 1)
	root.add_child(page)
	MenuStyle.fill(page)
	return page

func settle() -> void:
	await process_frame
	await process_frame

func remove_page(page: ChallengesPage) -> void:
	page.queue_free()
	await process_frame

func bounds(page: ChallengesPage, name: String) -> void:
	var node: Control = page.find_child(name,true,false)
	var rectangle: Rect2 = node.get_global_rect()
	var viewport: Rect2 = root.get_visible_rect()
	check(rectangle.position.x >= -1 and rectangle.position.y >= -1 and rectangle.end.x <= viewport.end.x+1 and rectangle.end.y <= viewport.end.y+1,name+" fits "+str(viewport.size))

func run() -> void:
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		var value: Dictionary = fixture()
		var page: ChallengesPage = page_for(value)
		await settle()
		check((page.find_child("ChallengeTargetTime",true,false) as Label).text == "01:38.250","duel shows the fixed target in minutes")
		check((page.find_child("ChallengePersonalBest",true,false) as Label).text.ends_with("01:39.250"),"own challenge best is distinct from target")
		check((page.find_child("ChallengePersonalGap",true,false) as Label).text == "+1.000 s","player gap compares with the fixed target")
		var own: PanelContainer = page.find_child("ChallengeDriver_self",true,false)
		check(own.get_theme_stylebox("panel").bg_color == MenuStyle.ACCENT,"player standing retains yellow highlight")
		var row: HBoxContainer = own.get_child(0)
		check((row.get_child(2) as Label).text == "01:39.250" and (row.get_child(3) as Label).text == "+1.000","standings give comparable times and signed gaps")
		for name: String in ["ChallengeHeader","ChallengeTrackPreview","ChallengeActions","ChallengeStandingsHeader"]: bounds(page,name)
		var race: Button = page.find_child("ChallengeRace",true,false)
		check(not race.disabled and race.text == "Race","joined recipient can race")
		var card: Button = page.find_child("ChallengeCard_"+str(value.code),true,false)
		if DisplayServer.get_name() != "headless":
			selection = ""
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = card.get_global_rect().get_center()
			click.global_position = click.position
			click.pressed = true
			root.push_input(click,true)
			click = click.duplicate()
			click.pressed = false
			root.push_input(click,true)
			await process_frame
			check(selection == value.code,"whole scenic card accepts pointer selection")
		await remove_page(page)
		value.standings[0].ms = 90000
		page = page_for(value)
		await settle()
		check((page.find_child("ChallengeTargetTime",true,false) as Label).text == "01:38.250","later creator best never moves the pinned duel target")
		await remove_page(page)
		value = fixture(true)
		page = page_for(value)
		await settle()
		var scroll: ScrollContainer = page.find_child("ChallengeStandingsScroll",true,false)
		check(scroll.get_v_scroll_bar().max_value > scroll.size.y,"all twenty drivers remain scrollable")
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await settle()
		check(page.find_child("ChallengeDriver_driver_19",true,false).get_global_rect().intersects(scroll.get_global_rect()),"final group driver is reachable")
		await remove_page(page)
	var value: Dictionary = fixture(true)
	for row: Dictionary in value.standings:
		row.ms = null
		row.ticks = null
		row.rank = null
	var page: ChallengesPage = page_for(value)
	await settle()
	check((page.find_child("ChallengeTargetTime",true,false) as Label).text == "Set the first time","unseeded group has an actionable empty state")
	check(page.find_child("ChallengePersonalBest",true,false) == null,"missing player time is never invented")
	await remove_page(page)
	value = fixture()
	value.standings[1].ms = value.target_ms
	value.standings[1].ticks = value.target_ticks
	page = page_for(value)
	await settle()
	check((page.find_child("ChallengePersonalGap",true,false) as Label).text == "Tied with target","equal duel time is never presented as a win")
	await remove_page(page)
	value.standings[1].ms = 97000
	value.standings[1].ticks = 11640
	page = page_for(value)
	await settle()
	check((page.find_child("ChallengePersonalGap",true,false) as Label).text == "Target beaten","faster verified challenge best shows success")
	await remove_page(page)
	value = fixture(true)
	value.standings[1].ms = value.standings[0].ms
	value.standings[1].ticks = value.standings[0].ticks
	value.standings[1].rank = 1
	page = page_for(value)
	await settle()
	check((page.find_child("ChallengePersonalGap",true,false) as Label).text == "Joint lead","shared group first place is described accurately")
	await remove_page(page)
	value = fixture()
	value.entry.name = "A very long community track name that must remain within the challenge panel"
	value.creator = "A very long driver name that must not push the race action outside the panel"
	page = page_for(value)
	await settle()
	for name: String in ["ChallengeHeader","ChallengeTrackPreview","ChallengeActions"]: bounds(page,name)
	await remove_page(page)
	for state: String in ["complete","cancelled","settling","exhausted","creator","busy","guest","unjoined"]:
		value = fixture()
		if state in ["complete","cancelled","settling"]: value.state = state
		if state == "exhausted":
			value.attempt_limit = 3
			value.attempts_remaining = 0
		if state == "creator": value.creator_id = "self"
		if state in ["guest","unjoined"]: value.joined = false
		page = page_for(value,state != "guest",state == "busy")
		await settle()
		var race: Button = page.find_child("ChallengeRace",true,false)
		check(race.disabled == (state not in ["guest","unjoined"]),state+" preserves the existing start gate")
		if state == "guest": check(race.text == "Try track","guest retains invitation try")
		if state == "unjoined": check(race.text == "Join & race","authenticated recipient has a clear join action")
		if state == "exhausted": check(race.text == "No tries left","exhausted start explains its state")
		if state == "creator": check(race.text == "Waiting for opponent","creator cannot race their fixed duel target")
		await remove_page(page)
	page = page_for({},true,true)
	await settle()
	var labels: Array[Node] = page.find_children("*","Label",true,false)
	check(labels.any(func(node: Node) -> bool: return node.text == "Loading challenges…"),"initial refresh does not claim an empty inbox")
	await remove_page(page)
	print("CHALLENGE TAB: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends "res://tests/test_rivalry_result.gd"
## Native layout, live-score refresh and reference evidence using isolated fixtures.
var before: bool = false

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	before = "--before" in OS.get_cmdline_user_args()
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-view-polish-2026-10-24/"+RenderingServer.get_current_rendering_method()+"/"+("before" if before else "after"))
	DirAccess.make_dir_recursive_absolute(evidence)
	var snapshot: Dictionary = fixture()
	snapshot.week = 43
	snapshot.self_id = snapshot.standings[0].id
	snapshot.standings.resize(14)
	var scores: Array[int] = [121,90,84,73,58,58,52,48,43,36,29,22,16,9]
	for index: int in range(snapshot.standings.size()):
		var driver: Dictionary = snapshot.standings[index]
		driver.points = scores[index]
		driver.rank = index+1
		driver.country_code = ["FI","ES","SE","JP","FR","DE"][index%6]
		driver.name = ["You","Kai Rowan","Kai Lake","Kai Reed","Ari Quinn","Nova Reed"][index%6]
		var livery: Dictionary = VehicleLivery.defaults("compact")
		livery.colors.body = ["b42d25","de4a21","c9c1a0"][index%3]
		livery.colors.accent = ["eee9d8","201d21","5c8790"][index%3]
		livery.pattern = "apex_twin"
		var parts: Dictionary = VehicleCustomisation.defaults()
		parts.aero = "wing"
		driver.appearance = {"vehicle_id":"compact","livery":livery,"customisation":parts}
	# Reference-shaped data lives only in this explicitly isolated UI fixture.
	var times: Array[int] = [46592,69717,74442,91500,77850]
	for slot: int in range(5):
		var track: Dictionary = snapshot.tracks[slot]
		track.entry.name = ["Infinity","Saw","Sightseeing","Spiral","Lonkero"][slot]
		track.entry.theme = "pine" if slot < 4 else "winter"
		track.entries = []
		for index: int in range(14):
			var driver: Dictionary = snapshot.standings[index]
			var place: int = index+1 if slot < 4 else 14 if index == 0 else index
			var ms: int = times[slot]+index*600 if slot < 4 else times[slot]-7030+(place-1)*300 if index > 0 else times[slot]
			track.entries.append({"id":driver.id,"name":driver.name,"country_code":driver.country_code,"rank":place,"ms":ms,"ticks":ms*120/1000,"points":snapshot.points_policy[place-1]})
		track.entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.rank) < int(b.rank))
	var model := WeeklyRivalry.new()
	model.apply_snapshot(snapshot)
	var page_script: Script = preload("res://ui/weekly_rivalry_page.gd")
	if before:
		var baseline := GDScript.new()
		baseline.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-view-polish-2026-10-24/before/weekly_rivalry_page.gd").replace("class_name WeeklyRivalryPage","")
		check(baseline.reload() == OK,"task-start page compiles for native comparison")
		page_script = baseline
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		var background := MenuBackdrop.new()
		root.add_child(background)
		background.size = root.get_visible_rect().size
		var shell := VBoxContainer.new()
		shell.theme = MenuStyle.theme()
		root.add_child(shell)
		shell.position = Vector2(24,20)
		shell.size = root.get_visible_rect().size-Vector2(48,40)
		shell.add_theme_constant_override("separation",12)
		var nav := HBoxContainer.new()
		shell.add_child(nav)
		nav.add_child(MenuBrand.new())
		for label: String in ["RACE","CREATE","GARAGE","STORE"]:
			var tab: Button = MenuStyle.tab(label,func() -> void: pass,label == "RACE")
			tab.custom_minimum_size.y = 64
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nav.add_child(tab)
		nav.add_child(MenuStyle.button("Ville  ⌄",func() -> void: pass))
		var page: Control = page_script.new()
		page.model = model
		page.signed_in = true
		shell.add_child(page)
		for _frame: int in range(16): await process_frame
		if not before: inspect_page(page)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(evidence.path_join("overview-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save native overview")
		page.free()
		shell.free()
		background.free()
		await process_frame
	if not before: await score_states(model,snapshot)
	print("RIVALRY_VIEW_POLISH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func inspect_page(page: Control) -> void:
	var winner: Control = page.find_child("RivalryPodium_1",true,false)
	var runner: Control = page.find_child("RivalryPodium_2",true,false)
	check(is_equal_approx(runner.global_position.y-winner.global_position.y,8.0),"winner is raised eight units")
	check(winner.size.y <= 194,"compact podium preserves standings space")
	var reference: Rect2 = page.find_child("RivalryPodiumFooter_1",true,false).get_global_rect()
	for position: int in range(1,4):
		var footer: Control = page.find_child("RivalryPodiumFooter_"+str(position),true,false)
		check(is_equal_approx(footer.global_position.y,reference.position.y) and is_equal_approx(footer.size.y,reference.size.y),"all footers align")
		var flag: Control = page.find_child("RivalryPodiumIdentity_"+str(position),true,false).get_node("PlayerCountryFlag")
		var name_label: Label = page.find_child("RivalryPodiumName_"+str(position),true,false)
		var points: Label = page.find_child("RivalryPodiumPoints_"+str(position),true,false)
		check(flag.get_global_rect().end.x <= name_label.global_position.x and name_label.get_global_rect().end.x <= points.global_position.x,"flag, name and right-hand points do not overlap")
		check(footer.get_global_rect().encloses(points.get_global_rect()),"points stay within footer")
		var car: Control = page.find_child("RivalryPodiumCar_"+str(position),true,false)
		check(car.size.y >= 88 and car.fit_to_frame,"larger car previews fit the available frame")
		check(car.viewport.size.x <= 1536 and car.viewport.size.y <= 768,"render targets retain existing bounds")
		var card: PanelContainer = page.find_child("RivalryPodium_"+str(position),true,false)
		var style: StyleBoxFlat = card.get_theme_stylebox("panel")
		var expected: Color = Color("27220df5") if position == 1 else Color("152b39f5") if position == 2 else Color("302019f5")
		check(style.bg_color == expected and card.material == null,"flat medal backgrounds retain reference colors without gradient materials")
	for index: int in range(5):
		var row: Button = page.find_child("SelectRivalryTrack_"+str(index),true,false)
		var time: Label = page._track_views[index].time
		var delta: Label = page._track_views[index].delta
		check(row.find_child("RivalryTrackSelectionMark_"+str(index),true,false) == null,"yellow selection stripe is removed")
		check(absf(row.get_global_rect().end.x-time.get_global_rect().end.x-6.0) < 1.0,"times use the row width with only six units of right padding")
		check(is_equal_approx(time.get_global_rect().end.x,delta.get_global_rect().end.x),"times and status share a right edge")
		check(row.size.y >= 48 and page.get_global_rect().grow(1).encloses(row.get_global_rect()),"all five track targets fit")
	var header: Label = page.find_child("RivalryPositionSummary",true,false)
	check(header.text == "1ST OF 14 · 31 PTS AHEAD","header derives actual position and lead")
	var clock: Control = page.find_child("RivalryWeekAndClock",true,false)
	check(header.get_global_rect().end.x < clock.global_position.x,"header summary and countdown do not overlap")
	var gap_heading: Control = page.find_child("RivalryColumn_GAP",true,false)
	var own_gap: Control = page.find_child("RivalryPlayerGap_you",true,false)
	check(absf(gap_heading.get_global_rect().end.x-own_gap.get_global_rect().end.x) <= 1.0,"standings headings align after the quieter scrollbar inherits its native theme")
	var started: int = page.content_builds
	var original_id: int = winner.get_instance_id()
	model_update(page,122)
	check(page.content_builds == started and winner.get_instance_id() == original_id,"score refresh retains the actual podium and car controls")
	check(header.text == "1ST OF 14 · 32 PTS AHEAD","live score refresh updates the header")
	check(page.find_child("RivalryPodiumPoints_1",true,false).text == "122","live footer points update without a repeated PTS suffix")
	model_update(page,121)

func model_update(page: Control, points: int) -> void:
	for row: Dictionary in page.model.server_standings:
		if row.id == WeeklyRivalry.SELF: row.points = points
	page.refresh_presentation()

func score_states(model: WeeklyRivalry, snapshot: Dictionary) -> void:
	var page := WeeklyRivalryPage.new()
	page.model = model
	check(page._position_summary() == "1ST OF 14 · 31 PTS AHEAD","leading state")
	var value: Dictionary = snapshot.duplicate(true)
	value.standings[0].points = 90
	model.apply_snapshot(value)
	check(page._position_summary() == "1ST OF 14 · TIED FOR LEAD","tied points never claim an advantage")
	value = snapshot.duplicate(true)
	value.self_id = value.standings[1].id
	model.apply_snapshot(value)
	check(page._position_summary() == "2ND OF 14 · 31 PTS TO LEAD","trailing state uses the actual leader gap")
	value.standings[1].rank = null
	value.standings[1].points = 0
	model.apply_snapshot(value)
	check(page._position_summary() == "UNRANKED OF 14","unranked state never invents a position")
	page.free()

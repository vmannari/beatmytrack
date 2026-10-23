extends "res://tests/test_rivalry_result.gd"
const Adapter = preload("res://backend/weekly_rivalry_client.gd")

func awarded_snapshot(kind: String) -> Dictionary:
	var value: Dictionary = fixture()
	value.state = "complete"
	value.personal_best_slots = [0,2,4]
	for slot: int in range(5):
		var track: Dictionary = value.tracks[slot]
		for row: Dictionary in track.entries:
			row.ticks = 12000+int(str(row.id).get_slice("_",1))*120
			if row.id == value.self_id:
				row.ticks = 11640 if kind == "perfect" or (kind == "champion" and slot < 4) else 12180 if kind in ["podium","champion"] else 12900
			if kind == "tied" and row.id in [value.self_id,"driver_0"]: row.ticks = 11640
			if kind == "unranked" and row.id == value.self_id: row.ticks = null
			row.ms = null if row.ticks == null else roundi(float(row.ticks)*1000/120)
		track.entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return b.ticks == null or (a.ticks != null and int(a.ticks) < int(b.ticks)))
		var rank: int = 0
		var previous: int = -1
		for position: int in range(track.entries.size()):
			var row: Dictionary = track.entries[position]
			if row.ticks == null: row.rank = null; row.points = 0; continue
			if int(row.ticks) != previous: rank = position+1
			previous = int(row.ticks)
			row.rank = rank
			row.points = value.points_policy[rank-1]
	for driver: Dictionary in value.standings:
		driver.points = 0; driver.completed = 0
		for track: Dictionary in value.tracks:
			for row: Dictionary in track.entries:
				if row.id == driver.id:
					driver.points += int(row.points)
					if row.ms != null: driver.completed += 1
	value.standings.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.points) > int(b.points))
	var rank: int = 0
	var previous: int = -1
	for index: int in range(value.standings.size()):
		var driver: Dictionary = value.standings[index]
		if int(driver.points) != previous: rank = index+1
		previous = int(driver.points)
		driver.rank = rank if driver.completed > 0 else null
	if kind == "unranked": value.personal_best_slots = []
	return value

func run() -> void:
	evidence = OS.get_environment("BMT_RIVALRY_AWARDS_CAPTURE_DIR")
	if evidence.is_empty(): evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-awards-2026-10-12/ui")
	if RenderingServer.get_current_rendering_method() == "mobile": evidence += "/mobile"
	DirAccess.make_dir_recursive_absolute(evidence)
	for kind: String in ["perfect","champion","podium","middle","unranked","tied"]:
		var model := WeeklyRivalry.new()
		var value: Dictionary = awarded_snapshot(kind)
		check(Adapter.valid_snapshot(value),kind+" fixture is a valid server-shaped snapshot")
		var before: String = JSON.stringify(value)
		model.apply_snapshot(value)
		var summary: Dictionary = model.finale_summary()
		check(JSON.stringify(value) == before,kind+" awards never mutate scores or pinned tracks")
		check(summary.perfect == (kind == "perfect"),kind+" Perfect Week requires five outright competitive wins")
		check(summary.tier == {"perfect":3,"champion":2,"podium":1,"middle":0,"unranked":0,"tied":2}[kind],kind+" celebration scales with verified achievement")
		check(summary.title == "JOINT WEEKLY CHAMPION" if kind == "tied" else true,"ties cannot claim an exclusive championship")
		check(not "clean" in " ".join(summary.highlights).to_lower(),"no clean-driving claim without collision evidence")
		if kind == "perfect":
			check(summary.wins == 5 and summary.points == 150 and summary.rank == 1,"perfect championship derives all five victories and actual points")
			check(summary.results[0].gap_to_second_ms == -3000,"gap to second is signed from actual finishing times")
		if kind == "unranked":
			check(summary.rank == null and summary.wins == 0 and summary.points == 0,"no finish cannot invent a position, victory or award")
		check(model.finale_share_text().contains("Week 41") and model.finale_share_text().contains("Frostbite"),"share includes the actual week and named tracks")
		model.completed = false
		check(model.finale_summary().tier == 0 and model.finale_share_text().is_empty(),"unsettled/active snapshots cannot share championship awards")
	var one: Dictionary = awarded_snapshot("perfect")
	one.standings = one.standings.filter(func(row: Dictionary) -> bool: return row.id == one.self_id)
	for track: Dictionary in one.tracks: track.entries = track.entries.filter(func(row: Dictionary) -> bool: return row.id == one.self_id)
	var solo := WeeklyRivalry.new()
	solo.apply_snapshot(one)
	check(not solo.finale_summary().perfect and solo.finale_summary().wins == 0 and solo.finale_summary().tier == 0,"a field with no opponent earns no contested victories")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(awarded_snapshot("perfect")))
	check(Adapter.valid_snapshot(parsed),"PB slots accept integral JSON numbers from the real decoder")
	solo.apply_snapshot(parsed)
	check(solo.personal_best_slots == [0,2,4],"PB slots survive a JSON response round trip")
	for bad: Array in [[0,0],[5],[0.5],["1"]]:
		parsed.personal_best_slots = bad
		check(not Adapter.valid_snapshot(parsed),"malformed PB slots cannot enter an awards snapshot")
	for tier: int in range(4):
		var art: Control = preload("res://ui/rivalry_award_art.gd").new()
		art.tier = tier
		root.add_child(art)
		check(art.is_processing() == (tier >= 2),"confetti motion is reserved for an earned championship")
		if tier >= 2:
			art._process(6.1)
			check(not art.is_processing() and art.elapsed == 6.0,"confetti stops after its bounded six-second flourish")
		art.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await check_rendered_laurel_symmetry()
		await visuals_awards()
	print("RIVALRY_AWARDS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func visuals_awards() -> void:
	OS.set_environment("BMT_API_URL","")
	var folder: String = "user://rivalry_awards_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.records.settings.vehicle_liveries = {"compact":{"version":1,"colors":{"body":"993d3d","accent":"e4ba59"}}}
	var saved_settings: String = JSON.stringify(app.records.settings)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1536,1024),Vector2i(1600,720)]:
		root.size = dimensions
		for kind: String in ["perfect","champion","podium","middle","unranked","tied"]:
			app.rivalry.model.apply_snapshot(awarded_snapshot(kind))
			app.rivalry.snapshot_scope = app.rivalry.scope()
			app.rivalry.busy = false
			app.rivalry_section = "overview"
			app._show_screen("rivalry")
			await settle()
			var ceremony: Control = app.content.find_child("WeeklyRivalryFinale",true,false)
			check(ceremony != null,"completed overview mounts the awards ceremony")
			var next: Button = ceremony.find_child("RivalryNextWeek",true,false)
			var share: Button = ceremony.find_child("RivalryShareResults",true,false)
			check(not next.disabled and not share.disabled,"completed authoritative ceremony enables sharing and Continue")
			check(next.get_global_rect().end.y <= app.root_ui.size.y+1,"Continue remains inside the visible screen")
			check(share.get_global_rect().end.y <= app.root_ui.size.y+1,"sharing remains inside the visible screen")
			check(next.get_global_rect().end.y <= app.content.get_global_rect().end.y+0.5,"Continue is fully inside the page clipping boundary")
			check(share.get_global_rect().end.y <= app.content.get_global_rect().end.y+0.5,"Share is fully inside the page clipping boundary")
			check(absf(share.size.x-next.size.x) < 2,"outside-card bottom actions have equal width")
			check(ceremony.track_buttons.size() == 5,"all five pinned tracks have a thumbnail/detail action")
			var track_scroll: ScrollContainer = ceremony.find_child("RivalryFinalTrackScroll",true,false)
			for row: Button in ceremony.track_buttons:
				check(row.get_global_rect().end.y <= track_scroll.get_global_rect().end.y+1,"all five track rows remain visible in the initial ceremony")
				check(row.get_global_rect().end.y <= ceremony.find_child("RivalryFinaleBody",true,false).get_global_rect().end.y+1,"track rows fit inside the actual body clipping viewport")
				for child: Node in row.find_children("*","Label",true,false):
					check(child.get_global_rect().end.x <= row.get_global_rect().end.x+1,"track names, times, gaps and points stay inside their row")
			check(ceremony.find_child("RivalryChampionLaurels",true,false).tier == ceremony.summary.tier,"award ornament receives the performance intensity")
			if kind in ["perfect","champion","tied"]: check_decoration_alignment(ceremony,kind)
			check((ceremony.find_child("RivalryPerfectWeekBadge",true,false) != null) == (kind == "perfect"),"Perfect Week badge matches the actual five-win condition")
			if kind == "perfect": check_perfect_badge_alignment(ceremony)
			check(ceremony.find_child("FinalDriver_you",true,false) != null,"compact final standings always include the highlighted player")
			check(ceremony.find_child("RivalryDriversPanel",true,false).find_children("FinalDriver_*","",true,false).size() <= 5,"compact standings contain at most five actual competitors")
			var car: Control = ceremony.find_child("RivalryVictoryCar",true,false)
			check(car.car.vehicle_id == app.rivalry.model.vehicle_id and car.viewport.transparent_bg,"scenic hero renders the actual pinned car with a transparent background")
			await capture(kind,dimensions)
		var page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
		var ceremony: Control = page.find_child("WeeklyRivalryFinale",true,false)
		ceremony.track_buttons[2].pressed.emit()
		await settle()
		check(app.rivalry_section == "detail" and app.rivalry_track == 2,"award track rows open their original completed-week detail")
		app.rivalry_section = "overview"
		app.rivalry.busy = true
		app.rivalry.error = "Could not continue. Try again."
		app._rivalry()
		await settle()
		var next: Button = app.content.find_child("RivalryNextWeek",true,false)
		var share: Button = app.content.find_child("RivalryShareResults",true,false)
		check(next.disabled and share.disabled,"ceremony guards both actions while Continue is in flight")
		check(app.content.find_child("RivalryStatusMessage",true,false).text == app.rivalry.error,"failed Continue remains actionable in the original ceremony")
		await capture("continuing",dimensions)
		app.rivalry.busy = false
		app.rivalry.error = ""
	for id: String in VehicleCatalog.IDS:
		var snapshot: Dictionary = awarded_snapshot("perfect")
		snapshot.vehicle_id = id
		app.rivalry.model.apply_snapshot(snapshot)
		app.rivalry_section = "overview"
		app._rivalry()
		await settle()
		var car: Control = app.content.find_child("RivalryVictoryCar",true,false)
		check(car.car.vehicle_id == id and car.car.livery == VehicleLivery.for_car(app.records.settings,id),"ceremony uses each actual car and its local livery")
		var pixels: Image = car.viewport.get_texture().get_image()
		var clipped: bool = false
		for x: int in range(pixels.get_width()):
			if pixels.get_pixel(x,0).a > 0.1 or pixels.get_pixel(x,pixels.get_height()-1).a > 0.1: clipped = true
		check(not clipped,"actual "+id+" car fits the transparent viewport without vertical clipping")
		await capture("car-"+id,Vector2i(1600,720))
	var share: Button = app.content.find_child("RivalryShareResults",true,false)
	share.pressed.emit()
	await settle()
	check(DisplayServer.clipboard_get().replace("\r\n","\n") == app.rivalry.model.finale_share_text(),"desktop Share copies the exact championship summary with Windows clipboard newline normalization")
	var copied: String = DisplayServer.clipboard_get()
	app.rivalry.snapshot_scope = "different-player-or-car"
	app._share_rivalry_results()
	check(DisplayServer.clipboard_get() == copied,"sharing cannot expose an out-of-scope finale after account/car changes")
	check(JSON.stringify(app.records.settings) == saved_settings,"ceremony and sharing never alter local paint, condition or profile settings")
	app.queue_free()
	await process_frame

func check_decoration_alignment(ceremony: Control, kind: String) -> void:
	var heading: Label = ceremony.title
	var art: Control = ceremony.ornament
	var font: Font = heading.get_theme_font("font")
	var font_size: int = heading.get_theme_font_size("font_size")
	var words_width: float = font.get_string_size(heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var heading_rect: Rect2 = heading.get_global_rect()
	var words_left: float = heading_rect.position.x+(heading_rect.size.x-words_width)*0.5 if heading.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else heading_rect.position.x
	var words := Rect2(Vector2(words_left,heading_rect.position.y),Vector2(words_width,heading_rect.size.y))
	var crown: PackedVector2Array = art.crown_geometry()
	var global_crown := PackedVector2Array()
	for point: Vector2 in crown: global_crown.append(art.get_global_transform()*point)
	var crown_bounds := Rect2(global_crown[0],Vector2.ZERO)
	for point: Vector2 in global_crown: crown_bounds = crown_bounds.expand(point)
	check(absf(crown_bounds.get_center().x-words.get_center().x) <= 1.0,kind+" crown is centered over the actual rendered words")
	check(crown_bounds.end.y+6 <= words.position.y,kind+" crown and its underline stay above the heading")
	check(crown_bounds.position.y >= app.content.get_global_rect().position.y,kind+" crown stays within the rivalry page")
	check(art.size.x >= words_width+100 and art.size.x <= words_width+120,kind+" wreath fits the heading with symmetric text clearance")
	var geometry: Dictionary = art.laurel_geometry()
	var left: Rect2 = geometry.left_rect
	var right: Rect2 = geometry.right_rect
	check(absf(left.get_center().x+right.get_center().x-art.size.x) < 0.01 and left.size == right.size,kind+" curved botanical branches mirror around the heading")
	var left_end: Vector2 = art.get_global_transform()*left.end
	var right_start: Vector2 = art.get_global_transform()*right.position
	check(left_end.x <= words.position.x-6 and right_start.x >= words.end.x+6,kind+" both laurel branches remain clear of the rendered heading")

func check_rendered_laurel_symmetry() -> void:
	for badge: bool in [false,true]: await check_rendered_branches(badge)

func check_rendered_branches(badge: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(112,72) if badge else Vector2i(480,128)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var art: Control = preload("res://ui/rivalry_award_art.gd").new()
	art.tier = 1
	art.badge = badge
	art.size = Vector2(viewport.size)
	viewport.add_child(art)
	await settle()
	await RenderingServer.frame_post_draw
	var pixels: Image = viewport.get_texture().get_image()
	var visible: int = 0
	var mismatched: int = 0
	for y: int in range(pixels.get_height()):
		for x: int in range(18 if badge else 44):
			var left: Color = pixels.get_pixel(x,y)
			var right: Color = pixels.get_pixel(pixels.get_width()-1-x,y)
			if left.a > 0.05: visible += 1
			if absf(left.r-right.r) > 0.02 or absf(left.g-right.g) > 0.02 or absf(left.b-right.b) > 0.02 or absf(left.a-right.a) > 0.02: mismatched += 1
	check(visible > (100 if badge else 500),"native render contains actual laurel leaves in the expected left branch")
	check(mismatched == 0,"actual laurel pixels mirror within their intended branch rectangles")
	viewport.queue_free()
	await process_frame

func check_perfect_badge_alignment(ceremony: Control) -> void:
	var badge: Control = ceremony.find_child("RivalryPerfectWeekBadge",true,false)
	var art: Control = badge.find_child("RivalryPerfectWeekArt",true,false)
	var label: Label = badge.find_child("RivalryPerfectWeekText",true,false)
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var width: float = maxf(font.get_string_size("PERFECT",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,font.get_string_size("WEEK",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
	var rect: Rect2 = label.get_global_rect()
	var words := Rect2(Vector2(rect.get_center().x-width*0.5,rect.position.y),Vector2(width,font.get_height(font_size)*2))
	var crown: Rect2 = art.get_global_transform()*art.crown_rect()
	var branches: Dictionary = art.laurel_geometry()
	var left: Rect2 = art.get_global_transform()*branches.left_rect
	var right: Rect2 = art.get_global_transform()*branches.right_rect
	check(absf(crown.get_center().x-words.get_center().x) <= 1,"Perfect Week crown centers over both title lines")
	check(crown.end.y <= words.position.y-2,"Perfect Week crown stays above its lettering")
	check(left.end.x <= words.position.x-4 and right.position.x >= words.end.x+4,"Perfect Week branches stay clear of both words")
	check(words.end.y <= badge.get_global_rect().end.y+0.5,"Perfect Week lettering fits inside the badge")
	check(left.position.y >= badge.get_global_rect().position.y and right.end.y <= badge.get_global_rect().end.y+0.5,"Perfect Week laurels fit inside their badge")

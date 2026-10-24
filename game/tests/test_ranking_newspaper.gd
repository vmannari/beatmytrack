extends SceneTree
## Native navigation, publication-week correctness and stale-response checks.
const Fixture = preload("res://tests/test_world_ranking.gd")
const News = preload("res://backend/news_client.gd")
const Awards = preload("res://tests/test_rivalry_awards.gd")
const Week = preload("res://ui/world_ranking_week_summary.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/ranking-newspaper-2026-10-24"

class Backend extends Fixture.Service:
	var signed: bool = true
	var fail_page: bool = false
	var hold_page: bool = false
	var week: int = 1792972800
	func signed_in() -> bool: return signed
	func request_api(path: String, method: int = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", auth: bool = false) -> Dictionary:
		if path.begins_with("/news"):
			return {"ok":true,"data":{"items":[],"next_cursor":"","refreshing":false,"checked_day":server_now()/86400}}
		if path.begins_with("/ranking?") and hold_page: await reply
		if path.begins_with("/ranking?") and fail_page: return {"ok":false}
		var response: Dictionary = await super.request_api(path,method,payload,key,auth)
		response.data.week_start = week
		return response

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func settle(count: int = 20) -> void:
	for _tick: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK,"capture "+id)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	output = ProjectSettings.globalize_path(output).path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	var backend := Backend.new()
	root.add_child(backend)
	var data: Dictionary = (await backend.request_api("/ranking/me")).data
	check("Up 36 places" in Week.describe(data,backend.week) and "+135 points" in Week.describe(data,backend.week),"weekly overview shows published place and net points change")
	data.movement = -8
	data.net_change = -60
	check("Down 8 places" in Week.describe(data,backend.week) and "-60 points" in Week.describe(data,backend.week),"falling rank and expiring points have explicit signs")
	data.movement = 0
	check("Position unchanged" in Week.describe(data,backend.week),"unchanged position is explicit")
	data.movement = null
	check("New World Ranking entry" in Week.describe(data,backend.week),"first ranking has no invented movement")
	data.movement = 36
	check(Week.describe(data,backend.week+604800) == "World Ranking updating…","unpublished week never shows the previous movement")
	check(not "places" in Week.describe(data,backend.week-604800),"older ceremony never attributes latest movement to its week")
	var host := MarginContainer.new()
	host.theme = MenuStyle.theme()
	for side: String in ["left","right","top","bottom"]: host.add_theme_constant_override("margin_"+side,24)
	root.add_child(host)
	MenuStyle.fill(host)
	var rivalry := WeeklyRivalryPage.new()
	rivalry.model = WeeklyRivalry.new(true)
	rivalry.safety_client = backend
	rivalry.signed_in = true
	host.add_child(rivalry)
	var before: int = backend.calls
	await settle()
	check(rivalry.find_child("WorldCircuitEntry",true,false) == null and rivalry.find_child("WorldRankingSummaryBlock",true,false) == null,"ordinary Rivalry header has no ranking navigation")
	check(backend.calls == before,"ordinary Rivalry opens without ranking reads")
	check(rivalry.get_combined_minimum_size().x <= host.size.x,"Rivalry overview fits its allocated width")
	capture("weekly-overview-1280")
	var rail: Node = rivalry.find_child("RaceModes",true,false)
	var returned: Array = []
	rivalry.car_rivalry_requested.connect(func() -> void: returned.append(true))
	rivalry.circuit_mode = true
	rail.mode_requested.emit("rivalry")
	check(returned.size() == 1,"Rivalry rail returns from Compact Circuit to car Rivalry")
	host.remove_child(rivalry)
	rivalry.queue_free()
	var awards := Awards.new()
	var model := WeeklyRivalry.new()
	model.apply_snapshot(awards.awarded_snapshot("champion"))
	model.world_circuit = {"week_start":backend.week}
	awards.free()
	var completed := WeeklyRivalryPage.new()
	completed.model = model
	completed.safety_client = backend
	completed.signed_in = true
	completed.circuit_mode = true
	host.add_child(completed)
	await settle()
	var change: Label = completed.find_child("WorldRankingWeekChange",true,false)
	check(change != null and "Up 36 places" in change.text,"completed-week overview displays ranking change")
	check(completed.find_child("RivalryFinaleBody",true,false).get_global_rect().encloses(change.get_global_rect()),"ranking movement is visible without scrolling the completed overview")
	check(completed.find_child("WorldCircuitEntry",true,false) == null,"completed-week overview has no Circuit button")
	check(completed.find_child("WorldRankingWeekResult",true,false).find_children("*","Button",true,false).is_empty(),"weekly ranking summary contains only results")
	capture("weekly-results-1280")
	host.queue_free()
	await settle()
	var directory: String = ProjectSettings.globalize_path("res://../build/ranking-newspaper/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	GameSoundtrack.instance().music_enabled = false
	app._show_screen("garage")
	await settle(45)
	var garage: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	var news := News.new()
	news.client = backend
	root.add_child(news)
	garage.news_client = news
	garage._show_section("news")
	await settle(45)
	var menu: Node = garage.tools.find_child("GarageNewsMenu",true,false)
	before = backend.calls
	await settle()
	check(backend.calls == before,"newspaper headlines do not load rankings")
	menu._tabs.ranking.pressed.emit()
	await settle()
	var ranking: Node = menu._ranking
	check(ranking.rows.get_child_count() == 50,"newspaper prints a bounded fifty-driver ranking list")
	check("1284" in ranking.summary.text and "2480" in ranking.summary.text,"newspaper shows own published rank and points")
	check(not menu._next.visible and not menu._previous.visible,"story navigation stays off ranking pages")
	check(not ranking.circuit.disabled,"newspaper owns the enabled Compact Circuit entry")
	var circuit_calls: Array = []
	ranking._adapter.circuit_requested.connect(func() -> void: circuit_calls.append(true))
	ranking.circuit.pressed.emit()
	check(circuit_calls.size() == 1,"newspaper Circuit action uses the existing official entry signal")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,900)]:
		root.size = dimensions
		await settle(35)
		check(menu._paper.get_global_rect().size.x <= menu._paper_host.size.x+1,"newspaper width fits "+str(dimensions))
		check(menu._paper.get_global_rect().size.y <= menu._paper_host.size.y+1,"newspaper height fits "+str(dimensions))
		check(menu._tabs.ranking.get_global_rect().end.x <= menu._paper.get_global_rect().end.x,"ranking tab fits "+str(dimensions))
		check(ranking.rows.get_child(0).get_global_rect().end.x <= menu._scroll.get_global_rect().end.x,"ranking rows fit "+str(dimensions))
		check(menu._scroll.get_global_rect().encloses(ranking.rows.get_child(1).get_global_rect()),"at least two ranking rows are visible without scrolling "+str(dimensions))
		capture("garage-ranking-%dx%d" % [dimensions.x,dimensions.y])
	ranking.next.pressed.emit()
	await settle()
	check(ranking._history.size() == 1 and ranking.rows.get_child_count() == 50,"pagination replaces the one printed page")
	ranking.previous.pressed.emit()
	await settle()
	check(ranking._history.is_empty(),"ranking previous returns to first page")
	ranking.around.pressed.emit()
	await settle()
	check(ranking.rows.get_child_count() == 9 and "around=true" in backend.paths.back(),"Near me requests the bounded published neighborhood")
	ranking.selector.selected = 3
	ranking.selector.item_selected.emit(3)
	await settle()
	check(backend.paths.back() == "/ranking?scope=season" and ranking.rows.get_child(0).get_child(2).text == "500","season scope prints season points")
	backend.fail_page = true
	menu._refresh_button.pressed.emit()
	await settle()
	check(ranking.rows.get_child_count() == 0 and "unavailable" in ranking.status.text,"failed ranking refresh clears stale rows and offers retry")
	backend.fail_page = false
	backend.hold_page = true
	menu._refresh_button.pressed.emit()
	await settle()
	backend.player = {"id":"other"}
	backend.identity_changed.emit()
	backend.reply.emit()
	await settle()
	check(ranking.rows.get_child_count() == 0 and ranking.summary.text == "World Ranking","account change fences delayed ranking and clears old player summary")
	backend.hold_page = false
	backend.signed = false
	menu._refresh_button.pressed.emit()
	await settle()
	check("Sign in" in ranking.status.text and ranking.circuit.disabled,"guest ranking gives sign-in state and disables Circuit")
	backend.signed = true
	backend._capabilities.world_ranking_launch_week = 0
	menu._refresh_button.pressed.emit()
	await settle()
	check(ranking.circuit.disabled,"unannounced Circuit remains disabled")
	backend._capabilities.world_ranking_version = 0
	menu._refresh_button.pressed.emit()
	await settle()
	check("unavailable on this server" in ranking.status.text,"old API has an honest unsupported state")
	backend._capabilities.world_ranking_version = 1
	backend._capabilities.world_ranking_launch_week = 1792972800
	backend.hold_page = true
	menu._refresh_button.pressed.emit()
	await settle()
	menu._tabs.news.pressed.emit()
	backend.reply.emit()
	await settle()
	check(menu._ranking == null and menu.find_child("NewspaperRankingRows",true,false) == null,"leaving ranking discards an in-flight page")
	app.queue_free()
	news.queue_free()
	backend.queue_free()
	await settle()
	print("RANKING NEWSPAPER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends SceneTree
## Actual daily page/dialog with explicit delayed feed and score responses.
var checks: int = 0
var failures: int = 0
var service: Service
var page: Node
var app: Node
var output: String

class Service extends Node:
	signal identity_changed
	signal released
	var player: Dictionary = {"id":"00000000-0000-0000-0000-000000000004"}
	var authenticated: bool = true
	var scores: Dictionary
	var feed: Dictionary
	var pending: bool = false
	var calls: Array[String] = []
	func signed_in() -> bool: return authenticated
	func base_url() -> String: return "http://daily-standings.invalid"
	func cancel_public_reads(_owner: int) -> void: pass
	func request_public(path: String, _owner: int) -> Dictionary:
		return await request_api(path,0,{},"",false)
	func request_api(path: String, _method: int, _body: Dictionary, _key: String, _authenticated: bool) -> Dictionary:
		calls.append(path)
		if path == "/track-of-the-day": return feed.duplicate(true)
		var response: Dictionary = scores.duplicate(true)
		if pending: await released
		return response

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	if app.menu_page_motion != null: app._finish_menu_page_slide()
	for _frame: int in range(8): await process_frame

func capture(id: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK,"capture "+id)

func row(index: int, ticks: int, rank: int) -> Dictionary:
	return {"player_id":"00000000-0000-0000-0000-%012d" % (index+1),
		"display_name":["Aino","Jules","Noa","You","Mira","Kai","Robin","Elin","Sami","Alex"][index],
		"country_code":"FI", "time_ticks":ticks,"rank":rank,"gap_ticks":ticks-15000}

func scores(vehicle: String = "compact") -> Dictionary:
	var items: Array[Dictionary] = []
	for index: int in range(10): items.append(row(index,15000+index*120,index+1))
	items[1].time_ticks = 15000
	items[1].rank = 1
	items[1].gap_ticks = 0
	var own: Variant = null
	for item: Dictionary in items:
		if str(item.player_id) == str(service.player.get("id","")): own = item
	return {"ok":true,"status":200,"data":{"day":20754,"starts_at":1793145600,"ends_at":1793232000,
		"server_now":1793209705,"version_id":"00000000-0000-0000-0000-000000000002",
		"vehicle_id":vehicle,"tick_rate":120,"board_id":"a".repeat(64),"population":34,
		"items":items,"player":own,"next_cursor":"second-page"}}

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: print("FAIL: daily standings deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_DAILY_STANDINGS_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280,720)
	var directory: String = "user://daily_standings_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("daily")
	await settle()
	page = app.content.find_child("TrackOfDayPage",true,false)
	service = Service.new()
	root.add_child(service)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/creator_tracks/lantern_village.json"))
	service.feed = {"ok":true,"data":{"server_now":1793209705,"ends_at":1793232000,"track":{
		"track_id":"00000000-0000-0000-0000-000000000001","version_id":"00000000-0000-0000-0000-000000000002",
		"content_hash":"a".repeat(64),"name":document.name,"creator":document.creator,"theme":"pine",
		"points":document.points,"rating_average":4.7,"rating_count":128}}}
	service.scores = scores()
	page.client = service
	await page.refresh()
	await settle()
	var button: Button = page.find_child("DailyStandingsButton",true,false)
	check(button != null and not button.disabled,"available daily pick exposes standings")
	await capture("daily-with-standings")
	button.pressed.emit()
	await settle()
	var dialog: Node = page.get_node("DailyStandings")
	check(dialog.visible and not dialog.busy,"native page button opens the populated standings view")
	check(dialog._rows.get_child_count() == 10,"first page contains ten real response rows")
	check(dialog._own.find_child("DailySelfRow",true,false) != null,"own daily result is pinned below the scrolling list")
	check(dialog._rows.get_parent().size.y >= 200,"standings reserve a readable scrolling results area")
	check(service.calls[-1].contains("day=20754") and service.calls[-1].contains("vehicle_id=compact"),"request pins UTC day and selected car")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		var canvas: Rect2 = root.get_visible_rect()
		check(canvas.encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"standings window fits visible canvas %s: canvas=%s window=%s/%s" % [dimensions,canvas,dialog.position,dialog.size])
		if dialog.size.y > canvas.size.y:
			for control: Node in dialog.find_children("*","Control",true,false):
				if control.get_combined_minimum_size().y > 400: print("DAILY_FIT: ",control.name," size=",control.size," minimum=",control.get_combined_minimum_size())
		await capture("standings-%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1280,720)
	service.scores.data.items = [row(9,18000,22)]
	service.scores.data.next_cursor = null
	dialog._next.pressed.emit()
	await settle()
	check(service.calls[-1].contains("cursor=second-page") and dialog._rows.get_child_count() == 1,"Next uses the server cursor")
	check(dialog._own.find_child("DailySelfRow",true,false) != null,"own result stays visible beyond the top page")
	await capture("own-outside-page")
	service.scores = scores("kart")
	dialog._cars.item_selected.emit(VehicleCatalog.IDS.find("kart"))
	await settle()
	check(dialog.vehicle == "kart" and not service.calls[-1].contains("cursor="),"car changes reset paging and load the correct cohort")
	check(VehicleCatalog.selected == "kart","dialog car selection uses ordinary App selection")
	service.pending = true
	dialog._refresh.pressed.emit()
	await settle()
	check(dialog.busy and dialog._rows.get_child_count() == 0 and dialog._own.get_child_count() == 0,"loading clears all old standings and private results")
	await capture("loading")
	service.player = {"id":"00000000-0000-0000-0000-000000000009"}
	service.scores = scores("kart")
	service.scores.data.player = null
	service.identity_changed.emit()
	service.pending = false
	service.released.emit()
	await settle()
	check(dialog._own.find_child("DailySelfRow",true,false) == null,"late prior-account response cannot restore the old player result")
	service.scores = {"ok":false,"status":503}
	dialog._refresh.pressed.emit()
	await settle()
	check(dialog._rows.get_child_count() == 0 and not dialog._refresh.disabled,"score failure has an explicit retry without stale rows")
	await capture("failure")
	service.scores = scores("kart")
	service.scores.data.items = []
	service.scores.data.population = 0
	service.scores.data.player = null
	service.scores.data.next_cursor = null
	dialog._refresh.pressed.emit()
	await settle()
	check(dialog._rows.get_child_count() == 0 and dialog._status.text == "No flying laps yet.","empty flying-lap board never substitutes race totals")
	await capture("empty")
	service.scores = scores("kart")
	service.scores.data.version_id = "00000000-0000-0000-0000-000000000005"
	dialog._refresh.pressed.emit()
	await settle()
	check(dialog._rows.get_child_count() == 0,"wrong-revision payload is rejected")
	service.scores = scores("kart")
	service.scores.data.items[0].rank = 1.5
	dialog._refresh.pressed.emit()
	await settle()
	check(dialog._rows.get_child_count() == 0,"fractional rank is rejected")
	service.scores = JSON.parse_string(JSON.stringify(scores("kart")))
	dialog._refresh.pressed.emit()
	await settle()
	check(dialog._rows.get_child_count() == 10,"integral JSON numbers are accepted from the wire")
	service.scores = scores("kart")
	dialog._refresh.pressed.emit()
	await settle()
	var calls: int = service.calls.size()
	app.cloud.race_verified.emit()
	await settle()
	check(service.calls.size() == calls+1,"verified race completion automatically refreshes an open board")
	TranslationServer.set_locale("fi")
	GameText.refresh(self)
	await settle()
	await capture("finnish")
	for locale_id: String in ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		TranslationServer.set_locale(locale_id)
		GameText.refresh(self)
		await settle()
		check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"translated standings fit: "+locale_id)
	TranslationServer.set_locale("en")
	GameText.refresh(self)
	service.authenticated = false
	service.scores = scores("kart")
	service.scores.data.player = null
	service.identity_changed.emit()
	await settle()
	check(dialog._own.find_child("DailySelfRow",true,false) == null,"guest view never labels a public driver's time as its own")
	await capture("guest")
	dialog.server_now = dialog.ends_at
	dialog._process(0.0)
	await settle()
	check(dialog._expired and dialog._rows.get_child_count() == 0 and dialog._own.get_child_count() == 0,"UTC rollover clears the expired board")
	await capture("rollover")
	dialog.queue_free()
	app.queue_free()
	service.queue_free()
	await process_frame
	print("DAILY_STANDINGS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

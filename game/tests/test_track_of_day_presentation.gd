extends SceneTree
## Actual App presentation with explicit synthetic feed responses; no live service or player data.
var checks: int = 0
var failures: int = 0
var app: Node
var page: Node
var service: Feed
var output: String
var baseline: bool
var emitted: Array[Dictionary] = []

class Feed extends Node:
	signal released
	var response: Dictionary = {}
	var held: bool = false
	var authenticated: bool = false
	var public_calls: int = 0
	var private_calls: int = 0
	func signed_in() -> bool: return authenticated
	func cancel_public_reads(_owner: int) -> void: pass
	func request_public(_path: String, _owner: int) -> Dictionary:
		if _path != "/track-of-the-day": return {"ok":false}
		public_calls += 1
		if held: await released
		return response.duplicate(true)
	func request_api(_path: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		if _path != "/track-of-the-day": return {"ok":false}
		private_calls += 1
		if held: await released
		return response.duplicate(true)

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

func pick(theme_id: String = "pine") -> Dictionary:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/creator_tracks/lantern_village.json"))
	return {"ok":true,"data":{"ends_at":1793232000,"server_now":1793209705,"track":{
		"track_id":"00000000-0000-0000-0000-000000000001","version_id":"00000000-0000-0000-0000-000000000002",
		"content_hash":"a".repeat(64),"name":document.name,"creator":document.creator,"theme":theme_id,
		"points":document.points,"rating_average":4.7,"rating_count":128}}}

func click(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event,true)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: print("FAIL: daily presentation deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_DAILY_PAGE_OUTPUT")
	baseline = OS.get_environment("BMT_DAILY_PAGE_BASELINE") == "1"
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var directory: String = "user://daily_presentation_"+TrackLibrary.unique_id()
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
	service = Feed.new()
	root.add_child(service)
	page.client = service
	# Observe the existing race boundary without starting a synthetic online race.
	for connection: Dictionary in page.race_requested.get_connections(): page.race_requested.disconnect(connection.callable)
	page.race_requested.connect(func(value: Dictionary) -> void: emitted.append(value))
	service.response = pick()
	await page.refresh()
	await settle()
	check(not page.entry.is_empty() and not page._race.disabled,"valid public pick is actionable")
	check(service.public_calls == 1,"signed-out page uses public authority")
	var calls_before_cache: int = service.public_calls
	var cached := preload("res://ui/track_of_day_page.gd").new()
	cached.client = service
	cached.cloud = app.cloud
	cached.cached_state = app._daily_track_cache.duplicate(true)
	root.add_child(cached)
	check(not cached.entry.is_empty() and not cached._race.disabled and service.public_calls == calls_before_cache,"cached daily pick appears without another request")
	cached.cached_state.ends_at = cached.cached_state.server_now
	check(not cached._restore_cached_track(),"expired cached pick is rejected")
	cached.queue_free()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		var scroll: ScrollContainer = page.find_child("DailyScroll",true,false)
		scroll.scroll_vertical = 0
		await capture("ready-%dx%d" % [dimensions.x,dimensions.y])
		check(page._race.get_combined_minimum_size().y >= 48,"race touch target "+str(dimensions))
		if not baseline:
			check(scroll.get_global_rect().encloses(page._race.get_global_rect()),"race action visible without scrolling "+str(dimensions))
			var hero: Control = page.find_child("DailyTrackCard",true,false)
			check(hero != null and hero.size.x >= 400 and hero.size.x*hero.size.y >= 160000,"featured route has a substantial display area "+str(dimensions))
	root.size = Vector2i(1280,720)
	for theme_id: String in ["desert","winter","night_city","storm"]:
		service.response = pick(theme_id)
		await page.refresh()
		await settle()
		check(str(page.entry.theme) == theme_id,"selected biome remains exact: "+theme_id)
		await capture("biome-"+theme_id)
	service.response = pick()
	service.response.data.track.name = "The extraordinarily long circuit name used to check the featured track title"
	service.response.data.track.creator = "A creator with a long name and {count} kept as literal text"
	service.response.data.track.rating_average = null
	service.response.data.track.rating_count = 0
	await page.refresh()
	await settle()
	await capture("long-name-unrated")
	if not baseline:
		var title: Label = page.find_child("DailyTrackName",true,false)
		check(title != null and title.text == str(service.response.data.track.name),"track name remains user text")
		check(title != null and title.get_global_rect().end.x <= page.find_child("DailyTrackCard",true,false).get_global_rect().end.x,"long title stays inside hero")
		var art: Control = page.find_child("DailyTrackCard",true,false)
		for path: PackedVector2Array in art._projected_paths:
			var bottom: float = -INF
			for point: Vector2 in path: bottom = maxf(bottom,point.y)
			check(art.global_position.y+bottom+8 <= title.global_position.y,"long caption does not cover the actual route")
	service.held = true
	page.refresh()
	await settle()
	check(page._busy and page._race.disabled,"refresh fences racing while authority is pending")
	var pending_calls: int = service.public_calls
	page.refresh()
	page._request_race()
	check(service.public_calls == pending_calls,"pending authority cannot be duplicated by refresh or race")
	await capture("loading")
	service.response = {"ok":false,"status":503}
	service.held = false
	service.released.emit()
	await settle()
	check(page.entry.is_empty() and page._race.disabled and page._retry.visible,"unavailable pick offers recovery without a race")
	if not baseline: check(not page._countdown.is_visible_in_tree(),"failure removes the old day's countdown")
	await capture("unavailable")
	service.response = pick()
	var before: int = service.public_calls
	page._retry_msec = Time.get_ticks_msec()-1
	page._process(0.0)
	await settle()
	check(service.public_calls == before+1 and not page.entry.is_empty(),"preparing retry uses one fresh authority read")
	service.response = {"ok":true,"data":{"ends_at":1793232000,"server_now":1793209705,"track":null}}
	await page.refresh()
	await settle()
	check(page.entry.is_empty() and page._race.disabled,"empty day never invents a circuit")
	await capture("empty-day")
	service.response = pick()
	service.authenticated = true
	await page.refresh()
	check(service.private_calls == 1 and not page.entry.is_empty(),"authenticated read path retained")
	page._ends_at = page._server_now
	page._process(0.0)
	await settle()
	check(page._ends_at > page._server_now and not page._race.disabled,"midnight refresh restores an authoritative pick")
	service.response.data.track.version_id = "00000000-0000-0000-0000-000000000003"
	await page._request_race()
	check(emitted.is_empty(),"rollover during race recheck cannot start the previous revision")
	await page._request_race()
	check(emitted.size() == 1 and str(emitted[0].version_id) == str(service.response.data.track.version_id),"unchanged rechecked revision emits the ordinary race boundary once")
	if not baseline:
		await settle()
		var hero: Control = page.find_child("DailyTrackCard",true,false)
		click(hero.global_position+Vector2(60,120))
		await settle()
		check(emitted.size() == 2,"native click reaches the featured preview through its overlay")
		page._race.grab_focus()
		await settle()
		check(page._race.has_focus(),"primary action retains keyboard focus")
		await capture("keyboard-focus")
	check(page.find_child("DailyCar",true,false) == null,"daily race card has no car dropdown")
	app._select_header_vehicle(VehicleCatalog.IDS.find("compact"))
	check(VehicleCatalog.selected == "compact","ordinary header car selection retained")
	TranslationServer.set_locale("fi")
	GameText.refresh(self)
	await settle()
	await capture("finnish")
	TranslationServer.set_locale("en")
	GameText.refresh(self)
	if not baseline:
		for locale_id: String in ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
			TranslationServer.set_locale(locale_id)
			GameText.refresh(self)
			await settle()
			var locale_scroll: ScrollContainer = page.find_child("DailyScroll",true,false)
			check(locale_scroll.get_global_rect().encloses(page._race.get_global_rect()),"translated action fits without scrolling: "+locale_id)
			check(page._countdown_panel.get_global_rect().end.x <= root.get_visible_rect().end.x+1,"translated countdown stays inside canvas: "+locale_id)
		TranslationServer.set_locale("en")
		GameText.refresh(self)
		service.response = pick()
		service.response.data.track.content_hash = "invalid"
		await page.refresh()
		check(page.entry.is_empty() and page._race.disabled,"malformed metadata cannot create a race")
		# Exercise the component's narrow layout independently of the global menu header.
		app.root_ui.hide()
		var previous_scale: Vector2i = root.content_scale_size
		root.content_scale_size = Vector2i(760,900)
		root.size = Vector2i(760,900)
		var narrow := preload("res://ui/track_of_day_page.gd").new()
		narrow.theme = MenuStyle.theme()
		narrow.client = service
		narrow.cloud = app.cloud
		narrow.page_preview = true
		root.add_child(narrow)
		MenuStyle.fill(narrow)
		service.response = pick("winter")
		await narrow.refresh()
		await settle()
		var narrow_scroll: ScrollContainer = narrow.find_child("DailyScroll",true,false)
		check(narrow._race_panel.position.y >= narrow._hero.size.y,"narrow layout stacks race controls below the preview")
		await capture("narrow-top")
		narrow_scroll.scroll_vertical = 9999
		await settle()
		check(narrow_scroll.get_global_rect().intersects(narrow._race.get_global_rect()),"narrow layout keeps the race action reachable")
		await capture("narrow-race")
		var private_calls: int = service.private_calls
		narrow._ends_at = narrow._server_now
		narrow._process(0.0)
		check(narrow._race.disabled and service.private_calls == private_calls,"preview page cannot refresh or race at rollover")
		narrow.queue_free()
		await process_frame
		root.content_scale_size = previous_scale
		root.size = Vector2i(1280,720)
		app.root_ui.show()
	service.response = pick()
	await page.refresh()
	app._request_race_mode("free")
	await settle()
	app._request_race_mode("daily")
	var returned: Node = app.content.find_child("TrackOfDayPage",true,false)
	check(returned != null and not returned.entry.is_empty() and not returned._busy,"returning to daily displays the cached pick immediately")
	app.queue_free()
	service.queue_free()
	await process_frame
	print("DAILY_PRESENTATION%s: %d checks, %d failures" % ["_BASELINE" if baseline else "",checks,failures])
	quit(1 if failures else 0)

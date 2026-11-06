extends "res://tests/test_own_profile_page.gd"
## Isolated fixture names/counts; no owner saves, authentication or live reads.
class ProfileHost extends Host:
	func _load_saved_document(id: String) -> void: action = "draft:"+id

class ProfileClient extends Client:
	var requests: Array[String] = []
	var fail_stats: bool = false
	func request_api(path: String, _method: int, _payload: Dictionary, _key: String, _auth: bool) -> Dictionary:
		requests.append(path)
		if delayed: await reply
		if path == "/ranking/me": return {"ok":true,"data":{"state":"published","world_rank":128,"points":2450,"results":[],"career":{}}}
		if path == "/me/profile-statistics":
			if fail_stats: return {"ok":false,"status":404}
			var cars: Dictionary = {}
			for i: int in range(VehicleCatalog.IDS.size()): cars[VehicleCatalog.IDS[i]] = {"races":(i+1)*12,"distance_m":(i+1)*12500}
			return {"ok":true,"data":{"schema":1,"cars":cars,"totals":{"races":180,"distance_m":187500,"tracks":18,"cars":5}}}
		if fail_tracks: return {"ok":false}
		var items: Array = [{"creator_id":"someone-else","track_id":"other","name":"Other"}]
		var names: Array = ["Forest Sprint","Over and Under","Midnight Loop","The Long Way Home"]
		for i: int in range(4):
			items.append({"creator_id":player.id,"track_id":"track"+str(i),"version_id":"version"+str(i),"name":names[i],"theme":["pine","desert","night_city","winter"][i],"points":[[0,0],[30,0],[50,15],[40,35],[5,40],[-10,10]],"rating_average":4.6,"verified_races":(i+1)*153,"state":"published"})
		return {"ok":true,"data":{"items":items,"next_offset":null}}

func capture(name: String) -> void:
	var directory: String = OS.get_environment("BMT_PROFILE_CAPTURE")
	if DisplayServer.get_name() == "headless" or directory.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name+".png")) == OK,"capture "+name)

func bounds(control: Control) -> void:
	var area: Rect2 = control.get_global_rect().grow(1)
	for item: Node in control.find_children("*","Label",true,false):
		if not item.is_visible_in_tree(): continue
		check(area.encloses(item.get_global_rect()),"text inside "+str(control.name)+" / "+str(item.name))

func tap(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var folder: String = "user://profile_redesign_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var host := ProfileHost.new()
	root.add_child(host)
	host.library = TrackLibrary.new(folder.path_join("tracks"))
	var doc: Dictionary = TrackDocument.create_default()
	doc.name = "My first circuit"
	check(host.library.save_document(doc) == OK,"isolated draft saved")
	var client := ProfileClient.new()
	host.add_child(client)
	var account := Account.new()
	account.client = client
	host.online = account
	host.add_child(account)
	var cloud := Cloud.new()
	host.cloud = cloud
	host.add_child(cloud)
	host.root_ui = host
	host.records = LocalRecords.new(folder.path_join("records.json"))
	host.records.settings.achievements = AchievementProgress.empty()
	host.records.settings.achievements.metrics = {"races":42,"distance_m":186000,"tracks":18,"clean":12}
	host.records.settings.achievements.unlocked = {"races/1":1,"distance/1":1,"tracks/1":1}
	host.records.settings.achievements.featured = ["races","distance","tracks"]
	var awards: Node = preload("res://backend/achievements_client.gd").new()
	awards.records = host.records
	host.achievements = awards
	host.add_child(awards)
	var page: Control = make_page(host)
	await settle()
	check(page.fleet.get_child_count() == 5,"all current cars appear together")
	check(page.published.size() == 4,"more than three created tracks remain visible")
	check(page.find_child("ProfileTrack_other",true,false) == null,"exact owner filtering")
	check(page.car_values.electric.races.text == "48" and page.car_values.electric.distance.text == "50.0","remote per-car history shown")
	check(page.find_child("ProfileTrack_track0",true,false).find_child("TrackRaceCount",true,false).text == "153","actual verified race count")
	for resolution: Vector2i in [Vector2i(1720,900),Vector2i(1280,720),Vector2i(960,540),Vector2i(400,720)]:
		root.size = resolution
		await settle()
		page._layout()
		await settle()
		check(page.size.x <= root.size.x+1,"profile fits "+str(resolution))
		check(page.fleet.get_global_rect().end.x <= root.size.x+1,"fleet fits "+str(resolution))
		for card: Control in page.fleet.get_children(): bounds(card)
		for card: Control in page.badge_grid.get_children(): bounds(card)
		for card: Control in page.track_grid.get_children(): bounds(card)
		await capture("profile-%dx%d" % [resolution.x,resolution.y])
	root.size = Vector2i(1280,720)
	await settle()
	page.scroll.scroll_vertical = 320
	await settle()
	await tap(page.find_child("ProfileTrack_track0",true,false).find_child("TrackRaceCount",true,false))
	check(host.action == "track0","race count area activates its exact track with mouse input")
	await capture("profile-records")
	page.scroll.scroll_vertical = 0
	await settle()
	page._select_tracks("drafts")
	await settle()
	check(page.drafts.size() == 1,"local drafts loaded by cancellable scanner")
	check(page.track_grid.get_child_count() == 1,"draft tab shows saved creation")
	page.track_grid.get_child(0).pressed.emit()
	check(host.action == "draft:"+str(doc.id),"draft opens exact editor document")
	await capture("profile-drafts")
	page._select_tracks("published")
	page.find_child("ProfileBadge_races",true,false).pressed.emit()
	await settle()
	check(page.collection != null and not page.page_body.visible,"achievement opens within profile")
	check(page.collection.selected == "races","exact medal details open")
	await capture("achievement-detail")
	page.collection._close_sheet()
	await settle()
	for card: Control in page.collection.grid.get_children():
		bounds(card)
		var title: Label = card.get_child(0).get_child(1).get_child(0)
		check(title.size.y >= 26 and not title.text.is_empty(),"every achievement has a visible title")
	await capture("achievement-collection")
	page.collection.find_child("AchievementClose",true,false).pressed.emit()
	await settle()
	check(page.page_body.visible and page.collection == null,"collection returns to same profile")
	client.player.display_name = "A long driver name that must stay inside the profile header"
	page.queue_free()
	await settle()
	TranslationServer.set_locale("de")
	page = make_page(host)
	await settle()
	check(page.size.x <= root.get_visible_rect().size.x+1,"German profile stays inside window")
	for card: Control in page.fleet.get_children(): bounds(card)
	await capture("profile-de")
	TranslationServer.set_locale("en")
	client.fail_stats = true
	client.fail_tracks = true
	page.queue_free()
	await settle()
	page = make_page(host)
	await settle()
	check(page.track_action.text == "Retry","failure keeps retry available")
	check(page.car_values.compact.races.text == "—","missing historical counts are not invented")
	client.fail_tracks = false
	page.track_action.pressed.emit()
	await settle()
	check(page.published.size() == 4,"retry retains exact publications")
	page.queue_free()
	await settle()
	client.delayed = true
	page = make_page(host)
	await settle()
	client.player.id = "different"
	client.identity_changed.emit()
	client.reply.emit()
	await settle()
	check(not page.visible and page.published.is_empty() and page.remote_cars.is_empty(),"late replies cannot cross accounts")
	page.queue_free()
	await settle()
	_test_history(folder)
	host.queue_free()
	await settle()
	await _actual_app(folder)
	print("Profile redesign: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _test_history(folder: String) -> void:
	var store := LocalRecords.new(folder.path_join("history.json"))
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	var laps: Array[float] = [10.0,10.0,10.0,10.0,10.0]
	check(store.record(track,VehicleCatalog.config("electric"),50.0,laps) == OK,"history commits with result")
	var saved := LocalRecords.new(store.path)
	saved.load_records()
	check(saved.settings.driving_history.cars.electric.races == 1,"per-car races survive restart")
	check(saved.settings.driving_history.cars.electric.distance_m == roundi(track.route_length*5),"distance uses completed course length")
	check(saved.settings.driving_history.tracks[track.identity] == 1,"per-track race count survives restart")
	check(store.record(track,VehicleCatalog.config("electric"),51.0,laps) != OK,"invalid result is rejected")
	check(store.settings.driving_history.cars.electric.races == 1,"rejected result cannot count")
	check(store.record(track,VehicleCatalog.config("kart"),50.0,laps) == OK,"second car records separately")
	store.path = folder.path_join("missing/history.json")
	check(store.record(track,VehicleCatalog.config("electric"),50.0,laps) != OK,"failed persistence rejects history")
	check(store.settings.driving_history.cars.electric.races == 1,"failed save rolls back race counter")
	var invalid: Dictionary = store.settings.driving_history.duplicate(true)
	invalid.cars.electric.races = -1
	check(not preload("res://persistence/driving_history.gd").valid(invalid),"negative counters rejected")

func _actual_app(folder: String) -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var app: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.records = LocalRecords.new(folder.path_join("app-records.json"))
	app.records.settings.achievements = AchievementProgress.empty()
	app.records.settings.achievements.metrics = {"races":180,"distance_m":187500,"tracks":18,"cars":5}
	app.records.settings.achievements.unlocked = {"races/1":1,"races/2":1,"distance/1":1,"tracks/1":1}
	app.records.settings.achievements.featured = ["races","distance","tracks"]
	app.records.settings.driving_history = {"version":1,"cars":{},"tracks":{}}
	for i: int in range(VehicleCatalog.IDS.size()):
		app.records.settings.driving_history.cars[VehicleCatalog.IDS[i]] = {"races":(i+1)*12,"distance_m":(i+1)*12500}
	check(app.records.save_records() == OK,"save isolated populated app fixture")
	app.library = TrackLibrary.new(folder.path_join("app-tracks"))
	var doc: Dictionary = TrackDocument.create_default()
	doc.name = "My first circuit"
	check(app.library.save_document(doc) == OK,"save isolated app creation")
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+30000
	while not app.startup_complete and Time.get_ticks_msec() < deadline: await process_frame
	check(app.startup_complete,"actual isolated app starts")
	if app.startup_complete:
		app._show_screen("profile")
		await settle()
		await capture("actual-app-profile")
		app.root_ui.find_child("ProfileChooseAchievements",true,false).pressed.emit()
		await settle()
		check(app.screen == "profile" and app.root_ui.find_child("AchievementsMenu",true,false) != null,"actual app collection stays in profile")
		await capture("actual-app-achievements")
		app.root_ui.find_child("AchievementClose",true,false).pressed.emit()
		await settle()
		app.root_ui.find_child("ManageAccount",true,false).pressed.emit()
		check(app.screen == "account","edit profile preserves account navigation")
	app.queue_free()
	await settle()

extends SceneTree
## Real header selection with independent delayed appearance, membership and join replies.
const Adapter = preload("res://backend/weekly_rivalry_client.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var service: Service
var evidence: String
var publications: Array[String] = []

class Reply extends RefCounted:
	signal released
	var path: String
	var response: Dictionary
	var done: bool = false
	func finish(value: Dictionary) -> void:
		response = value
		done = true
		released.emit()

class Service extends Node:
	var player: Dictionary = {"id":"you"}
	var pending: Array[Reply] = []
	var calls: int = 0
	var appearance_held: bool = false
	func base_url() -> String: return "http://car-switch-fixture.invalid"
	func signed_in() -> bool: return true
	func test_drivers_available() -> bool: return true
	func new_operation_key() -> String: return "fixture-operation-"+str(calls)
	func request_api(path: String, _method: int = 0, _payload: Dictionary = {}, _key: String = "", _authorized: bool = true) -> Dictionary:
		calls += 1
		var reply := Reply.new()
		reply.path = path
		pending.append(reply)
		await reply.released
		return reply.response.duplicate(true)
	func sync_appearance() -> void:
		if appearance_held: await request_api("/appearance")
	func latest() -> Reply: return pending[-1]

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func snapshot(vehicle: String, group: String, points: int, automatic: bool = true) -> Dictionary:
	var drivers: Array = [
		{"id":"rival_a","name":group+" leader","rank":1,"points":points+20,"completed":5},
		{"id":"you","name":"You","rank":2,"points":points,"completed":5},
		{"id":"rival_b","name":group+" third","rank":3,"points":points-10,"completed":5}]
	var now: int = int(Time.get_unix_time_from_system())
	var value: Dictionary = {"state":"active","group_id":group,"self_id":"you","vehicle_id":vehicle,"week":44,
		"server_now":now,"ends_at":now+86400,"test_population":true,"automatic_test_drivers":automatic,
		"standings":drivers,"tracks":[]}
	var document: Dictionary = TrackDocument.create_default()
	for slot: int in range(5):
		var entries: Array = drivers.duplicate(true)
		for row: Dictionary in entries: row.ms = 80000+int(row.rank)*1000
		value.tracks.append({"board_id":group+str(slot),"entries":entries,"entry":{"name":group+" track "+str(slot+1),
			"theme":"pine","creator":"Beat my track","track_id":"track_"+str(slot),"version_id":group+str(slot),
			"content_hash":"a".repeat(64),"points":document.points}})
	return value

func page() -> WeeklyRivalryPage:
	return app.content.find_child("WeeklyRivalryPage",true,false) as WeeklyRivalryPage

func record_publication() -> void:
	var view: WeeklyRivalryPage = page()
	if view != null and view.find_child("RivalryDriversPanel",true,false) != null:
		var key: String = view.model.group_id+"/"+str(WeeklyRivalry.self_row(view.model.standing()).get("points",-1))
		if publications.is_empty() or publications[-1] != key: publications.append(key)

func settle() -> void:
	for _frame: int in range(6):
		await process_frame
		record_publication()
	while app.menu_page_motion != null: await process_frame

func loading(message: String) -> void:
	for frame: int in range(3):
		await process_frame
		check(page().find_child("RivalryLoading",true,false) != null and page().find_child("RivalryDriversPanel",true,false) == null,
			message+" frame "+str(frame))
		record_publication()

func final_board(group: String, points: int, message: String) -> void:
	await settle()
	var label: Label = page().find_child("RivalryPlayerPoints_you",true,false) as Label
	check(page().model.group_id == group and label != null and label.text == str(points) and not app.rivalry.busy,message)

func capture(id: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(id+".png")) == OK,"save "+id)

func run() -> void:
	var profile: String = ProjectSettings.globalize_path("user://").replace("\\","/").simplify_path()
	var isolated: String = ProjectSettings.globalize_path("res://../build/rivalry-car-switch/").replace("\\","/").simplify_path().trim_suffix("/")+"/"
	if not profile.begins_with(isolated):
		check(false,"set APPDATA under build/rivalry-car-switch")
		quit(1)
		return
	OS.set_environment("BMT_API_URL","")
	var offline := ConfigFile.new()
	offline.set_value("backend","url","")
	check(offline.save("user://backend.cfg") == OK,"isolated profile disables service access")
	evidence = OS.get_environment("BMT_RIVALRY_CAR_SWITCH_CAPTURE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--compact": root.size = Vector2i(960,540)
	var folder: String = "user://car_switch_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.configured,"App starts offline")
	service = Service.new()
	app.add_child(service)
	app.rivalry.client = service
	app.rivalry.appearance_sync = service.sync_appearance
	app.rivalry.test_population = true
	app.online.client.player = service.player
	app.online.client._access_token = "isolated-fixture"
	for vehicle: String in ["forklift","electric","kart"]:
		VehicleCatalog.selected = vehicle
		app.rivalry._remember_snapshot(snapshot(vehicle,vehicle+"-saved",40))
	VehicleCatalog.selected = "compact"
	app.rivalry.model.apply_snapshot(snapshot("compact","compact-final",80))
	app.rivalry.snapshot_scope = app.rivalry.scope()
	app._show_screen("rivalry")
	await settle()
	app.rivalry.changed.connect(record_publication)
	publications.clear()
	await capture("compact-before")
	page().track_requested.emit(2)
	await settle()
	check(app.rivalry_section == "detail" and page().section == "detail","track selection opens Rivalry detail")
	app._select_header_vehicle(VehicleCatalog.IDS.find("compact"))
	check(app.rivalry_section == "detail" and page().section == "detail","selecting the current car preserves track detail")
	service.appearance_held = true
	app._select_header_vehicle(VehicleCatalog.IDS.find("forklift"))
	check(app.rivalry_section == "overview" and page().section == "overview","changing car from track detail immediately returns to the Rivalry overview")
	var appearance: Reply = service.pending[-2]
	var membership: Reply = service.latest()
	check(app.rivalry.busy and appearance.path == "/appearance" and membership.path == "/rivalry/current?vehicle_id=forklift&test_population=true", "membership starts while appearance sync is still held")
	await loading("previous car is cleared while both requests are pending")
	await capture("forklift-appearance-loading")
	await loading("saved forklift scores stay hidden during membership fetch")
	service.appearance_held = false
	membership.finish({"ok":true,"data":snapshot("forklift","forklift-intermediate",60,false)})
	check(service.latest().path == "/rivalry/join","automatic enrollment follows intermediate membership")
	await loading("intermediate membership stays hidden until enrollment finishes")
	await capture("forklift-enrollment-loading")
	service.latest().finish({"ok":true,"data":snapshot("forklift","forklift-final",100)})
	await final_board("forklift-final",100,"selected car publishes its final server standings")
	check(app.rivalry_section == "overview" and page().section == "overview","new car standings stay on the Rivalry overview")
	check(not appearance.done,"standings become usable without waiting for appearance synchronization")
	appearance.finish({"ok":true,"data":{}})
	check(publications == ["forklift-final/100"],"switch publishes exactly one standings set: "+str(publications))
	await capture("forklift-final")
	# Same-car background refreshes keep usable standings and stable controls.
	var before: int = page().content_builds
	var scroll: ScrollContainer = page().standings_scroll
	app.rivalry.refresh()
	await settle()
	check(page().find_child("RivalryDriversPanel",true,false) != null and page().content_builds == before and page().standings_scroll == scroll,
		"same-car background refresh keeps the existing board and controls")
	service.latest().finish({"ok":true,"data":snapshot("forklift","forklift-final",101)})
	await final_board("forklift-final",101,"same-car refresh applies updated server scores")
	check(page().content_builds == before,"ordinary score refresh updates the retained page in place")
	# Old and new requests for the same vehicle must remain distinct.
	publications.clear()
	app._select_header_vehicle(VehicleCatalog.IDS.find("electric"))
	var old_electric: Reply = service.latest()
	await loading("first rapid switch waits for its own reply")
	app._select_header_vehicle(VehicleCatalog.IDS.find("compact"))
	var old_compact: Reply = service.latest()
	app._select_header_vehicle(VehicleCatalog.IDS.find("electric"))
	var new_electric: Reply = service.latest()
	old_electric.finish({"ok":true,"data":snapshot("electric","electric-obsolete",70)})
	await loading("late reply for an earlier selection of the same car is ignored")
	new_electric.finish({"ok":true,"data":snapshot("electric","electric-final",110)})
	await final_board("electric-final",110,"latest selection publishes its own authoritative board")
	old_compact.finish({"ok":true,"data":snapshot("compact","compact-obsolete",50)})
	await final_board("electric-final",110,"late other-car reply cannot replace the displayed board")
	check(publications == ["electric-final/110"],"rapid switches publish only the final selected car")
	var calls: int = service.calls
	app._select_header_vehicle(VehicleCatalog.IDS.find("electric"))
	check(service.calls == calls,"selecting the current car does not refetch")
	# A failed switch offers an actionable retry without reviving saved scores.
	app._select_header_vehicle(VehicleCatalog.IDS.find("kart"))
	service.latest().finish({"ok":false,"data":{},"error":"CONNECTION_FAILED"})
	await settle()
	var retry: Button = page().find_child("RivalryRefresh",true,false) as Button
	check(not app.rivalry.error.is_empty() and retry != null and not retry.disabled and page().find_child("RivalryDriversPanel",true,false) == null,
		"failed switch shows a usable retry without stale standings")
	await capture("kart-failed")
	if retry != null: retry.pressed.emit()
	await loading("retry keeps saved scores hidden")
	service.latest().finish({"ok":true,"data":snapshot("kart","kart-final",120)})
	await final_board("kart-final",120,"retry publishes the selected car and clears the error")
	await capture("kart-recovered")
	# A genuinely new adapter still restores the existing startup presentation cache.
	var restarted: Node = Adapter.new()
	restarted.client = service
	restarted.cache_directory = app.rivalry.cache_directory
	root.add_child(restarted)
	restarted.refresh(false)
	check(restarted.cached_snapshot and restarted.model.group_id == "kart-final" and restarted.busy,"initial startup still restores its scoped cache")
	service.latest().finish({"ok":true,"data":snapshot("kart","kart-final",120)})
	restarted.queue_free()
	check(service.pending.all(func(reply: Reply) -> bool: return reply.done),"all synthetic requests complete")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("RIVALRY_CAR_SWITCH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

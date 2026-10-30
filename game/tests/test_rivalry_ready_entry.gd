extends SceneTree
## Actual App entry routes with delayed membership and frame-by-frame publication.
var app: Node
var service: Service
var checks: int = 0
var failures: int = 0
var evidence: String

class Service extends Node:
	signal released
	var player: Dictionary = {"id":"you"}
	var response: Dictionary = {}
	var calls: int = 0
	var pending: bool = false
	func base_url() -> String: return "http://rivalry-ready.invalid"
	func signed_in() -> bool: return true
	func test_drivers_available() -> bool: return false
	func new_operation_key() -> String: return "ready-fixture"
	func request_api(path: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		if path == "/rivalry/appearance": return {"ok":true,"data":{}}
		calls += 1
		pending = true
		await released
		pending = false
		return response.duplicate(true)
	func respond(value: Dictionary) -> void:
		response = value
		released.emit()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func frames(count: int = 6) -> void:
	for _frame: int in range(count): await process_frame

func settle() -> void:
	await frames()
	var deadline: int = Time.get_ticks_msec()+15000
	while app.menu_page_motion != null and Time.get_ticks_msec()<deadline: await process_frame
	check(app.menu_page_motion == null,"page transition completes")
	await frames()

func snapshot() -> Dictionary:
	var model := WeeklyRivalry.new(true)
	var value: Dictionary = {"state":"active","group_id":"ready-group","self_id":"you","vehicle_id":"compact",
		"week":44,"server_now":0,"ends_at":604800,"standings":model.standing(),"tracks":[]}
	for slot: int in range(5):
		var track: Dictionary = model.tracks[slot]
		value.tracks.append({"board_id":"board-"+str(slot),"entries":model.board(slot),"entry":{
			"name":track.name,"theme":track.theme,"creator":"Beat my track","track_id":"track-"+str(slot),
			"version_id":"version-"+str(slot),"content_hash":"a".repeat(64),"points":track.document.points}})
	return value

func capture(id: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(id+".png"))==OK,"capture "+id)

func waiting(message: String) -> void:
	for frame: int in range(5):
		await process_frame
		check(app.screen=="biome" and app.content.find_child("RivalryLoading",true,false)==null,message+" frame "+str(frame))

func arrival(id: String) -> void:
	var inspected: bool = false
	for _frame: int in range(600):
		await process_frame
		if app.screen!="rivalry": continue
		var page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
		var visible_area: Rect2 = app.menu_body.get_global_rect().intersection(app.menu_body_slot.get_global_rect())
		if visible_area.size.x>2.0 and visible_area.size.y>2.0:
			check(page!=null and page.find_child("RivalryLoading",true,false)==null,"first entering frame has no empty loading cards")
			check(page!=null and page.track_rows.size()==5 and page.standings_ready,"first entering frame has five tracks and settled standings")
			var cars: Array[Node] = page.find_children("RivalryPodiumCar_*","",true,false)
			check(cars.size()==3,"first entering frame has all podium cars")
			for car: Node in cars:
				check(car.presentation_ready and car.viewport.size.x>1 and car.viewport.size.y>1,"podium car is prepared before entry")
				if DisplayServer.get_name()!="headless":
					var picture: Image = car.viewport.get_texture().get_image()
					var pixels: int = 0
					for y: int in range(0,picture.get_height(),4):
						for x: int in range(0,picture.get_width(),4):
							if picture.get_pixel(x,y).a>0.1: pixels += 1
					check(pixels>50,"first entering frame has a rendered car image")
			await capture(id+"-first-frame")
			inspected = true
			break
	check(inspected,"observe the first visible rivalry frame")
	await settle()

func run() -> void:
	var profile: String = ProjectSettings.globalize_path("user://").replace("\\","/").simplify_path()
	var isolated: String = ProjectSettings.globalize_path("res://../build/rivalry-ready-entry/").replace("\\","/").simplify_path().trim_suffix("/")+"/"
	if not profile.begins_with(isolated):
		check(false,"set APPDATA under build/rivalry-ready-entry")
		quit(1)
		return
	OS.set_environment("BMT_API_URL","")
	var offline := ConfigFile.new()
	offline.set_value("backend","url","")
	check(offline.save("user://backend.cfg")==OK,"disable real service access")
	evidence = OS.get_environment("BMT_RIVALRY_READY_CAPTURE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(960,540) if "--compact" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	app = load("res://core/app.tscn").instantiate()
	var folder: String = "user://ready-"+TrackLibrary.unique_id()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.configured,"actual App starts offline")
	service = Service.new()
	app.add_child(service)
	app.rivalry.client = service
	app.rivalry.cache_directory = ""
	app.rivalry.appearance_sync = func() -> void: pass
	app.online.client.player = service.player
	app.online.client._access_token = "isolated-fixture"
	VehicleCatalog.selected = "compact"
	# A horizontal swipe used to promote the unresolved neighbor immediately.
	app.race_area_mode = "rivalry"
	app._show_screen("biome")
	await settle()
	check(app.menu_neighbors.has(-1) and app.menu_neighbors[-1].screen=="rivalry","prepare the actual Race neighbor")
	app._drag_menu_edge(200.0)
	await frames(3)
	var neighbor: Control = app.menu_neighbors[-1].body
	check(not neighbor.visible or not neighbor.get_global_rect().intersects(app.menu_body_slot.get_global_rect()),"drag never exposes an unresolved rivalry neighbor")
	app._swipe_menu_page(-1)
	await waiting("swipe retains current page during membership")
	await capture("swipe-waiting")
	check(service.pending,"swipe starts the membership request")
	service.respond({"ok":true,"data":snapshot()})
	await arrival("swipe")
	await capture("swipe-ready")
	# The top Race tab uses the same readiness gate and reuses prefetch.
	app._show_screen("biome")
	await settle()
	app.rivalry.reset()
	app._prefetch_rivalry()
	var calls: int = service.calls
	app._open_race_area()
	await waiting("Race tab retains current page during prefetch")
	check(service.calls==calls,"entry reuses the pending membership request")
	service.respond({"ok":true,"data":snapshot()})
	await arrival("tab")
	await capture("tab-ready")
	# Navigation away cancels the pending entry even when its request finishes.
	app._show_screen("biome")
	await settle()
	app.rivalry.reset()
	app._open_rivalry()
	app._open_free_race()
	service.respond({"ok":true,"data":snapshot()})
	await settle()
	check(app.screen=="tracks" and not app._rivalry_entry_pending,"late completion cannot undo a later Free Race choice")
	# Vertical rail entry also prepares native images before its slide starts.
	app._open_rivalry()
	var prepared_motion: Tween = app.menu_page_motion
	app._settle_menu_before_touch()
	check(app.menu_page_motion==prepared_motion and prepared_motion!=null,"a new touch cannot bypass incoming page preparation")
	await arrival("rail")
	await capture("rail-ready")
	if service.pending: service.respond({"ok":true,"data":snapshot()})
	# A failed read opens an actionable state, with no loading skeleton left behind.
	app._show_screen("biome")
	await settle()
	app.rivalry.reset()
	app._open_rivalry()
	service.respond({"ok":false,"error":"UNAVAILABLE","data":{}})
	await settle()
	check(app.screen=="rivalry" and app.content.find_child("RivalryRefresh",true,false)!=null,"failure opens a usable Refresh action")
	check(app.content.find_child("RivalryLoading",true,false)==null,"failure does not leave loading cards visible")
	await capture("failure")
	app.queue_free()
	await frames()
	print("RIVALRY_READY_ENTRY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

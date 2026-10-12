extends SceneTree
## Frame-by-frame entry and warmed-page regression with isolated, delayed responses.
var checks: int = 0
var failures: int = 0
var app: Node
var service: Service
var evidence: String = ""

class Service extends Node:
	signal reply_ready
	var player: Dictionary = {"id":"you"}
	var development: bool = false
	var response: Dictionary = {}
	var pending_path: String = ""
	var calls: int = 0
	func base_url() -> String: return "http://fixture"
	func signed_in() -> bool: return true
	func test_drivers_available() -> bool: return development
	func new_operation_key() -> String: return "fixture-key"
	func request_api(path: String, _method: int, _payload: Dictionary, _key: String, _authorized: bool) -> Dictionary:
		calls += 1
		pending_path = path
		await reply_ready
		pending_path = ""
		return response.duplicate(true)
	func respond(value: Dictionary) -> void:
		response = value
		reply_ready.emit()

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func snapshot() -> Dictionary:
	var fixture := WeeklyRivalry.new(true)
	var value: Dictionary = {"state":"active","group_id":"fixture-group","self_id":"you","week":41,
		"server_now":0,"ends_at":604800,"vehicle_id":"compact","standings":fixture.standing(),"tracks":[],
		"test_population":service.development,"automatic_test_drivers":service.development}
	for slot: int in range(5):
		var track: Dictionary = fixture.tracks[slot]
		value.tracks.append({"board_id":"board_"+str(slot),"entries":fixture.board(slot),
			"entry":{"name":track.name,"theme":track.theme,"creator":"Beat my track","track_id":"track_"+str(slot),
				"version_id":"version_"+str(slot),"content_hash":"a".repeat(64),"points":track.document.points}})
	return value

func settle() -> void:
	for _frame: int in range(5): await process_frame
	while app != null and app.menu_page_motion != null: await process_frame

func capture(id: String, dimensions: Vector2i) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(id+"-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save "+id+" evidence")

func no_join_frames(column: Control, message: String) -> void:
	for frame: int in range(5):
		await process_frame
		check(column.find_child("RivalryJoin",true,false) == null,message+" frame "+str(frame))

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	evidence = OS.get_environment("BMT_RIVALRY_ENTRY_CAPTURE_DIR")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	var directory: String = "user://rivalry_entry_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	service = Service.new()
	app.add_child(service)
	app.rivalry.client = service
	# This suite deliberately resets cold membership between scenarios. Restart
	# persistence is exercised separately by test_menu_loading_speed.gd.
	app.rivalry.cache_directory = ""
	app.online.client.player = service.player
	app.online.client._access_token = "fixture"
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		app.rivalry.reset()
		app._show_screen("tracks")
		await settle()
		app._prefetch_rivalry()
		var prefetched_calls: int = service.calls
		app._open_rivalry()
		check(app.screen == "tracks" and app._rivalry_entry_pending,"first entry keeps the current page until membership is ready")
		check(service.calls == prefetched_calls,"entry reuses the in-flight preload")
		check(app.content.find_child("RivalryLoading",true,false) == null and app.content.find_child("RivalryJoin",true,false) == null,"first entry never displays an empty rivalry")
		await no_join_frames(app.content,"delayed membership has no join flash")
		await capture("waiting-on-current-page",dimensions)
		service.respond({"ok":true,"data":snapshot()})
		await settle()
		check(app.content.find_child("RivalryTracksPanel",true,false) != null,"membership response immediately shows actual tracks")
		check(app.content.find_child("RivalryLoading",true,false) == null,"membership resolves the loading state")
		app._finish_menu_page_slide()
		await settle()
		await capture("overview",dimensions)
		app._open_rivalry()
		check(app.content.find_child("RivalryTracksPanel",true,false) != null,"repeat entry keeps loaded standings while refreshing")
		await no_join_frames(app.content,"refresh retains the known rivalry")
		service.respond({"ok":true,"data":snapshot()})
		service.player.id = "another-player"
		app._open_rivalry()
		check(app._rivalry_entry_pending and app.rivalry.model.tracks.is_empty(),"account changes fence the previous model while preparing entry")
		service.respond({"ok":true,"data":snapshot()})
		await settle()
		service.player.id = "you"
		# Warm a page while membership is unresolved, then update it offscreen.
		app.rivalry.reset()
		app._show_screen("garage")
		app._finish_menu_page_slide()
		await settle()
		check(app.menu_neighbors.has(-2),"Garage prepares its rivalry neighbor")
		if not app.menu_neighbors.has(-2):
			quit(1)
			return
		var neighbor: Dictionary = app.menu_neighbors[-2]
		check(neighbor.screen == "rivalry" and neighbor.content.find_child("RivalryLoading",true,false) != null,"warmed rivalry starts with unresolved membership")
		app.rivalry.refresh()
		service.respond({"ok":true,"data":snapshot()})
		check(neighbor.content.find_child("RivalryTracksPanel",true,false) != null,"offscreen response refreshes the warmed rivalry")
		app._open_rivalry()
		check(app.content == neighbor.content and app.content.find_child("RivalryTracksPanel",true,false) != null,"entry promotes the updated warmed page immediately")
		service.respond({"ok":true,"data":snapshot()})
		app._finish_menu_page_slide()
		await settle()
		if not service.pending_path.is_empty(): service.respond({"ok":true,"data":snapshot()})
		# A confirmed nonmember must still receive the real Join action.
		app.rivalry.reset()
		app._open_rivalry()
		service.respond({"ok":true,"data":{"state":"not_joined","week":41,"ends_at":604800,"server_now":0}})
		await settle()
		app._finish_menu_page_slide()
		check(app.content.find_child("RivalryJoin",true,false) != null,"confirmed nonmembers can join")
		# Development auto-enrollment's intermediate not_joined response is hidden.
		service.development = true
		app._open_rivalry()
		service.respond({"ok":true,"data":{"state":"not_joined","week":41,"ends_at":604800,"server_now":0,"test_population":true}})
		check(service.pending_path == "/rivalry/join","automatic membership issues its normal join request")
		await no_join_frames(app.content,"automatic enrollment has no intermediate join flash")
		service.respond({"ok":true,"data":snapshot()})
		await settle()
		check(app.content.find_child("RivalryTracksPanel",true,false) != null,"automatic enrollment opens the actual field")
		service.development = false
		app.rivalry.reset()
		app._open_rivalry()
		service.respond({"ok":false,"error":"UNAVAILABLE","data":{}})
		await settle()
		app._finish_menu_page_slide()
		check(app.content.find_child("RivalryRefresh",true,false) != null and app.content.find_child("RivalryLoading",true,false) == null,"failed membership remains retryable")
		app.online.client._access_token = ""
		app.rivalry.reset()
		app._rivalry()
		check(app.content.find_child("RivalryJoin",true,false) != null,"guests keep the sign-in action")
		app.online.client._access_token = "fixture"
		# Changing the user's choice must cancel an unresolved entry.
		app._show_screen("tracks")
		app.rivalry.reset()
		app._prefetch_rivalry()
		app._open_rivalry()
		app._open_free_race()
		service.respond({"ok":true,"data":snapshot()})
		await settle()
		check(app.screen == "tracks" and not app._rivalry_entry_pending,"a completed preload cannot undo a later Free Race choice")
		# After preloading, the very first rivalry frame has its five real tracks.
		app._open_rivalry()
		check(app.screen == "rivalry" and app.content.find_child("RivalryTracksPanel",true,false) != null,"preloaded first frame includes populated rivalry data")
		service.respond({"ok":true,"data":snapshot()})
		app._finish_menu_page_slide()
		await settle()
		if not service.pending_path.is_empty(): service.respond({"ok":true,"data":snapshot()})
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("RIVALRY_ENTRY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

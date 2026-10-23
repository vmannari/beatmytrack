extends SceneTree
## Exercise the actual newspaper -> hash-checked download -> native race path.
## Only transport replies are fixtures; persistence stays inside the workspace.
const VERSION: String = "11111111-2222-4333-8444-555555555555"
const OTHER_VERSION: String = "11111111-2222-4333-8444-666666666666"
const NewsFixture = preload("res://tests/test_garage_news.gd")
const News = preload("res://backend/news_client.gd")
var app: Node
var backend: Transport
var page: GaragePage
var checks: int = 0
var failures: int = 0
var output: String
var frozen_draws: int = 0
var loading_draws: int = 0
var countdown_at_reveal: int = -1
var captured_loading: bool = false

class Transport extends Node:
	var app: Node
	var safety: Node
	var player: Dictionary = {}
	var _base_url: String = "http://isolated-news.invalid"
	var _capabilities: Dictionary = {}
	var document: Dictionary
	var metadata: Dictionary
	var calls: Array[String] = []
	var held: bool = false
	var hold_document: bool = false
	var missing: bool = false
	var corrupt: bool = false
	var ticket_failure: bool = false
	func base_url() -> String: return _base_url
	func signed_in() -> bool: return app.online.client.signed_in()
	func server_now() -> int: return 1792152000
	func new_operation_key() -> String: return "isolated-news-operation"
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		calls.append(path)
		while held and (not hold_document or path.ends_with("/document")): await get_tree().process_frame
		await get_tree().process_frame
		if missing: return {"ok":false,"status":404,"data":{},"error":"Track unavailable"}
		if path.begins_with("/tracks?"): return {"ok":true,"data":{"items":[metadata.duplicate(true)]}}
		if path.ends_with("/document"):
			return {"ok":true,"data":document.duplicate(true),"body":JSON.stringify(document)+(" " if corrupt else "")}
		return {"ok":true,"data":metadata.duplicate(true)}
	func request_public(_path: String, _owner: int) -> Dictionary:
		# Race's ordinary return opens the browser; keep that unrelated read local.
		await get_tree().process_frame
		return {"ok":false,"data":{},"error":"Isolated browser"}
	func race_ticket(version: String, vehicle: String, _key: String, _purpose: String) -> Dictionary:
		calls.append("ticket/"+version+"/"+vehicle)
		await get_tree().process_frame
		if ticket_failure: return {"ok":false,"error":"Isolated ticket failure"}
		var engine: Dictionary = Engine.get_version_info()
		var config: HandlingConfig = HandlingSelection.config()
		var values: Dictionary = {}
		for property: Dictionary in config.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: values[str(property.name)] = config.get(str(property.name))
		return {"ok":true,"data":{"ticket_id":"isolated-news-ticket","manifest":{
			"compiler_version":TrackCompiler.VERSION,"physics_version":VehicleSimulation.PHYSICS_VERSION,"rules_key":RaceRules.KEY,
			"engine_version":"%s.%s.%s.%s.%s.%s" % [engine.major,engine.minor,engine.patch,engine.status,engine.build,str(engine.hash).left(9)],
			"tick_rate":VehicleSimulation.TICK_RATE,"track_schema":TrackDocument.SCHEMA,"replay_schema":"bmt-replay-v1","verifier_version":"canonical-verifier-1",
			"track_content_hash":app.selected_track.content_hash,"config_hash":JSON.stringify(values,"",true).sha256_text()}}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)
func frames(count: int = 5) -> void:
	for tick: int in range(count): await process_frame
func wait_preparation() -> void:
	var deadline: int = Time.get_ticks_msec()+40000
	while app.cloud_starting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.cloud_starting,"preparation finishes within its deadline")
func clear_dialogs() -> void:
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog:
			child.hide()
			child.queue_free()
	await frames(2)
func observe() -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.race_loading): return
	loading_draws += 1
	if is_instance_valid(app.game):
		frozen_draws += 1
		check(app.game.process_mode == Node.PROCESS_MODE_DISABLED and app.game.sim.state.tick == 0 and app.game.countdown_ticks == 360,"loading keeps race and countdown frozen")
	if DisplayServer.get_name() != "headless" and not captured_loading:
		captured_loading = root.get_texture().get_image().save_png(output.path_join("story-race-loading.png")) == OK
func show_news() -> void:
	app._show_screen("garage")
	page = app._retained_garage
	page._show_section("news")
	await frames(12)
	while page._menu_motion != null: await process_frame
func story() -> Dictionary:
	return {"id":"published-story","kind":"friend_track","actor_id":"bob","actor_name":"Bob","track_name":"Dust cloud","version_id":VERSION,"track_points":backend.document.points}

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var evidence_root: String = "res://../docs/evidence/garage-news-race-2026-10-16"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): evidence_root = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(evidence_root.path_join(RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name()))
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = ProjectSettings.globalize_path("res://../build/news-race/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = directory.path_join("roads")
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory)
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	GameSoundtrack.instance().music_enabled = false
	backend = Transport.new()
	backend.app = app
	backend.safety = app.online.client.safety
	backend.document = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json"))
	backend.metadata = {"version_id":VERSION,"track_id":"aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee","authoring_id":backend.document.id,"version":1,"state":"published","hidden":false,
		"name":backend.document.name,"creator":"Bob","creator_id":"bob","content_hash":JSON.stringify(backend.document).sha256_text(),"points":backend.document.points,"theme":backend.document.theme,"rating_average":null,"rating_count":0}
	root.add_child(backend)
	app.cloud.client = backend
	if DisplayServer.get_name() == "headless": process_frame.connect(observe)
	else: RenderingServer.frame_post_draw.connect(observe)
	await show_news()
	# Failed metadata, unavailable publication, blocked author and corrupt bytes.
	backend.missing = true
	await app._race_news_story(story())
	check(app.game == null and app.race_loading == null and page.section == "news" and app.root_ui.visible,"missing publication returns to the newspaper")
	backend.missing = false
	await clear_dialogs()
	backend.metadata.state = "archived"
	await app._race_news_story(story())
	check(app.game == null and app.race_loading == null,"archived publication cannot start")
	backend.metadata.state = "published"
	await clear_dialogs()
	backend.safety.blocked.bob = "Bob"
	var before: int = backend.calls.size()
	await app._race_news_story(story())
	check(app.game == null and backend.calls.size() == before+1 and app.race_loading == null,"blocked author cannot download or race")
	backend.safety.blocked.clear()
	await clear_dialogs()
	backend.corrupt = true
	await app._race_news_story(story())
	check(app.game == null and app.race_loading == null and app.cloud.last_error.contains("integrity"),"download must match the published hash")
	backend.corrupt = false
	await clear_dialogs()
	# Leave or change context while an actual metadata request is in flight.
	for change: String in ["section","navigation","account","origin","vehicle","selection","document-section","document-origin","local-search"]:
		await show_news()
		var old_vehicle: String = VehicleCatalog.selected
		var old_selection: NativeTrack = app.selected_track
		var old_origin: String = backend._base_url
		before = backend.calls.size()
		backend.hold_document = change.begins_with("document-")
		backend.held = true
		var pending: Dictionary = story()
		if change == "local-search": pending.erase("version_id"); pending.authoring_id = backend.document.id
		app._race_news_story(pending)
		var expected_calls: int = 2 if backend.hold_document else 1
		while backend.calls.size() < before+expected_calls: await process_frame
		match change:
			"section", "document-section", "local-search": page._show_section("care")
			"navigation": app._show_screen("settings")
			"account": backend.player = {"id":"changed-account"}
			"origin", "document-origin": backend._base_url = "http://changed-origin.invalid"
			"vehicle": VehicleCatalog.selected = "formula" if old_vehicle != "formula" else "compact"
			"selection": app.selected_track = NativeTrack.new()
		backend.held = false
		await wait_preparation()
		check(app.game == null and app.race_loading == null and backend.calls.size() == before+expected_calls,"stale "+change+" cannot continue loading or launch a hidden race")
		VehicleCatalog.selected = old_vehicle
		app.selected_track = old_selection
		backend.player = {}
		backend._base_url = old_origin
		check(not FileAccess.file_exists(app.cloud.cache_root().path_join(str(backend.metadata.content_hash)+".json")),"cancelled "+change+" stores no downloaded track")
		await clear_dialogs()
	await show_news()
	var news_backend := NewsFixture.Backend.new()
	root.add_child(news_backend)
	var service := News.new()
	service.client = news_backend
	root.add_child(service)
	service.identity_changed()
	service.items = [story()]
	service._fetched_at = Time.get_ticks_msec()
	service.checked_day = news_backend.server_now()/86400
	page.news_client = service
	page._show_section("cars")
	page._show_section("news")
	await frames(14)
	var menu: Node = page.tools.find_child("GarageNewsMenu",true,false)
	var car: CarVisual = page.showroom.car
	var camera_pose: Transform3D = page.showroom.camera.transform
	before = backend.calls.size()
	check(news_backend.calls.is_empty(),"viewing the publication starts no transport work")
	var race_button: Button = menu.find_child("GarageNewsRace",true,false)
	check(race_button != null and not race_button.disabled,"actual publication has an enabled race action")
	race_button.pressed.emit()
	var loading: Node = app.race_loading
	check(loading != null and app.game == null and app.cloud_starting,"story immediately presents one loading cover")
	check(loading.scenery.texture == null and not loading.facts_label.text.contains("Grass"),"opening cover waits for the real biome metadata")
	loading.tree_exiting.connect(func() -> void:
		if is_instance_valid(app.game): countdown_at_reveal = app.game.countdown_ticks)
	race_button.pressed.emit()
	check(app.race_loading == loading,"duplicate presses retain one loading operation")
	await wait_preparation()
	check(backend.calls.slice(before) == ["/track-versions/"+VERSION,"/track-versions/"+VERSION+"/document"],"real story reads its exact version and document without a catalog query")
	check(is_instance_valid(app.game) and app.race_loading == null,"story enters the real native race directly")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		check(app.game.native_track.metadata.cloud_version == VERSION and app.selected_track == app.game.native_track,"race uses the story's pinned published version")
		check(app.game.track_session.target_laps == 5 and countdown_at_reveal == 360,"normal five-lap race retains the full countdown")
		check(app.game.sim.state.tick == 0 and app.game.track_session.elapsed_ticks == 0 and app.game.sim.config.vehicle_id == VehicleCatalog.selected,"loading preserves canonical time and selected vehicle")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("story-race-countdown.png")) == OK,"native countdown captured")
		app._leave_race()
	await show_news()
	check(page.showroom.car == car and page.showroom.camera.transform == camera_pose,"racing from News retains the original Garage car and camera")
	# Every track-related article reaches the same native race pipeline.
	for kind: String in ["milestone","world_record","friend_overtake","percentile_drop"]:
		var article: Dictionary = story()
		article.kind = kind
		service.items = [article]
		service.changed.emit()
		menu = page.tools.find_child("GarageNewsMenu",true,false)
		var action: Button = menu.find_child("GarageNewsRace",true,false)
		check(action != null and not action.disabled,kind+" exposes its actual race action")
		before = backend.calls.size()
		if action != null: action.pressed.emit()
		await wait_preparation()
		check(backend.calls.slice(before) == ["/track-versions/"+VERSION],kind+" pins its exact version and reuses the hash-checked document")
		check(is_instance_valid(app.game),kind+" starts the native race")
		if is_instance_valid(app.game):
			app.game.set_physics_process(false)
			check(app.game.native_track.metadata.cloud_version == VERSION and app.game.track_session.target_laps == 5 and app.game.sim.config.vehicle_id == VehicleCatalog.selected,kind+" preserves version, five laps and selected car")
			app._leave_race()
		await show_news()
	app.online.client._access_token = "isolated-test-token"
	app.online.client.player = {"id":"alice"}
	backend.player = {"id":"alice"}
	backend.ticket_failure = true
	await app._race_news_story(story())
	var offline_choice: ConfirmationDialog
	for child: Node in app.root_ui.get_children():
		if child is ConfirmationDialog: offline_choice = child
	check(app.game == null and app.race_loading == null and not app.cloud_starting and app.root_ui.visible,"failed online ticket leaves the newspaper without a stuck cover")
	check(offline_choice != null and offline_choice.visible and offline_choice.ok_button_text == "Race offline","normal explicit offline choice remains after ticket failure")
	backend.ticket_failure = false
	await clear_dialogs()
	# Local article resolves by authored identity, then reuses downloaded bytes.
	service.items.clear()
	service.changed.emit()
	menu = page.tools.find_child("GarageNewsMenu",true,false)
	menu._choose(0)
	before = backend.calls.size()
	menu.find_child("GarageNewsRace",true,false).pressed.emit()
	await wait_preparation()
	check(is_instance_valid(app.game) and app.cloud_ticket.get("ticket_id","") == "isolated-news-ticket","local publication uses normal signed-in ticket verification and starts a native race")
	var local_reads: Array = backend.calls.slice(before)
	check(local_reads.size() == 3 and local_reads[0].begins_with("/tracks?") and local_reads[1] == "/track-versions/"+VERSION and local_reads[2] == "ticket/"+VERSION+"/"+VehicleCatalog.selected,"local story resolves once, reuses cached document and requests the selected-car ticket")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		app._leave_race()
	await show_news()
	# A real version must never fall back to an unrelated newer catalog result.
	var mismatched: Dictionary = story()
	mismatched.version_id = OTHER_VERSION
	before = backend.calls.size()
	check((await app.cloud.news_story_entry(mismatched)).is_empty() and backend.calls.slice(before) == ["/track-versions/"+OTHER_VERSION],"mismatched pinned version fails without fallback")
	app.cloud.entries.clear()
	app.cloud.entries.append(backend.metadata.duplicate(true))
	before = backend.calls.size()
	var local_story: Dictionary = preload("res://ui/garage_news_examples.gd").stories()[0]
	check(not (await app.cloud.news_story_entry(local_story)).is_empty() and backend.calls.slice(before) == ["/track-versions/"+VERSION],"known local track skips the catalog search but rechecks visibility")
	# The other local articles identify Underpass rather than borrowing Dust cloud.
	backend.document = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/underpass.json"))
	backend.metadata.merge({"version_id":OTHER_VERSION,"track_id":"aaaaaaaa-bbbb-4ccc-8ddd-ffffffffffff","authoring_id":backend.document.id,"name":backend.document.name,"content_hash":JSON.stringify(backend.document).sha256_text(),"points":backend.document.points,"theme":backend.document.theme},true)
	service.items.clear()
	service.changed.emit()
	menu = page.tools.find_child("GarageNewsMenu",true,false)
	menu._choose(1)
	before = backend.calls.size()
	menu.find_child("GarageNewsRace",true,false).pressed.emit()
	await wait_preparation()
	check(is_instance_valid(app.game),"local milestone starts the actual Underpass race")
	check(backend.calls.slice(before) == ["/tracks?limit=20&q=Underpass","/track-versions/"+OTHER_VERSION,"/track-versions/"+OTHER_VERSION+"/document","ticket/"+OTHER_VERSION+"/"+VehicleCatalog.selected],"local Underpass resolves by authored identity and uses ordinary download and ticket")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		check(app.game.native_track.metadata.cloud_version == OTHER_VERSION and app.game.track_session.target_laps == 5,"local milestone races its own published track")
		app._leave_race()
	check(loading_draws > 0 and frozen_draws > 0,"loading spans frames including the frozen native world")
	check(DisplayServer.get_name() == "headless" or captured_loading,"loading cover captured natively")
	app.online.client._access_token = ""
	app.online.client.player = {}
	app.cloud.client = app.online.client
	app.queue_free()
	service.queue_free()
	news_backend.queue_free()
	backend.queue_free()
	await frames(25)
	print("GARAGE NEWS RACE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

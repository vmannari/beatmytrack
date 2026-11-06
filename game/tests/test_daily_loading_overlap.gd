extends SceneTree
const Preparation = preload("res://race/daily_start_preparation.gd")
const Rules = preload("res://race/daily_elimination.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var client: LimitsClient
var rows: Array = []
var folder: String

class LimitsClient extends "res://backend/backend_client.gd":
	var authenticated: bool = false
	var response: Dictionary = {}
	var flights: Array = []
	var routes: Array = []
	var auto_delay: float = 0.0
	func _ready() -> void: pass
	func signed_in() -> bool: return authenticated
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _idempotency: String = "", _authenticated: bool = false) -> Dictionary:
		return await read(path,"authenticated")
	func request_public(path: String, _owner: int) -> Dictionary:
		return await read(path,"public")
	func read(path: String, route: String) -> Dictionary:
		if not path.begins_with("/track-of-the-day/limits?"): return {"ok":false,"data":{}}
		routes.append(route)
		var flight := {"released":false,"response":response.duplicate(true)}
		flights.append(flight)
		if auto_delay > 0.0:
			var deadline: int = Time.get_ticks_usec()+int(auto_delay*1000000.0)
			while Time.get_ticks_usec() < deadline: await get_tree().process_frame
		else:
			while not flight.released: await get_tree().process_frame
		return flight.response
	func release() -> void:
		for flight: Dictionary in flights: flight.released = true

class TestApp extends "res://core/app.gd":
	var cpu_blocked: bool = false
	var cpu_started: bool = false
	var cpu_delay: float = 0.0
	var join_us: int = 0
	var notices: Array[String] = []
	func _await_selected_preparation(_track: NativeTrack, loading_id: int, scope: String, navigation: int, starting_screen: String, vehicle: String, selection: NativeTrack) -> bool:
		cpu_started = true
		if cpu_delay > 0.0:
			var deadline: int = Time.get_ticks_usec()+int(cpu_delay*1000000.0)
			while Time.get_ticks_usec() < deadline: await get_tree().process_frame
		while cpu_blocked:
			await get_tree().process_frame
			if _race_preparation_changed(loading_id,scope,navigation,starting_screen,vehicle,selection): return false
		return not _race_preparation_changed(loading_id,scope,navigation,starting_screen,vehicle,selection)
	func _load_daily_limits(track: NativeTrack, vehicle: String, request: Dictionary) -> RefCounted:
		var result: RefCounted = await super._load_daily_limits(track,vehicle,request)
		join_us = Time.get_ticks_usec()
		return result
	func _notice(text: String) -> void: notices.append(text)

class FixtureCloud extends "res://backend/cloud_tracks.gd":
	var document: Dictionary
	func _ready() -> void: pass
	func download_document(_entry: Dictionary, _cancelled: Callable = Callable()) -> Dictionary:
		await get_tree().process_frame
		return document.duplicate(true)

class EventPage extends Control:
	var _server_now: int = 20761*86400+10
	var _ends_at: int = _server_now+100
	var entry: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func settle(frames: int = 4) -> void:
	for index: int in range(frames): await process_frame

func wait_wall(seconds: float) -> void:
	var deadline: int = Time.get_ticks_usec()+int(seconds*1000000.0)
	while Time.get_ticks_usec() < deadline: await process_frame

func until(predicate: Callable, label: String) -> void:
	var deadline: int = Time.get_ticks_msec()+60000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	check(predicate.call(),label)

func limits(track: NativeTrack) -> Dictionary:
	var engine: Dictionary = Engine.get_version_info()
	var manifest := {"engine_version":"%s.%s.%s.%s.%s.%s" % [engine.major,engine.minor,engine.patch,engine.status,engine.build,str(engine.hash).left(9)],"tick_rate":120,"vehicle_id":"compact","track_schema":TrackDocument.SCHEMA,"track_content_hash":track.content_hash,"compiler_version":TrackCompiler.VERSION,"rules_key":RaceRules.KEY,"physics_version":VehicleSimulation.PHYSICS_VERSION,"config_hash":JSON.stringify(VehicleCatalog.config("compact").snapshot(),"",true).sha256_text()}
	var data := {"day":20761,"server_now":1000,"ends_at":1100,"manifest":manifest,"policy":"daily-flying-elimination-v1","version_id":"daily-overlap","vehicle_id":"compact","tick_rate":120,"population":100,"cutoffs":[]}
	for percentile: int in Rules.PERCENTILES: data.cutoffs.append({"percentile":percentile,"lap_ticks":3600})
	return {"ok":true,"data":data}

func reset() -> NativeTrack:
	if is_instance_valid(app.game): app._leave_race()
	if is_instance_valid(app.race_loading): app._close_race_loading()
	app._cancel_selected_preparation()
	app.screen = "daily"
	app.cloud_starting = false
	app.cpu_started = false
	app.cpu_blocked = true
	app.cpu_delay = 0.0
	app.join_us = 0
	app.notices.clear()
	client.flights.clear()
	client.routes.clear()
	client.auto_delay = 0.0
	client.authenticated = false
	client.player = {}
	VehicleCatalog.selected = "compact"
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
	track.metadata.cloud_version = "daily-overlap"
	app.selected_track = track
	client.response = limits(track)
	return track

func start(track: NativeTrack) -> void:
	app._start_race(track,false,false,{},null,{"day":20761,"version_id":"daily-overlap"})
	await until(func() -> bool: return app.cpu_started,"selected CPU stage starts")

func finish() -> void:
	app.cpu_blocked = false
	client.release()
	await until(func() -> bool: return not app.cloud_starting,"loading attempt finishes")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		check(app.game.preparation_complete,"both stages install the complete Game")
		check(app.game.daily_elimination != null and app.game.track_session.target_laps == 10,"fresh Daily rules retain ten laps")
		check(app.game.sim.state.tick == 0 and app.game.countdown_ticks == 360,"readiness leaves the complete start clock")

func controller(control: bool) -> void:
	var path := "res://core/features/race.gd"
	if app._feature_resources.has(path): app._feature_resources[path].free(); app._feature_resources.erase(path)
	if control:
		var source := FileAccess.get_file_as_string("res://../docs/evidence/daily-loading-overlap-2026-11-05/before/game/core/features/race.gd")
		var script := GDScript.new(); script.source_code = source
		check(script.reload() == OK,"archived controller parses")
		var node: Node = script.new(); app.add_child(node); app._feature_resources[path] = node
	else:
		app._feature_resource(path)

func timing() -> void:
	for control: bool in [true,false,true,false]:
		controller(control)
		var track := reset()
		app.cpu_blocked = false; app.cpu_delay = 0.30; client.auto_delay = 0.20
		var began := Time.get_ticks_usec()
		await app._start_race(track,false,false,{},null,{"day":20761,"version_id":"daily-overlap"})
		if is_instance_valid(app.game): app.game.set_physics_process(false)
		check(is_instance_valid(app.game) and app.game.daily_elimination != null,"timing attempt installs the actual Daily")
		check(client.flights.size() == 1,"timing attempt uses one fresh read")
		rows.append({"control":control,"join_ms":(app.join_us-began)/1000.0,"entry_ms":(Time.get_ticks_usec()-began)/1000.0})
		if is_instance_valid(app.game): app._leave_race()
		await settle()

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("overlap fixture deadline"); quit(1))
	folder = "user://daily-overlap-"+TrackLibrary.unique_id()
	app = TestApp.new()
	app.records = LocalRecords.new(folder.path_join("records.json")); app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks")); app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._garage_preloader.set_process(false)
	client = LimitsClient.new(); app.add_child(client)
	app.online.client = client; app.cloud.client = client
	if "--timing" in OS.get_cmdline_user_args():
		await timing()
	else:
		var control: bool = "--control" in OS.get_cmdline_user_args()
		if control: controller(true)
		var track := reset()
		await start(track)
		check(client.flights.size() == 1,"limits read starts before CPU readiness")
		if control:
			app.cpu_blocked = false
			await until(func() -> bool: return not client.flights.is_empty(),"control eventually reads limits")
			await finish()
		else:
			client.release(); await settle()
			check(not is_instance_valid(app.game) and app.cloud_starting,"fast read cannot bypass CPU readiness")
			await finish()
			check(client.flights.size() == 1 and client.routes == ["public"],"guest start has one public read")
			track = reset(); client.authenticated = true
			await start(track); app.cpu_blocked = false; await settle()
			check(not is_instance_valid(app.game) and app.cloud_starting,"fast CPU cannot bypass the pending read")
			await finish()
			check(client.flights.size() == 1 and client.routes == ["authenticated"],"signed-in start has one authenticated read")
			for mutation: String in ["navigation","account","session","car","selection","version","source","content","event_day","event_source","day","failure","manifest","expired"]:
				track = reset()
				var event_page: EventPage
				if mutation.begins_with("event_"):
					event_page = EventPage.new(); app.add_child(event_page)
					app._selected_preparation_track = track
					app._selected_preparation_event = {"kind":"daily","page":weakref(event_page),"pin":Preparation.Event.pin(app,"daily",event_page),"expires":Time.get_ticks_msec()+100000}
				if mutation == "source": track.metadata.cloud_entry = {"id":"test","version_id":"daily-overlap","content_hash":"original"}
				if mutation == "day": client.response.data.day += 1
				if mutation == "failure": client.response.ok = false
				if mutation == "manifest": client.response.data.manifest.track_content_hash = "wrong"
				if mutation == "expired": client.response.data.ends_at = client.response.data.server_now
				await start(track)
				match mutation:
					"navigation": app._navigation_generation += 1
					"account": client.player = {"id":"different-fixture-account"}
					"session": client._session_generation += 1
					"car": VehicleCatalog.selected = "kart"
					"selection": app.selected_track = NativeTrack.new()
					"version": track.metadata.cloud_version = "different-version"
					"source": track.metadata.cloud_entry.content_hash = "different-source"
					"content": track.content_hash = "different-content"
					"event_day": event_page._server_now += 86400
					"event_source": event_page.entry.version_id = "different-event"
				await finish()
				check(not is_instance_valid(app.game),mutation+" cannot install stale Daily rules")
				check(not is_instance_valid(app.race_loading),mutation+" releases its loading cover")
				if event_page != null: event_page.queue_free()
				await settle()
			# The day can expire after a successful response, during CPU work.
			track = reset(); client.response.data.ends_at = client.response.data.server_now+1
			await start(track); client.release()
			await wait_wall(1.05)
			await finish()
			check(not is_instance_valid(app.game),"expiry during CPU preparation rejects an earlier valid response")
			track = reset(); client.response.data.ends_at = client.response.data.server_now+1
			await start(track); app.cpu_blocked = false
			await wait_wall(1.05)
			await finish()
			check(not is_instance_valid(app.game),"expiry includes time spent waiting for the limits response")
			# A closed cover owns the abandoned result, even during a newer start.
			track = reset(); await start(track)
			var old_flight: Dictionary = client.flights[0]
			app._close_race_loading(); app.cpu_blocked = false; await settle()
			track = reset(); await start(track)
			old_flight.released = true; await settle()
			check(not is_instance_valid(app.game) and client.flights.size() == 1,"abandoned response cannot complete a newer attempt")
			await finish()
			track = reset(); await start(track)
			app.cpu_blocked = false; client.release()
			await until(func() -> bool: return is_instance_valid(app.game),"Game installation begins after both stages")
			var preparing: RefCounted = Preparation.find(app.race_loading)
			if preparing != null: preparing.expires_msec = Time.get_ticks_msec()-1
			await until(func() -> bool: return not app.cloud_starting,"expiry stops the disabled Game installation")
			check(not is_instance_valid(app.game),"expiry during installation cannot enable the race")
			# Metadata download/compile uses the same in-flight limits receipt.
			track = reset()
			var source: Dictionary = TrackDocument.create_default()
			var entry := {"id":"cloud_overlap","track_id":"overlap","version_id":"daily-overlap","content_hash":JSON.stringify(source).sha256_text(),"name":"Overlap fixture","creator":"Fixture","theme":"pine","points":source.points,"cache_path":folder.path_join("missing.json")}
			var compiled: NativeTrack = preload("res://backend/cloud_tracks.gd").compile_document(entry,source)
			track = preload("res://backend/cloud_tracks.gd").metadata_track(entry)
			app.selected_track = track; client.response = limits(compiled)
			var cloud := FixtureCloud.new(); cloud.client = client; cloud.document = source; cloud.root_override = folder.path_join("metadata-cloud"); app.add_child(cloud); app.cloud = cloud; app.lifecycle.cloud = cloud
			await start(track); client.release(); await settle()
			check(track.metadata.get("metadata_only",false) and not is_instance_valid(app.game),"early response waits for metadata hydration")
			await finish()
			check(client.flights.size() == 1 and not track.metadata.get("metadata_only",false),"metadata handoff retains one read and the exact track object")
			check(is_instance_valid(app.game) and app.game.native_track == track,"hydrated metadata reaches the actual Game")
			# Release a delayed response after the entire App owner has gone.
			track = reset(); await start(track)
			var receipt: WeakRef = weakref(Preparation.find(app.race_loading))
			client.reparent(root)
			app.cpu_blocked = false; await settle()
			app.queue_free(); app = null; await settle()
			client.release(); await settle(12)
			check(not is_instance_valid(receipt.get_ref()),"owner teardown releases a late limits receipt")
			client.queue_free()
	if is_instance_valid(app):
		if is_instance_valid(app.game): app._leave_race()
		client.release(); app.cpu_blocked = false; await settle(8)
		app.queue_free(); app = null; await settle(12)
	var result := {"checks":checks,"failures":failures,"rows":rows}
	var output := OS.get_environment("BMT_LOADING_OUTPUT")
	if not output.is_empty(): FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DAILY_LOADING_OVERLAP ",JSON.stringify(result))
	quit(1 if failures else 0)

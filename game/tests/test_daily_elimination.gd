extends SceneTree
const Rules = preload("res://race/daily_elimination.gd")
var checks: int = 0
var failures: int = 0

class LimitsClient extends "res://backend/backend_client.gd":
	var response: Dictionary
	var requested_path: String = ""
	func signed_in() -> bool: return false
	func request_public(path: String, _owner: int) -> Dictionary:
		requested_path = path
		return response.duplicate(true)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func data() -> Dictionary:
	var result: Dictionary = {"policy":"daily-flying-elimination-v1","version_id":"track","vehicle_id":"compact","tick_rate":120,"population":100,"cutoffs":[]}
	for i: int in range(9): result.cutoffs.append({"percentile":Rules.PERCENTILES[i],"lap_ticks":(30-i)*120})
	return result

func lap(session: TrackSession, rules: RefCounted, seconds: float) -> void:
	session.lap_times.append(seconds)
	session.completed_laps += 1
	session.lap_start_time += seconds
	session.elapsed_ticks = roundi(session.lap_start_time*120)
	rules.observe(session)

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Daily elimination deadline"); quit(1))
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960,540)
	root.theme = MenuStyle.theme()
	for missed: int in range(9):
		var rules := Rules.new()
		check(rules.configure(data(),"track","compact"),"valid descending lap limits")
		var session := TrackSession.new(120,10)
		lap(session,rules,999.0)
		check(not session.finished and rules.passed == 0,"arbitrarily slow opening lap never eliminates")
		for stage: int in range(missed): lap(session,rules,30.0-stage)
		check(not session.finished and rules.passed == missed,"boundary ties pass all preceding stages")
		lap(session,rules,30.0-missed+1.0/120.0)
		check(rules.eliminated and session.finished and rules.passed == missed,"one tick over cutoff eliminates at stage %d" % missed)
		rules.observe(session)
		check(rules.passed == missed,"terminal evaluation is idempotent")
	var rules := Rules.new()
	rules.configure(data(),"track","compact")
	var session := TrackSession.new(120,10)
	lap(session,rules,0.01)
	for index: int in range(9): lap(session,rules,30.0-index)
	check(rules.complete and not rules.eliminated and rules.passed == 9 and session.finished,"nine flying laps complete top one percent")
	var retry := TrackSession.new(120,10)
	rules.reset()
	check(not rules.complete and not rules.eliminated and rules.passed == 0 and rules.limits.size() == 9,"retry clears progress and retains frozen limits")
	lap(retry,rules,30)
	lap(retry,rules,1)
	lap(retry,rules,30)
	check(rules.eliminated and rules.passed == 1,"earlier fast lap cannot qualify a later slow lap")
	var rewound := Rules.new()
	rewound.configure(data(),"track","compact")
	var restored := TrackSession.new(120,10)
	lap(restored,rewound,50)
	lap(restored,rewound,25)
	restored.lap_times.resize(1)
	restored.completed_laps = 1
	rewound.observe(restored)
	check(rewound.passed == 0 and not rewound.eliminated,"rewinding across the line restores the previous cutoff")
	lap(restored,rewound,31)
	check(rewound.eliminated and rewound.passed == 0,"rewound stage still requires its own valid lap")
	for mutation: String in ["vehicle","version","empty","unordered","wrong_percent","nan","tick_rate"]:
		var value: Dictionary = data()
		match mutation:
			"vehicle": value.vehicle_id = "electric"
			"version": value.version_id = "other"
			"empty": value.cutoffs = []
			"unordered": value.cutoffs[4].lap_ticks = 9000
			"wrong_percent": value.cutoffs[0].percentile = 80
			"nan": value.cutoffs[0].lap_ticks = NAN
			"tick_rate": value.tick_rate = 60
		check(not Rules.new().configure(value,"track","compact"),"reject invalid limits: "+mutation)
	check(TrackSession.new().target_laps == 5,"ordinary race remains five laps")
	await request_contract()
	await native_game()
	await render_results(retry,rules,"eliminated")
	var won := Rules.new()
	won.configure(data(),"track","compact")
	var winning := TrackSession.new(120,10)
	lap(winning,won,100)
	for index: int in range(9): lap(winning,won,30-index)
	await render_results(winning,won,"complete")
	print("DAILY_ELIMINATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func request_contract() -> void:
	var app: Node = load("res://core/app.gd").new()
	app.online = preload("res://backend/account_controller.gd").new()
	app.online.client.free()
	var client := LimitsClient.new()
	app.online.client = client
	var track := NativeTrack.new()
	track.content_hash = "track-hash"
	track.metadata.cloud_version = "track"
	var payload: Dictionary = data()
	payload.day = 123
	payload.ends_at = 124*86400
	payload.server_now = 123*86400+60
	var engine: Dictionary = Engine.get_version_info()
	payload.manifest = {"engine_version":"%s.%s.%s.%s.%s.%s" % [engine.major,engine.minor,engine.patch,engine.status,engine.build,str(engine.hash).left(9)],"tick_rate":120,"vehicle_id":"compact","track_schema":TrackDocument.SCHEMA,"track_content_hash":track.content_hash,"compiler_version":TrackCompiler.VERSION,"rules_key":RaceRules.KEY,"physics_version":VehicleSimulation.PHYSICS_VERSION,"config_hash":JSON.stringify(VehicleCatalog.config("compact").snapshot(),"",true).sha256_text()}
	client.response = {"ok":true,"data":payload}
	var request: Dictionary = {"day":123,"version_id":"track"}
	check(await app._load_daily_limits(track,"compact",request) != null,"actual App accepts exact compatible server lap limits")
	check(client.requested_path == "/track-of-the-day/limits?day=123&version_id=track&vehicle_id=compact","limits request pins day, track and car")
	for field: String in ["engine_version","config_hash","compiler_version","rules_key","track_content_hash","physics_version","vehicle_id"]:
		client.response.data = payload.duplicate(true)
		client.response.data.manifest[field] = "wrong"
		check(await app._load_daily_limits(track,"compact",request) == null,"reject incompatible limit manifest: "+field)
	client.response.data = payload.duplicate(true)
	client.response.data.day = 124
	check(await app._load_daily_limits(track,"compact",request) == null,"reject rollover response")
	client.free()
	app.online.free()
	app.free()

func native_game() -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/ellipse.json")
	game.production_mode = true
	game.handling_test_enabled = false
	game.daily_elimination = Rules.new()
	game.daily_elimination.configure(data(),"track","compact")
	root.add_child(game)
	while not game.preparation_complete: await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	check(game.track_session.target_laps == 10,"actual game restart installs daily ten lap session")
	lap(game.track_session,game.daily_elimination,100)
	lap(game.track_session,game.daily_elimination,31)
	check(game.track_session.finished and game.daily_elimination.eliminated,"actual game owns elimination state")
	game.restart()
	check(game.track_session.target_laps == 10 and game.track_session.lap_times.is_empty() and not game.daily_elimination.eliminated,"actual game retry resets session and elimination")
	game.queue_free()
	await process_frame

func render_results(session: TrackSession, rules: RefCounted, title: String) -> void:
	var panel := preload("res://ui/daily_elimination_results.gd").new()
	panel.rules = rules
	panel.session = session
	root.add_child(panel)
	for size: Vector2i in [Vector2i(960,540),Vector2i(844,390),Vector2i(390,844)]:
		root.size = size
		for frame: int in range(4): await process_frame
		check(panel.size.x <= size.x,"result fits viewport "+str(size))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var output: String = ProjectSettings.globalize_path("res://../docs/evidence/daily-elimination-2026-10-31")
			check(root.get_texture().get_image().save_png(output.path_join(title+"-%dx%d.png" % [size.x,size.y])) == OK,"result capture")
	panel.queue_free()
	await process_frame
	for locale: String in ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		TranslationServer.set_locale(locale)
		var localized := preload("res://ui/daily_elimination_results.gd").new()
		localized.rules = rules
		localized.session = session
		root.add_child(localized)
		for frame: int in range(3): await process_frame
		var grid: Control = localized.find_child("DailyLapGrid",true,false)
		check(grid.get_global_rect().end.x <= root.get_visible_rect().size.x,"localized result columns fit: "+locale)
		localized.queue_free()
		await process_frame
	TranslationServer.set_locale("en")

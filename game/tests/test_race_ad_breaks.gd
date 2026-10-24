extends SceneTree
## Deterministic policy plus the real app's completed-race/results/retry path.
const Breaks = preload("res://platform/race_ad_breaks.gd")
const Adapter = preload("res://platform/admob_interstitial.gd")
const AppScene = preload("res://core/app.tscn")
var checks: int = 0
var failures: int = 0
var now: int = 0
var capture_directory: String = ""

class TestAds extends Node:
	var calls: int = 0
	var prepares: int = 0
	var discards: int = 0
	var available: bool = true
	var shown: bool = true
	var hold: bool = false
	func supported() -> bool: return available
	func prepare() -> void: prepares += 1
	func discard() -> void: discards += 1
	func show_interstitial() -> Dictionary:
		calls += 1
		await get_tree().process_frame
		while hold: await get_tree().process_frame
		return {"shown":shown}

class TestClient extends Node:
	var player: Dictionary = {}
	var reads: int = 0
	var hold: bool = false
	var ok: bool = true
	var owned: Dictionary = {"publishing_slots":1,"ad_free_until":0,"max_rewinds_per_race":3,"server_now":1,"ad_free":false,"ad_free_forever":false,"free_rewinds":false,"purchase_simulation":false,"store_available":false}
	func base_url() -> String: return "https://ad-fixture.invalid"
	func signed_in() -> bool: return not player.is_empty()
	func request_api(_path: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		reads += 1
		await get_tree().process_frame
		while hold: await get_tree().process_frame
		return {"ok":ok,"data":owned.duplicate(true)}

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + label)

func fixture() -> Node:
	var policy := Breaks.new()
	var ads := TestAds.new()
	var client := TestClient.new()
	policy.adapter = ads
	policy.client = client
	policy.clock_msec = func() -> int: return now
	policy.enabled = true
	policy.add_child(ads)
	policy.add_child(client)
	root.add_child(policy)
	return policy

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-ad-breaks="): capture_directory = argument.trim_prefix("--capture-ad-breaks=")
	var policy: Node = fixture()
	policy.observe_time(true)
	check(not policy.due(), "fresh session is not due")
	for index: int in range(2):
		policy.record_finish()
		check(not (await policy.show_if_due(func() -> bool: return true)).shown, "first two finishes are quiet: %d" % index)
	policy.record_finish()
	check(policy.due(), "third completed race becomes due")
	check((await policy.show_if_due(func() -> bool: return true)).shown, "third finish shows one ad")
	check(policy.races == 0 and policy.active_msec == 0, "show resets both counters")
	check(not (await policy.show_if_due(func() -> bool: return true)).shown and policy.adapter.calls == 1, "same break cannot show twice")
	policy.races = 3
	policy.active_msec = Breaks.INTERVAL_MSEC
	policy.adapter.hold = true
	policy.show_if_due(func() -> bool: return true)
	await process_frame
	check(not (await policy.show_if_due(func() -> bool: return true)).shown and policy.adapter.calls == 2, "both thresholds and repeat requests own one fullscreen ad")
	policy.adapter.hold = false
	for frame: int in range(2): await process_frame
	check(not policy.due() and not policy.busy, "one dismissal clears both simultaneous thresholds")
	policy.observe_time(true)
	now += Breaks.INTERVAL_MSEC - 1
	policy.observe_time(true)
	check(not policy.due(), "ten-minute threshold excludes the preceding millisecond")
	now += 1
	policy.observe_time(true)
	check(policy.due() and policy.races == 0, "ten minutes can win before three races")
	check(not (await policy.show_if_due(func() -> bool: return false)).shown and policy.adapter.calls == 2, "elapsed time cannot open an ad during racing")
	policy.adapter.shown = false
	check(not (await policy.show_if_due(func() -> bool: return true)).shown and policy.due(), "unavailable ad preserves due counters")
	policy.adapter.shown = true
	check((await policy.show_if_due(func() -> bool: return true)).shown and not policy.due(), "later finish can fulfill deferred ad")
	policy.observe_time(true)
	now += 2000
	policy.observe_time(false)
	now += 3600000
	policy.observe_time(false)
	check(policy.active_msec == 2000, "background, pause and ad time are excluded")
	policy.observe_time(true)
	now += 1000
	policy.observe_time(false)
	check(policy.active_msec == 3000, "foreground time resumes without counting absence")
	policy.enabled = false
	policy.observe_time(true)
	now += Breaks.INTERVAL_MSEC
	policy.observe_time(true)
	check(policy.active_msec == 3000, "disabled development preference does not accrue time")
	policy.races = 3
	check(not (await policy.show_if_due(func() -> bool: return true)).shown, "disabled placement stays quiet")
	policy.enabled = true
	policy.adapter.available = false
	check(not (await policy.show_if_due(func() -> bool: return true)).shown, "unsupported platform stays quiet")
	policy.adapter.available = true
	policy.free()
	for mode: String in ["monthly", "forever", "unavailable", "malformed", "changed", "left", "ordinary"]:
		policy = fixture()
		policy.record_finish()
		policy.races = 3
		policy.client.player = {"id":"owner"}
		if mode == "monthly": policy.client.owned.ad_free = true
		if mode == "forever": policy.client.owned.ad_free_forever = true
		if mode == "unavailable": policy.client.ok = false
		if mode == "malformed": policy.client.owned.erase("ad_free")
		var present: Array[bool] = [true]
		if mode in ["changed", "left"]:
			policy.client.hold = true
			policy.show_if_due(func() -> bool: return present[0])
			await process_frame
			check(policy.busy and not policy.blocking, "ownership read leaves result actions usable: " + mode)
			if mode == "changed": policy.client.player = {"id":"another-owner"}
			else: present[0] = false
			policy.client.hold = false
			for frame: int in range(3): await process_frame
		else:
			await policy.show_if_due(func() -> bool: return true)
		check(policy.adapter.calls == (1 if mode == "ordinary" else 0), "entitlement and break fence: " + mode)
		check(not policy.busy and not policy.blocking, "ownership path releases request: " + mode)
		policy.free()
	policy = fixture()
	policy.client.player = {"id":"owner"}
	policy.client.owned.ad_free = true
	await policy.prepare()
	check(policy.adapter.prepares == 0 and policy.adapter.discards == 1, "ad-free account does not preload SDK ads")
	policy.free()
	var adapter := Adapter.new()
	root.add_child(adapter)
	check(not (await adapter.show_interstitial()).shown, "desktop SDK adapter returns unavailable")
	var callbacks: Array[int] = [0]
	adapter.finished.connect(func(_value: Dictionary) -> void: callbacks[0] += 1)
	adapter._request = "current"
	adapter._completed("stale", true, "")
	adapter._completed("current", true, "")
	adapter._completed("current", true, "")
	check(callbacks[0] == 1, "SDK adapter ignores stale and duplicate callbacks")
	adapter.free()
	await app_flow()
	print("RACE_AD_BREAKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func finish(app: Node) -> RaceResults:
	var session: TrackSession = app.game.track_session
	session.finished = true
	session.completed_laps = RaceRules.LAPS
	session.elapsed_ticks = 6000
	session.lap_start_time = 50.0
	session.lap_times.assign([10.0,10.0,10.0,10.0,10.0])
	app.game.paused = true
	app._results()
	return app.root_ui.find_child("RaceResults", true, false) as RaceResults

func app_flow() -> void:
	root.size = Vector2i(1280,720)
	OS.set_environment("BMT_API_URL", "")
	var directory: String = "user://race_ads_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = AppScene.instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.set_process(false)
	var ads := TestAds.new()
	app.race_ad_breaks.adapter.free()
	app.race_ad_breaks.add_child(ads)
	app.race_ad_breaks.adapter = ads
	app.race_ad_breaks.enabled = true
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	track.metadata.cloud_version = "isolated-ad-cadence-fixture"
	app.selected_track = track
	await app._start_race(track, false, true)
	check(is_instance_valid(app.game), "real app starts the isolated published-track fixture")
	if not is_instance_valid(app.game):
		app.free()
		return
	track.metadata.erase("cloud_version")
	app.game.set_physics_process(false)
	for index: int in range(3):
		if index > 0: await app._retry_race()
		app.game.set_physics_process(false)
		ads.hold = index == 2
		var panel: RaceResults = finish(app)
		var retry: Button = panel.find_child("RetryRace",true,false) as Button
		if index == 2: retry.grab_focus()
		app._results()
		for frame: int in range(3): await process_frame
		check(panel != null and panel.saved, "normal result saves before ad: %d" % index)
		if index < 2:
			check(ads.calls == 0 and app.race_ad_breaks.races == index + 1, "app counts one finish per attempt: %d" % index)
		else:
			check(ads.calls == 1 and app.race_ad_breaks.blocking, "third real app finish owns one interstitial")
			check(is_instance_valid(app._ad_input_blocker), "SDK handoff blocks result touch actions")
			check(root.gui_get_focus_owner() == app._ad_input_blocker, "SDK handoff owns keyboard focus")
			await capture("results-during-injected-ad.png")
			var game_id: int = app.game.get_instance_id()
			await app._retry_race()
			app._leave_race()
			app._results_continue(panel, panel.get_parent())
			check(app.game.get_instance_id() == game_id and panel.is_visible_in_tree(), "ad keeps retry, exit and Continue on the same result")
			ads.hold = false
			for frame: int in range(3): await process_frame
			check(not app.race_ad_breaks.due() and not app.race_ad_breaks.blocking and not is_instance_valid(app._ad_input_blocker), "dismissal restores results and resets both limits")
			check(root.gui_get_focus_owner() == retry, "dismissal restores previous result-button focus")
			await capture("results-after-injected-ad.png")
	await app._retry_race()
	app.game.set_physics_process(false)
	app.returning_to_editor = true
	finish(app)
	for frame: int in range(2): await process_frame
	check(app.race_ad_breaks.races == 0 and ads.calls == 1, "creator test finish is excluded")
	app.returning_to_editor = false
	await app._retry_race()
	app.game.set_physics_process(false)
	app.game.attempt_practice = true
	finish(app)
	for frame: int in range(2): await process_frame
	check(app.race_ad_breaks.races == 0 and ads.calls == 1, "practice finish is excluded")
	app.game.attempt_practice = false
	app.game.paused = false
	app.screen = "tracks"
	app._publishing_slots_foreground = true
	check(app._ad_play_active(), "ordinary foreground race contributes time")
	app.game.paused = true
	check(not app._ad_play_active(), "paused race and result screen exclude time")
	app.game.paused = false
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not app._ad_play_active(), "background race excludes time")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await app._retry_race()
	app.game.set_physics_process(false)
	app.game.attempt_practice = false
	app.race_ad_breaks.active_msec = Breaks.INTERVAL_MSEC
	for frame: int in range(2): await process_frame
	check(ads.calls == 1, "real app does not open elapsed-time ad in an unfinished race")
	finish(app)
	for frame: int in range(4): await process_frame
	check(ads.calls == 2 and not app.race_ad_breaks.due(), "ten-minute limit shows at next finish before the third race")
	app.race_ad_breaks.record_finish()
	app.race_ad_breaks.record_finish()
	app.race_ad_breaks.active_msec = 90000
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(app.race_ad_breaks.storage_path == directory.path_join("ad_cadence.json"), "real App uses its install-level cadence state outside account profiles")
	var saved_progress: Dictionary = preload("res://backend/atomic_json.gd").read(app.race_ad_breaks.storage_path,256)
	check(saved_progress.get("races",0) == 2 and saved_progress.get("active_msec",0) == 90000, "actual background notification commits both cumulative counters")
	root.remove_child(app)
	app.free()
	await process_frame
	app = AppScene.instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.set_process(false)
	check(app.race_ad_breaks.races == 2 and app.race_ad_breaks.active_msec == 90000, "real App relaunch restores both counters")
	check(app.race_ad_breaks.session_races == 0 and not app.race_ad_breaks.can_present(), "real App relaunch starts behind the first-race guard")
	ads = TestAds.new()
	app.race_ad_breaks.adapter.free()
	app.race_ad_breaks.add_child(ads)
	app.race_ad_breaks.adapter = ads
	app.race_ad_breaks.enabled = true
	track.metadata.cloud_version = "isolated-ad-cadence-fixture"
	app.selected_track = track
	await app._start_race(track,false,true)
	track.metadata.erase("cloud_version")
	app.game.set_physics_process(false)
	check(ads.calls == 0, "new session reaches its first race without an interstitial")
	finish(app)
	for frame: int in range(4): await process_frame
	check(ads.calls == 1 and not app.race_ad_breaks.due(), "new session first finish completes saved N-race interval")
	root.remove_child(app)
	app.free()
	await process_frame

func capture(filename: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_directory.path_join(filename)) == OK, "capture result presentation: " + filename)

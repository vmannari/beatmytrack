extends SceneTree
## Relaunches use the same tiny disk state and a fresh session eligibility gate.
const Breaks = preload("res://platform/race_ad_breaks.gd")
const Existing = preload("res://tests/test_race_ad_breaks.gd")
const Policy = preload("res://backend/game_config_policy.gd")
const Storage = preload("res://backend/atomic_json.gd")
var checks: int = 0
var failures: int = 0
var clock: int = 0
var directory: String

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: " + label)

func launch(name: String, settings: Dictionary = {}) -> Node:
	var controller := Breaks.new()
	controller.client = Existing.TestClient.new()
	controller.adapter = Existing.TestAds.new()
	controller.add_child(controller.client)
	controller.add_child(controller.adapter)
	controller.enabled = true
	controller.storage_path = directory.path_join(name+".json")
	controller.clock_msec = func() -> int: return clock
	if not settings.is_empty(): controller.set_policy(settings)
	root.add_child(controller)
	return controller

func run() -> void:
	directory = "user://cumulative-ad-" + TrackLibrary.unique_id()
	var first: Node = launch("races")
	first.observe_time(true)
	clock += 90000
	first.observe_time(false)
	first.record_finish()
	first.record_finish()
	check(first.flush_progress(), "first session saves its two races and active time")
	first.free()
	clock += 86400000
	var second: Node = launch("races")
	check(second.races == 2 and second.active_msec == 90000, "second session restores both cumulative counters without counting absence")
	check(second.session_races == 0 and second.session_msec == 0 and second.shown_count == 0, "session-local guard, delay and cap start fresh")
	second.observe_time(true)
	clock += 1000
	second.observe_time(false)
	second.record_finish()
	check(second.due() and second.session_races == 1, "one new finish completes three races across two sessions")
	check((await second.show_if_due(func() -> bool: return true)).shown, "cumulative race threshold shows after current session's first finish")
	check(second.session_races == 1, "show reset does not reinstate the first-race gate in the same session")
	second.free()
	var third: Node = launch("races")
	check(third.races == 0 and third.active_msec == 0 and not third.due(), "actual show reset survives another restart")
	third.free()
	var settings: Dictionary = Policy.DEFAULTS.duplicate(true)
	settings["ads.permitted"] = true
	settings["ads.interstitial_enabled"] = true
	settings["ads.races"] = 7
	settings["ads.active_seconds"] = 120
	first = launch("time",settings)
	first.observe_time(true)
	clock += 70000
	first.observe_time(false)
	first.free()
	second = launch("time",settings)
	second.observe_time(true)
	clock += 50000
	second.observe_time(false)
	check(second.active_msec == 120000 and second.due() and second.races == 0, "configured X minutes accumulate across launches before N races")
	check(not second.can_present(), "time-due carryover cannot bypass first race")
	check(not (await second.show_if_due(func() -> bool: return true)).shown and second.adapter.calls == 0 and second.client.reads == 0, "even an apparent break cannot show an ad before the first race")
	second.record_finish()
	second.adapter.shown = false
	check(not (await second.show_if_due(func() -> bool: return true)).shown, "no-fill does not fulfill the carried time threshold")
	second.free()
	third = launch("time",settings)
	check(third.races == 1 and third.active_msec == 120000 and third.due(), "no-fill leaves cumulative due counters on disk")
	check(not third.can_present() and not (await third.show_if_due(func() -> bool: return true)).shown, "already-due launch still requires a new session race")
	third.record_finish()
	check((await third.show_if_due(func() -> bool: return true)).shown, "first finish unlocks the saved time-due ad")
	third.free()
	settings["ads.trigger"] = "both"
	first = launch("both",settings)
	for race: int in range(6): first.record_finish()
	first.observe_time(true)
	clock += 120000
	first.observe_time(false)
	first.free()
	second = launch("both",settings)
	check(not second.due(), "optional AND policy still needs cumulative N races as well as time")
	second.record_finish()
	check(second.due() and (await second.show_if_due(func() -> bool: return true)).shown, "AND policy combines saved time and race progress without a reset")
	second.free()
	first = launch("periodic")
	first.observe_time(true)
	clock += Breaks.SAVE_INTERVAL_MSEC
	first.observe_time(true)
	for frame: int in range(12):
		await process_frame
		first.observe_time(true)
	check(Storage.read(first.storage_path,256).get("active_msec",0) == Breaks.SAVE_INTERVAL_MSEC, "periodic low-priority checkpoint commits while play continues")
	first.free()
	first = launch("coalesced")
	for race: int in range(12): first.record_finish()
	check(first.flush_progress(), "suspend joins pending writes and saves the latest race total")
	second = launch("coalesced")
	check(second.races == 12, "latest progress wins over an older asynchronous snapshot")
	second.free()
	first.free()
	for invalid: Variant in [{"schema":1,"races":-1,"active_msec":0},{"schema":1,"races":3,"active_msec":1.5},{"schema":1,"races":true,"active_msec":0},{"schema":2,"races":3,"active_msec":0},{"schema":1,"races":101,"active_msec":0}]:
		Storage.write(directory.path_join("invalid.json"),invalid,256)
		first = launch("invalid")
		check(first.races == 0 and first.active_msec == 0 and not first.can_present(), "invalid saved counters cannot create an early ad: " + str(invalid))
		first.free()
	var oversized := FileAccess.open(directory.path_join("invalid.json"),FileAccess.WRITE)
	oversized.store_string(" ".repeat(257))
	oversized.close()
	first = launch("invalid")
	check(not first.due() and not first.can_present(), "oversized state is bounded and starts behind the first-race guard")
	first.free()
	first = launch("failure")
	first.storage_path = directory
	first.record_finish()
	check(not first.flush_progress() and first.races == 1, "failed disk save retains the in-memory race count")
	first.storage_path = directory.path_join("recovered.json")
	check(first.flush_progress(), "save failure can recover to a writable path without losing progress")
	first.free()
	second = launch("recovered")
	check(second.races == 1 and second.session_races == 0, "recovered state remains cumulative and session guard remains new")
	second.free()
	print("CUMULATIVE_AD_CADENCE: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

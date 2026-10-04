extends SceneTree
var checks: int = 0
var failures: int = 0
const Credits = preload("res://platform/resume_credits.gd")
const Ads = preload("res://platform/admob_test_ads.gd")
const InputFrame = preload("res://input/drive_frame.gd")
# Match the shipping app's loading graph, including typed canonical inputs.
# Without it this standalone harness retains an indirect DriveFrame script.
const AppScene = preload("res://core/app.tscn")

class TestAds extends Node:
	var calls: int = 0
	var succeeds: bool = true
	var during_ad: Callable
	func show_rewarded() -> Dictionary:
		calls += 1
		await get_tree().process_frame
		if during_ad.is_valid(): during_ad.call()
		return {"ok":succeeds,"error":"Ad closed before completion."}

class TestClient extends Node:
	var player: Dictionary = {"id":"ad-test-player"}
	var balance: int = 0
	var daily: int = 0
	var consumptions: int = 0
	var fail_once: bool = false
	var wallet_failure: bool = false
	var begin_failure: bool = false
	var preview_available: bool = true
	var consume_keys: Array[String] = []
	func signed_in() -> bool: return not player.is_empty()
	func request_api(path: String, _method: int, _body: Dictionary, key: String, _auth: bool) -> Dictionary:
		await get_tree().process_frame
		if path == "/resumes":
			if wallet_failure: return {"ok":false,"error":"Unavailable"}
			return {"ok":true,"data":{"balance":balance,"free":daily,"ad_preview_available":preview_available}}
		if path == "/resume-races":
			if begin_failure:
				begin_failure = false
				return {"ok":false,"error":"Lost race response","status":0}
			return {"ok":true,"data":{"race_id":"test-race"}}
		consumptions += 1
		consume_keys.append(key)
		if fail_once:
			fail_once = false
			return {"ok":false,"error":"Lost response","status":0}
		return {"ok":true,"data":{"receipt_id":"test-receipt","wallet":{"balance":0,"free":0,"ad_preview_available":true}}}

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)

func run() -> void:
	var store := LocalRecords.new("user://admob-test-" + str(Time.get_ticks_usec()) + ".json")
	store.settings.development_show_ads = true
	check(store.save_records() == OK, "development bool commits through atomic records")
	var loaded := LocalRecords.new(store.path)
	loaded.load_records()
	check(loaded.settings.get("development_show_ads", false), "development bool survives reload")
	store.settings.development_show_ads = 1
	check(store.save_records() == ERR_INVALID_DATA and store.settings.development_show_ads == true, "invalid preference type is rejected and rolled back")
	var hidden := SettingsPage.new()
	hidden.records = loaded
	hidden.development_available = false
	root.add_child(hidden)
	check(not hidden.categories.has("development"), "release-style settings hide the development section")
	hidden._show_section("development")
	check(hidden.section == "controls", "hidden development cannot be selected")
	hidden.queue_free()
	await process_frame
	for label: String in ["off", "daily", "banked", "cancelled", "complete", "retry", "begin_retry", "account", "race", "unavailable", "disabled_backend"]:
		var client := TestClient.new()
		root.add_child(client)
		var credits := Credits.new()
		credits.client = client
		root.add_child(credits)
		credits.ad_adapter.queue_free()
		var ads := TestAds.new()
		credits.add_child(ads)
		credits.ad_adapter = ads
		credits.show_ads = label != "off"
		credits.begin()
		if label == "daily": client.daily = 1
		if label == "banked": client.balance = 2
		if label == "cancelled": ads.succeeds = false
		if label == "retry": client.fail_once = true
		if label == "account": ads.during_ad = func() -> void: client.player = {"id":"another-player"}
		if label == "race": ads.during_ad = func() -> void: credits.begin()
		if label == "unavailable": client.wallet_failure = true
		if label == "disabled_backend": client.preview_available = false
		if label == "begin_retry": client.begin_failure = true
		var result: Dictionary = await credits.consume(1200, 600, 1200)
		if label in ["cancelled", "account", "race", "unavailable", "disabled_backend"]:
			check(not result.ok and credits.used == 0 and client.consumptions == 0, label + " never authorizes or spends a resume")
		elif label == "retry":
			check(not result.ok and not credits.pending.is_empty() and credits.used == 0, "ambiguous result retains pending request")
			result = await credits.consume(1200, 600, 1200)
			check(result.ok and credits.used == 1 and ads.calls == 1, "retry resolves one resume without another ad")
			check(client.consume_keys[0] == client.consume_keys[1], "retry uses original idempotency key")
		elif label == "begin_retry":
			check(not result.ok and credits.pending.is_empty() and credits.used == 0, "lost race-start response spends no resume")
			result = await credits.consume(1200, 600, 1200)
			check(result.ok and credits.used == 1 and ads.calls == 1, "race-start retry reuses completed ad for the same selection")
		else:
			check(result.ok and credits.used == 1 and client.consumptions == 1, label + " authorizes exactly one resume")
		check(ads.calls == (0 if label in ["off", "daily", "banked", "unavailable", "disabled_backend"] else 1), label + " respects ad selection and resource order")
		credits.used = 3
		check(not (await credits.consume(1200, 600, 1200)).ok, "race cap remains enforced: " + label)
		credits.queue_free()
		client.queue_free()
		await process_frame
	var adapter := Ads.new()
	root.add_child(adapter)
	if not Ads.supported(): check(not (await adapter.show_rewarded()).ok, "unsupported SDK reports failure without a simulated ad")
	var deliveries: Array[int] = [0]
	adapter.finished.connect(func(_result: Dictionary) -> void: deliveries[0] += 1)
	adapter._request = "active"
	adapter._completed("stale", true, "")
	check(deliveries[0] == 0, "stale callbacks are ignored")
	adapter._completed("active", true, "")
	adapter._completed("active", true, "")
	check(deliveries[0] == 1, "duplicate completion is delivered once")
	adapter.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(store.path + suffix): DirAccess.remove_absolute(store.path + suffix)
	print("ADMOB_DEVELOPMENT_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

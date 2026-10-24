extends SceneTree
const Policy = preload("res://backend/game_config_policy.gd")
const Configuration = preload("res://backend/game_configuration.gd")
const Breaks = preload("res://platform/race_ad_breaks.gd")
const Telemetry = preload("res://backend/product_telemetry.gd")
var checks: int = 0
var failures: int = 0
var clock: int = 1000

class Client extends Node:
	var player: Dictionary = {"id":"11111111-1111-4111-8111-111111111111","analytics_enabled":true}
	var analytics: bool = true
	var hold: bool = false
	var calls: int = 0
	var response: Dictionary = {}
	var supported: bool = true
	func base_url() -> String: return "https://configuration-fixture.invalid"
	func signed_in() -> bool: return not player.is_empty()
	func telemetry_supported() -> bool: return analytics and signed_in()
	func test_drivers_available() -> bool: return false
	func game_configuration_supported() -> bool: return supported
	func server_now() -> int: return 1000
	func cancel_configuration() -> void: pass
	func request_configuration(_path: String, _assign: bool = false) -> Dictionary:
		calls += 1
		await get_tree().process_frame
		while hold: await get_tree().process_frame
		return response
	func request_api(_path: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		return {"ok":true,"data":{"publishing_slots":1,"ad_free":false,"ad_free_forever":false,"ad_free_until":0,"server_now":1000,"max_rewinds_per_race":3,"free_rewinds":false,"purchase_simulation":false,"store_available":false}}

class Observations extends Node:
	var values: Array[Dictionary] = []
	func observe(name: String, properties: Dictionary, _once: String = "") -> bool:
		values.append({"name":name,"properties":properties.duplicate(true)})
		return true

class Ads extends Node:
	var shown: bool = true
	var calls: int = 0
	func supported() -> bool: return true
	func prepare() -> void: pass
	func discard() -> void: pass
	func show_interstitial() -> Dictionary:
		calls += 1
		await get_tree().process_frame
		return {"shown":shown}

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)

func envelope() -> Dictionary:
	var policy: Dictionary = Policy.DEFAULTS.duplicate(true)
	policy["ads.permitted"] = true
	policy["ads.interstitial_enabled"] = true
	policy["ads.races"] = 4
	policy["notice.message"] = "Service notice"
	return {"schema_version":1,"generation":2,"control_revision":3,"server_now":1000,"expires_at":605800,
		"scope":"11111111-1111-4111-8111-111111111111","resolution_id":"a".repeat(64),"settings":policy,
		"assignments":[{"experiment_id":"22222222-2222-4222-8222-222222222222","variant":"control","revision":1,"layer":"ads","boundary":"race_result"}],"restrictions":[]}

func config_fixture() -> Node:
	var node := Configuration.new()
	node.client = Client.new()
	node.telemetry = Observations.new()
	node.add_child(node.client)
	node.add_child(node.telemetry)
	node.clock_msec = func() -> int: return clock
	node._allowed = false
	root.add_child(node)
	for child: Node in node.get_children():
		if child is Timer: child.stop()
	node._reset_scope()
	node.negotiated = true
	node._permission_until = clock+120000
	return node

func run() -> void:
	check(Policy.valid(Policy.DEFAULTS),"complete defaults validate")
	var packet: Dictionary = envelope()
	check(Policy.snapshot_valid(packet,packet.scope),"valid complete envelope")
	for mutation: Dictionary in [{"ads.races":true},{"ads.races":0},{"ads.races":101},{"ads.session_cap":0},{"store_order":["ad_free_month"]},{"ads.trigger":"random"}]:
		var invalid: Dictionary = Policy.DEFAULTS.duplicate(true)
		invalid.merge(mutation,true)
		check(not Policy.valid(invalid),"invalid group rejected: "+str(mutation))
	check(not Policy.snapshot_valid(packet,"other"),"account scope rejects old cache")
	var config: Node = config_fixture()
	config.pending = packet.duplicate(true)
	check(config.settings["ads.races"] == 3,"download has no activation side effect")
	config._allowed = true
	config.enter_menu()
	check(config.settings["notice.message"] == "Service notice" and config.settings["ads.races"] == 3,"menu boundary keeps ad group pending")
	check(config.telemetry.values.is_empty(),"menu/download is not ad exposure")
	config.menu_applied("tracks")
	config.at_result()
	check(config.settings["ads.races"] == 4,"ad group applies at result")
	check(config.permission("ads.interstitial_enabled"),"fresh emergency permission permits implemented policy")
	var exposed: int = 0
	for event: Dictionary in config.telemetry.values:
		if event.name == "experiment_exposed": exposed += 1
	check(exposed == 1,"one actual policy exposure")
	check(config.event_context("race_started").get("experiment_id","") == packet.assignments[0].experiment_id,"race observations reference the exposed ad variant")
	config.at_result()
	var repeated: int = 0
	for event: Dictionary in config.telemetry.values:
		if event.name == "experiment_exposed": repeated += 1
	check(repeated == exposed,"repeated boundaries deduplicate exposure")
	config.emergency = {"ads.permitted":false}
	check(not config.permission("ads.interstitial_enabled"),"emergency wins over variant")
	config.emergency = {}
	clock += 120001
	check(not config.permission("ads.interstitial_enabled"),"stale permission skips ads")
	config.client.response = {"ok":true,"data":{"revision":4,"restrictions":{},"valid_seconds":120}}
	config._allowed = false
	check(await config.rewarded_permission(),"explicit paused rewarded offer renews the emergency lease")
	check(config.client.calls == 1 and not config._allowed,"rewarded renewal sends one small read without enabling background transport")
	check(await config.rewarded_permission() and config.client.calls == 1,"fresh rewarded permission reuses its lease")
	clock += 120001
	await config.renew_result_permission()
	check(config.client.calls == 1,"ordinary driving cannot renew a result permission lease")
	config._allowed = true
	await config.renew_result_permission()
	check(config.permission("ads.interstitial_enabled") and config.client.calls == 2,"long-race result renews permission without changing the applied policy")
	config.client.player = {"id":"33333333-3333-4333-8333-333333333333"}
	check(not config.permission("ads.interstitial_enabled"),"account switch immediately fences old permission")
	config.enter_menu()
	check(config.snapshot.is_empty() and config.pending.is_empty(),"account switch clears private pending groups")
	config.free()
	config = config_fixture()
	config.client.supported = false
	config._permission_until = 0
	var cached: Dictionary = envelope()
	cached.assignments = []
	config._disk_cache = {"scope":config._identity().sha256_text(),"snapshot":cached}
	config._allowed = true
	config.pump()
	check(not config.pending.is_empty() and config.client.calls == 0,"compatible non-experiment cache restores without a config service")
	config.at_result(false)
	check(config.settings["ads.races"] == 4 and not config.permission("ads.interstitial_enabled"),"cached policy cannot renew advertising permission")
	config.free()
	config = config_fixture()
	config.client.response = {"ok":true,"data":envelope()}
	config.client.hold = true
	config._allowed = true
	config._refresh()
	await process_frame
	config.client.player = {"id":"44444444-4444-4444-8444-444444444444"}
	config.client.hold = false
	for frame: int in range(3): await process_frame
	check(config.pending.is_empty(),"late authenticated reply cannot cross account switch")
	config.free()
	var breaks := Breaks.new()
	breaks.client = Client.new()
	breaks.adapter = Ads.new()
	breaks.add_child(breaks.client)
	breaks.add_child(breaks.adapter)
	breaks.enabled = true
	breaks.clock_msec = func() -> int: return clock
	root.add_child(breaks)
	var policy: Dictionary = envelope().settings
	policy["ads.trigger"] = "both"
	policy["ads.active_seconds"] = 360
	policy["ads.first_delay_seconds"] = 360
	policy["ads.session_cap"] = 2
	breaks.set_policy(policy)
	breaks.record_finish()
	breaks.races = 4
	check(not breaks.due(),"AND policy requires time too")
	breaks.active_msec = 360000
	check(breaks.due() and not breaks.can_present(),"first delay is independent of due")
	breaks.session_msec = 360000
	check(breaks.can_present(),"all policy minima satisfied")
	breaks.adapter.shown = false
	await breaks.show_if_due(func() -> bool: return true)
	check(breaks.races == 4 and breaks.active_msec == 360000 and breaks.shown_count == 0,"no-fill retains due counters and cap")
	breaks.adapter.shown = true
	await breaks.show_if_due(func() -> bool: return true)
	check(breaks.races == 0 and breaks.active_msec == 0 and breaks.shown_count == 1,"actual show resets spacing once")
	policy["ads.races"] = 1
	policy["ads.active_seconds"] = 60
	policy["ads.trigger"] = "either"
	policy["ads.first_delay_seconds"] = 0
	policy["ads.rewarded_cooldown_seconds"] = 120
	breaks.set_policy(policy)
	breaks.races = 1
	breaks.rewarded_presented()
	check(breaks.due() and not breaks.can_present(),"rewarded presentation postpones automatic ad")
	breaks.observe_time(true)
	clock += 120000
	breaks.observe_time(false)
	await breaks.show_if_due(func() -> bool: return true)
	check(breaks.shown_count == 2,"rewarded cooldown expires on active time")
	breaks.races = 1
	check(not breaks.can_present(),"session cap prevents another automatic show")
	policy["ads.session_cap"] = 1
	breaks.set_policy(policy)
	check(breaks.shown_count == 2 and not breaks.can_present(),"policy change never resets consumed session cap")
	breaks.free()
	var telemetry := Telemetry.new()
	var properties: Dictionary = {"config_generation":2,"config_resolution":"a".repeat(64),"config_group":"ads"}
	check(telemetry._safe_properties("config_applied",properties) == properties,"existing bounded telemetry retains application context")
	check(telemetry._safe_properties("experiment_exposed",properties).is_empty(),"exposure requires assigned variant reference")
	telemetry.free()
	print("GAME_CONFIGURATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

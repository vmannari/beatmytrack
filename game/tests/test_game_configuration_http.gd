extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Configuration = preload("res://backend/game_configuration.gd")
const Telemetry = preload("res://backend/product_telemetry.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func run() -> void:
	var origin: String = OS.get_environment("BMT_CONFIG_TEST_ORIGIN")
	var secret: String = OS.get_environment("BMT_CONFIG_TEST_KEY")
	if not origin.begins_with("http://127.0.0.1:") or secret.length() < 32:
		print("Configuration HTTP fixture requires its owned loopback service.")
		quit(1)
		return
	var client := Client.new()
	root.add_child(client)
	client.configure(origin)
	var bootstrap: Dictionary = await client.request_api("/bootstrap")
	check(bootstrap.get("ok",false) and client.game_configuration_supported(),"bootstrap negotiates config capability")
	var login: Dictionary = await client.development_login("configuration-http-fixture","Configuration HTTP driver",secret)
	check(login.get("ok",false),"owned development account signs in")
	var preference: Dictionary = await client.request_api("/privacy/preferences",HTTPClient.METHOD_POST,{"analytics_enabled":true},"",true)
	check(preference.get("ok",false),"explicit fixture measurement consent")
	client.player.analytics_enabled = true
	client.analytics_opt_in = true
	var telemetry := Telemetry.new()
	telemetry.client = client
	telemetry.storage_path = "user://configuration-http-telemetry.json"
	root.add_child(telemetry)
	var configuration := Configuration.new()
	configuration.client = client
	configuration.telemetry = telemetry
	telemetry.configuration = configuration
	configuration.storage_path = "user://configuration-http-cache.json"
	configuration._allowed = false
	root.add_child(configuration)
	for child: Node in configuration.get_children():
		if child is Timer: child.stop()
	configuration._reset_scope()
	configuration.negotiated = true
	configuration._allowed = true
	await configuration._refresh_emergency()
	await configuration._refresh()
	check(not configuration.pending.is_empty(),"real adapter receives validated policy")
	check(configuration.pending.get("assignments",[]).size() == 1,"existing assignment POST commits an experimental variant")
	check(configuration.settings["ads.races"] == 3,"download leaves ad group pending")
	configuration.enter_menu()
	configuration.menu_applied("tracks")
	var expected_races: int = int(configuration.pending.settings["ads.races"])
	configuration.at_result(true)
	check(int(configuration.settings["ads.races"]) == expected_races,"result boundary applies assigned policy: "+str(expected_races))
	check(configuration.permission("ads.interstitial_enabled"),"fresh emergency read permits configured debug policy")
	configuration._permission_until = 0
	configuration._next_emergency = 0
	await configuration.renew_result_permission()
	check(configuration.permission("ads.interstitial_enabled"),"real HTTP result renewal restores an expired long-race lease")
	configuration.record_ad_decision("suppressed")
	telemetry.observe("menu_ready")
	telemetry.observe("race_started")
	var attributed: bool = false
	for entry: Dictionary in telemetry.queue:
		if entry.event.name == "race_started" and entry.event.properties.get("experiment_id","") == configuration.snapshot.assignments[0].experiment_id: attributed = true
	check(attributed,"ordinary product observations carry the applied policy and exposed variant")
	var exposures: int = 0
	for entry: Dictionary in telemetry.queue:
		if entry.event.name == "experiment_exposed": exposures += 1
	check(exposures == 1,"actual assigned-policy exposure enters the existing queue")
	var conditional: Dictionary = await client.request_configuration("/game-config"+configuration._query())
	check(conditional.get("ok",false) and conditional.get("not_modified",false),"private conditional fetch reuses validated body")
	check(int(conditional.get("data",{}).get("server_now",0)) > 0,"conditional response retains server freshness")
	for frame: int in range(120):
		telemetry.pump()
		await process_frame
		if telemetry._thread == null and telemetry._persisted_ids.size() == telemetry.queue.size(): break
	var payload: Dictionary = telemetry.batch_payload()
	check(not payload.get("events",[]).is_empty(),"observations persist before upload")
	var accepted: Dictionary = await client.request_telemetry(payload)
	check(accepted.get("ok",false),"real bounded telemetry endpoint accepts configuration observations")
	client.analytics_opt_in = false
	configuration.enter_menu()
	check(configuration.snapshot.is_empty() and not configuration.permission("ads.interstitial_enabled"),"measurement opt-out immediately clears cached experiment")
	await configuration._refresh()
	check(configuration.pending.get("assignments",[]).is_empty(),"opted-out request receives baseline without re-enrollment")
	configuration.queue_free()
	telemetry.queue_free()
	client.queue_free()
	await process_frame
	await process_frame
	print("GAME_CONFIGURATION_HTTP: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

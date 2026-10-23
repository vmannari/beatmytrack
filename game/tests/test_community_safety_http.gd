extends SceneTree
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: print("FAIL: safety HTTP deadline"); quit(1))
	var client := Client.new()
	root.add_child(client)
	client.resume_recovery.set_process(false)
	client.configure(OS.get_environment("BMT_API_URL"))
	check((await client.request_api("/bootstrap")).ok,"real backend bootstrap")
	check((await client.development_login("safety-http-racer","Safety HTTP racer",OS.get_environment("BMT_DEV_AUTH_KEY"))).ok,"real account session")
	var terms: Dictionary = await client.safety.terms()
	check(terms.ok and not terms.data.get("accepted",true) and str(terms.data.get("text","")).contains("No sexual content"),"full rules and fresh acceptance state cross HTTP")
	if not terms.ok:
		print("TERMS_FAILURE: ",terms.error)
		quit(1)
		return
	check((await client.request_api("/community/terms",HTTPClient.METHOD_POST,{"version":terms.data.version,"accepted":true},"",true)).ok,"explicit acceptance crosses HTTP")
	check((await client.safety.terms()).data.accepted,"acceptance is persisted by backend")
	var author: String = OS.get_environment("BMT_SAFETY_AUTHOR")
	var version: String = OS.get_environment("BMT_SAFETY_VERSION")
	var track: String = OS.get_environment("BMT_SAFETY_TRACK")
	var before: Dictionary = await client.request_discovery({"feed":"new"},get_instance_id())
	check(before.ok and before.data.total == null and before.data.items.size() == 1,"published track is initially visible through v3")
	check((await client.safety.set_block(author,"Safety fixture author",true)).ok,"real private block receipt")
	var after: Dictionary = await client.request_discovery({"feed":"new"},get_instance_id())
	check(after.ok and after.data.items.is_empty(),"authenticated discovery hides blocked author's track")
	var direct: Dictionary = await client.request_api("/track-versions/"+version+"/document")
	check(not direct.ok and int(direct.status) == 403,"authenticated direct download honors block")
	var report: Dictionary = await client.safety.report({"reason":"harassment","text":"Public fixture report", "track_id":track,"version_id":version,"reported_player_id":author})
	check(report.ok and report.data.status == "open","blocked content remains reportable through actual wire contract")
	var reports: Dictionary = await client.request_api("/reports",HTTPClient.METHOD_GET,{},"",true)
	check(reports.ok and reports.data.items.size() == 1 and reports.data.items[0].id == report.data.id,"private report status is readable in game")
	check((await client.safety.set_block(author,"Safety fixture author",false)).ok,"real unblock receipt")
	check((await client.request_discovery({"feed":"new"},get_instance_id())).data.items.size() == 1,"unblocked content returns")
	client.queue_free()
	await process_frame
	print("COMMUNITY_HTTP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

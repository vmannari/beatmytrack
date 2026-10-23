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
	create_timer(45).timeout.connect(func() -> void: print("FAIL: News HTTP deadline"); quit(1))
	var client := Client.new()
	root.add_child(client)
	client.resume_recovery.set_process(false)
	client.configure(OS.get_environment("BMT_API_URL"))
	check((await client.request_api("/bootstrap")).ok,"real bootstrap")
	check(int(client._capabilities.get("garage_news_version",0)) == 1,"News capability negotiated")
	check((await client.development_login("news-wire-Alice","News wire Alice",OS.get_environment("BMT_DEV_AUTH_KEY"))).ok,"real session")
	await client.news.refresh()
	var publication: bool = OS.get_environment("BMT_NEWS_PUBLICATION") == "1"
	check(client.news.error.is_empty() and client.news.items.size() == (2 if publication else 1),"private News crosses actual wire")
	if client.news.items.is_empty(): quit(1); return
	var milestones: Array = client.news.items.filter(func(item: Dictionary) -> bool: return item.kind == "milestone")
	check(milestones.size() == 1 and int(milestones[0].count) == 1000,"milestone value survives native JSON parsing")
	check(client.news.items[0].track_points == JSON.parse_string("[[0,0],[20,0],[20,20],[0,20]]"),"real version outline survives deduplicated wire payload")
	if publication:
		var published: Array = client.news.items.filter(func(item: Dictionary) -> bool: return item.kind == "friend_track")
		check(published.size() == 1 and published[0].actor_name == "News wire Bob" and published[0].track_name == "Bob's fresh circuit","friend publication crosses the real feed wire")
		check(published.size() == 1 and published[0].track_points.size() == 4,"friend publication carries its own circuit")
	await client.news.load_friends()
	check(client.news.friends.size() == 1 and client.news.friends[0].status == ("friends" if publication else "received"),"actual friendship state crosses wire")
	await client.news.friend_action("accept",OS.get_environment("BMT_NEWS_BOB"))
	check(client.news.error.is_empty() and client.news.friends[0].status == "friends","native friend acceptance persists")
	await client.news.friend_action("remove",OS.get_environment("BMT_NEWS_BOB"))
	check(client.news.error.is_empty() and client.news.friends.is_empty(),"native friend removal persists")
	if publication: check(client.news.items.size() == 1 and client.news.items[0].kind == "milestone","unfriending immediately removes cached publication")
	client.player = {}
	client._access_token = ""
	client.identity_changed.emit()
	check(client.news.items.is_empty() and client.news.friends.is_empty(),"identity switch clears private feed")
	check(not client.news.available(),"guest cannot request news")
	client.queue_free()
	await process_frame
	print("NEWS_HTTP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

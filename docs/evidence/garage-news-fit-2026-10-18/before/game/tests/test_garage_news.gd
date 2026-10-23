extends SceneTree
const News = preload("res://backend/news_client.gd")
const Menu = preload("res://ui/garage_news_menu.gd")
var checks: int = 0
var failures: int = 0

class Backend extends Node:
	var safety: Node
	var player: Dictionary = {"id":"alice"}
	var _capabilities: Dictionary = {"garage_news_version":1}
	var calls: Array[String] = []
	var origin: String = "https://fixture.invalid"
	var signed: bool = true
	var delay_reply: bool = false
	var remote_items: Array = []
	var remote_friends: Array = [{"player_id":"bob","display_name":"Bob","status":"received"}]
	func signed_in() -> bool: return signed
	func base_url() -> String: return origin
	func server_now() -> int: return 1792152000
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		calls.append(str(method)+" "+path)
		while delay_reply: await get_tree().process_frame
		await get_tree().process_frame
		var data: Dictionary = {"items":remote_items.duplicate(true),"next_cursor":"","refreshing":false,"checked_day":server_now()/86400}
		if path == "/news/refresh": data = {"refreshing":false,"checked_day":server_now()/86400}
		elif path == "/news/friends": data = {"items":remote_friends.duplicate(true)}
		elif path.begins_with("/news/friends/"):
			remote_friends = [] if method == HTTPClient.METHOD_DELETE else [{"player_id":"bob","display_name":"Bob","status":"friends"}]
			data = {"status":"friends"}
		return {"ok":true,"status":200,"error":"","data":data}

class Blocks extends Node:
	var blocked: Dictionary = {}
	func is_blocked(id: String) -> bool: return blocked.has(id)

class Pane extends Control:
	signal account_requested
	signal news_race_requested(story: Dictionary)
	var section: String = "news"
	var tools: VBoxContainer
	func _ready() -> void:
		tools = VBoxContainer.new()
		add_child(tools)
		MenuStyle.fill(tools)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func frames(count: int = 3) -> void:
	for tick: int in range(count): await process_frame

func run() -> void:
	var backend := Backend.new()
	root.add_child(backend)
	backend.remote_items = [
		{"id":"one","kind":"milestone","count":1000,"track_name":"Underpass","created_at":1792152000},
		{"id":"two","kind":"world_record","metric":"lap","actor_name":"Bob","time_ticks":15223,"tick_rate":120,"vehicle_id":"compact","track_name":"Underpass","created_at":1792152000},
		{"id":"three","kind":"friend_overtake","metric":"race","actor_name":"Bob","time_ticks":75223,"tick_rate":120,"vehicle_id":"compact","track_name":"Dust cloud","created_at":1792152000},
		{"id":"four","kind":"percentile_drop","metric":"lap","threshold":5,"current_band":10,"vehicle_id":"compact","track_name":"Blind spot","created_at":1792152000}]
	for item: Dictionary in backend.remote_items: item.version_id = "11111111-2222-4333-8444-555555555555"
	var news := News.new()
	news.client = backend
	root.add_child(news)
	news.identity_changed()
	await frames()
	check(backend.calls.is_empty(),"idle client makes no reads")
	await news.refresh()
	check(backend.calls.size() == 2 and news.items.size() == 4,"explicit entry requests work and reads page")
	await news.refresh()
	check(backend.calls.size() == 2,"repeat entry shares scoped sixty-second cache")
	await news.load_friends()
	check(news.friends.size() == 1,"friends fetched only on explicit request")
	await news.friend_action("accept","bob")
	check(news.friends[0].status == "friends","accept refreshes actual friend list")
	var pane := Pane.new()
	pane.theme = MenuStyle.theme()
	pane.position = Vector2(20,20)
	pane.size = Vector2(920,580)
	root.add_child(pane)
	var menu := Menu.new()
	menu.page = pane
	menu.service = news
	pane.tools.add_child(menu)
	await frames(8)
	check(menu.find_child("LeadStory",true,false) != null and menu.find_child("NewsBrief3",true,false) != null,"front page has a lead and three selectable briefs")
	check(menu.get_combined_minimum_size().x <= 740,"newspaper fits the expanded Garage desk")
	var before_browse: int = backend.calls.size()
	menu._choose(1)
	await frames(4)
	check(menu.find_child("NewsCarPhoto",true,false) != null and menu._index() == 1,"selected record has its relevant native vehicle photograph")
	check(backend.calls.size() == before_browse,"reading another cached story makes no request")
	news.items.append({"id":"publication","kind":"friend_track","actor_id":"bob","actor_name":"Bob","track_name":"Bob's circuit","version_id":"11111111-2222-4333-8444-555555555555","track_points":[[0,0],[10,0],[10,20]]})
	menu._choose(4)
	await frames(4)
	check(menu.find_child("NewsCircuit",true,false).points.size() == 3 and menu.find_child("NewsCarPhoto",true,false) == null,"friend publication uses the published circuit outline")
	check(menu._category(news.items[4]) == "NEW CIRCUIT" and menu._headline(news.items[4]).contains("Bob"),"friend publication gets a named newspaper headline")
	check(backend.calls.size() == before_browse,"reading a friend's publication creates no request")
	var requested: Array = []
	pane.news_race_requested.connect(func(story: Dictionary) -> void: requested.append(story))
	var race_button: Button = menu.find_child("GarageNewsRace",true,false)
	check(race_button != null and not race_button.disabled,"friend publication offers Race track")
	race_button.pressed.emit()
	check(requested.size() == 1 and requested[0] == news.items[4],"Race track emits the exact published story")
	requested[0].track_name = "Changed copy"
	check(news.items[4].track_name == "Bob's circuit","race request cannot mutate the cached story")
	for index: int in range(news.items.size()):
		menu._choose(index)
		var action: Button = menu.find_child("GarageNewsRace",true,false)
		check(action != null and not action.disabled,"track-related "+str(news.items[index].kind)+" offers racing")
		if action != null:
			action.pressed.emit()
			check(requested.back() == news.items[index],"race action keeps the exact "+str(news.items[index].kind)+" story and version")
	check(backend.calls.size() == before_browse,"all story actions emit without eager track reads")
	requested.resize(1)
	news.items.append({"id":"no-track","kind":"paddock"})
	menu._choose(5)
	check(menu.find_child("GarageNewsRace",true,false) == null,"story without a track has no race action")
	menu._race_story(news.items.back())
	check(requested.size() == 1,"trackless stories cannot emit a race request")
	news.items.pop_back()
	var old_story: Dictionary = news.items[4].duplicate(true)
	menu._select_tab("friends")
	await frames(5)
	check(menu._add_row.visible and menu._list.get_child_count() == 3,"Friends directory and exact-name entry render")
	await news.friend_action("remove","bob")
	check(news.items.size() == 4 and news._fetched_at == -60001,"unfriending removes cached publications immediately and invalidates feed cache")
	menu._race_story(old_story)
	check(requested.size() == 1,"departed or removed publication cannot launch from a queued click")
	backend.remote_friends = [{"player_id":"bob","display_name":"Bob","status":"received"}]
	backend.origin = "https://second-fixture.invalid"
	news.identity_changed()
	backend.delay_reply = true
	menu._select_tab("news")
	await frames()
	menu._select_tab("friends")
	check(menu._waiting,"tab switch queues one read behind the current request")
	backend.delay_reply = false
	await frames(12)
	check(news.friends.size() == 1 and not menu._waiting,"queued Friends read finishes after News")
	var count: int = backend.calls.size()
	pane.section = "care"
	await menu._open()
	await menu._poll_once()
	check(backend.calls.size() == count,"departing pane cannot read or poll")
	pane.section = "news"
	pane.hide()
	await menu._open()
	check(backend.calls.size() == count,"hidden pane cannot read")
	backend.delay_reply = true
	news._fetched_at = -60001
	news.refresh()
	await frames()
	backend.player = {"id":"carol"}
	news.identity_changed()
	backend.delay_reply = false
	await frames(5)
	check(news.items.is_empty() and news.friends.is_empty(),"account change discards cached and in-flight data")
	backend._capabilities.clear()
	count = backend.calls.size()
	await news.refresh()
	check(backend.calls.size() == count,"older server uses no unsupported endpoints")
	backend._capabilities = {"garage_news_version":1}
	backend.signed = false
	await news.refresh()
	check(backend.calls.size() == count,"guest News makes no requests")
	backend.safety = Blocks.new()
	root.add_child(backend.safety)
	backend.safety.blocked = {"bob":true,"author":true}
	news.items = [{"actor_id":"bob"},{"creator_id":"author"}]
	news.friends = [{"player_id":"bob"}]
	news.blocks_changed()
	check(news.items.is_empty() and news.friends.is_empty(),"cached blocked actors and creators disappear immediately")
	check(backend.calls.size() == count,"block filtering makes no background reads")
	pane.show()
	menu._select_tab("news")
	await frames(5)
	check(menu._using_examples() and menu._stories().size() == 5,"guest newspaper shows the local stories")
	menu._choose(0)
	check(not menu.find_child("GarageNewsRace",true,false).disabled,"local publication also offers racing")
	menu._race_story(old_story)
	check(requested.size() == 1,"stale account story cannot launch from the local edition")
	check(menu._folio.text.begins_with("STORY ") and menu.find_child("LeadStory",true,false) != null,"local stories use the ordinary newspaper")
	for index: int in range(menu._stories().size()):
		menu._choose(index)
		await frames(2)
		var action: Button = menu.find_child("GarageNewsRace",true,false)
		check(action != null and not action.disabled,"local "+str(menu._stories()[index].kind)+" offers racing")
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+("dust_cloud" if menu._stories()[index].track_name == "Dust cloud" else "underpass")+".json"))
		check(menu._stories()[index].authoring_id == fixture.id,"local story resolves its actual authored track")
	check(backend.calls.size() == count and news.items.is_empty(),"browsing local stories makes no requests and never fills account data")
	backend.signed = true
	backend._capabilities.clear()
	news.changed.emit()
	check(menu._using_examples() and menu.find_child("LeadStory",true,false) != null,"older server also shows normal local stories")
	backend._capabilities = {"garage_news_version":1}
	news.items = backend.remote_items.duplicate(true)
	news.changed.emit()
	check(not menu._using_examples() and menu._stories() == news.items,"actual news automatically replaces local stories")
	news.items.clear()
	news.changed.emit()
	check(menu._using_examples() and backend.calls.size() == count,"empty actual feed falls back locally without new work")
	backend.safety.queue_free()
	pane.queue_free()
	news.queue_free()
	backend.queue_free()
	await frames()
	print("GARAGE NEWS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

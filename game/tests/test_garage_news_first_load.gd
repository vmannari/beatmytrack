extends SceneTree
## Initial account reads must not print and mark a fallback story first.
const Fixture = preload("res://tests/test_garage_news.gd")
const News = preload("res://backend/news_client.gd")
const Menu = preload("res://ui/garage_news_menu.gd")
var checks: int = 0
var failures: int = 0

class Backend extends Fixture.Backend:
	var fail_feed: bool = false
	var refresh_pending: bool = false
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, body: Dictionary = {}, key: String = "", auth: bool = false) -> Dictionary:
		var response: Dictionary = await super.request_api(path,method,body,key,auth)
		if path == "/news" and fail_feed: return {"ok":false,"error":"UNAVAILABLE"}
		if path == "/news" or path == "/news/refresh": response.data.refreshing = refresh_pending
		return response

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func frames(count: int = 8) -> void:
	for tick: int in range(count): await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path("res://../build/news-first-load-20261114/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	root.size = Vector2i(1280,720)
	var backend := Backend.new()
	backend.delay_reply = true
	backend.remote_items = [{"id":"actual-lead","kind":"milestone","count":2400,"track_name":"Underpass","created_at":1792152000}]
	root.add_child(backend)
	var news := News.new()
	news.client = backend
	news.read_state_path = "user://news-first-load.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(news.read_state_path))
	root.add_child(news)
	news.identity_changed()
	var pane := Fixture.Pane.new()
	pane.theme = MenuStyle.theme()
	root.add_child(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu := Menu.new()
	menu.page = pane
	menu.service = news
	pane.tools.add_child(menu)
	check(menu._stories().is_empty() and menu.find_child("LeadStory",true,false) == null,"no fallback prints before the deferred first request")
	await frames()
	check(news.busy and backend.calls.size() == 1,"opening starts exactly one account read")
	check(menu._stories().is_empty() and menu._selected_id.is_empty(),"delayed first response keeps the edition pending")
	check(menu._previous.disabled and menu._next.disabled,"pending edition cannot browse stories")
	check(not news.story_read(str(Menu.Examples.stories()[0].id),true),"unseen fallback is not marked read")
	await capture("pending")
	backend.delay_refresh = true
	backend.delay_reply = false
	await frames()
	check(menu._selected_id == "actual-lead" and not menu._using_examples(),"the first printed story is the actual account lead")
	check(news.busy and menu.find_child("LeadStory",true,false) != null,"actual stories render while the daily request is delayed")
	await capture("ready")
	backend.delay_refresh = false
	await frames()
	news.items.push_front({"id":"newer-story","kind":"milestone","count":2500,"track_name":"Underpass","created_at":1792152100})
	news.changed.emit()
	check(menu._selected_id == "actual-lead" and menu._index() == 1,"later feed updates retain the displayed story")
	backend.player.id = "empty-account"
	backend.remote_items = []
	backend.delay_reply = true
	news.identity_changed()
	menu._open()
	await frames()
	check(menu._stories().is_empty() and menu.find_child("LeadStory",true,false) == null,"another account waits for its own first response")
	backend.delay_reply = false
	backend.refresh_pending = true
	await frames()
	check(menu._stories().is_empty() and news.refreshing,"an empty initial feed waits while the daily edition is still being generated")
	backend.refresh_pending = false
	await menu._poll_once()
	check(menu._using_examples() and menu.find_child("LeadStory",true,false) != null,"a confirmed empty edition shows ordinary local stories")
	var calls: int = backend.calls.size()
	menu._render()
	check(menu._using_examples() and backend.calls.size() == calls,"confirmed empty edition stays readable without another read")
	backend.player.id = "failed-account"
	backend.fail_feed = true
	news.identity_changed()
	await menu._open()
	check(menu._using_examples() and not news.error.is_empty(),"failed first read releases fallback stories with the existing error")
	backend.player.id = "old-account"
	backend.fail_feed = false
	backend.delay_reply = true
	backend.remote_items = [{"id":"old-account-story","kind":"milestone","count":1000}]
	news.identity_changed()
	menu._open()
	await frames()
	backend.player.id = "new-account"
	news.identity_changed()
	backend.delay_reply = false
	await frames()
	check(news.items.is_empty() and menu._stories().is_empty(),"late old-account response cannot settle the new edition")
	backend.remote_items = [{"id":"cached-story","kind":"milestone","count":1000}]
	await menu._open()
	backend.delay_reply = true
	news._fetched_at = -60001
	menu._open()
	await frames()
	check(news.busy and menu._selected_id == "cached-story" and menu.find_child("LeadStory",true,false) != null,"cached account story remains visible during a delayed refresh")
	pane.hide()
	backend.delay_reply = false
	await frames()
	pane.show()
	backend.signed = false
	news.changed.emit()
	check(menu._using_examples() and menu.find_child("LeadStory",true,false) != null,"guest edition shows local stories immediately")
	backend.signed = true
	backend._capabilities.clear()
	news.changed.emit()
	check(menu._using_examples(),"unsupported server shows local stories immediately")
	menu._poll.stop()
	pane.queue_free()
	news.queue_free()
	backend.queue_free()
	await frames()
	print("NEWS FIRST LOAD: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends SceneTree

const Fixture = preload("res://tests/test_garage_news.gd")
const News = preload("res://backend/news_client.gd")
const Menu = preload("res://ui/garage_news_menu.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle(menu: Control) -> void:
	for tick: int in range(12): await process_frame
	while menu._story_motion != null: await process_frame
	for tick: int in range(6): await process_frame

func brief_names(menu: Control) -> Array[String]:
	var names: Array[String] = []
	for child: Node in menu.find_child("OtherStoriesList",true,false).get_children():
		if child is Button and child.name.begins_with("NewsBrief"): names.append(child.name)
	return names

func run() -> void:
	root.size = Vector2i(1280,720)
	var backend := Fixture.Backend.new()
	root.add_child(backend)
	var news := News.new()
	news.client = backend
	news.read_state_path = "user://news-scroll-test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(news.read_state_path))
	root.add_child(news)
	news.identity_changed()
	news.checked_day = backend.server_now()/86400
	news._fetched_at = Time.get_ticks_msec()
	for index: int in range(12):
		news.items.append({"id":"story-%d" % index,"kind":"milestone","count":1000,"track_name":"Underpass","created_at":1792152000-index})
	var pane := Fixture.Pane.new()
	pane.theme = MenuStyle.theme()
	root.add_child(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu := Menu.new()
	menu.page = pane
	menu.service = news
	pane.tools.add_child(menu)
	await settle(menu)
	check(news.story_read("story-0"),"opening the lead marks it read")
	check(brief_names(menu).size() == 11,"all other loaded stories appear in the side list")
	var scroll: ScrollContainer = menu.find_child("OtherStoriesScroll",true,false)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = dimensions
		await settle(menu)
		scroll = menu.find_child("OtherStoriesScroll",true,false)
		scroll.scroll_vertical = 0
		await settle(menu)
		var list: VBoxContainer = menu.find_child("OtherStoriesList",true,false)
		var buttons: Array[Node] = list.find_children("NewsBrief*","Button",false,false)
		var bounds: Rect2 = scroll.get_global_rect()
		for index: int in range(5):
			check(bounds.encloses((buttons[index] as Control).get_global_rect()),"headline %d fits the five-row viewport at %s" % [index+1,str(dimensions)])
		check((buttons[5] as Control).get_global_rect().position.y >= bounds.end.y-0.1,"sixth headline starts below the viewport at "+str(dimensions))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var output: String = ProjectSettings.globalize_path("res://../build/news-five-rows/"+RenderingServer.get_current_rendering_method())
			DirAccess.make_dir_recursive_absolute(output)
			check(root.get_texture().get_image().save_png(output.path_join("headlines-%d.png" % dimensions.x)) == OK,"capture five headline rows")
	root.size = Vector2i(1280,720)
	await settle(menu)
	scroll = menu.find_child("OtherStoriesScroll",true,false)
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,"the side list has a scrollable overflow")
	var wheel := InputEventMouseButton.new()
	wheel.position = scroll.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel,true)
	wheel = wheel.duplicate()
	wheel.pressed = false
	root.push_input(wheel,true)
	await settle(menu)
	check(scroll.scroll_vertical > 0,"mouse wheel scrolls the side list")
	scroll.scroll_vertical = 0
	var start: Vector2 = scroll.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = start
	touch.pressed = true
	root.push_input(touch,true)
	for step: int in range(1,5):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = start+Vector2(0,-25*step)
		drag.relative = Vector2(0,-25)
		root.push_input(drag,true)
		await process_frame
	touch = touch.duplicate()
	touch.position = start+Vector2(0,-100)
	touch.pressed = false
	root.push_input(touch,true)
	await settle(menu)
	check(scroll.scroll_vertical > 0,"touch dragging scrolls the side list")
	check(menu._selected_id == "story-0","scrolling does not open a story")
	var target: Button = menu.find_child("NewsBrief8",true,false)
	scroll.ensure_control_visible(target)
	await settle(menu)
	var move := InputEventMouseMotion.new()
	move.position = target.get_global_rect().get_center()
	move.global_position = move.position
	root.push_input(move,true)
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = target.get_global_rect().get_center()
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	root.push_input(click,true)
	await settle(menu)
	check(news.story_read("story-8") and menu._selected_id == "story-8","clicking a scrolled story marks it read and keeps it selected")
	var names: Array[String] = brief_names(menu)
	check(names[0] == "NewsBrief1" and names.back() == "NewsBrief0","unread stories precede previously read stories")
	check(news.items[0].id == "story-0" and news.items[8].id == "story-8","sorting the side list does not reorder the feed")
	scroll = menu.find_child("OtherStoriesScroll",true,false)
	scroll.scroll_vertical = 20
	news.changed.emit()
	await settle(menu)
	scroll = menu.find_child("OtherStoriesScroll",true,false)
	check(scroll.scroll_vertical == 20,"refreshing the feed keeps the side list's scroll position")
	target = menu.find_child("NewsBrief9",true,false)
	scroll.ensure_control_visible(target)
	await settle(menu)
	touch = InputEventScreenTouch.new()
	touch.position = target.get_global_rect().get_center()
	touch.index = 1
	touch.pressed = true
	root.push_input(touch,true)
	touch = touch.duplicate()
	touch.pressed = false
	root.push_input(touch,true)
	await settle(menu)
	check(menu._selected_id == "story-9" and news.story_read("story-9"),"touching a scrolled story opens it")
	var restored := News.new()
	restored.client = backend
	restored.read_state_path = news.read_state_path
	check(restored.story_read("story-0") and restored.story_read("story-8"),"read markers survive a client restart")
	backend.player.id = "another-player"
	check(not restored.story_read("story-8"),"read markers are isolated by account")
	backend.player.id = "alice"
	check(restored.story_read("story-8"),"returning to the first account restores its markers")
	check(not restored.story_read("story-8",true),"example stories have their own read state")
	backend.origin = "https://other.invalid"
	check(not restored.story_read("story-8"),"read markers are isolated by server")
	backend.origin = "https://fixture.invalid"
	news.next_cursor = "older"
	menu._render()
	await settle(menu)
	check(backend.calls.is_empty(),"browsing cached stories makes no network requests")
	var more: Button = menu.find_child("NewsLoadOlder",true,false)
	check(more != null,"older pages have an explicit load action")
	scroll = menu.find_child("OtherStoriesScroll",true,false)
	scroll.ensure_control_visible(more)
	await settle(menu)
	var before_more: int = scroll.scroll_vertical
	backend.remote_items = [{"id":"older-story","kind":"milestone","count":1000,"track_name":"Underpass","created_at":1792150000}]
	more.pressed.emit()
	await settle(menu)
	check(news.items.any(func(item: Dictionary) -> bool: return item.id == "older-story"),"load older retrieves the next feed page")
	check(backend.calls.size() == 1 and backend.calls[0].contains("cursor=older"),"only the explicit older action requests the next page")
	check(menu.find_child("NewsLoadOlder",true,false) == null,"the older action disappears at the end of the feed")
	check(not news.story_read("older-story"),"loading a story does not mark it read")
	var loaded_scroll: ScrollContainer = menu.find_child("OtherStoriesScroll",true,false)
	var max_scroll: int = maxi(0,roundi(loaded_scroll.get_v_scroll_bar().max_value-loaded_scroll.get_v_scroll_bar().page))
	check(loaded_scroll.scroll_vertical == mini(before_more,max_scroll),"loading a page retains the side list position within its new bounds")
	var state_path: String = news.read_state_path
	restored.free()
	pane.queue_free()
	news.queue_free()
	backend.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state_path))
	print("NEWS SCROLL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends SceneTree

const Fixture = preload("res://tests/test_garage_news.gd")
const News = preload("res://backend/news_client.gd")
const Menu = preload("res://ui/garage_news_menu.gd")
var checks: int = 0
var failures: int = 0

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
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(1280,720)
	var backend := Fixture.Backend.new()
	root.add_child(backend)
	var news := News.new()
	news.client = backend
	news.read_state_path = "user://news-time-test.cfg"
	root.add_child(news)
	news.identity_changed()
	news.checked_day = backend.server_now()/86400
	news._fetched_at = Time.get_ticks_msec()
	news.items = [
		{"id":"record","kind":"world_record","actor_name":"Bob","vehicle_id":"compact","track_name":"Underpass","metric":"race","time_ticks":95450,"tick_rate":1000,"version_id":"11111111-2222-4333-8444-555555555555","track_points":[[0,0],[20,0],[10,20]]},
		{"id":"lap","kind":"friend_overtake","actor_name":"Bob","vehicle_id":"compact","track_name":"Underpass","metric":"lap","time_ticks":31400,"your_ticks":32000,"tick_rate":1000,"version_id":"11111111-2222-4333-8444-555555555555","track_points":[[0,0],[20,0],[10,20]]}]
	var pane := Fixture.Pane.new()
	pane.theme = MenuStyle.theme()
	root.add_child(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu := Menu.new()
	menu.page = pane
	menu.service = news
	pane.tools.add_child(menu)
	await settle(menu)
	var output: String = ProjectSettings.globalize_path("res://../build/news-time-style/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = dimensions
		await settle(menu)
		for index: int in range(2):
			menu._choose(index)
			await settle(menu)
			var time: Label = menu.find_child("NewsRecordTime",true,false)
			var metric: Label = menu.find_child("NewsRecordMetric",true,false)
			var group: Control = menu.find_child("NewsResult",true,false)
			var map_column: Control = menu.find_child("NewsMapColumn",true,false)
			check(time.text == ("1:35.450" if index == 0 else "0:31.400") and metric.text == ("TRACK" if index == 0 else "LAP"),"time and metric match the selected story at "+str(dimensions))
			check(map_column.get_global_rect().encloses(group.get_global_rect()),"complete time fits below the circuit at "+str(dimensions))
			check(menu._scroll.get_global_rect().encloses(group.get_global_rect()) and menu._scroll.get_global_rect().encloses(menu.find_child("GarageNewsRace",true,false).get_global_rect()),"time and race action remain visible at "+str(dimensions))
			check(time.get_theme_color("font_color") == Menu.INK and metric.get_theme_color("font_color") == Menu.RED,"time uses newspaper ink with a restrained metric accent")
			if DisplayServer.get_name() != "headless":
				check(root.get_texture().get_image().save_png(output.path_join("%s-%d.png" % ["track" if index == 0 else "lap",dimensions.x])) == OK,"capture result")
	check(backend.calls.is_empty(),"reading the displayed times adds no network requests")
	pane.queue_free()
	news.queue_free()
	backend.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://news-time-test.cfg"))
	print("NEWS TIME: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

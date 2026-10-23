extends SceneTree
const Fixture = preload("res://tests/test_garage_news.gd")
const News = preload("res://backend/news_client.gd")
var checks: int = 0
var failures: int = 0
var page: GaragePage
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func settle() -> void:
	for tick: int in range(8): await frame()
	while page._menu_motion != null: await frame()
	for tick: int in range(5): await frame()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var evidence_root: String = "res://../docs/evidence/garage-news-friend-publication-2026-10-16"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): evidence_root = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(evidence_root.path_join(RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = ProjectSettings.globalize_path("res://../build/news-native/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	GameSoundtrack.instance().music_enabled = false
	app._show_screen("garage")
	page = app.root_ui.find_child("GaragePage",true,false)
	await settle()
	var backend := Fixture.Backend.new()
	root.add_child(backend)
	var service := News.new()
	service.client = backend
	root.add_child(service)
	page.news_client = service
	service.identity_changed()
	service.checked_day = backend.server_now()/86400
	service._fetched_at = Time.get_ticks_msec()
	service.items = [
		{"id":"one","kind":"milestone","count":1000,"track_name":"Underpass","created_at":1792152000},
		{"id":"two","kind":"world_record","metric":"lap","actor_name":"Bob","time_ticks":15223,"tick_rate":120,"vehicle_id":"compact","track_name":"Underpass","created_at":1792152000},
		{"id":"three","kind":"friend_overtake","metric":"race","actor_name":"Bob","time_ticks":75223,"tick_rate":120,"vehicle_id":"compact","track_name":"Dust cloud","created_at":1792152000},
		{"id":"four","kind":"percentile_drop","metric":"lap","threshold":5,"vehicle_id":"compact","track_name":"Underpass","created_at":1792152000},
		{"id":"five","kind":"friend_track","actor_id":"bob","actor_name":"Bob","track_name":"Dust cloud","version_id":"11111111-2222-4333-8444-555555555555","created_at":1792152000}]
	var underpass: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/underpass.json"))
	var dust: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json"))
	for index: int in range(service.items.size()):
		service.items[index]["track_points"] = dust.points if index in [2,4] else underpass.points
		service.items[index]["version_id"] = "11111111-2222-4333-8444-555555555555"
	var car: CarVisual = page.showroom.car
	var viewport: SubViewport = page.showroom.showroom_viewport
	var camera_pose: Transform3D = page.showroom.camera.transform
	var condition: Dictionary = page.showroom.weathering.snapshot()
	var livery: Dictionary = page.draft.duplicate(true)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720),Vector2i(1720,914)]:
		root.size = dimensions
		service._fetched_at = Time.get_ticks_msec()
		page._show_section("news")
		await settle()
		check(page.showroom.car == car and page.showroom.showroom_viewport == viewport,"News retains car and viewport")
		check(page.showroom.camera.transform == camera_pose,"News retains car camera")
		check(page.showroom.weathering.snapshot() == condition and page.draft == livery,"News retains condition and livery")
		check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"News panel fits "+str(dimensions))
		check(not page.preview.visible and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"newspaper suspends the retained live showroom")
		check(page.tools_panel.size.x > page.size.x*0.75,"newspaper uses the full main area")
		check(page.tools.find_child("LeadStory",true,false) != null,"newspaper lead is present")
		check(backend.calls.is_empty(),"cached News entry makes no request")
		await capture("news-"+str(dimensions.x))
		var menu: Node = page.tools.find_child("GarageNewsMenu",true,false)
		var masthead: Label = menu.find_child("NewsMasthead",true,false)
		var tagline: Label = menu.find_child("NewsTagline",true,false)
		check(masthead.get_global_rect().end.x < tagline.get_global_rect().position.x and masthead.get_global_rect().position.y < tagline.get_global_rect().end.y,"masthead and adjacent tagline stay separate at "+str(dimensions))
		check(menu.find_child("NewsFooter",true,false).get_global_rect().end.y <= menu.get_global_rect().end.y,"complete editorial footer fits at "+str(dimensions))
		for index: int in range(service.items.size()):
			menu._choose(index)
			await settle()
			var action: Button = menu.find_child("GarageNewsRace",true,false)
			check(action != null and not action.disabled,"race action exists for "+str(service.items[index].kind))
			check(menu.find_child("NewsArticle",true,false).get_line_count() == 2,"short article retains two lines: "+str(service.items[index].kind)+" at "+str(dimensions))
			if action != null:
				check(action.size.y >= 48 and menu._scroll.get_global_rect().encloses(action.get_global_rect()),"complete race touch target fits "+str(service.items[index].kind)+" at "+str(dimensions))
				check(menu._scroll.scroll_vertical == 0 and menu._scroll.get_global_rect().encloses(menu.find_child("LeadStory",true,false).get_global_rect()),"complete article fits without scrolling: "+str(service.items[index].kind)+" at "+str(dimensions))
				check(not menu._scroll.get_v_scroll_bar().visible,"article has no vertical scrollbar")
				await capture("race-"+str(service.items[index].kind)+"-"+str(dimensions.x))
		menu._choose(1)
		await settle()
		check(menu.find_child("NewsCarPhoto",true,false) != null,"record has car photograph")
		check(menu.find_child("NewsPhotoCaption",true,false) != null,"printed photograph has a newspaper caption")
		var image_rect: Rect2 = menu.find_child("NewsCarPhoto",true,false).get_global_rect()
		var divider_rect: Rect2 = menu.find_child("NewsImageDivider",true,false).get_global_rect()
		var circuit_rect: Rect2 = menu.find_child("NewsCircuit",true,false).get_global_rect()
		check(image_rect.end.x <= divider_rect.position.x and divider_rect.end.x <= circuit_rect.position.x,"photo, divider and real outline remain side by side at "+str(dimensions))
		check(menu.find_child("NewsCircuit",true,false).points.size() == mini(96,underpass.points.size()),"record uses real bounded circuit points")
		check(backend.calls.is_empty(),"browsing stories makes no request")
		await capture("record-"+str(dimensions.x))
		menu._choose(4)
		await settle()
		check(menu.find_child("NewsCircuit",true,false).points.size() == mini(96,dust.points.size()),"friend's new track has its actual outline")
		check(menu.find_child("NewsCarPhoto",true,false) == null,"publication illustrates the circuit without inventing a car")
		var race_button: Button = menu.find_child("GarageNewsRace",true,false)
		check(race_button != null and not race_button.disabled,"publication offers direct racing")
		check(menu._scroll.get_global_rect().encloses(race_button.get_global_rect()),"Race track is reachable inside the article at "+str(dimensions))
		check(backend.calls.is_empty(),"friend publication browsing needs no request")
		await capture("friend-track-"+str(dimensions.x))
		menu._select_tab("friends")
		await settle()
		check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"Friends panel fits "+str(dimensions))
		await capture("friends-"+str(dimensions.x))
		var actual_items: Array = service.items
		var reads_before: int = backend.calls.size()
		backend.signed = false
		menu._select_tab("news")
		await settle()
		check(menu._using_examples() and menu._stories().size() == 5,"guest sees local newspaper stories")
		check(menu._folio.text.begins_with("STORY "),"local stories retain the normal newspaper folio")
		menu._choose(0)
		check(not menu.find_child("GarageNewsRace",true,false).disabled,"local publication also offers direct racing")
		await capture("local-stories-"+str(dimensions.x))
		for index: int in range(menu._stories().size()):
			menu._choose(index)
			await settle()
			check(menu.find_child("NewsCircuit",true,false).points.size() == 96,"local story has a packaged real outline")
			var action: Button = menu.find_child("GarageNewsRace",true,false)
			check(action != null and not action.disabled,"local story has its direct race action")
			check(menu._scroll.get_global_rect().encloses(action.get_global_rect()),"local "+str(menu._stories()[index].kind)+" race action is reachable at "+str(dimensions))
			check(menu._scroll.scroll_vertical == 0 and menu._scroll.get_global_rect().encloses(menu.find_child("LeadStory",true,false).get_global_rect()),"complete local "+str(menu._stories()[index].kind)+" article fits without scrolling at "+str(dimensions))
			check(menu.find_child("NewsArticle",true,false).get_line_count() == 2,"local "+str(menu._stories()[index].kind)+" copy stays in two lines at "+str(dimensions))
			await capture("local-"+str(menu._stories()[index].kind)+"-"+str(dimensions.x))
			if index == 2: await capture("local-record-"+str(dimensions.x))
		check(backend.calls.size() == reads_before and service.items == actual_items,"local reading leaves API and account news untouched")
		backend.signed = true
		service._fetched_at = Time.get_ticks_msec()
		service.changed.emit()
		check(not menu._using_examples() and menu._stories() == actual_items,"actual news replaces the local edition")
		backend.calls.clear()
		page._show_section("cars")
		await settle()
		check(page.showroom.car == car and page.showroom.camera.transform == camera_pose,"return preserves original showroom")
		check(page.preview.visible,"return reveals the original car")
	# Each original chassis photograph uses the same printed treatment.
	root.size = Vector2i(1280,720)
	page._show_section("news")
	await settle()
	var photo_menu: Node = page.tools.find_child("GarageNewsMenu",true,false)
	var original_items: Array = service.items.duplicate(true)
	for vehicle: String in VehicleCatalog.IDS:
		service.items = [{"id":"photo-review","kind":"world_record","actor_name":"Bob","track_name":"Underpass","metric":"lap","vehicle_id":vehicle,"time_ticks":2188,"tick_rate":120,"track_points":underpass.points}]
		service.changed.emit()
		for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
			root.size = dimensions
			await settle()
			var photo: TextureRect = photo_menu.find_child("NewsCarPhoto",true,false)
			var caption: Label = photo_menu.find_child("NewsPhotoCaption",true,false)
			check(photo != null and photo.texture.resource_path == "res://assets/news/vehicles/"+vehicle+".png","printed photo retains the actual "+vehicle+" model")
			check(photo.texture.get_size() == Vector2(640,400),"photo uses the complete fitted "+vehicle+" frame")
			check(caption != null and caption.text.contains(VehicleCatalog.title(vehicle).capitalize()),"caption names the actual "+vehicle+" class")
			check(absf(photo.get_global_rect().get_center().x-caption.get_global_rect().get_center().x) <= 0.5,"photo and caption share the same centre for "+vehicle+" at "+str(dimensions))
			check(backend.calls.is_empty() and page.showroom.car == car,"printing "+vehicle+" adds no reads or live car renders")
			await capture("printed-"+vehicle+"-"+str(dimensions.x))
	root.size = Vector2i(1280,720)
	service.items = original_items
	service.changed.emit()
	# Other retained workbenches restore their original split layout after News.
	for destination: String in ["records","customise","tuning","care","trophies"]:
		page._show_section("news")
		await settle()
		page._show_section(destination)
		await settle()
		check(page.preview.visible and page._preview_slot.visible and page._actions_slot.visible,"News restores "+destination+" slots")
		check(app.root_ui.get_global_rect().encloses(page.preview.get_global_rect()),destination+" preview fits after News")
		check(page.showroom.car == car and page.showroom.showroom_viewport == viewport,"News transition retains native resources for "+destination)
	page._show_section("cars")
	await settle()
	while page.showroom.camera_motion != null and page.showroom.camera_motion.is_running(): await frame()
	check(page.showroom.camera.transform.is_equal_approx(camera_pose) and page.draft == livery,"all News workbench returns retain camera and livery")
	app.queue_free()
	service.queue_free()
	backend.queue_free()
	for tick: int in range(20): await frame()
	print("GARAGE NEWS NATIVE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

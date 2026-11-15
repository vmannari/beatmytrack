extends SceneTree

const Fixture = preload("res://tests/test_garage_news.gd")
const News = preload("res://backend/news_client.gd")
const Menu = preload("res://ui/garage_news_menu.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	root.size = Vector2i(1280,720)
	var backend := Fixture.Backend.new()
	root.add_child(backend)
	var service := News.new()
	service.client = backend
	service.read_state_path = "user://news-livery-test.cfg"
	root.add_child(service)
	service.identity_changed()
	service.checked_day = backend.server_now()/86400
	service._fetched_at = Time.get_ticks_msec()
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "d32535"
	paint.colors.accent = "f6de51"
	var appearance := {"vehicle_id":"compact","livery":paint,"customisation":VehicleCustomisation.defaults()}
	service.items = [{"id":"record","kind":"world_record","actor_id":"bob","actor_name":"Bob","vehicle_id":"compact","appearance":appearance,"metric":"race","time_ticks":12000,"tick_rate":120,"track_name":"Underpass","track_points":[[0,0],[20,0],[10,20]]}]
	var pane := Fixture.Pane.new()
	pane.theme = MenuStyle.theme()
	root.add_child(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu := Menu.new()
	menu.page = pane
	menu.service = service
	pane.tools.add_child(menu)
	for tick: int in range(12): await process_frame
	var view: Control = menu.find_child("NewsLiveryCar",true,false)
	check(view != null,"a valid featured appearance creates the livery render")
	var initial_photo: Control = menu.find_child("NewsCarPhoto",true,false)
	check(not initial_photo.visible or initial_photo.modulate.a == 0.0,"stock car is never shown as the featured driver's livery")
	if view != null:
		var count: int = 0
		while is_instance_valid(view) and not view.presentation_ready and count < 1200:
			count += 1
			await process_frame
		if not view.presentation_ready: print("PREVIEW WAIT: ",view.car.model_ready," stage ",view.car._model_stage," yields ",view.car.model_yields," frames ",count)
		check(view.presentation_ready,"livery render finishes")
		if view.presentation_ready:
			for tick: int in range(5):
				await process_frame
				if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
			check(view.car.livery == paint and view.car.customisation == appearance.customisation,"the rendered car uses the featured livery and fitted parts")
			check(view.viewport.transparent_bg and view.visible,"car render has a transparent background")
			check(not menu.find_child("NewsCarPhoto",true,false).visible,"stock photograph is hidden once the actual car is ready")
			check(not menu.find_child("NewsCarLoading",true,false).visible,"preparation message clears when the car is ready")
	check(menu.find_child("NewsPhotoFrame",true,false).get_theme_stylebox("panel") is StyleBoxEmpty,"picture has no border")
	check(menu.find_child("NewsPhotoCaption",true,false).text == "Bob · Rally","caption identifies the featured driver and car")
	check(menu.find_child("NewsArticle",true,false).get_theme_font_size("font_size") == 14,"article copy uses the smaller size")
	check(backend.calls.is_empty(),"rendering the cached appearance needs no extra API requests")
	var garage := GaragePage.new()
	garage.records = LocalRecords.new(ProjectSettings.globalize_path("user://news-livery-records.json"))
	garage.records.settings["vehicle_liveries"] = {"compact":paint.duplicate(true)}
	menu.page = garage
	var own_record := {"kind":"world_record","actor_id":"alice","vehicle_id":"compact"}
	var own_appearance: Dictionary = menu._story_appearance(own_record,"compact",false)
	check(own_appearance.get("livery",{}).get("colors",{}).get("body") == "d32535","the player's own story uses the saved local livery")
	check(menu._story_uses_local_appearance(own_record,false),"the player's record is identified as their own car")
	check(menu._story_appearance({"kind":"milestone"},"compact",true).livery.colors.body == "d32535","a milestone uses the selected Garage car's livery")
	menu.page = pane
	garage.free()
	var output: String = ProjectSettings.globalize_path("res://../build/news-livery")
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join("featured-car.png")) == OK,"capture the featured car")
	var own_garage := GaragePage.new()
	own_garage.section = "news"
	own_garage.tools = pane.tools
	own_garage.records = LocalRecords.new(ProjectSettings.globalize_path("user://news-livery-records.json"))
	own_garage.records.settings["vehicle_liveries"] = {"compact":paint.duplicate(true)}
	menu.page = own_garage
	var original_items: Array = service.items
	service.items = [{"id":"own","kind":"world_record","actor_id":"alice","actor_name":"Alice","vehicle_id":"compact","track_name":"Underpass"}]
	menu._render()
	for tick: int in range(4):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	check(menu.find_child("NewsLiveryCar",true,false) != null and menu.find_child("NewsPhotoCaption",true,false) == null,"own car keeps its livery without a caption")
	menu.page = pane
	own_garage.free()
	service.items = original_items
	service.items[0].appearance.vehicle_id = "pickup"
	menu._render()
	for tick: int in range(4): await process_frame
	check(menu.find_child("NewsLiveryCar",true,false) == null,"a mismatched appearance cannot be presented as the featured car")
	check(menu.find_child("NewsPhotoCaption",true,false).text.contains("illustration"),"fallback photograph is identified as an illustration")
	pane.queue_free()
	service.queue_free()
	backend.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://news-livery-test.cfg"))
	print("NEWS LIVERY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

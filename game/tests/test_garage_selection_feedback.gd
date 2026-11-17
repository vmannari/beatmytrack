extends SceneTree
## Selection must be drawn before synchronous model construction starts.
class ObservedGarage extends GaragePage:
	var builds: Array[Dictionary] = []
	var capture_path: String = ""
	var delayed_build: bool = false
	var selection_drawn: bool = false
	var capture_error: Error = OK

	func _replace_showroom_car() -> void:
		builds.append({"car":vehicle_id,"draw":Engine.get_frames_drawn()})
		if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
			var image: Image = get_viewport().get_texture().get_image()
			var card: Control = cards.get_child(VehicleCatalog.IDS.find(vehicle_id))
			var pixel: Color = image.get_pixelv(Vector2i(card.get_global_rect().position+Vector2(1,30)))
			selection_drawn = pixel.r > 0.8 and pixel.g > 0.55 and pixel.b < 0.45
			capture_error = image.save_png(capture_path)
			capture_path = ""
		if delayed_build:
			OS.delay_msec(180)
			delayed_build = false
		super._replace_showroom_car()

var checks: int = 0
var failures: int = 0
var page: ObservedGarage
var output: String = "res://../docs/evidence/garage-selection-2026-11-14"
var dispatch_ms: float = 0.0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame

func highlighted(id: String) -> bool:
	var card: Button = page.cards.get_child(VehicleCatalog.IDS.find(id))
	var title: Label = card.find_child("CarCardTitle_"+id,true,false)
	return card.get_theme_stylebox("normal").border_color == MenuStyle.ACCENT and title.get_theme_color("font_color") == MenuStyle.ACCENT

func press(index: int) -> void:
	(page.cards.get_child(index) as Button).pressed.emit()

func pointer(index: int, touch: bool) -> void:
	var point: Vector2 = (page.cards.get_child(index) as Control).get_global_rect().get_center()
	for down: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = point
			event.index = 3
			event.pressed = down
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			root.push_input(event,true)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	var directory: String = ProjectSettings.globalize_path("res://../build/garage-selection-2026-11-14/profile-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	records.settings = {"music_enabled":false,"selected_car":"compact"}
	var kart_wear: Dictionary = VehicleWeathering.new().snapshot()
	kart_wear.dirt = 0.64
	VehicleCondition.save(records,"kart",kart_wear)
	var original_settings: Dictionary = records.settings.duplicate(true)
	page = ObservedGarage.new()
	page.records = records
	page.cached_carousel = true
	page.preview_can_render = func() -> bool: return false
	root.add_child(page)
	MenuStyle.fill(page)
	while not page.showroom.showroom_ready: await process_frame
	page._finish_menu_move()
	await frames(8)
	# GCS01: every replacement must retain the room's camera, including wide
	# cars and the tall Forklift. Check both default and player-adjusted views.
	for adjusted: bool in [false,true]:
		if adjusted:
			page.showroom.set_zoom(0.87)
			page.showroom.elevation += 0.08
			page.showroom.yaw += 0.3
			page.showroom._orbit()
		var fixed_camera: Transform3D = page.showroom.camera.transform
		var fixed_offset: float = page.showroom.camera.h_offset
		for index: int in range(VehicleCatalog.IDS.size()):
			page.preview_car(index)
			check(page.showroom.camera.transform.is_equal_approx(fixed_camera),"camera stays still on replacement "+VehicleCatalog.IDS[index]+" adjusted="+str(adjusted))
			page.showroom.finish_car_transition()
			await frames(4)
			check(page.showroom.camera.transform.is_equal_approx(fixed_camera) and is_equal_approx(page.showroom.camera.h_offset,fixed_offset),"camera stays still after reveal "+VehicleCatalog.IDS[index]+" adjusted="+str(adjusted))
			if not adjusted and DisplayServer.get_name() != "headless":
				for frame: int in range(8):
					page.showroom.invalidate_render()
					await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output.path_join("fixed-"+VehicleCatalog.IDS[index]+".png")) == OK,"capture shared framing "+VehicleCatalog.IDS[index])
	page.preview_car(0)
	page.showroom.finish_car_transition()
	page.builds.clear()
	page.showroom.set_zoom(0.87)
	var camera: Transform3D = page.showroom.camera.transform
	var showroom: CarShowroom = page.showroom
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("before.png")) == OK,"capture original selection")
	page.capture_path = output.path_join("highlight-before-construction.png")
	page.delayed_build = true
	var before_draw: int = Engine.get_frames_drawn()
	var began: int = Time.get_ticks_usec()
	pointer(1,false)
	dispatch_ms = (Time.get_ticks_usec()-began)/1000.0
	check(highlighted("kart") and not highlighted("compact"),"mouse activation changes the highlighted car immediately")
	check(page.heading.text == VehicleCatalog.title("kart"),"title changes immediately")
	check(page.builds.is_empty() and page.showroom.car.vehicle_id == "compact","input returns before building the selected model")
	check(page.vehicle_id == "compact" and page.draft == VehicleLivery.for_car(records.settings,"compact"),"displayed car and editable state stay coherent until replacement")
	await frames()
	check(page.builds.size() == 1 and page.showroom.car.vehicle_id == "kart","requested car is eventually constructed")
	if DisplayServer.get_name() != "headless":
		check(int(page.builds[0].draw) > before_draw,"a frame presents before construction including an intentionally slow build")
		check(page.selection_drawn and page.capture_error == OK,"captured pixels show the new selected border before construction")
	check(page.showroom == showroom and page.showroom.camera.transform.is_equal_approx(camera) and page.showroom.zoom == 0.87,"feedback preserves the showroom and camera")
	check(page._condition_saved == kart_wear,"selected car receives its own saved wear")
	check(records.settings == original_settings and VehicleCatalog.selected == "compact","preview does not equip or save a different car")
	page.showroom.finish_car_transition()
	var count: int = page.builds.size()
	pointer(0,true)
	check(highlighted("compact") and page.builds.size() == count,"touch activation also highlights before construction")
	press(2)
	press(3)
	check(highlighted(VehicleCatalog.IDS[3]),"rapid input highlights the latest request")
	await frames()
	check(page.builds.size() == count+1 and page.showroom.car.vehicle_id == VehicleCatalog.IDS[3],"rapid requests build only the latest car")
	page.showroom.finish_car_transition()
	count = page.builds.size()
	press(1)
	press(3)
	await frames()
	check(page.builds.size() == count and highlighted(VehicleCatalog.IDS[3]),"returning to the displayed car cancels the pending build")
	press(1)
	page.preview_car(0)
	await frames()
	check(page.showroom.car.vehicle_id == "compact" and highlighted("compact"),"programmatic preview supersedes a queued card activation")
	press(1)
	page._confirm_car()
	check(page.section == "customise" and page.vehicle_id == "kart" and page._selected_vehicle_id == "kart" and page.showroom.car.vehicle_id == "kart","immediate Select confirms the pending choice")
	count = page.builds.size()
	await frames()
	check(page.builds.size() == count,"confirmation cancels the stale callback")
	page._show_section("cars")
	page._finish_menu_move()
	press(0)
	page._show_section("care")
	check(page.vehicle_id == "compact" and page.showroom.car.vehicle_id == "compact","workshop navigation flushes the latest choice")
	page._show_section("cars")
	page._finish_menu_move()
	press(1)
	page._request_free_drive()
	check(page._selected_vehicle_id == "kart" and page.showroom.car.vehicle_id == "kart","immediate Test drive uses the pending choice")
	count = page.builds.size()
	press(0)
	page.hide()
	await frames()
	check(page.builds.size() == count and page.vehicle_id == "kart" and highlighted("kart"),"hiding cancels deferred work and restores the displayed selection")
	page.show()
	press(0)
	page.refresh_selection()
	await frames()
	check(page.showroom.car.vehicle_id == "compact" and highlighted("compact"),"external selection refresh supersedes deferred work")
	press(1)
	page.queue_free()
	await frames()
	check(not is_instance_valid(page),"pending work releases with the page")
	print("GARAGE_SELECTION_FEEDBACK ",JSON.stringify({"checks":checks,"failures":failures,"dispatch_ms":dispatch_ms}))
	quit(1 if failures else 0)

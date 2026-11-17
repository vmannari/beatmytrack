extends "res://tests/test_customisation_carousel.gd"
## GPC04-GPC06: close-ups rotate the pedestal while the camera faces the door.
var _expected_horizontal := Vector2.ZERO
var _minimum_heading_dot: float = 1.0
var _motion_frames: int = 0

func settle() -> void:
	while page._workbench_focus_pending or page._menu_motion != null or (page.showroom.camera_motion != null and page.showroom.camera_motion.is_running()):
		if _expected_horizontal != Vector2.ZERO:
			var direction: Vector3 = page.showroom.camera.basis.z
			_minimum_heading_dot = minf(_minimum_heading_dot,Vector2(direction.x,direction.z).normalized().dot(_expected_horizontal))
			_motion_frames += 1
		await process_frame
	for frame: int in range(12): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	GameSoundtrack.instance().music_enabled = false
	output = "res://../docs/evidence/garage-part-closeups-2026-11-16/native"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	VehicleCatalog.selected = "compact"
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	var shop := Shop.new()
	host.add_child(shop)
	page = GaragePage.new()
	page.records = LocalRecords.new("user://parts_camera_"+TrackLibrary.unique_id()+".json")
	page.economy = shop
	host.add_child(page)
	MenuStyle.fill(page)
	page.offset_top = 100
	for car_index: int in range(VehicleCatalog.IDS.size()):
		page.open_car(car_index)
		await settle()
		var view: CarShowroom = page.showroom
		var id: String = view.vehicle_id
		var saved: Dictionary = page.records.settings.duplicate(true)
		for turn: float in [0.0,1.7,-2.4]:
			_expected_horizontal = Vector2.ZERO
			page._show_section("cars")
			await settle()
			view.yaw = CarShowroom.GARAGE_CAMERA_YAW+turn
			view._orbit()
			var home: Transform3D = view.camera.transform
			page._show_section("customise")
			await settle()
			var appearance: Transform3D = view.camera.transform
			_expected_horizontal = Vector2(appearance.basis.z.x,appearance.basis.z.z).normalized()
			var appearance_distance: float = appearance.origin.distance_to(page._customisation_camera.target)
			if turn==1.7: await capture(id+"-appearance")
			page._show_section("tuning")
			await settle()
			check(page._customisation_camera.focused_category==("body_kit" if page.kit_category=="body" else page.kit_category),id+": Parts opens the selected close-up")
			for category: String in VehicleCustomisation.CATEGORIES:
				page._select_kit_category(category)
				await settle()
				var closeup: Transform3D = view.camera.transform
				var category_yaw: float = view.yaw
				check(Vector2(closeup.basis.z.x,closeup.basis.z.z).normalized().dot(_expected_horizontal)>0.9999,id+": close-up faces the door "+category)
				var point: Vector2 = view.camera.unproject_position(page._customisation_camera.target)
				check(point.distance_to(Vector2(view.showroom_viewport.size)*0.5)<3.0,id+": selected region is centred "+category)
				var local_direction: Vector3 = view.car.global_basis.orthonormalized().inverse()*closeup.basis.z
				if category=="aero": check(local_direction.z>0.35,id+": rear aero turns towards the camera")
				if category=="hood": check(local_direction.z>0.35 if id=="forklift" else local_direction.z< -0.35,id+": hood turns towards the camera")
				if category=="rims": check(local_direction.x>0.25,id+": wheel side turns towards the camera")
				if category!="body": check(closeup.origin.distance_to(page._customisation_camera.target)<appearance_distance,id+": selected region zooms closer "+category)
				var options: Array = VehicleCustomisation.options(category,id)
				if options.size()>1:
					page._preview_kit(category,str(options[1][0]))
					await settle()
					check(view.camera.transform.is_equal_approx(closeup) and is_equal_approx(view.yaw,category_yaw),id+": preview retains the category close-up "+category)
					check(view.customisation[category]==options[1][0],id+": selected part remains visible "+category)
				if turn==1.7: await capture(id+"-parts-"+category)
			page._select_kit_category("hood")
			await settle()
			view.rotate_view(Vector2(35,4))
			view.zoom_by(0.95)
			var adjusted: Transform3D = view.camera.transform
			page._preview_kit("hood",str(VehicleCustomisation.options("hood",id)[0][0]))
			await settle()
			check(view.camera.transform.is_equal_approx(adjusted),id+": selection retains manual orbit and zoom")
			page._show_section("customise")
			await settle()
			check(page._customisation_camera.focused_category=="body",id+": Appearance returns to the whole car")
			check(Vector2(view.camera.basis.z.x,view.camera.basis.z.z).normalized().dot(_expected_horizontal)>0.9999,id+": Appearance faces the door")
			page._show_section("tuning")
			await settle()
			var reentry: Transform3D = view.camera.transform
			check(page._customisation_camera.focused_category=="hood",id+": Parts reentry restores the hood close-up")
			root.size = Vector2i(960,540)
			root.content_scale_size = root.size
			await settle()
			check(view.camera.basis.is_equal_approx(reentry.basis),id+": compact resize retains camera direction")
			root.size = Vector2i(1280,720)
			root.content_scale_size = root.size
			await settle()
			check(page.records.settings==saved and shop.purchases==0,id+": browsing does not save or purchase")
			page._select_kit_category("aero")
			await process_frame
			page._select_kit_category("rims")
			await settle()
			check(page._customisation_camera.focused_category=="rims",id+": rapid category changes finish on the requested part")
			_expected_horizontal = Vector2.ZERO
			page._show_section("cars")
			await settle()
			check(view.camera.transform.is_equal_approx(home),id+": leaving editing restores Garage camera")
			check(is_equal_approx(view.yaw,CarShowroom.GARAGE_CAMERA_YAW+turn),id+": leaving editing restores the car rotation")
	await interrupted_focus()
	check(_motion_frames>0 and _minimum_heading_dot>0.9999,"animated camera keeps the door direction throughout "+str(_motion_frames)+" frames, minimum dot "+str(_minimum_heading_dot))
	host.queue_free()
	for frame: int in range(6): await process_frame
	print("GARAGE_PARTS_CAMERA: "+str(checks)+" checks, "+str(failures)+" failures")
	quit(1 if failures else 0)

func interrupted_focus() -> void:
	var view: CarShowroom = page.showroom
	var home: Transform3D = view.camera.transform
	var home_yaw: float = view.yaw
	page._show_section("customise")
	await settle()
	_expected_horizontal = Vector2(view.camera.basis.z.x,view.camera.basis.z.z).normalized()
	page._show_section("tuning")
	await process_frame
	page._select_kit_category("aero")
	await process_frame
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	await settle()
	var point: Vector2 = view.camera.unproject_position(page._customisation_camera.target)
	check(point.distance_to(Vector2(view.showroom_viewport.size)*0.5)<3.0,"resize during rotation finishes with the selected part centred")
	page._select_kit_category("rims")
	await process_frame
	view.rotate_view(Vector2(16,3))
	var dragged_yaw: float = view.yaw
	await settle()
	check(is_equal_approx(view.yaw,dragged_yaw),"drag during rotation cancels the automatic turn")
	point = view.camera.unproject_position(page._customisation_camera.target)
	check(point.distance_to(Vector2(view.showroom_viewport.size)*0.5)<3.0,"drag during rotation keeps the selected part centred")
	page._select_kit_category("hood")
	await process_frame
	_expected_horizontal = Vector2.ZERO
	page._show_section("cars")
	await settle()
	check(view.camera.transform.is_equal_approx(home) and is_equal_approx(view.yaw,home_yaw),"leaving mid-turn restores the preceding car and camera poses")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size

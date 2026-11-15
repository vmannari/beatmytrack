extends "res://tests/test_customisation_carousel.gd"
## GPC01-GPC03: Parts retains the Appearance view at every turntable angle.

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	GameSoundtrack.instance().music_enabled = false
	output = "res://../docs/evidence/garage-parts-camera-2026-11-15/native"
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
			page._show_section("cars")
			await settle()
			view.yaw = CarShowroom.GARAGE_CAMERA_YAW+turn
			view._orbit()
			var home: Transform3D = view.camera.transform
			page._show_section("customise")
			await settle()
			var appearance: Transform3D = view.camera.transform
			if car_index==0 and turn==1.7: await capture("appearance-turned")
			page._show_section("tuning")
			await settle()
			check(view.camera.transform.is_equal_approx(appearance),id+": Parts entry matches Appearance at turn "+str(turn))
			for category: String in VehicleCustomisation.CATEGORIES:
				page._select_kit_category(category)
				await settle()
				check(view.camera.transform.is_equal_approx(appearance),id+": category keeps camera "+category)
				var options: Array = VehicleCustomisation.options(category,id)
				if options.size()>1:
					page._preview_kit(category,str(options[1][0]))
					await settle()
					check(view.camera.transform.is_equal_approx(appearance),id+": preview keeps camera "+category)
					check(view.customisation[category]==options[1][0],id+": selected part remains visible "+category)
				if car_index==0 and turn==1.7: await capture("parts-turned-"+category)
			view.yaw += 0.6
			view.elevation += 0.07
			view.zoom *= 0.95
			view._orbit()
			var adjusted: Transform3D = view.camera.transform
			page._select_kit_category("hood")
			page._preview_kit("hood",str(VehicleCustomisation.options("hood",id)[0][0]))
			await settle()
			check(view.camera.transform.is_equal_approx(adjusted),id+": selection retains manual orbit and zoom")
			page._show_section("customise")
			await settle()
			check(view.camera.transform.is_equal_approx(adjusted),id+": return to Appearance keeps adjusted view")
			page._show_section("tuning")
			await settle()
			check(view.camera.transform.is_equal_approx(adjusted),id+": Parts reentry keeps adjusted view")
			root.size = Vector2i(960,540)
			root.content_scale_size = root.size
			await settle()
			check(view.camera.basis.is_equal_approx(adjusted.basis),id+": compact resize retains camera direction")
			root.size = Vector2i(1280,720)
			root.content_scale_size = root.size
			await settle()
			check(page.records.settings==saved and shop.purchases==0,id+": browsing does not save or purchase")
			page._show_section("cars")
			await settle()
			check(view.camera.transform.is_equal_approx(home),id+": leaving editing restores Garage camera")
	host.queue_free()
	for frame: int in range(6): await process_frame
	print("GARAGE_PARTS_CAMERA: "+str(checks)+" checks, "+str(failures)+" failures")
	quit(1 if failures else 0)

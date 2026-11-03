extends "res://tests/test_rivalry_result.gd"
## Loading art, actual animation, error/retry and authoritative-board handoff.
const Visual = preload("res://ui/rivalry_loading_visual.gd")

func mean_delta(a: Image, b: Image, region: Rect2i) -> float:
	var difference: float = 0.0
	var count: int = 0
	for y: int in range(region.position.y,region.end.y,2):
		for x: int in range(region.position.x,region.end.x,2):
			var first: Color = a.get_pixel(x,y)
			var second: Color = b.get_pixel(x,y)
			difference += absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b)
			count += 3
	return difference*255.0/maxi(1,count)

func settle() -> void:
	for frame: int in range(8): await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	if DisplayServer.get_name() != "headless": root.position = Vector2i(-12000,-12000)
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-loading-placeholders-2026-11-02/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(evidence)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var background := MenuBackdrop.new()
		root.add_child(background)
		background.size = Vector2(dimensions)
		var shell := VBoxContainer.new()
		shell.theme = MenuStyle.theme()
		shell.position = Vector2(24,20)
		shell.size = Vector2(dimensions)-Vector2(48,40)
		root.add_child(shell)
		var brand := MenuBrand.new()
		brand.custom_minimum_size.y = 60
		shell.add_child(brand)
		var page := WeeklyRivalryPage.new()
		page.model = WeeklyRivalry.new()
		page.signed_in = true
		page.busy = true
		shell.add_child(page)
		await settle()
		check(page.find_child("RivalryLoading",true,false) != null,"unresolved selected car shows the loading presentation")
		check(page.find_children("*","SubViewport",true,false).is_empty(),"loading art creates no 3D car worlds or render targets")
		check(page.find_child("RivalryDriversPanel",true,false) == null,"loading never invents driver scores or publishes another car's standings")
		check(not page.ready_for_display(),"placeholder does not bypass the fresh-membership entry gate")
		var rows: Control = page.find_child("RivalryLoadingStandings",true,false)
		check(rows != null and rows.size.y >= 70 and root.get_visible_rect().encloses(rows.get_global_rect()),"animated table fits the smaller hub")
		for position: int in range(1,4):
			var car: Control = page.find_child("RivalryLoadingCar_"+str(position),true,false)
			check(car != null and car.size.x > 20 and car.size.y >= 100 and root.get_visible_rect().encloses(car.get_global_rect()),"each abstract car is visible inside its podium card")
			check(car.mouse_filter == Control.MOUSE_FILTER_IGNORE and not car.is_processing(),"car animation uses no input interception or CPU frame callbacks")
		var retained: Control = page.find_child("RivalryLoadingCar_1",true,false)
		var builds: int = page.content_builds
		page.refresh_presentation()
		check(page.content_builds == builds and page.find_child("RivalryLoadingCar_1",true,false) == retained,"pending notifications retain the same placeholder controls")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var first: Image = root.get_texture().get_image()
			check(first.save_png(evidence.path_join("loading-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save native loading view")
			await create_timer(0.65).timeout
			await RenderingServer.frame_post_draw
			var second: Image = root.get_texture().get_image()
			var cars_delta: float = mean_delta(first,second,Rect2i(retained.get_global_rect()))
			var rows_delta: float = mean_delta(first,second,Rect2i(rows.get_global_rect()))
			check(cars_delta > 0.001 and cars_delta < 4.0,"native abstract-car pulse changes pixels gently")
			check(rows_delta > 0.001 and rows_delta < 5.0,"native standings shimmer changes pixels gently")
			print("RIVALRY_LOADING_MOTION ",JSON.stringify({"size":str(dimensions),"car_mean_delta_255":cars_delta,"rows_mean_delta_255":rows_delta}))
			check(second.save_png(evidence.path_join("loading-motion-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save second animation sample")
		var old_visual: WeakRef = weakref(retained)
		page.busy = false
		page.error = "Rivalry unavailable. Check your connection and try again."
		page.refresh_presentation()
		await settle()
		var retry: Button = page.find_child("RivalryRefresh",true,false)
		check(retry != null and not retry.disabled and page.find_child("RivalryLoading",true,false) == null,"failure replaces loading with an actionable retry")
		check(old_visual.get_ref() == null,"departing loading controls and their animation materials are released")
		page.busy = true
		page.error = ""
		page.refresh_presentation()
		check(page.find_child("RivalryLoadingCar_1",true,false) != null,"retry restores the loading art")
		page.model.apply_snapshot(fixture())
		page.busy = false
		page.refresh_presentation()
		await settle()
		check(page.find_child("RivalryLoading",true,false) == null and page.find_child("RivalryLoadingStandings",true,false) == null,"final server board removes all loading visuals")
		check(page.find_child("RivalryDriversPanel",true,false) != null and page.find_child("RivalryPodiumCar_1",true,false) != null,"handoff retains the real standings and player cars")
		var before_refresh: Node = page.find_child("RivalryPodiumCar_1",true,false)
		page.busy = true
		page.background_refresh = true
		page.refresh_presentation()
		check(page.find_child("RivalryPodiumCar_1",true,false) == before_refresh and page.find_child("RivalryLoading",true,false) == null,"same-car background refresh keeps usable standings")
		shell.free()
		background.free()
		await process_frame
	print("RIVALRY_LOADING_VISUALS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

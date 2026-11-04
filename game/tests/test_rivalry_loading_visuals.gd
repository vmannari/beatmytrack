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
	var output: String = OS.get_environment("BMT_RIVALRY_LOADING_EVIDENCE")
	if output.is_empty(): output = "res://../docs/evidence/rivalry-loading-tracks-2026-11-04"
	evidence = ProjectSettings.globalize_path(output).path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(evidence)
	var atlas: Image = Visual.SILHOUETTES.get_image()
	check(atlas != null and atlas.get_size() == Vector2i(1920,256),"packaged silhouette atlas loads")
	var hashes: Array[String] = []
	for index: int in range(Visual.CAR_IDS.size()):
		var mask: Image = atlas.get_region(Rect2i(Vector2i(index*384,0),Vector2i(384,256)))
		var bounds: Rect2i = mask.get_used_rect()
		check(bounds.size.x > 100 and bounds.size.y > 70 and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < 384 and bounds.end.y < 256,"each actual-model silhouette is substantial and unclipped")
		hashes.append(mask.get_data().hex_encode().sha256_text())
	var distinct: Dictionary = {}
	for fingerprint: String in hashes: distinct[fingerprint] = true
	check(hashes.size() == 5 and hashes.size() == distinct.size(),"five model silhouettes have distinct shapes")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		VehicleCatalog.selected = "compact"
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
		var tracks: Control = page.find_child("RivalryLoadingTracksPanel",true,false)
		check(tracks != null and shell.get_global_rect().encloses(tracks.get_global_rect()),"weekly track loading panel stays inside the available menu area")
		var track_status: RichTextLabel = page.find_child("RivalryLoadingTracksStatus",true,false)
		check(track_status != null and track_status.get_parsed_text() == GameText.message("Loading tracks…"),"weekly track placeholders explain the wait with existing translated copy")
		for slot: int in range(5):
			var track: Control = page.find_child("RivalryLoadingTrack_"+str(slot),true,false)
			var art: Control = page.find_child("RivalryLoadingTrackArt_"+str(slot),true,false)
			check(track != null and track.size.y >= 48 and tracks.get_global_rect().encloses(track.get_global_rect()),"all five track placeholders fit without clipping")
			check(art != null and art.kind == Visual.Kind.TRACK and art.track_slot == slot and not art.is_processing(),"each track row uses retained 2D drawing and shader animation")
			check(track.mouse_filter == Control.MOUSE_FILTER_IGNORE and art.mouse_filter == Control.MOUSE_FILTER_IGNORE and track.find_children("*","Button",true,false).is_empty(),"unresolved tracks cannot intercept input or start a race")
			var number: Label = track.find_children("*","Label",true,false)[0]
			check(number.text == "%02d" % (slot+1),"track placeholders retain the five stable slot numbers")
		var loading_styles: Dictionary = {}
		for position: int in range(1,4):
			var car: Control = page.find_child("RivalryLoadingCar_"+str(position),true,false)
			check(car != null and car.size.x > 20 and car.size.y >= 100 and root.get_visible_rect().encloses(car.get_global_rect()),"each model silhouette is visible inside its podium card")
			check(car.mouse_filter == Control.MOUSE_FILTER_IGNORE and not car.is_processing(),"car animation uses no input interception or CPU frame callbacks")
			check(car.podium_color == [Color("ffd348"),Color("c0d4e3"),Color("dc9069")][position-1],"silhouette uses the actual podium's medal pigment")
			var panel: PanelContainer = page.find_child("RivalryLoadingPodium_"+str(position),true,false)
			var footer: PanelContainer = page.find_child("RivalryLoadingFooter_"+str(position),true,false)
			loading_styles[position] = [panel.get_theme_stylebox("panel"),footer.get_theme_stylebox("panel")]
			check(panel.find_child("RivalryPodiumBackdrop",true,false) != null,"loading card uses the actual medal-lit podium backdrop")
		var retained: Control = page.find_child("RivalryLoadingCar_1",true,false)
		var builds: int = page.content_builds
		page.refresh_presentation()
		check(page.content_builds == builds and page.find_child("RivalryLoadingCar_1",true,false) == retained,"pending notifications retain the same placeholder controls")
		check(page.find_child("RivalryLoadingTracksPanel",true,false) == tracks,"pending notifications also retain the track animation")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var first: Image = root.get_texture().get_image()
			check(first.save_png(evidence.path_join("loading-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save native loading view")
			await create_timer(0.65).timeout
			await RenderingServer.frame_post_draw
			var second: Image = root.get_texture().get_image()
			var cars_delta: float = mean_delta(first,second,Rect2i(retained.get_global_rect()))
			var rows_delta: float = mean_delta(first,second,Rect2i(rows.get_global_rect()))
			var tracks_delta: float = mean_delta(first,second,Rect2i(tracks.get_global_rect()))
			var sample_seconds: float = 0.65
			# Flat masks can quantize to the same alpha on either side of a pulse peak.
			# Sample the next part of the real animation before judging it stationary.
			if cars_delta <= 0.001 or rows_delta <= 0.001 or tracks_delta <= 0.001:
				await create_timer(0.65).timeout
				await RenderingServer.frame_post_draw
				var third: Image = root.get_texture().get_image()
				cars_delta = maxf(cars_delta,mean_delta(first,third,Rect2i(retained.get_global_rect())))
				rows_delta = maxf(rows_delta,mean_delta(first,third,Rect2i(rows.get_global_rect())))
				tracks_delta = maxf(tracks_delta,mean_delta(first,third,Rect2i(tracks.get_global_rect())))
				second = third
				sample_seconds = 1.3
			check(cars_delta > 0.001 and cars_delta < 4.0,"native model-silhouette pulse changes pixels gently")
			check(rows_delta > 0.001 and rows_delta < 5.0,"native standings shimmer changes pixels gently")
			check(tracks_delta > 0.001 and tracks_delta < 5.0,"native weekly track shimmer changes pixels gently")
			print("RIVALRY_LOADING_MOTION ",JSON.stringify({"size":str(dimensions),"sample_seconds":sample_seconds,"car_mean_delta_255":cars_delta,"rows_mean_delta_255":rows_delta,"tracks_mean_delta_255":tracks_delta}))
			check(second.save_png(evidence.path_join("loading-motion-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save second animation sample")
		if dimensions.x == 1280:
			for id: String in Visual.CAR_IDS:
				VehicleCatalog.selected = id
				page.refresh_presentation()
				await settle()
				for position: int in range(1,4):
					check(page.find_child("RivalryLoadingCar_"+str(position),true,false).vehicle_id == id,"loading follows the selected model immediately: "+id)
				check(page.find_children("*","SubViewport",true,false).is_empty(),"model-specific silhouette still needs no live 3D render")
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					check(root.get_texture().get_image().save_png(evidence.path_join("model-"+id+".png")) == OK,"capture model-specific podium colors: "+id)
			VehicleCatalog.selected = "electric"
			page.circuit_mode = true
			page.refresh_presentation()
			check(page.find_child("RivalryLoadingCar_1",true,false).vehicle_id == "compact","Compact Circuit placeholder follows its pinned car")
			page.circuit_mode = false
			VehicleCatalog.selected = "compact"
			page.refresh_presentation()
			retained = page.find_child("RivalryLoadingCar_1",true,false)
		var old_visual: WeakRef = weakref(retained)
		var old_tracks: WeakRef = weakref(page.find_child("RivalryLoadingTracksPanel",true,false))
		page.busy = false
		page.error = "Rivalry unavailable. Check your connection and try again."
		page.refresh_presentation()
		await settle()
		var retry: Button = page.find_child("RivalryRefresh",true,false)
		check(retry != null and not retry.disabled and page.find_child("RivalryLoading",true,false) == null,"failure replaces loading with an actionable retry")
		check(old_visual.get_ref() == null,"departing loading controls and their animation materials are released")
		check(old_tracks.get_ref() == null,"failure releases the track placeholders and their animation materials")
		page.busy = true
		page.error = ""
		page.refresh_presentation()
		check(page.find_child("RivalryLoadingCar_1",true,false) != null,"retry restores the loading art")
		check(page.find_child("RivalryLoadingTracksPanel",true,false) != null,"retry also restores the weekly track presentation")
		await settle()
		if dimensions.x == 960:
			for resized_dimensions: Vector2i in [Vector2i(1280,720),dimensions]:
				root.size = resized_dimensions
				root.content_scale_size = resized_dimensions
				background.size = Vector2(resized_dimensions)
				shell.size = Vector2(resized_dimensions)-Vector2(48,40)
				await settle()
				# This fixture's shell is manually sized rather than anchored by App.
				# Reapply its bounds after the old minimum has settled on resize.
				shell.size = Vector2(resized_dimensions)-Vector2(48,40)
				await settle()
				check(root.get_visible_rect().encloses(page.find_child("RivalryLoadingTracksPanel",true,false).get_global_rect()),"pending track layout still fits after resizing across the compact threshold")
		var loading_geometry: Array[Rect2] = []
		var loading_thumbnails: Array[Rect2] = []
		for slot: int in range(5):
			loading_geometry.append(page.find_child("RivalryLoadingTrack_"+str(slot),true,false).get_global_rect())
			var art: Control = page.find_child("RivalryLoadingTrackArt_"+str(slot),true,false)
			var preview: Rect2 = art.track_thumbnail_rect()
			preview.position += art.global_position
			loading_thumbnails.append(preview)
		var loading_panel: Rect2 = page.find_child("RivalryLoadingTracksPanel",true,false).get_global_rect()
		var loading_podium: Rect2 = page.find_child("RivalryLoadingPodium",true,false).get_global_rect()
		page.model.apply_snapshot(fixture())
		page.busy = false
		page.refresh_presentation()
		await settle()
		check(page.find_child("RivalryLoading",true,false) == null and page.find_child("RivalryLoadingStandings",true,false) == null,"final server board removes all loading visuals")
		check(page.find_child("RivalryLoadingTracksPanel",true,false) == null and page.find_child("SelectRivalryTrack_4",true,false) != null,"authoritative tracks replace all five placeholders with usable rows")
		check(page.find_child("RivalryDriversPanel",true,false) != null and page.find_child("RivalryPodiumCar_1",true,false) != null,"handoff retains the real standings and player cars")
		var final_panel: Rect2 = page.find_child("RivalryTracksPanel",true,false).get_global_rect()
		var final_podium: Rect2 = page.find_child("RivalryPodium",true,false).get_global_rect()
		print("RIVALRY_LOADING_LAYOUT ",JSON.stringify({"size":str(dimensions),"loading_panel":str(loading_panel),"final_panel":str(final_panel),"loading_podium":str(loading_podium),"final_podium":str(final_podium)}))
		check(loading_panel.is_equal_approx(final_panel),"track panel keeps its exact position and dimensions when content is ready")
		check(loading_podium.is_equal_approx(final_podium),"podium keeps its exact position and dimensions when content is ready")
		check(shell.get_global_rect().encloses(final_panel) and root.get_visible_rect().encloses(final_panel),"all five ready tracks stay inside the available menu area")
		for slot: int in range(5):
			var actual: Rect2 = page.find_child("RivalryTrackRow_"+str(slot),true,false).get_global_rect()
			print("RIVALRY_LOADING_ROW ",slot," ",loading_geometry[slot]," -> ",actual)
			check(loading_geometry[slot].is_equal_approx(actual),"each track slot stays fixed when the real track replaces its placeholder")
			var thumbnail: Rect2 = page.find_child("RivalryTrackThumbnail_"+str(slot),true,false).get_global_rect()
			print("RIVALRY_LOADING_THUMBNAIL ",slot," ",loading_thumbnails[slot]," -> ",thumbnail)
			check(thumbnail.is_equal_approx(loading_thumbnails[slot]),"the real thumbnail occupies the exact placeholder thumbnail rectangle")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(evidence.path_join("ready-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"capture ready layout for comparison with loading")
		for position: int in range(1,4):
			var panel: PanelContainer = page.find_child("RivalryPodium_"+str(position),true,false)
			var footer: PanelContainer = page.find_child("RivalryPodiumFooter_"+str(position),true,false)
			var loading: StyleBoxFlat = loading_styles[position][0]
			var actual: StyleBoxFlat = panel.get_theme_stylebox("panel")
			check(actual.bg_color == loading.bg_color and actual.border_color == loading.border_color and actual.shadow_color == loading.shadow_color,"loading and final podium panels have exactly matching colors")
			check(footer.get_theme_stylebox("panel").bg_color == loading_styles[position][1].bg_color,"loading and final footers have exactly matching colors")
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

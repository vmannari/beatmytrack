extends SceneTree
## Fitted geometry, actual Garage taps, atomic persistence and race integration.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/compact-kits-2026-10-13/compatibility"
var metrics: Array[Dictionary] = []

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	for i: int in range(10): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func tap(control: Control) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = control.get_global_rect().get_center()
	touch.pressed = true
	root.push_input(touch,true)
	await process_frame
	touch = touch.duplicate()
	touch.pressed = false
	root.push_input(touch,true)
	await settle()
func geometry(car: CarVisual) -> Dictionary:
	var triangles: int = 0
	var draws: int = 0
	var finite: bool = true
	for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		draws += mesh.mesh.get_surface_count()
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
			for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				if not p.is_finite(): finite = false
	return {"triangles":triangles,"meshes":draws,"finite":finite}

func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var defaults: Dictionary = VehicleCustomisation.defaults()
	check(VehicleCustomisation.valid(defaults),"valid stock schema")
	for category: String in VehicleCustomisation.CATEGORIES:
		var bad: Dictionary = defaults.duplicate(true)
		bad[category] = "unknown"
		check(not VehicleCustomisation.valid(bad),"reject unknown "+category)
	check(not VehicleCustomisation.valid_collection({"pickup":defaults}),"unsupported cars rejected")
	var folder: String = "user://kit_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	page.open_car(0)
	page._show_section("tuning")
	await settle()
	check(page.showroom.reflections.views.size()==2,"reflection views survive Customise/Tuning transfer")
	page.showroom.zoom = 0.70
	page.showroom.elevation = 0.34
	page.showroom._orbit()
	var room: Node = page.showroom.showroom_viewport.find_child("GarageArchitecture",true,false)
	var deck: Node3D = page.showroom.turntable
	var camera: Transform3D = page.showroom.camera.transform
	var pb_key: String = app.records.key_for(app.selected_track,VehicleCatalog.config("compact"))
	var colors: Dictionary = page.showroom.livery.duplicate(true)
	for category: String in VehicleCustomisation.CATEGORIES:
		await tap(page.kit_categories[category])
		check(page.kit_category==category,"touch category "+category)
		check(page.kit_cards.get_child_count()==(13 if category=="aero" else 10),"all choices for "+category)
		for index: int in range(VehicleCustomisation.OPTIONS[category].size()):
			page.kit_scroll.ensure_control_visible(page.kit_cards.get_child(index))
			await settle()
			await tap(page.kit_cards.get_child(index))
			var id: String = VehicleCustomisation.OPTIONS[category][index][0]
			check(page.showroom.car.customisation[category]==id,"touch installs "+category+"/"+id)
			check(page.showroom.camera.transform==camera and page.showroom.turntable==deck,"retained pose/stage "+category+"/"+id)
			check(page.showroom.car.livery==colors,"retained paint "+category+"/"+id)
			var info: Dictionary = geometry(page.showroom.car)
			info["option"] = category+"/"+id
			metrics.append(info)
			check(info.finite and info.meshes<100 and info.triangles<170000,"bounded finite geometry "+category+"/"+id)
			check(page.showroom.car.rolling_wheels.size()==4 and page.showroom.car.front_wheels.size()==2,"articulation "+category+"/"+id)
			for wheel: Vector3 in page.showroom.car.wheel_rest_positions:
				check(is_equal_approx(absf(wheel.x),0.83) and is_equal_approx(absf(wheel.z),1.28),"fitted original wheel pivots")
			await capture(category+"-"+id)
			var reopened := LocalRecords.new(app.records.path)
			reopened.load_records()
			check(VehicleCustomisation.for_car(reopened.settings,"compact")==page.kit_draft,"atomic reload "+category+"/"+id)
	check(page.showroom.showroom_viewport.find_child("GarageArchitecture",true,false)==room,"room retained across kit edits")
	check(app.records.key_for(app.selected_track,VehicleCatalog.config("compact"))==pb_key,"cosmetic kit leaves PB key")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		check(app.root_ui.get_global_rect().encloses(page.actions.get_global_rect()),"actions fit "+str(dimensions))
		check(app.root_ui.get_global_rect().encloses(page.kit_scroll.get_global_rect()),"scrolling parts fit "+str(dimensions))
		check(page.showroom.size.y>=250,"usable showroom "+str(dimensions))
		await capture("tuning-"+str(dimensions.x))
	var saved: Dictionary = page.kit_draft.duplicate(true)
	var saved_path: String = app.records.path
	app.records.path = folder.path_join("missing/records.json")
	page._select_kit("hood","stock")
	check(page.kit_draft==saved and page.showroom.car.customisation==saved,"failed save restores committed kit")
	app.records.path = saved_path
	page._show_section("care")
	page._toggle_wash()
	check(page.showroom.wash_mode,"fitted parts still washable")
	page._show_section("trophies")
	page._show_section("tuning")
	await settle()
	check(page.kit_draft==saved,"navigation retains kit")
	page._show_section("cars")
	await settle()
	check((page.thumbnails.compact as CarShowroom).car.customisation==saved,"carousel shows installed kits")
	page.open_car(1)
	page._show_section("tuning")
	check(page.find_child("CompactKitCards",true,false)==null,"unsupported car has no fitting controls")
	check(VehicleCustomisation.for_car(app.records.settings,"pickup")==defaults,"other car untouched")
	page.open_car(0)
	page._show_section("tuning")
	page._reset_kits()
	check(page.showroom.car.customisation==defaults,"reset restores original parts")
	page._save_kits(saved)
	page._show_section("customise")
	check(page.showroom.reflections.views.size()==2,"reflection views survive Tuning/Customise transfer")
	page._preview_color(Color("945348"),"body")
	page._save()
	check(page.showroom.car.customisation==saved,"paint editing retains fitted parts")
	check(page.showroom.car.paint_materials.body.albedo_color.to_html(false)=="945348","paint applies to fitted body/aero")
	if not LiveryCatalog.patterns.is_empty():
		page._select_livery(page.LIVERY_NAMES.size())
		check(page.showroom.car.customisation==saved and not page.showroom.car.graphics.bindings.is_empty(),"patterned livery remains fitted")
		await capture("merged-livery-kits")
	var game: Node = load("res://core/game.tscn").instantiate()
	game.preference_records = app.records
	game.vehicle_id = "compact"
	game.initial_track = app.selected_track
	game.production_mode = true
	root.add_child(game)
	check(game.car.customisation==saved,"actual race uses local fitted kits")
	check(game.handling.snapshot()==VehicleCatalog.config("compact").snapshot(),"handling remains canonical")
	# Current race startup defers optional ghost geometry until an actual target.
	# Exercise that same preparation path with an isolated presentation fixture.
	game.ghost_mode = "race"
	game.ghost_bests.race = {}
	game._prepare_personal_ghost()
	game.ghost_mode = "off"
	check(game.personal_ghost!=null and game.personal_ghost.mesh!=null,"race ghost uses fitted silhouette")
	app.root_ui.hide()
	await capture("race-installed-kits")
	var victory: Control = preload("res://ui/rivalry_victory_car.gd").new()
	victory.customisation = saved
	root.add_child(victory)
	check(victory.car.customisation==saved,"awards retain installed local kits")
	victory.queue_free()
	game.queue_free()
	var reflections: GarageReflections = page.showroom.reflections
	app.queue_free()
	await process_frame
	check(reflections.views.is_empty(),"real showroom teardown releases reflection views")
	var report := FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"geometry":metrics,"cached_parts":CompactKits.meshes.size(),"cached_images":CompactKitThumbnail.images.size()},"\t"))
	report.close()
	print("COMPACT_KITS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

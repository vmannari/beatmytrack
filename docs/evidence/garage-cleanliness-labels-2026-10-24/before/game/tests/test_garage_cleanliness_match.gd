extends SceneTree
## Real native exteriors: concentrated dirty sides and negligible film residue.
var checks: int = 0
var failures: int = 0
var output: String
var inspector_script: GDScript = preload("res://ui/garage_cleanliness.gd")
var rows: Array[Dictionary] = []
var before: bool = false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func fixture(effect: VehicleWeathering, kind: String) -> Dictionary:
	var wear: Dictionary = effect.snapshot()
	wear.dirt = 0.95
	wear.slow_dirt = 1.0
	wear.snow = 0.0
	wear.slow_snow = 0.0
	wear.mud = 1.0
	var primary := PackedByteArray()
	primary.resize(VehicleCondition.CELLS)
	primary.fill(255)
	var slow: PackedByteArray = primary.duplicate()
	if kind in ["dirty-side","dirty-other-side","snowy-side"]:
		# A substantial central lower-door section on one side, roof washed.
		for y: int in range(16):
			for z: int in range(4,12):
					for x: int in (range(0,5) if kind == "dirty-other-side" else range(11,16)): primary[y*256+z*16+x] = 0
		if kind == "snowy-side":
			wear.dirt = 0.0
			wear.snow = 0.95
	elif kind == "negligible-film":
		# Only nearly removed upper dust remains. Primary dirt is fully gone.
		slow.fill(237)
	elif kind == "light-film":
		wear.dirt = 0.08
		wear.slow_dirt = 0.08
		primary.fill(0)
		slow.fill(0)
	wear.wash = Marshalls.raw_to_base64(primary)
	wear.slow_wash = Marshalls.raw_to_base64(slow)
	return wear

func capture_page() -> void:
	if DisplayServer.get_name() == "headless" or before: return
	var selected: String = VehicleCatalog.selected
	var records := LocalRecords.new(output.path_join("isolated-records.json"))
	VehicleCatalog.selected = "compact"
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	var page := GaragePage.new()
	page.records = records
	root.add_child(page)
	MenuStyle.fill(page)
	for id: String in VehicleCatalog.IDS:
		page._show_section("cars")
		page.open_car(VehicleCatalog.IDS.find(id))
		page.showroom.finish_car_transition()
		page._show_section("care")
		await create_timer(0.45).timeout
		for kind: String in ["dirty-side","negligible-film"]:
			var wear: Dictionary = fixture(page.showroom.weathering,kind)
			check(VehicleCondition.save(records,id,wear) == OK,id+" isolated fixture saves")
			page._process(0.0)
			check(page._wash_status.text == ("Needs a rinse" if kind == "dirty-side" else "Shiny. For now."),id+" live status agrees with the inspection")
			check(page._clean_for_customisation() == (kind != "dirty-side"),id+" editing gate agrees with the live status")
			for angle: float in [-PI*0.5,PI*0.5]:
				page.showroom.yaw = angle
				page.showroom.elevation = 0.16
				page.showroom._orbit()
				page.showroom.invalidate_render()
				for frame: int in range(8): await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output.path_join("%s-%s-%s.png" % [id,kind,"left" if angle < 0.0 else "right"])) == OK,id+" native side capture")
	page.queue_free()
	await process_frame
	VehicleCatalog.selected = selected

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = ProjectSettings.globalize_path("res://../build/garage-cleanliness-match-2026-10-24/probe")
	for argument: String in OS.get_cmdline_user_args():
		# dev.ps1 receives one string from an external PowerShell process.
		for option: String in argument.split(","):
			if option.begins_with("--evidence-root="): output = option.trim_prefix("--evidence-root=")
			if option == "--before":
				before = true
				inspector_script = GDScript.new()
				inspector_script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/garage-cleanliness-match-2026-10-24/before/game/ui/garage_cleanliness.gd").replace("class_name GarageCleanliness","")
				check(inspector_script.reload() == OK,"original inspector compiles")
	DirAccess.make_dir_recursive_absolute(output)
	for id: String in VehicleCatalog.IDS:
		var view := CarShowroom.new()
		view.vehicle_id = id
		root.add_child(view)
		await process_frame
		var inspector: RefCounted = inspector_script.new()
		for kind: String in ["dirty-side","dirty-other-side","snowy-side","negligible-film","light-film","fully-washed"]:
			var wear: Dictionary = fixture(view.weathering,kind)
			view.weathering.restore(wear)
			var label: String = inspector.description(view)
			print(id," ",kind," ",label," mean=",inspector._mean_residue," missed=",inspector._dirty_fraction)
			rows.append({"car":id,"fixture":kind,"label":label,"mean":inspector._mean_residue,"missed":inspector._dirty_fraction})
			if kind in ["dirty-side","dirty-other-side","snowy-side"]: check(not inspector.is_clean(view),id+" "+kind+" prevents a clean status")
			if kind in ["negligible-film","fully-washed"]: check(label == "Shiny. For now.",id+" "+kind+" earns the fully clean status")
			if kind == "light-film": check(label == "Clean enough for company",id+" noticeable light film retains the intermediate grade")
			check(view.weathering.snapshot() == wear,id+" inspection preserves every condition field and mask")
			check(inspector.description(view) == label,id+" repeated cached inspection retains the grade")
			if kind == "dirty-side":
				view.weathering.begin_wash_batch()
				for point: Vector3 in inspector.points: view.weathering.wash(point,8.0)
				view.weathering.end_wash_batch()
				check(inspector.description(view) == "Shiny. For now.",id+" actual local washing refreshes the cached grade")
		view.queue_free()
		await process_frame
	await capture_page()
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":rows},"\t"))
	file.close()
	print("CLEANLINESS_MATCH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends SceneTree
## Read a cosmetic-only copy; never opens or writes the owner's records.
var output: String = "res://../build/wash-easier-2026-10-19"
var condition_file: String = "res://../build/wash-easier-2026-10-19/owner-condition.json"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--condition-file="): condition_file = argument.trim_prefix("--condition-file=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(condition_file))
	var records := LocalRecords.new(output.path_join("unused-records.json"))
	records.settings = {"vehicle_conditions": fixture.conditions, "vehicle_liveries": fixture.liveries, "vehicle_customisation": fixture.customisations}
	VehicleCatalog.selected = "compact"
	root.size = Vector2i(1280,720)
	root.theme = MenuStyle.theme()
	var page := GaragePage.new()
	page.records = records
	root.add_child(page)
	MenuStyle.fill(page)
	page.open_car(0)
	await create_timer(0.8).timeout
	page.showroom.finish_car_transition()
	page._show_section("care")
	var view: CarShowroom = page.showroom
	view.set_process(false)
	var source := GDScript.new()
	source.source_code = FileAccess.get_file_as_string("res://ui/garage_cleanliness.gd").replace("class_name GarageCleanliness", "")
	source.source_code = source.source_code.replace("var points :=", "var locations: Array = []\nvar points :=")
	source.source_code = source.source_code.replace("points.append(point)", "points.append(point)\n\t\t\t\tlocations.append(str(target.get_path()) + ':' + str(surface))")
	assert(source.reload() == OK)
	var inspector: RefCounted = source.new()
	var label: String = inspector.description(view)
	var effect: VehicleWeathering = view.weathering
	var groups: Dictionary = {}
	var rows: Array = []
	for index: int in range(inspector.points.size()):
		var point: Vector3 = inspector.points[index]
		var scope: Vector3 = inspector._scopes[index]
		var primary: float = effect.dirt_amount * scope.x * (1.0 - inspector._washed(point,effect.bounds,effect.wash_image.get_data()))
		var slow: float = effect.slow_dirt_amount * 0.62 * scope.z * (1.0 - inspector._washed(point,effect.bounds,effect.slow_wash_image.get_data()))
		var residue: float = maxf(primary,slow)
		var part: String = inspector.locations[index]
		if not groups.has(part): groups[part] = {"count":0,"missed":0,"total":0.0,"max":0.0}
		groups[part].count += 1
		groups[part].total += residue
		groups[part].max = maxf(groups[part].max,residue)
		if residue > 0.20: groups[part].missed += 1
		rows.append({"part":part,"point":[point.x,point.y,point.z],"primary":primary,"slow":slow,"residue":residue,"scope":[scope.x,scope.y,scope.z]})
	var mismatches: int = 0
	for binding: Dictionary in effect.bindings:
		if binding.node.get_active_material(binding.index) != binding.finish: mismatches += 1
	var report: Dictionary = {"label":label,"mean":inspector._mean_residue,"dirty_fraction":inspector._dirty_fraction,"groups":groups,"points":rows,"material_mismatches":mismatches}
	var file := FileAccess.open(output.path_join("inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("OWNER WASH: ",label," mean=",inspector._mean_residue," missed=",inspector._dirty_fraction)
	for part: String in groups:
		if groups[part].missed > 0: print(part," ",groups[part])
	if DisplayServer.get_name() != "headless":
		for angle: float in [0.0,PI*0.5,PI,PI*1.5]:
			view.yaw = angle
			view.elevation = 0.16
			view._orbit()
			view.invalidate_render()
			for frame: int in range(10): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("owner-%d.png" % roundi(rad_to_deg(angle))))
	page.queue_free()
	await process_frame
	quit()

extends SceneTree
## Actual menu dispatch and first-render timings using isolated local cosmetics.
var output: String = "res://../docs/evidence/garage-customisation-speed-2026-10-13/baseline"
var rows: Array[Dictionary] = []
var app: Node
var page: GaragePage
func _initialize() -> void: _run.call_deferred()
func settle() -> void:
	for i: int in range(6): await process_frame
	await RenderingServer.frame_post_draw
func measure(label: String, action: Callable) -> void:
	var begin: int = Time.get_ticks_usec()
	action.call()
	var dispatch: int = Time.get_ticks_usec()-begin
	await process_frame
	await RenderingServer.frame_post_draw
	var first_render: int = Time.get_ticks_usec()-begin
	rows.append({"action":label,"dispatch_ms":dispatch/1000.0,"first_render_ms":first_render/1000.0})
	print("GARAGE_SWITCH ",rows[-1])
	await settle()
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = "user://garage_speed_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	await settle()
	page = app.root_ui.find_child("GaragePage",true,false)
	await measure("confirm car",page.open_car.bind(0))
	for pass_index: int in range(3):
		for tab: String in ["colours","stickers","livery"]:
			await measure("customise/%s/%d"%[tab,pass_index],page._set_customise_tab.bind(tab))
		await measure("tuning/%d"%pass_index,page._show_section.bind("tuning"))
		for category: String in VehicleCustomisation.CATEGORIES:
			await measure("kit category/%s/%d"%[category,pass_index],page._select_kit_category.bind(category))
		for category: String in VehicleCustomisation.CATEGORIES:
			var options: Array = VehicleCustomisation.OPTIONS[category]
			var id: String = options[(pass_index%2)+1][0]
			await measure("install/%s/%s/%d"%[category,id,pass_index],page._select_kit.bind(category,id))
		await measure("customise return/%d"%pass_index,page._show_section.bind("customise"))
		await measure("livery apply/%d"%pass_index,page._select_livery.bind(4+pass_index))
	await settle()
	root.get_texture().get_image().save_png(output.path_join("final.png"))
	var file := FileAccess.open(output.path_join("timings.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"rows":rows,"scope":"desktop actual dispatch/first render; not phone FPS"},"\t"))
	file.close()
	app.queue_free()
	await process_frame
	print("GARAGE_SWITCH_PROFILE: complete")
	quit()

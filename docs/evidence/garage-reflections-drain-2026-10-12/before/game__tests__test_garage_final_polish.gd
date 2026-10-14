extends SceneTree
## Roof occlusion, fixed platform geometry and workshop-clearance inspection.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-final-polish-2026-10-12/layout"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func draw_frame() -> void:
	for index: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await draw_frame()
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)
func platform(stage: Node3D) -> Array[PackedByteArray]:
	var result: Array[PackedByteArray] = []
	for child: Node in stage.get_children():
		if child is MeshInstance3D and child.material_override is BaseMaterial3D:
			result.append(var_to_bytes(child.mesh.surface_get_arrays(0)))
	return result
func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var directory: String = "user://garage_polish_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	await create_timer(0.4).timeout
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	var view: CarShowroom = page.showroom
	var geometry: Array[PackedByteArray] = platform(view.turntable)
	check(not geometry.is_empty(),"actual prepared platform geometry exists")
	var camera_pose: Transform3D = view.camera.transform
	for index: int in range(VehicleCatalog.IDS.size()):
		page.preview_car(index)
		await create_timer(0.75).timeout
		var id: String = VehicleCatalog.IDS[index]
		check(platform(view.turntable) == geometry,id+" main platform mesh buffers identical")
		check(platform((page.thumbnails[id] as CarShowroom).turntable) == geometry,id+" carousel platform mesh buffers identical")
		check(view.camera.transform.is_equal_approx(camera_pose),id+" car preview retains camera")
		view.reset_view()
		check(view.camera.transform.is_equal_approx(camera_pose),id+" Reset keeps the same platform framing")
		await capture("fixed-platform-"+id)
	page.preview_car(0)
	await create_timer(0.75).timeout
	var room: Node = view.showroom_viewport.find_child("GarageArchitecture",true,false)
	var toolbox: Node3D = room.find_child("GarageCounterToolbox",true,false)
	check(toolbox != null and toolbox.global_position.y+0.22 < 2.45-0.0425,"counter toolbox and handle clear the lowest shelf")
	check(view.roof != null and view.roof.visible and view.roof.find_children("*","MeshInstance3D",true,false).size()>0,"normal view retains prepared ceiling geometry")
	view.elevation = PI*0.36
	view.set_zoom(1.15)
	check(view.camera.position.y > 5.84 and not view.roof.visible,"roof becomes fully transparent when camera is above it")
	check((room.find_child("GarageTrophyWall",true,false) as Node3D).visible,"cutaway preserves the trophy display")
	await capture("roof-cutaway")
	var clear: PackedByteArray = view.showroom_viewport.get_texture().get_image().get_data()
	view.roof.show()
	await draw_frame()
	check(view.showroom_viewport.get_texture().get_image().get_data() != clear,"hidden roof makes a real rendered difference from the blocked view")
	await capture("roof-blocked-diagnostic")
	view.set_zoom(view.zoom)
	check(not view.roof.visible,"next camera update restores the cutaway")
	view.reset_view()
	check(view.roof.visible,"returning below roof restores ceiling")
	await capture("workshop-clearance")
	page._confirm_car()
	page._show_section("trophies")
	await create_timer(0.75).timeout
	check(view.roof.visible and view.trophy_view,"trophy camera retains the low-angle roof")
	page._show_section("care")
	await create_timer(0.75).timeout
	check(view.camera.transform.is_equal_approx(camera_pose),"submenu return keeps original car view")
	app.queue_free()
	await process_frame
	print("GARAGE_FINAL_POLISH: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

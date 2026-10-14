extends SceneTree
## Actual marked props: native full-room and inspection views, isolated cosmetics.
var output: String = "res://../docs/evidence/garage-workshop-detail-2026-10-12/detail"
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)
func capture(label: String) -> void:
	for index: int in range(10): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
func inspect(node: Node, facts: Dictionary) -> void:
	if node is MeshInstance3D:
		facts.meshes += 1
		for index: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			facts.vertices += vertices.size()
			facts.triangles += arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX] != null else vertices.size()/3
			for point: Vector3 in vertices: if not point.is_finite(): facts.finite = false
	for child: Node in node.get_children(): inspect(child,facts)
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1720,914)
	var records := LocalRecords.new("user://workshop_detail_"+TrackLibrary.unique_id()+".json")
	VehicleCatalog.selected = "compact"
	var holder := MarginContainer.new()
	holder.theme = MenuStyle.theme()
	MenuStyle.fill(holder)
	for side: String in ["left","top","right","bottom"]: holder.add_theme_constant_override("margin_"+side,20)
	root.add_child(holder)
	var page := GaragePage.new()
	page.records = records
	holder.add_child(page)
	await capture("showroom-1720")
	var view: CarShowroom = page.showroom
	var room: Node = view.showroom_viewport.find_child("GarageArchitecture",true,false)
	var facts: Dictionary = {"meshes":0,"vertices":0,"triangles":0,"finite":true}
	inspect(room,facts)
	print("WORKSHOP_GEOMETRY ",JSON.stringify(facts))
	check(facts.finite,"prepared workshop mesh vertices finite")
	for name: String in ["WorkshopFluidCan","WorkshopPartsBin","WorkshopBrakePackage","WorkshopToolBag","WorkshopRatchet","WorkshopPliers","WorkshopHammer","WorkshopSquare"]:
		check(room.find_child(name,true,false) != null,"varied equipment present: "+name)
	check(room.find_child("MouldedScrewdriverGrip",true,false) == null,"hand-tool meshes were prepared into material batches")
	var toolbox: Node3D = room.find_child("GarageCounterToolbox",true,false)
	check(toolbox.global_position.y+0.22 < 2.45-0.0425,"detailed handle stays clear of first shelf")
	check(view.zoom == 1.0 and not view.trophy_view,"normal garage view remains default")
	page._confirm_car()
	page._show_section("care")
	root.size = Vector2i(1280,720)
	await capture("selected-car-1280")
	var saved: Transform3D = view.camera.transform
	view.camera.position = Vector3(6.6,1.85,2.8)
	view.camera.look_at(Vector3(6.9,1.25,7.65))
	await capture("left-workshop")
	view.camera.position = Vector3(-6.9,2.3,1.5)
	view.camera.look_at(Vector3(-6.9,2.25,7.85))
	await capture("right-workshop")
	view.camera.position = Vector3(5.35,0.67,5.58)
	view.camera.look_at(Vector3(5.4,0.50,7.08))
	await capture("compressor")
	view.camera.position = Vector3(5.04,1.65,6.1)
	view.camera.look_at(Vector3(5.27,1.26,7.48))
	await capture("vice-tools")
	view.camera.transform = saved
	check(records.settings.get("vehicle_conditions",{}).is_empty(),"inspection creates no condition records")
	page.queue_free()
	await process_frame
	print("GARAGE_WORKSHOP_DETAIL: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

extends SceneTree
## Reference layout inspection using the actual app and isolated clean cosmetics.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-reference-2026-10-12/clean"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)
func capture(label: String) -> void:
	await create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture " + label)
func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = "user://garage_reference_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	await create_timer(0.3).timeout
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	var room: Node = page.showroom.showroom_viewport.find_child("GarageArchitecture",true,false)
	var wall: Node3D = room.find_child("GarageTrophyWall",true,false)
	var poster: Node3D = room.find_child("GarageLeftPoster",true,false)
	check(wall.position.x < -9 and is_equal_approx(wall.rotation.y,-PI*0.5),"display occupies the right-hand side wall")
	check(poster.position.x > 9 and is_equal_approx(poster.rotation.y,PI*0.5),"poster occupies the left-hand side wall")
	for name: String in ["GarageWorkbench","GarageToolStorage","GarageTyreRack","GarageCompressor"]:
		check((room.find_child(name,true,false) as Node3D).position.z > 7,"back wall reserved for " + name)
	check(wall.find_children("AwardSlot_*","Node3D",true,false).size() == 6,"future trophy display retains six unearned-empty spaces")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720),Vector2i(1720,914)]:
		root.size = dimensions
		await capture("garage-"+str(dimensions.x))
		print("GARAGE_RENDER_SIZE ",dimensions," control=",page.showroom.size," render=",page.showroom.showroom_viewport.size)
		check(app.root_ui.get_global_rect().encloses(page.select_button.get_global_rect()),"Select car fits " + str(dimensions))
		if dimensions.x >= 1600:
			check(page.gallery.get_global_rect().encloses((page.cards.get_child(4) as Control).get_global_rect()),"all five model cards visible at wide reference size")
	root.size = Vector2i(1280,720)
	for index: int in range(VehicleCatalog.IDS.size()):
		page.preview_car(index)
		await capture("car-"+VehicleCatalog.IDS[index])
	page._confirm_car()
	page._show_section("trophies")
	await create_timer(0.8).timeout
	await capture("trophy-wall")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1600,720),Vector2i(1720,914)]:
		root.size = dimensions
		await capture("trophy-wall-"+str(dimensions.x))
	root.size = Vector2i(1280,720)
	await capture("trophy-wall")
	var finishes: Array[ShaderMaterial] = []
	for mesh: Node in room.find_children("*","MeshInstance3D",true,false):
		var instance := mesh as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material: Material = instance.get_active_material(surface)
			if material is ShaderMaterial and material.shader == preload("res://ui/garage_display_stone.gdshader") and not finishes.has(material): finishes.append(material)
	check(not finishes.is_empty(),"stone reflective finish found in prepared wall")
	var reflected: Image = root.get_texture().get_image()
	for finish: ShaderMaterial in finishes: finish.set_shader_parameter("wall_reflections_enabled",false)
	await capture("wall-reflections-off")
	var matte: Image = root.get_texture().get_image()
	var changed: int = 0
	for y: int in range(200,570):
		for x: int in range(188,1160):
			var a: Color = reflected.get_pixel(x,y)
			var b: Color = matte.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.015: changed += 1
	check(changed > 100,"reflections visibly change stone pixels")
	print("WALL_REFLECTION_CHANGED_PIXELS ",changed)
	for finish: ShaderMaterial in finishes: finish.set_shader_parameter("wall_reflections_enabled",true)

	page._show_section("customise")
	await create_timer(0.8).timeout
	await capture("customise")
	check(app.records.settings.get("vehicle_conditions",{}).is_empty(),"clean reference captures do not create cosmetic records")
	app.queue_free()
	await process_frame
	print("GARAGE_REFERENCE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

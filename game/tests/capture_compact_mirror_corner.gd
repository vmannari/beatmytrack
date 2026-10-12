extends SceneTree
## Actual app feature inspection; no owner records or remote requests.
func _initialize() -> void:_capture.call_deferred()
func _capture() -> void:
	OS.set_environment("BMT_API_URL","")
	var directory: String="user://compact_mirror_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(directory.path_join("records.json"))
	app.library=TrackLibrary.new(directory)
	app.cloud_root_override=directory.path_join("cloud")
	root.size=Vector2i(1280,720)
	root.add_child(app)
	while not app.startup_complete:await process_frame
	VehicleCatalog.selected="compact"
	app._show_screen("garage")
	await create_timer(0.45).timeout
	var view: CarShowroom=app.root_ui.find_child("GarageShowroom",true,false)
	var bounds: AABB
	var first: bool=true
	for key: String in CompactCoachwork.meshes:
		if key.begins_with("mirror_left") and "glass" not in key:
			var mesh: ArrayMesh=CompactCoachwork.meshes[key]
			bounds=mesh.get_aabb() if first else bounds.merge(mesh.get_aabb())
			first=false
	print("MIRROR_HOUSING_METRES ",bounds.size," HEIGHT_RATIO ",bounds.size.y/0.11," DEPTH_RATIO ",bounds.size.z/0.128)
	var output: String="res://../docs/evidence/compact-mirrors-2026-10-10"
	for pose: Array in [["mirror-side",Vector3(0.932,1.065,-0.74),Vector3(1.0,0.45,0.65)],["mirror-top",Vector3(0.932,1.065,-0.74),Vector3(0.6,1.2,-0.7)],["front-corner",Vector3(0.76,0.96,-1.99),Vector3(1.0,0.55,-0.9)]]:
		var target: Vector3=pose[1]*HandlingConfig.BODY_SCALE
		view.camera.fov=30
		view.camera.position=target+(pose[2] as Vector3)
		view.camera.look_at(target)
		for frame: int in range(12):await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output.path_join(str(pose[0])+"-1280.png"))!=OK:
			quit(1)
			return
	app.queue_free()
	await process_frame
	print("COMPACT_MIRROR_CORNER_CAPTURE: 3 views saved")
	quit()

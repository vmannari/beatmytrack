extends SceneTree
## Offline photographs of the actual Rivalry podium renderer, fitted to paper.
const VictoryCar = preload("res://ui/rivalry_victory_car.gd")
const PHOTO_SIZE := Vector2i(640,400)
const FILL: float = 0.80
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func vertices(node: Node, result: PackedVector3Array) -> void:
	if node is Node3D and not node.is_visible_in_tree(): return
	if node is MeshInstance3D and node.mesh != null:
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: result.append(node.global_transform*vertex)
	for child: Node in node.get_children(): vertices(child,result)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native rendering is required to bake news photographs.")
		quit(1)
		return
	# Each chassis is built once; rest-scene caches add no value to this bake.
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	var directory: String = "res://assets/news/vehicles"
	var evidence: String = "res://../docs/evidence/garage-news-rivalry-view-2026-10-17"
	var only_vehicle: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): evidence = argument.trim_prefix("--evidence-root=")
		if argument.begins_with("--vehicle="): only_vehicle = argument.trim_prefix("--vehicle=")
	assert(only_vehicle.is_empty() or only_vehicle in VehicleCatalog.IDS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	var viewport := SubViewport.new()
	viewport.size = PHOTO_SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("363b3d")
	background.size = Vector2(PHOTO_SIZE)
	viewport.add_child(background)
	var report: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),"size":[PHOTO_SIZE.x,PHOTO_SIZE.y],"fill":FILL,"view_source":"res://ui/rivalry_victory_car.gd","cars":[]}
	for id: String in VehicleCatalog.IDS:
		if not only_vehicle.is_empty() and id != only_vehicle: continue
		var view := VictoryCar.new()
		view.vehicle_id = id
		view.podium_presentation = true
		view.simple_model = true
		view.livery = VehicleLivery.defaults(id)
		view.livery.colors.body = GaragePage.LIVERY_COLORS[0][0]
		view.livery.colors.accent = GaragePage.LIVERY_COLORS[0][1]
		view.customisation = VehicleCustomisation.defaults()
		view.size = Vector2(PHOTO_SIZE)
		viewport.add_child(view)
		# Let the renderer finish its existing bounded radiance preparation.
		for frame: int in range(6):
			await process_frame
			await RenderingServer.frame_post_draw
		var camera: Camera3D = view.viewport.find_children("*","Camera3D",true,false)[0]
		var rivalry_pose: Transform3D = camera.transform
		var rivalry_fov: float = camera.fov
		var inner_size := Vector2(view.viewport.size)
		var points := PackedVector3Array()
		vertices(view.car,points)
		var projected := Rect2(camera.unproject_position(points[0]),Vector2.ZERO)
		for point: Vector3 in points: projected = projected.expand(camera.unproject_position(point))
		var extent: Vector2 = projected.size/inner_size
		# Zoom only. Keep the exact camera transform, perspective and PI car pose.
		camera.fov = rad_to_deg(2.0*atan(tan(deg_to_rad(rivalry_fov)*0.5)*maxf(extent.x,extent.y)/FILL))
		projected = Rect2(camera.unproject_position(points[0]),Vector2.ZERO)
		for point: Vector3 in points: projected = projected.expand(camera.unproject_position(point))
		projected = Rect2(projected.position/inner_size*Vector2(PHOTO_SIZE),projected.size/inner_size*Vector2(PHOTO_SIZE))
		# A canvas offset centers the complete car without moving the 3D camera.
		view.position = Vector2(PHOTO_SIZE)*0.5-projected.get_center()
		projected.position += view.position
		view._refresh()
		for frame: int in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var error: Vector2 = projected.get_center()-Vector2(PHOTO_SIZE)*0.5
		var margins: Array[float] = [projected.position.x,projected.position.y,PHOTO_SIZE.x-projected.end.x,PHOTO_SIZE.y-projected.end.y]
		var centered: bool = error.length() <= 0.1 and margins.min() >= PHOTO_SIZE.y*0.099
		var matched: bool = camera.transform == rivalry_pose and camera.projection == Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(view.car.rotation.y,PI) and view.car.simple_model
		if not centered or not matched: failures += 1
		var pixels: Image = viewport.get_texture().get_image()
		pixels.convert(Image.FORMAT_RGB8)
		var path: String = directory.path_join(id+".png")
		if pixels.save_png(path) != OK: failures += 1
		report.cars.append({"vehicle_id":id,"path":path,"sha256":FileAccess.get_sha256(path),"vertices":points.size(),"bounds":[projected.position.x,projected.position.y,projected.size.x,projected.size.y],"center_error_px":[error.x,error.y],"margins_px":margins,"centered_unclipped":centered,"matched_rivalry_view":matched,"camera_transform":str(camera.transform),"rivalry_fov":rivalry_fov,"fitted_fov":camera.fov,"canvas_offset":[view.position.x,view.position.y],"source_viewport":[view.viewport.size.x,view.viewport.size.y]})
		view.queue_free()
		await process_frame
	var file := FileAccess.open(evidence.path_join("framing.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	viewport.queue_free()
	for frame: int in range(20): await process_frame
	print("NEWS PHOTO FRAMING: %d cars, %d failures" % [report.cars.size(),failures])
	quit(1 if failures else 0)

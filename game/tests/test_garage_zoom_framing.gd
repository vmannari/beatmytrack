extends SceneTree
## GZF01-GZF02: zoom keeps cars visible without restoring car-dependent framing.
var checks: int = 0
var failures: int = 0
var output: String
var page: GaragePage
var samples: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func frames(count: int = 8) -> void:
	for frame: int in range(count): await process_frame

func corners() -> PackedVector3Array:
	var result := PackedVector3Array()
	for mesh: MeshInstance3D in page.showroom.car.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var box: AABB = mesh.mesh.get_aabb()
		for i: int in range(8): result.append(mesh.global_transform*box.get_endpoint(i))
	return result

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = ProjectSettings.globalize_path("res://../docs/evidence/garage-zoom-framing-2026-11-16/default")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = ProjectSettings.globalize_path(argument.trim_prefix("--evidence-root="))
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = ProjectSettings.globalize_path("res://../build/garage-zoom-framing-20261116/profile-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	records.settings = {"music_enabled":false,"selected_car":"compact"}
	VehicleCatalog.selected = "compact"
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	page = GaragePage.new()
	page.records = records
	page.cached_carousel = true
	page.preview_can_render = func() -> bool: return false
	root.add_child(page)
	MenuStyle.fill(page)
	while not page.showroom.showroom_ready: await process_frame
	page._finish_menu_move()
	await frames()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(2400,1066),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frames(12)
		var shared_cameras: Dictionary = {}
		for index: int in range(VehicleCatalog.IDS.size()):
			page.preview_car(index)
			page.showroom.finish_car_transition()
			await frames(2)
			var view: CarShowroom = page.showroom
			var maximum_radius: float = 0.0
			var height: float = 0.0
			for point: Vector3 in corners():
				maximum_radius = maxf(maximum_radius,Vector2(point.x,point.z).length())
				height = maxf(height,point.y)
			print("CAR_ENVELOPE ",view.vehicle_id," radius=",maximum_radius," height=",height)
			check(maximum_radius < 2.55 and height < 2.85,"stock geometry stays inside shared clearance "+view.vehicle_id)
			for zoom: float in [1.0,0.75,CarShowroom.MIN_ZOOM,CarShowroom.MAX_ZOOM]:
				for pose: Vector2 in [Vector2(-0.7,atan(0.16)),Vector2(PI/2,atan(0.16)),Vector2(0,CarShowroom.MAX_ELEVATION)]:
					view.yaw = pose.x
					view.elevation = pose.y
					view.set_zoom(zoom)
					var key: String = str(zoom)+str(pose)
					var state: Array = [view.camera.transform,view.camera.h_offset]
					if not shared_cameras.has(key): shared_cameras[key] = state
					check(shared_cameras[key] == state,"same camera across cars "+view.vehicle_id+" "+key)
					var rect := Rect2()
					var first: bool = true
					var in_front: bool = true
					for point: Vector3 in corners():
						in_front = in_front and not view.camera.is_position_behind(point)
						var pixel: Vector2 = view.camera.unproject_position(point)*view.size/Vector2(view.showroom_viewport.size)
						rect = Rect2(pixel,Vector2.ZERO) if first else rect.expand(pixel)
						first = false
					var safe := Rect2(Vector2(0,8),view.size-Vector2(8,40))
					check(in_front and safe.encloses(rect),"whole car visible "+view.vehicle_id+" "+str(dimensions)+" "+key+" rect="+str(rect)+" safe="+str(safe))
					check(rect.position.x > page._car_stats.get_rect().end.x+8,"zoom clears stats "+view.vehicle_id+" "+key)
					samples.append({"car":view.vehicle_id,"size":str(dimensions),"zoom":zoom,"pose":str(pose),"rect":str(rect)})
					if dimensions.x == 2400 and is_equal_approx(zoom,CarShowroom.MIN_ZOOM) and pose.x < 0 and DisplayServer.get_name() != "headless":
						for frame: int in range(8):
							view.invalidate_render()
							await process_frame
						await RenderingServer.frame_post_draw
						check(root.get_texture().get_image().save_png(output.path_join(view.vehicle_id+"-zoom-in.png")) == OK,"capture zoom "+view.vehicle_id)
			view.yaw = -0.7
			view.elevation = atan(0.16)
			view.set_zoom(1.0)
			var home: Transform3D = view.camera.transform
			view.set_zoom(CarShowroom.MIN_ZOOM)
			var closest: Transform3D = view.camera.transform
			check(not home.is_equal_approx(closest),"zoom in enlarges the car "+view.vehicle_id)
			var wheel := InputEventMouseButton.new()
			wheel.position = view.size*0.65
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			view.gui_input.emit(wheel)
			check(closest.is_equal_approx(view.camera.transform),"wheel cannot pass safe zoom limit "+view.vehicle_id)
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			view.gui_input.emit(wheel)
			check(not closest.is_equal_approx(view.camera.transform),"wheel zoom-out responds immediately after limit "+view.vehicle_id)
			view.set_zoom(CarShowroom.MIN_ZOOM)
			closest = view.camera.transform
			var center: Vector2 = view.size*0.65
			for finger: int in range(2):
				var touch := InputEventScreenTouch.new()
				touch.index = finger
				touch.position = center+Vector2(-50 if finger==0 else 50,0)
				touch.pressed = true
				view.gui_input.emit(touch)
			var pinch := InputEventScreenDrag.new()
			pinch.index = 1
			pinch.position = center+Vector2(150,0)
			pinch.relative = Vector2(100,0)
			view.gui_input.emit(pinch)
			check(closest.is_equal_approx(view.camera.transform),"pinch cannot pass safe zoom limit "+view.vehicle_id)
			pinch.position = center+Vector2(50,0)
			pinch.relative = Vector2(-100,0)
			view.gui_input.emit(pinch)
			check(not closest.is_equal_approx(view.camera.transform),"pinch zoom-out responds immediately after limit "+view.vehicle_id)
			for finger: int in range(2):
				var touch := InputEventScreenTouch.new()
				touch.index = finger
				touch.position = center+Vector2(-50 if finger==0 else 50,0)
				view.gui_input.emit(touch)
	page.queue_free()
	await frames()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"\t"))
	print("GARAGE_ZOOM_FRAMING ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)

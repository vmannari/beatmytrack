extends SceneTree
## Review-only native views. No saves, model edits, or visual acceptance assertions.
const COACH = preload("res://vehicle/electric_coachwork.gd")
var output: String = "res://../docs/evidence/electric-rear-redesign-2026-10-28/native"
var report: Dictionary = {"captures":[],"geometry":{}}
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for frame: int in range(6): await process_frame
	await RenderingServer.frame_post_draw

func capture(viewport: SubViewport, label: String) -> void:
	await settle()
	var result: Error = viewport.get_texture().get_image().save_png(output.path_join(label+".png"))
	if result != OK: failures += 1
	report.captures.append({"name":label,"save_error":result})

func measure(car: CarVisual) -> Dictionary:
	var bounds := AABB()
	var first: bool = true
	var count: int = 0
	var meshes: int = 0
	var groups: Dictionary = {}
	for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		meshes += 1
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		var triangles: int = faces.size()/3
		count += triangles
		var group: String = "wheels" if not car.body.is_ancestor_of(mesh) else "body_and_cabin"
		groups[group] = int(groups.get(group,0))+triangles
		for point: Vector3 in faces:
			var world_point: Vector3 = mesh.global_transform*point
			if first:
				bounds = AABB(world_point,Vector3.ZERO)
				first = false
			else: bounds = bounds.expand(world_point)
	var wheels: Array = []
	for wheel: Vector3 in car.wheel_rest_positions: wheels.append([wheel.x*HandlingConfig.BODY_SCALE,wheel.y*HandlingConfig.BODY_SCALE,wheel.z*HandlingConfig.BODY_SCALE])
	return {"triangles":count,"mesh_instances_unbatched":meshes,"groups":groups,
		"world_aabb_min":[bounds.position.x,bounds.position.y,bounds.position.z],
		"world_aabb_size":[bounds.size.x,bounds.size.y,bounds.size.z],
		"wheel_centres_world":wheels,"wheelbase_metres":COACH.AXLE*2*HandlingConfig.BODY_SCALE,
		"wheel_diameter_metres":0.74*HandlingConfig.BODY_SCALE}

func garage_review() -> void:
	var showroom:=CarShowroom.new()
	showroom.vehicle_id="electric"
	showroom.read_only=true
	showroom.garage_mode=true
	showroom.framing_scale=0.75
	showroom.livery=VehicleLivery.defaults("electric")
	showroom.customisation=VehicleCustomisation.defaults()
	showroom.size=Vector2(1280,720)
	root.add_child(showroom)
	while not showroom.showroom_ready: await process_frame
	showroom.yaw=2.25
	showroom.zoom=0.85
	showroom.elevation=atan(0.16)
	showroom._orbit()
	for worn: bool in [false,true]:
		if worn: showroom.weathering.restore({"dirt":0.38,"slow_dirt":0.12,"mud":0.09,"smudge":0.02,"color":"463225"})
		for frame: int in range(8):
			showroom.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			showroom.reflections.request_draw()
			await process_frame
			await RenderingServer.frame_post_draw
		await capture(showroom.showroom_viewport,"garage-rear-"+("worn" if worn else "clean"))
	showroom.queue_free()
	await process_frame

func run() -> void:
	if "--before" in OS.get_cmdline_user_args():
		preload("res://ui/garage_car_cache.gd").enabled=false
		preload("res://vehicle/prepared_car_cache.gd").enabled=false
		var author: GDScript=COACH
		author.source_code=FileAccess.get_file_as_string("res://../docs/evidence/electric-rear-redesign-2026-10-28/before/game/vehicle/electric_coachwork.gd")
		assert(author.reload()==OK)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1440,900)
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["source_sha256"] = FileAccess.get_sha256("res://../docs/evidence/electric-rear-redesign-2026-10-28/before/game/vehicle/electric_coachwork.gd" if "--before" in OS.get_cmdline_user_args() else "res://vehicle/electric_coachwork.gd")
	report["before"] = "--before" in OS.get_cmdline_user_args()
	report["model_sha256"] = FileAccess.get_sha256("res://vehicle/electric_car_model.gd")
	for simple: bool in [false,true]:
		var label: String = "simple" if simple else "full"
		var world := Node3D.new()
		viewport.add_child(world)
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.livery = VehicleLivery.defaults("electric")
		car.livery.colors.body = "777f86"
		car.livery.colors.accent = "777f86"
		world.add_child(car)
		report.geometry[label] = measure(car)
		ShowroomStudio.build(world,car)
		var camera := Camera3D.new()
		camera.fov = 32
		camera.current = true
		world.add_child(camera)
		var shots: Array = [
			["front-quarter",Vector3(-4.2,2.5,-5.9),Vector3(0,0.65,0),0.0],
			["rear-quarter",Vector3(4.2,2.4,5.9),Vector3(0,0.65,0),0.0],
			["rear-low",Vector3(-4.6,1.55,4.4),Vector3(0,0.75,0.75),0.0],
			["side",Vector3(-8,0.7,0),Vector3(0,0.7,0),3.35],
			["front",Vector3(0,0.85,-8),Vector3(0,0.85,0),2.55],
			["rear",Vector3(0,0.85,8),Vector3(0,0.85,0),2.55],
			["top",Vector3(0,8,0.001),Vector3(0,0,0),5.0],
			["bonnet",Vector3(-1.8,2.8,-3.8),Vector3(0,0.78,-1.3),0.0],
			["roof",Vector3(-2.8,3.2,3.4),Vector3(0,0.9,0.2),0.0],
			["wheel",Vector3(-2.3,0.65,-1.9),Vector3(-0.74,0.35,-1.23),0.0],
			["tail-detail",Vector3(1.8,1.25,4.0),Vector3(0,0.55,1.85),0.0]]
		for shot: Array in shots:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL if float(shot[3])>0 else Camera3D.PROJECTION_PERSPECTIVE
			if float(shot[3])>0: camera.size = float(shot[3])
			camera.position = shot[1]
			camera.look_at(shot[2])
			await capture(viewport,label+"-"+str(shot[0]))
		camera.current = false
		var follow := FollowCamera.new()
		world.add_child(follow)
		follow.follow(Vector2.ZERO,Vector2.ZERO,0,0,true)
		follow.current = true
		await capture(viewport,label+"-production-camera-studio")
		world.free()
	viewport.free()
	await garage_review()
	report["failures"] = failures
	var file := FileAccess.open(output.path_join("capture-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("ELECTRIC_DESIGN_REVIEW: %d captures, %d save failures; geometry %s" % [report.captures.size(),failures,JSON.stringify(report.geometry)])
	quit(1 if failures else 0)

extends SceneTree
## Offline alpha masks from current production meshes in the actual podium pose.
const TILE := Vector2i(384,256)
const OUTPUT: String = "res://assets/menu/rivalry_loading_cars_v1.png"
const EVIDENCE: String = "res://../docs/evidence/rivalry-loading-model-silhouettes-2026-11-02"
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Silhouette baking requires a native renderer.")
		quit(1)
		return
	root.position = Vector2i(-12000,-12000)
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	var viewport := SubViewport.new()
	viewport.size = TILE*2
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(-5,2.5,6)
	world.add_child(camera)
	camera.look_at(Vector3(0,0.65,0))
	camera.current = true
	var pigment := StandardMaterial3D.new()
	pigment.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pigment.albedo_color = Color.WHITE
	var atlas := Image.create(TILE.x*VehicleCatalog.IDS.size(),TILE.y,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var report: Dictionary = {"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"source":"res://vehicle/car_visual.gd","pose":"res://ui/rivalry_victory_car.gd","tile":[TILE.x,TILE.y],"cars":[],"sources":{}}
	for file: String in DirAccess.get_files_at("res://vehicle"):
		if file.ends_with(".gd") or file.ends_with(".gdshader"): report.sources["vehicle/"+file] = FileAccess.get_sha256("res://vehicle/"+file)
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		var car := CarVisual.new()
		car.vehicle_id = id
		car.simple_model = true
		car.cache_rest_pose = false
		car.rotation.y = PI
		car.customisation = VehicleCustomisation.defaults()
		world.add_child(car)
		while not car.model_ready: await process_frame
		car.force_update_transform()
		var extent: float = 0.0
		var mesh_count: int = 0
		var camera_space: Transform3D = camera.global_transform.affine_inverse()
		for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
			if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				mesh.hide()
				continue
			mesh.material_override = pigment
			mesh.material_overlay = null
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.force_update_transform()
			mesh_count += 1
			var bounds: AABB = mesh.get_aabb()
			for x: float in [bounds.position.x,bounds.end.x]:
				for y: float in [bounds.position.y,bounds.end.y]:
					for z: float in [bounds.position.z,bounds.end.z]:
						var point: Vector3 = camera_space*mesh.to_global(Vector3(x,y,z))
						var depth: float = maxf(0.01,-point.z)
						extent = maxf(extent,maxf(absf(point.y)/depth,absf(point.x)/(depth*float(TILE.x)/TILE.y)))
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = rad_to_deg(2.0*atan(extent*1.15))
		for frame: int in range(4):
			await process_frame
			await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var occupied: Rect2i = image.get_used_rect()
		if occupied.size.x == 0 or occupied.size.y == 0 or occupied.position.x <= 0 or occupied.position.y <= 0 or occupied.end.x >= image.get_width() or occupied.end.y >= image.get_height(): failures += 1
		var shape: Image = image.get_region(occupied)
		var scale_factor: float = minf(float(TILE.x-40)/shape.get_width(),float(TILE.y-36)/shape.get_height())
		shape.resize(roundi(shape.get_width()*scale_factor),roundi(shape.get_height()*scale_factor),Image.INTERPOLATE_LANCZOS)
		var offset: Vector2i = (TILE-shape.get_size())/2
		atlas.blit_rect(shape,Rect2i(Vector2i.ZERO,shape.get_size()),Vector2i(index*TILE.x,0)+offset)
		report.cars.append({"vehicle":id,"tile_index":index,"mesh_instances":mesh_count,"camera_transform":str(camera.transform),"fov":camera.fov,"rotation_y":car.rotation.y,"source_bounds":str(occupied),"mask_bounds":str(Rect2i(offset,shape.get_size()))})
		car.free()
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	if atlas.save_png(OUTPUT) != OK: failures += 1
	report.output = OUTPUT
	report.sha256 = FileAccess.get_sha256(OUTPUT)
	report.failures = failures
	var file := FileAccess.open(EVIDENCE.path_join("bake.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	viewport.free()
	print("RIVALRY_SILHOUETTES_BAKE: %d cars, %d failures" % [report.cars.size(),failures])
	quit(1 if failures else 0)

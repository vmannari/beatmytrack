extends SceneTree
## Offline photographs and paint masks from the actual production car geometry.
const SIZE := Vector2i(512,320)
const OUTPUT: String = "res://assets/menu/rivalry_cars_v2"
var evidence: String = OS.get_environment("BMT_REAL_CAR_EVIDENCE")
var failures: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("BAKE_FAIL ",label)

func drawn() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func mask_material(color: Color, source: Material) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = source.cull_mode if source is BaseMaterial3D else BaseMaterial3D.CULL_DISABLED
	return material

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute(evidence)
	var report: Dictionary = {"schema":"rivalry-actual-car-photos-2","engine":Engine.get_version_info().string,"size":[SIZE.x,SIZE.y],"neutral":"808080","baker_sha256":FileAccess.get_sha256("res://tests/bake_rivalry_car_previews.gd"),"cars":{},"source":"Canonical reduced CarVisual construction; stock kits; original mesh positions/normals/UVs; original materials and Garage lighting"}
	for id: String in VehicleCatalog.IDS:
		var only: String = OS.get_environment("BMT_REAL_CAR_ONLY")
		if not only.is_empty() and id!=only: continue
		var viewport := SubViewport.new()
		viewport.size = SIZE*2
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		var car := CarVisual.new()
		car.vehicle_id = id
		car.simple_model = true
		car.cache_rest_pose = false
		car.rotation.y = PI
		car.livery = VehicleLivery.defaults(id)
		car.customisation = VehicleCustomisation.defaults()
		world.add_child(car)
		while not car.model_ready: await process_frame
		GarageEnvironment.build_lighting(world,false,true)
		ShowroomStudio._studio_glass(car,{})
		var camera := Camera3D.new()
		camera.position = Vector3(-5,2.5,6)
		world.add_child(camera)
		camera.look_at(Vector3(0,0.65,0))
		camera.current = true
		var view: Transform3D = camera.global_transform.affine_inverse()
		var extent: float = 0
		var mesh_count: int = 0
		var triangles: int = 0
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null or not part.is_visible_in_tree(): continue
			if part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: part.hide(); continue
			part.force_update_transform()
			mesh_count += 1
			triangles += part.mesh.get_faces().size()/3
			var bounds: AABB = part.get_aabb()
			for x: float in [bounds.position.x,bounds.end.x]:
				for y: float in [bounds.position.y,bounds.end.y]:
					for z: float in [bounds.position.z,bounds.end.z]:
						var point: Vector3 = view*part.to_global(Vector3(x,y,z))
						var depth: float = maxf(0.01,-point.z)
						extent = maxf(extent,maxf(absf(point.y)/depth,absf(point.x)/(depth*float(SIZE.x)/SIZE.y)))
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = rad_to_deg(2*atan(extent*1.10))
		for _i: int in range(5): await drawn()
		var reference: Image = viewport.get_texture().get_image()
		check(reference.get_used_rect().size.x>100,id+" actual native geometry is visible")
		var neutral: Dictionary = VehicleLivery.defaults(id)
		for role: String in VehicleLivery.SLOTS: neutral.colors[role] = "808080"
		car.apply_livery(neutral)
		for _i: int in range(3): await drawn()
		var base: Image = viewport.get_texture().get_image()
		var slots: Dictionary = {}
		for slot: String in car.paint_materials: slots[car.paint_materials[slot]] = slot
		if car.accent_roof!=null: slots[car.accent_roof] = "accent"
		for variant: Dictionary in car.paint_variants: slots[variant.material] = variant.slot
		var mask_colors: Dictionary = {"body":Color.RED,"accent":Color.GREEN,"detail":Color.BLUE}
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null or not part.is_visible_in_tree(): continue
			var active: Array[Material] = []
			for surface: int in range(part.mesh.get_surface_count()): active.append(part.get_active_material(surface))
			part.material_override = null
			part.material_overlay = null
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface: int in range(active.size()):
				var source: Material = active[surface]
				var original: Material = source.get_meta("livery_source") if source!=null and source.has_meta("livery_source") else source
				part.set_surface_override_material(surface,mask_material(mask_colors.get(slots.get(original,""),Color.BLACK),original))
		for _i: int in range(3): await drawn()
		var mask: Image = viewport.get_texture().get_image()
		for image: Image in [reference,base,mask]:
			image.convert(Image.FORMAT_RGBA8)
			image.resize(SIZE.x,SIZE.y,Image.INTERPOLATE_LANCZOS)
		# Downsample coverage in premultiplied form, then store straight-alpha
		# colour for ordinary canvas sampling. Leave mask coverage premultiplied.
		for image: Image in [reference,base]:
			for y: int in range(SIZE.y):
				for x: int in range(SIZE.x):
					var pixel: Color = image.get_pixel(x,y)
					if pixel.a>0.001 and pixel.a<0.999:
						image.set_pixel(x,y,Color(minf(1,pixel.r/pixel.a),minf(1,pixel.g/pixel.a),minf(1,pixel.b/pixel.a),pixel.a))
		var reference_path: String = evidence.path_join(id+"-actual.png")
		check(reference.save_png(reference_path)==OK,id+" reference saved")
		check(base.save_png(evidence.path_join(id+"-neutral.png"))==OK,id+" neutral saved")
		check(mask.save_png(evidence.path_join(id+"-mask.png"))==OK,id+" masks saved")
		var files: Dictionary = {}
		for item: Array in [["image",base],["mask",mask]]:
			var image: Image = item[1]
			image.generate_mipmaps()
			var texture := ImageTexture.create_from_image(image)
			texture.set_meta("schema","rivalry-actual-car-photos-2")
			texture.set_meta("vehicle_id",id)
			texture.set_meta("image_role",str(item[0]))
			texture.set_meta("paint_defaults",VehicleLivery.defaults(id).colors)
			texture.set_meta("baker_sha256",report.baker_sha256)
			var path: String = OUTPUT.path_join(id+"_"+str(item[0])+".res")
			check(ResourceSaver.save(texture,path,ResourceSaver.FLAG_COMPRESS)==OK,id+" texture saved")
			files[item[0]] = FileAccess.get_sha256(path)
		report.cars[id] = {"meshes":mesh_count,"source_triangles":triangles,"fov":camera.fov,"rotation_y":car.rotation.y,"hashes":files,"default_paint":VehicleLivery.defaults(id).colors,"reference_sha256":FileAccess.get_sha256(reference_path)}
		viewport.free()
		await process_frame
		print("ACTUAL_CAR_BAKED ",id," ",JSON.stringify(report.cars[id]))
	FileAccess.open(evidence.path_join("bake.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ACTUAL_CAR_BAKE ",report.cars.size()," cars, ",failures," failures")
	quit(1 if failures else 0)

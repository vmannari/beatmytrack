extends SceneTree
## PL01-PL04: native five-panel art review. Isolated from owner saves and commerce.
const OUT: String = "res://../docs/evidence/artistic-liveries-2026-11-15"
var checks: int = 0
var failures: int = 0
var frames: Array = []
var stock_frames: Array = []
var output: String

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ARTISTIC_FAIL ",label)

func value_for(item: Dictionary) -> Dictionary:
	var value: Dictionary = VehicleLivery.defaults(item.vehicle)
	value.pattern = item.id
	for i: int in range(3): value.colors[VehicleLivery.SLOTS[i]] = item.colours[i]
	return value

func mesh_signature(car: CarVisual) -> Array:
	var result: Array = []
	for node: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		result.append([str(node.get_path()),node.mesh.get_instance_id(),node.transform])
	return result

func draw_frame() -> void:
	for i: int in range(6): await process_frame
	await RenderingServer.frame_post_draw

func legacy_pixels(car: CarVisual, camera: Camera3D, viewport: SubViewport, vehicle: String) -> void:
	var target := Vector3(0,0.78 if vehicle=="forklift" else 0.43,0)
	camera.size = 4.5*(0.73 if vehicle=="kart" else 1.17 if vehicle=="forklift" else 1.0)
	camera.position = target+Vector3(-5,3.5,-7)
	camera.look_at(target)
	await draw_frame()
	var current_image: Image = viewport.get_texture().get_image()
	var stable: bool = false
	for attempt: int in range(8):
		await draw_frame()
		var repeated: Image = viewport.get_texture().get_image()
		stable = current_image.get_data()==repeated.get_data()
		current_image = repeated
		if stable: break
	check(stable,"stable original-program reference before comparison "+vehicle)
	var current: PackedByteArray = current_image.get_data()
	var saved_shaders: Array = []
	var saved_uniforms: Array = []
	var old_shaders: Dictionary = {}
	var previous_include: String = FileAccess.get_file_as_string(OUT.path_join("before/livery_finish.gdshaderinc"))
	check(FileAccess.get_file_as_string("res://vehicle/livery_finish.gdshaderinc")==previous_include,"original released shader include is byte-exact "+vehicle)
	check(FileAccess.get_file_as_string("res://vehicle/livery_finish.gdshader")==FileAccess.get_file_as_string(OUT.path_join("before/livery_finish.gdshader")),"original released shader source is byte-exact "+vehicle)
	for binding: Dictionary in car.graphics.bindings:
		var shader: Shader = binding.finish.shader
		saved_shaders.append(shader)
		var parameters: Dictionary = {}
		for uniform: Dictionary in shader.get_shader_uniform_list():
			parameters[uniform.name] = binding.finish.get_shader_parameter(uniform.name)
		saved_uniforms.append(parameters)
		if not old_shaders.has(shader):
			# Keep the original program identity as well as its exact source.
			# Recompiling inlined equivalent GLSL introduces driver 1-LSB drift.
			var previous: Shader = LiveryGraphics.FINISH if shader==LiveryGraphics.FINISH else LiveryGraphics.toon_finish
			check(shader==previous,"released paint binds the original GPU program "+vehicle)
			old_shaders[shader] = previous
		binding.finish.shader = old_shaders[shader]
		for uniform: Dictionary in (old_shaders[shader] as Shader).get_shader_uniform_list():
			if parameters.has(uniform.name): binding.finish.set_shader_parameter(uniform.name,parameters[uniform.name])
	await draw_frame()
	var previous_image: Image = viewport.get_texture().get_image()
	var exact: bool = current==previous_image.get_data()
	check(exact,"byte-exact released-pattern pixels against original shader "+vehicle)
	if not exact:
		current_image.save_png(output.path_join("legacy-"+vehicle+"-current.png"))
		previous_image.save_png(output.path_join("legacy-"+vehicle+"-before.png"))
	for i: int in range(saved_shaders.size()):
		car.graphics.bindings[i].finish.shader = saved_shaders[i]
		for key: String in saved_uniforms[i]: car.graphics.bindings[i].finish.set_shader_parameter(key,saved_uniforms[i][key])

func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	var native: bool = DisplayServer.get_name() != "headless"
	var only: String = ""
	var pattern_only: String = ""
	var prototype: bool = "--prototype" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--vehicle="): only = argument.trim_prefix("--vehicle=")
		if argument.begins_with("--pattern="): pattern_only = argument.trim_prefix("--pattern=")
	var renderer: String = RenderingServer.get_current_rendering_method()
	output = ProjectSettings.globalize_path(OUT.path_join(renderer if native else "headless"))
	DirAccess.make_dir_recursive_absolute(output)
	# Use the current authored models; a cosmetic source edit must not republish
	# unrelated prepared geometry just to make design review possible.
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	check(LiveryCatalog.patterns.size()==48,"released 48-pattern catalogue retained")
	check(LiveryCatalog.premium_patterns.size()==18,"18 authored premium designs")
	check(LiveryCatalog.archived_premium_patterns.size()==18,"first collection IDs remain compatible")
	var old_images: Dictionary = {}
	for item: Dictionary in LiveryCatalog.premium_patterns:
		check(item.vehicle in VehicleCatalog.IDS and item.layout=="illustrated_five_panel_atlas" and item.kind=="full_color","bound panel artwork "+item.id)
		var wrong_car: String = "kart" if item.vehicle!="kart" else "compact"
		var appearance: Dictionary = value_for(item)
		check(VehicleLivery.normalize(appearance,wrong_car).pattern=="plain" and not VehicleLivery.valid_collection({wrong_car:appearance}),"car-specific artwork cannot transfer "+item.id)
		check(item.release_state=="art_review" and not item.has("price") and not item.has("sku"),"art review is not a purchase grant "+item.id)
		if prototype and not FileAccess.file_exists("res://assets/liveries/"+str(item.source)): continue
		var texture: Texture2D = LiveryCatalog.texture(item.id)
		check(texture!=null and texture.get_size()==Vector2(1536,1024),"bounded panel atlas "+item.id)
		var digest: String = texture.get_image().get_data().hex_encode().sha256_text()
		check(not old_images.has(digest),"unique native mask "+item.id)
		old_images[digest] = true
		check(texture.get_image().has_mipmaps(),"mipmapped art "+item.id)
		var pixels: Image = texture.get_image()
		var pigments: Dictionary = {}
		for y: int in range(0,1024,16):
			for x: int in range(0,1536,16):
				pigments[pixels.get_pixel(x,y).to_html(false)]=true
		check(pigments.size()>256,"full-colour illustration rather than a three-role mask "+item.id)
	check(LiveryCatalog.mask_order.size()<=4,"four-mask reuse bound")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,900)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for vehicle: String in VehicleCatalog.IDS:
		if not only.is_empty() and only!=vehicle: continue
		var designs: Array = LiveryCatalog.premium_for(vehicle)
		check(designs.size()==3,"three unique designs for "+vehicle)
		var world := Node3D.new()
		viewport.add_child(world)
		var car := CarVisual.new()
		car.vehicle_id = vehicle
		car.simple_model = true
		car.livery = VehicleLivery.defaults(vehicle)
		world.add_child(car)
		while not car.model_ready: await process_frame
		var original_meshes: Array = mesh_signature(car)
		ShowroomStudio.build(world,car)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.current = true
		world.add_child(camera)
		var wear := VehicleWeathering.new()
		wear.configure(car,"pine",VehicleCatalog.config(vehicle))
		var archived: Dictionary = LiveryCatalog.archived_premium_patterns.filter(func(item: Dictionary) -> bool: return item.vehicle==vehicle)[0]
		var archived_value: Dictionary = value_for(archived)
		car.apply_livery(archived_value)
		check(car.livery==archived_value and car.graphics.bindings[0].finish.get_shader_parameter("premium_full_color")==false,"first collection retains its original mask interpretation "+vehicle)
		# A released pattern must continue down the original mapping path.
		var released: Dictionary = VehicleLivery.defaults(vehicle)
		released.pattern = "apex_twin"
		car.apply_livery(released)
		check(not car.graphics.bindings[0].finish.shader.has_meta("premium_livery_base"),"released patterns retain original shader "+vehicle)
		if native: await legacy_pixels(car,camera,viewport,vehicle)
		if native:
			car.apply_livery(VehicleLivery.defaults(vehicle))
			await draw_frame()
			var stock_file: String = vehicle+"-stock-hero.png"
			check(viewport.get_texture().get_image().save_png(output.path_join(stock_file))==OK,"matched factory-paint comparison "+vehicle)
			stock_frames.append({"vehicle":vehicle,"file":stock_file})
		for item: Dictionary in designs:
			if not pattern_only.is_empty() and item.id!=pattern_only: continue
			var value: Dictionary = value_for(item)
			check(VehicleLivery.valid(value) and VehicleLivery.normalize(value,vehicle)==value,"round-trip appearance "+item.id)
			car.apply_livery(value)
			check(car.livery==value and not car.graphics.bindings.is_empty(),"actual model accepts "+item.id)
			for binding: Dictionary in car.graphics.bindings:
				check(binding.finish.get_shader_parameter("panel_art")==true and binding.finish.get_shader_parameter("premium_full_color")==true and binding.finish.get_shader_parameter("premium_illustration")==LiveryCatalog.texture(item.id),"full-colour panel binding "+item.id)
			check(mesh_signature(car)==original_meshes,"paint keeps exact meshes/transforms "+item.id)
			wear.dirt_amount = 0.72
			wear._update_finish()
			wear.refresh_paint()
			check(wear.installed and wear.materials.any(func(material: ShaderMaterial) -> bool: return material.get_shader_parameter("panel_art")==true and material.get_shader_parameter("premium_full_color")==true and material.get_shader_parameter("premium_illustration")==LiveryCatalog.texture(item.id)),"full-colour art below live weathering "+item.id)
			wear.reset()
			check(car.graphics.bindings[0].node.get_active_material(car.graphics.bindings[0].index)==car.graphics.bindings[0].finish,"wash restores art "+item.id)
			if not native: continue
			var target := Vector3(0,0.78 if vehicle=="forklift" else 0.43,0)
			var factor: float = 0.73 if vehicle=="kart" else 1.17 if vehicle=="forklift" else 1.0
			var views: Dictionary = {"hero":Vector3(-5,3.5,-7),"rear":Vector3(5,3.1,7),"left":Vector3(-8,1.2,0),"right":Vector3(8,1.2,0),"deck":Vector3(-0.01,9,-2.8)}
			for key: String in views:
				camera.size = (5.4 if key=="deck" else 4.5)*factor
				camera.position = target+(views[key] as Vector3)*factor
				camera.look_at(target)
				for i: int in range(6): await process_frame
				await RenderingServer.frame_post_draw
				var file: String = item.id+"-"+key+".png"
				var pixels: Image = viewport.get_texture().get_image()
				check(not pixels.is_empty() and pixels.save_png(output.path_join(file))==OK,"native capture "+file)
				frames.append({"id":item.id,"vehicle":vehicle,"view":key,"file":file})
			print("ARTISTIC_CAPTURE ",item.id)
		car.apply_livery(VehicleLivery.defaults(vehicle))
		check(not car.graphics.bindings[0].finish.shader.has_meta("premium_livery_base"),"premium reset restores original shader "+vehicle)
		check(car.graphics.bindings[0].node.get_active_material(car.graphics.bindings[0].index) is StandardMaterial3D,"factory material restoration "+vehicle)
		world.queue_free()
		await process_frame
	viewport.queue_free()
	await process_frame
	check(LiveryGraphics.premium_shaders.size()<=4,"bounded Burley/toon clean/weathering shader families")
	var report := FileAccess.open(output.path_join("report-"+pattern_only+".json" if not pattern_only.is_empty() else "report.json" if only.is_empty() else "report-"+only+".json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":renderer,"native":native,"frames":frames,"stock_frames":stock_frames},"\t"))
	report.close()
	print("ARTISTIC_REVIEW: %d checks, %d failures, %d native views (%s)" % [checks,failures,frames.size(),renderer])
	quit(1 if failures else 0)

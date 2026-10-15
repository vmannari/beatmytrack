extends SceneTree
const CARS = preload("res://vehicle/prepared_car_cache.gd")
const SandDustEffect = preload("res://vehicle/sand_dust.gd")
var checks: int = 0
var failures: int = 0
var output: String
var metrics: Array = []
var viewport: SubViewport
var stage: Node3D

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func value_key(value: Variant) -> Variant:
	if value is Shader: return value.code
	if value is Texture2D: return value.resource_path if not value.resource_path.is_empty() else [value.get_image().get_format(),value.get_image().get_data()]
	if value is Material: return material_key(value)
	return value

func material_key(material: Material) -> Array:
	if material == null: return []
	var result: Array = [material.get_class()]
	if material is ShaderMaterial:
		result.append(material.shader.code)
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			var value: Variant = material.get_shader_parameter(uniform.name)
			if value == null: value = RenderingServer.shader_get_parameter_default(material.shader.get_rid(),uniform.name)
			result.append([uniform.name,value_key(value)])
	else:
		for property: Dictionary in material.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"): result.append([property.name,value_key(material.get(property.name))])
	return result

func geometry(node: Node3D) -> Array:
	var result: Array = [node.transform,node.visible,node.global_transform]
	if node is MeshInstance3D:
		result.append([node.cast_shadow,node.layers,node.mesh.get_aabb()])
		for surface: int in range(node.mesh.get_surface_count()): result.append([node.mesh.surface_get_arrays(surface),material_key(node.get_active_material(surface))])
	for child: Node3D in node.get_children(): result.append(geometry(child))
	return result

func first_diff(a: Variant, b: Variant, path: String = "") -> bool:
	if var_to_bytes(a) == var_to_bytes(b): return false
	if a is Array and b is Array and a.size() == b.size():
		for index: int in range(a.size()):
			if first_diff(a[index],b[index],path+"/"+str(index)): return true
	else: print("RESOURCE_DIFFERENCE ",path," ",str(a).left(240)," vs ",str(b).left(240))
	return true

func gpu_materials(car: CarVisual) -> Array:
	var result: Array = []
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		for surface: int in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface)
			if material == null: continue
			var values: Array = [material.get_class()]
			if material.has_method("get_shader_rid"): values.append(RenderingServer.shader_get_code(material.call("get_shader_rid")))
			for key: String in ["albedo","roughness","specular","metallic","emission","emission_energy","uv1_scale","uv1_offset","finish_color"]: values.append([key,RenderingServer.material_get_param(material.get_rid(),key)])
			result.append(values)
	return result

func photo(car: CarVisual, label: String, frames: int) -> PackedByteArray:
	if DisplayServer.get_name() == "headless": return PackedByteArray()
	car.show()
	for frame: int in range(frames): await RenderingServer.frame_post_draw
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	check(image.save_png(output.path_join(label+".png")) == OK,"actual car capture saved")
	return image.get_data()

func make_car(id: String, simple: bool, parts: Dictionary, livery: Dictionary) -> CarVisual:
	var car := CarVisual.new()
	car.vehicle_id = id; car.simple_model = simple; car.customisation = parts.duplicate(true); car.livery = livery.duplicate(true)
	stage.add_child(car)
	return car

func car_case(id: String, simple: bool, fitted: bool = false) -> void:
	var parts: Dictionary = VehicleCustomisation.defaults()
	if fitted: parts.merge({"hood":"scoop","aero":"wing","rims":"split","body":"rally"},true)
	var livery: Dictionary = VehicleLivery.defaults(id)
	var label: String = id+"-"+str(simple)+("-fitted" if fitted else "")
	var cached: bool = id == "compact" and not simple and not fitted
	CARS.entries.clear(); CARS.enabled = false
	var began: int = Time.get_ticks_usec()
	var baseline: CarVisual = make_car(id,simple,parts,livery)
	var cold_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var pixels: PackedByteArray = await photo(baseline,label+"-before",120)
	var expected: Array = geometry(baseline)
	CARS.enabled = not ("--uncached-control" in OS.get_cmdline_user_args())
	if CARS.enabled:
		CARS.remember(baseline)
		var admitted: PackedByteArray = await photo(baseline,label+"-admitted",8)
		if not pixels.is_empty(): check(admitted == pixels,label+" cache admission leaves original car pixels exact")
	baseline.hide()
	var first: CarVisual = make_car(id,simple,parts,livery)
	if DisplayServer.get_name() != "headless":
		for frame: int in range(8): await RenderingServer.frame_post_draw
	first_diff(expected,geometry(first))
	check(geometry(first) == expected,label+" cold template preserves exact arrays, frames and finishes")
	var first_pixels: PackedByteArray = await photo(first,label+"-cold",120)
	if not pixels.is_empty() and cached: check(first_pixels == pixels,label+" first restored car pixels exact")
	first.hide()
	began = Time.get_ticks_usec()
	var hits: int = CARS.hits
	var restored: CarVisual = make_car(id,simple,parts,livery)
	check(CARS.hits == hits+(1 if cached else 0),label+" accepted model restores; other shadow/material sequences retain original builder")
	if "--clone-meshes" in OS.get_cmdline_user_args():
		for node: MeshInstance3D in restored.find_children("*","MeshInstance3D",true,false):
			var original_mesh: Mesh = node.mesh
			node.mesh = original_mesh.duplicate()
			if node.mesh is ArrayMesh: node.mesh.custom_aabb = original_mesh.get_aabb()
	var warm_ms: float = (Time.get_ticks_usec()-began)/1000.0
	first_diff(expected,geometry(restored),"RESTORE")
	check(geometry(restored) == expected,label+" restored car preserves exact arrays, frames and finishes")
	var after: PackedByteArray = await photo(restored,label+"-after",120)
	first_diff(expected,geometry(restored),"STRICT")
	first_diff(gpu_materials(first),gpu_materials(restored),"GPU")
	if not pixels.is_empty() and cached: check(after == pixels,label+" framebuffer is byte-exact")
	check(restored.body != first.body and restored.rolling_wheels.size() == 4 and restored.front_wheels.size() == 2,label+" articulation nodes are independent")
	check(restored.paint_materials.body != first.paint_materials.body and restored.brake_material != first.brake_material,label+" paint and brakes are independent")
	var painted: Dictionary = livery.duplicate(true)
	painted.colors.body = "#cb3049"
	restored.apply_livery(painted)
	restored.rolling_wheels[0].rotation.x = 0.5
	first.show()
	check(geometry(first) == expected,label+" painting/wheel motion cannot mutate another car or cached mesh")
	var fresh: CarVisual = make_car(id,simple,parts,livery)
	check(geometry(fresh) == expected,label+" template remains pristine after live edits")
	var original_ghost: ArrayMesh = PersonalGhost.mesh_for(fresh)
	var ghost := PersonalGhost.new()
	stage.add_child(ghost); ghost.configure(fresh)
	check(ghost.mesh.surface_get_arrays(0) == original_ghost.surface_get_arrays(0),label+" prepared rest-pose ghost is exact")
	ghost.free()
	metrics.append({"case":label,"cold_car_ms":cold_ms,"warm_car_ms":warm_ms})
	baseline.free(); first.free(); restored.free(); fresh.free()
	await process_frame

func particles() -> void:
	SandDustEffect.prepared_emitters.clear()
	var first := SandDustEffect.new(); stage.add_child(first)
	var second := SandDustEffect.new(); stage.add_child(second)
	check(first.get_child_count() == second.get_child_count(),"prepared effects preserve all emitter families")
	for index: int in range(first.get_child_count()):
		var a: GPUParticles3D = first.get_child(index); var b: GPUParticles3D = second.get_child(index)
		check(a.amount == b.amount and a.lifetime == b.lifetime and a.fixed_fps == b.fixed_fps,"particle budgets/cadence unchanged")
		check(a.draw_pass_1.surface_get_arrays(0) == b.draw_pass_1.surface_get_arrays(0) and material_key(a.draw_pass_1.surface_get_material(0)) == material_key(b.draw_pass_1.surface_get_material(0)),"particle geometry/finish exact")
		check(a.process_material != b.process_material and a.draw_pass_1 != b.draw_pass_1 and a.draw_pass_1.surface_get_material(0) != b.draw_pass_1.surface_get_material(0),"process and bridge/finish bindings independently owned")
	first._set_desert_profile(true)
	check(second.dust_emitters[0].amount == 360 and second.dust_emitters[0].lifetime == 5.2,"desert cannot change another biome's budget")
	var third := SandDustEffect.new(); stage.add_child(third)
	check(third.dust_emitters[0].amount == 360 and third.dust_emitters[0].lifetime == 5.2,"cached particle template stays pristine")
	first.free(); second.free(); third.free()

func audio() -> void:
	VehicleAudio.prepared_streams.clear()
	var first := VehicleAudio.new(); first.use_windows_impacts = false; stage.add_child(first); first.configure("compact",VehicleCatalog.config("compact"))
	var second := VehicleAudio.new(); second.use_windows_impacts = false; stage.add_child(second); second.configure("compact",VehicleCatalog.config("compact"))
	check(first.engine_load[0] != second.engine_load[0] and first.engine_load[0].stream == second.engine_load[0].stream,"prepared stream shared with independent playback")
	var before: AudioStream = second.engine_load[0].stream
	first.configure("pickup",VehicleCatalog.config("pickup")); first.free()
	check(second.engine_load[0].stream == before and second.model.vehicle_id == "compact","car switch/teardown cannot change another audio bank")
	var bytes: int = 0
	for entry: Dictionary in VehicleAudio.prepared_streams: bytes += int(entry.bytes)
	check(bytes <= VehicleAudio.STREAM_CACHE_BYTES,"audio cache byte budget respected")
	second.free()

func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/track-load-improvements-2026-10-14/"+RenderingServer.get_current_rendering_method())
	if DisplayServer.get_name() == "headless": output = output.path_join("headless")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new(); viewport.size = Vector2i(640,360); viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new(); viewport.add_child(stage)
	var camera := Camera3D.new(); stage.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 7.0; camera.position = Vector3(5.4,5.8,7.1); camera.look_at(Vector3(0,0.6,0)); camera.current = true
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-58,-35,0); light.shadow_enabled = true; stage.add_child(light)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new(); environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color("647158"); environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color = Color("bac8ce"); environment.environment.ambient_light_energy = 0.35; stage.add_child(environment)
	for id: String in ["compact","pickup","classic","formula","kart"]:
		for simple: bool in [false,true]: await car_case(id,simple)
	await car_case("compact",false,true); await car_case("compact",true,true)
	particles(); audio()
	var file := FileAccess.open(output.path_join("resources.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	viewport.free()
	print("PREPARED_RACE_RESOURCES: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

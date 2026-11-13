extends SceneTree
## Offline component review: real cars, room, reflections and close prop views.
var output: String = "res://../build/garage-model-review-2026-11-12"
var phase: String = "final"
var checks: int = 0
var failures: int = 0
var report: Dictionary = {}
var reference_room: String = ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func stats(holder: Node) -> Dictionary:
	var result: Dictionary = {"meshes":0,"vertices":0,"triangles":0,"bytes":0,"lod_bytes":0}
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null or part.get_parent() is CarVisual: continue
		# A pedestal's car is measured separately from its immutable shell.
		var ancestor: Node = part
		var is_car: bool = false
		while ancestor != holder:
			if ancestor is CarVisual: is_car = true
			ancestor = ancestor.get_parent()
		if is_car: continue
		result.meshes += 1
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			result.vertices += vertices.size()
			result.triangles += (indices.size() if not indices.is_empty() else vertices.size())/3
		if part.mesh is ArrayMesh:
			result.bytes += preload("res://tests/support/car_model_buffers.gd").payload(part.mesh)
			for packet: Dictionary in part.mesh.get("_surfaces"):
				var lods: Array = packet.get("lods",[])
				for index: int in range(1,lods.size(),2): result.lod_bytes += lods[index].size()
	return result

func frames(count: int = 12) -> void:
	for i: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(view: CarShowroom, label: String) -> void:
	view.invalidate_render()
	await frames()
	if DisplayServer.get_name() == "headless": return
	check(view.showroom_viewport.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
	for index: int in range(2):
		check(view.reflections.views[index].get_texture().get_image().save_png(output.path_join(label+"-reflection"+str(index)+".png")) == OK,"capture reflection "+label)

func pedestal_reuse(view: CarShowroom) -> void:
	var car := CarVisual.new()
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(car)
	while not car.model_ready: await process_frame
	var first: Node3D = GarageEnvironment.build_pedestal(world,car)
	car.reparent(world)
	var second: Node3D = GarageEnvironment.build_pedestal(world,car)
	var a: Array[Node] = first.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D and (n.material_override is BaseMaterial3D or (n.material_override is ShaderMaterial and n.material_override.shader == preload("res://ui/garage_deck.gdshader"))))
	var b: Array[Node] = second.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D and (n.material_override is BaseMaterial3D or (n.material_override is ShaderMaterial and n.material_override.shader == preload("res://ui/garage_deck.gdshader"))))
	check(a.size() == b.size() and a.size() == 5,"all five pedestal batches remain")
	if phase != "source-control":
		for i: int in range(mini(a.size(),b.size())):
			check(a[i].mesh == b[i].mesh,"pedestal reuses immutable mesh "+str(i))
			if a[i].material_override is ShaderMaterial:
				check(a[i].material_override != b[i].material_override,"each pedestal owns its reflection material")
				a[i].material_override.set_shader_parameter("reflection_enabled",true)
				var independent: ShaderMaterial = b[i].material_override
				independent.set_shader_parameter("reflection_enabled",false)
				check(a[i].material_override.get_shader_parameter("reflection_enabled") != false,"changing another pedestal cannot disable this reflection")
		var template: Node3D = GarageEnvironment.pedestal_scene.instantiate()
		for part: Node in template.get_children():
			if part is MeshInstance3D and part.material_override is ShaderMaterial:
				check(part.material_override.get_shader_parameter("reflection_image") == null,"cached pedestal retains no live viewport texture")
		template.free()
	var times: Array[float] = []
	for i: int in range(12):
		car.reparent(world)
		second.free()
		var start: int = Time.get_ticks_usec()
		second = GarageEnvironment.build_pedestal(world,car)
		times.append((Time.get_ticks_usec()-start)/1000.0)
	times.sort()
	report.pedestal_rebuild_median_ms = times[6]
	world.free()
	view.invalidate_render()

func straight_cylinders() -> void:
	var holder := Node3D.new()
	var finish := StandardMaterial3D.new()
	for sides: int in [6,12,20,32,48,64,96]:
		var part: MeshInstance3D = GarageFurnishings.tube(holder,Vector3(0,-0.75,0),Vector3(0,0.75,0),0.16,finish,sides)
		var reduced: CylinderMesh = part.mesh
		check(reduced.rings == 0 and reduced.radial_segments == sides,"straight tube retains radial silhouette "+str(sides))
		var original := CylinderMesh.new()
		original.top_radius = 0.16
		original.bottom_radius = 0.16
		original.height = 1.5
		original.radial_segments = sides
		check(original.get_aabb() == reduced.get_aabb(),"tube bounds unchanged "+str(sides))
		var a: Array = original.surface_get_arrays(0)
		var b: Array = reduced.surface_get_arrays(0)
		check(b[Mesh.ARRAY_INDEX].size()*3 == a[Mesh.ARRAY_INDEX].size(),"two thirds of redundant tube triangles removed "+str(sides))
		var original_corners: Dictionary = {}
		for i: int in range(a[Mesh.ARRAY_VERTEX].size()):
			var position: Vector3 = a[Mesh.ARRAY_VERTEX][i]
			if absf(position.y) < 0.749: continue
			original_corners[[position,a[Mesh.ARRAY_NORMAL][i],a[Mesh.ARRAY_TEX_UV][i]]] = true
		var exact: bool = true
		for i: int in range(b[Mesh.ARRAY_VERTEX].size()):
			if not original_corners.has([b[Mesh.ARRAY_VERTEX][i],b[Mesh.ARRAY_NORMAL][i],b[Mesh.ARRAY_TEX_UV][i]]): exact = false
		check(exact,"tube end rings, cap vertices, normals and UVs exact "+str(sides))
	var deck: MeshInstance3D = GarageEnvironment.cylinder(holder,Vector3.ZERO,3.65,0.17,finish)
	check((deck.mesh as CylinderMesh).rings == 0 and (deck.mesh as CylinderMesh).radial_segments == 96,"turntable preserves 96-sided outline")
	holder.free()

func compare_room(a: Node, b: Node) -> void:
	check(a.get_class() == b.get_class() and a.get_child_count() == b.get_child_count(),"room hierarchy retained "+str(a.name))
	if a is Node3D and b is Node3D:
		check(a.transform == b.transform,"room transform retained "+str(a.name))
	if a is MeshInstance3D and b is MeshInstance3D:
		check(a.layers == b.layers and a.cast_shadow == b.cast_shadow,"room visibility and shadows retained")
		check(a.mesh.get_aabb().is_equal_approx(b.mesh.get_aabb()),"room mesh bounds retained")
		check(a.mesh.get_surface_count() == b.mesh.get_surface_count(),"room material slots retained")
		for surface: int in range(mini(a.mesh.get_surface_count(),b.mesh.get_surface_count())):
			var left: Material = a.get_active_material(surface)
			var right: Material = b.get_active_material(surface)
			check(left.get_class() == right.get_class(),"room finish type retained")
			if left is ShaderMaterial and right is ShaderMaterial:
				check(left.shader.code == right.shader.code,"room shader retained")
			elif left is BaseMaterial3D and right is BaseMaterial3D:
				for key: String in ["albedo_color","metallic","roughness","metallic_specular","emission_enabled","emission","emission_energy_multiplier","transparency","cull_mode","shading_mode","vertex_color_use_as_albedo"]:
					check(left.get(key) == right.get(key),"room finish retained "+key)
				if left.albedo_texture != null and right.albedo_texture != null:
					check(left.albedo_texture.get_image().get_data() == right.albedo_texture.get_image().get_data(),"room texture retained")
	for i: int in range(mini(a.get_child_count(),b.get_child_count())): compare_room(a.get_child(i),b.get_child(i))

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: print("FAIL: Garage model review deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--reference-room="): reference_room = arg.trim_prefix("--reference-room=")
	if phase == "source-control":
		# Task-start procedural settings, using the same current prop/art sources.
		var environment: Script = load("res://ui/garage_environment.gd")
		environment.source_code = environment.source_code.replace("mesh.rings = 0","mesh.rings = 4").replace("if pedestal_scene != null:","if false:")
		check(environment.reload(true) == OK,"load original pedestal and cylinder settings in memory")
		var furnishings: Script = load("res://ui/garage_furnishings.gd")
		furnishings.source_code = furnishings.source_code.replace("shape.rings = 0","shape.rings = 4")
		check(furnishings.reload(true) == OK,"restore original tube subdivisions in memory")
		var world := Node3D.new()
		root.add_child(world)
		var control_car := CarVisual.new()
		world.add_child(control_car)
		while not control_car.model_ready: await process_frame
		GarageEnvironment.architecture_scene = null
		GarageEnvironment.build(world,control_car,false,false)
		var control_path: String = "res://../build/garage-model-review-2026-11-12/source-control-"+RenderingServer.get_current_rendering_method()+".scn"
		check(ResourceSaver.save(GarageEnvironment.architecture_scene,control_path,ResourceSaver.FLAG_COMPRESS) == OK,"save source control")
		check(preload("res://tests/support/garage_mesh_lods.gd").new().bake(control_path) == OK,"prepare original LOD policy on source control")
		GarageEnvironment.architecture_scene = ResourceLoader.load(control_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		world.free()
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	var music: GameSoundtrack = GameSoundtrack.instance()
	music.music_enabled = false
	var view := CarShowroom.new()
	view.garage_mode = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	while not view.showroom_ready: await process_frame
	await frames()
	report = {"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string,"room":stats(view.camera.get_parent().find_child("GarageArchitecture",true,false)),"pedestal":stats(view.turntable)}
	if phase not in ["before","source-control"]: straight_cylinders()
	if not reference_room.is_empty():
		var original: Node = (load(reference_room) as PackedScene).instantiate()
		var optimized: Node = (load(GarageEnvironment.PREPARED_ARCHITECTURE) as PackedScene).instantiate()
		compare_room(original,optimized)
		original.free()
		optimized.free()
	for id: String in VehicleCatalog.IDS:
		if id != view.vehicle_id: view.replace_car(id,VehicleLivery.defaults(id),{})
		view.finish_car_transition()
		view.reset_view()
		await capture(view,id+"-front")
		view.rotate_view(Vector2(180,0))
		await capture(view,id+"-rear")
		view.reset_view()
		view.set_zoom(CarShowroom.MIN_ZOOM)
		await capture(view,id+"-close")
		view.reset_view()
	view.set_record_view(true)
	await create_timer(0.9).timeout
	await capture(view,"record")
	view.set_record_view(false)
	view.set_trophy_view(true)
	await create_timer(0.9).timeout
	await capture(view,"trophies")
	view.set_trophy_view(false)
	await create_timer(0.9).timeout
	for pose: Array in [["workbench",Vector3(6.35,1.6,4.7),Vector3(6.35,0.9,7.65)],["tyres",Vector3(7,1.8,5.1),Vector3(9.2,1.0,7.6)],["overhead",Vector3(0,9,-7),Vector3(0,0,0)]]:
		view.camera.position = pose[1]
		view.camera.look_at(pose[2])
		await capture(view,pose[0])
	if phase != "before": await pedestal_reuse(view)
	report.checks = checks
	report.failures = failures
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("GARAGE_MODEL_REVIEW ",JSON.stringify(report))
	view.free()
	await process_frame
	quit(1 if failures else 0)

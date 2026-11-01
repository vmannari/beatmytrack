extends SceneTree
## RCM01-RCM03: retained detail, reduced work, independent articulation and local settings.
var checks: int = 0
var failures: int = 0
var output: String = "res://../build/racing-car-models-2026-10-13"
var graphical: bool = false
var camera: Camera3D
var metrics: Dictionary = {}

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func inspect(node: Node) -> Dictionary:
	var result: Dictionary = {"meshes":0,"triangles":0,"casters":0,"shadow_triangles":0}
	if node is MeshInstance3D and node.mesh != null:
		var triangles: int = 0
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			result.meshes += 1
			result.triangles += triangles
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			result.casters += 1
			result.shadow_triangles += triangles
	for child: Node in node.get_children():
		var value: Dictionary = inspect(child)
		for key: String in result: result[key] += int(value[key])
	return result

func settle() -> void:
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw

func legacy_batches(car: CarVisual) -> void:
	# Match the old constructor's exhaust flattening before its sibling-only batch.
	var assembly: Node3D = car.body.get_node_or_null("RearExhaustAssembly")
	if assembly != null:
		for parent: Node3D in assembly.get_children():
			for part: Node3D in parent.get_children():
				var pose: Transform3D = parent.transform*part.transform
				parent.remove_child(part)
				assembly.add_child(part)
				part.transform = pose
			assembly.remove_child(parent)
			parent.queue_free()
	VisualGeometry.batch_static_parts(car)
	car.graphics = LiveryGraphics.new()
	car.graphics.configure(car)

func picture(car: CarVisual, tag: String) -> Image:
	car.show()
	await settle()
	var result: Image = root.get_texture().get_image()
	result.save_png(output.path_join(tag+".png"))
	car.hide()
	return result

func _run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	var only_vehicle: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--vehicle="): only_vehicle = argument.trim_prefix("--vehicle=")
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	assert(only_vehicle.is_empty() or only_vehicle in VehicleCatalog.IDS)
	root.size = Vector2i(1280,720)
	output = output.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var world := Node3D.new()
	root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-25,0)
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 65.0
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("34434a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.5
	world.add_child(environment)
	VisualGeometry.box(world,Vector3(30,0.1,30),Vector3(0,-0.1,0),VisualGeometry.material(Color("a7a79d")))
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	camera.position = Vector3(-5,7,-9)
	camera.look_at(Vector3.ZERO)
	for id: String in VehicleCatalog.IDS:
		if not only_vehicle.is_empty() and id!=only_vehicle: continue
		var control := CarVisual.new()
		control.vehicle_id = id
		control.batch_parts = false
		world.add_child(control)
		while not control.model_ready: await process_frame
		legacy_batches(control)
		var detailed := CarVisual.new()
		detailed.vehicle_id = id
		world.add_child(detailed)
		while not detailed.model_ready: await process_frame
		var simple := CarVisual.new()
		simple.vehicle_id = id
		simple.simple_model = true
		world.add_child(simple)
		while not simple.model_ready: await process_frame
		var before: Dictionary = inspect(control)
		var after: Dictionary = inspect(detailed)
		var reduced: Dictionary = inspect(simple)
		check(before.triangles == after.triangles,id+" detailed batches retain every triangle")
		check(after.meshes <= before.meshes,id+" detailed batching adds no submissions")
		if id == "compact": check(after.meshes < before.meshes,"compact detailed batching reduces submissions")
		check(reduced.triangles < after.triangles*0.8,id+" simpler model reduces triangles")
		check(reduced.casters == (1 if id == "hovercraft" else 5),id+" shadow casters match the vehicle frames")
		check(reduced.shadow_triangles < after.shadow_triangles*0.5,id+" shadow geometry reduced")
		if id == "forklift":
			check(simple.body.get_node_or_null("RaceShadowProxy") != null,"stock forklift body uses its prepared shadow proxy")
			var wheel_proxies: int = 0
			for rotor: Node3D in simple.rolling_wheels:
				if rotor.get_node_or_null("RaceShadowProxy") != null: wheel_proxies += 1
			check(wheel_proxies == 4,"stock forklift has one shadow proxy per rolling wheel")
			var forklift_fitted := CarVisual.new()
			forklift_fitted.vehicle_id = id
			forklift_fitted.simple_model = true
			forklift_fitted.customisation = VehicleCustomisation.defaults()
			forklift_fitted.customisation.hood = "fork_vent"
			world.add_child(forklift_fitted)
			while not forklift_fitted.model_ready: await process_frame
			check(forklift_fitted.find_children("RaceShadowProxy","MeshInstance3D",true,false).is_empty(),"fitted forklift does not use stock-only shadow proxies")
			check(inspect(forklift_fitted).casters > 5,"fitted forklift retains its actual silhouette casters")
			forklift_fitted.queue_free()
			var editable_forklift := CarVisual.new()
			editable_forklift.vehicle_id = id
			editable_forklift.simple_model = true
			editable_forklift.editable_kits = true
			world.add_child(editable_forklift)
			while not editable_forklift.model_ready: await process_frame
			var editable_wheels: Array[Node3D] = editable_forklift.rolling_wheels.duplicate()
			for hood: String in ["stock","fork_vent","stock"]:
				if hood != editable_forklift.customisation.hood:
					var parts: Dictionary = editable_forklift.customisation.duplicate(true)
					parts.hood = hood
					editable_forklift.graphics.restore_originals()
					editable_forklift.change_kit_parts(parts)
				check(editable_forklift.find_children("RaceShadowProxy","MeshInstance3D",true,false).is_empty() and inspect(editable_forklift).casters > 5,"editable simple forklift retains silhouette casters with "+hood+" hood")
				if hood == "fork_vent":
					var kit_casters: int = 0
					for frame: Node3D in editable_forklift.kit_frames.get("hood",[]): kit_casters += int(inspect(frame).casters)
					check(kit_casters > 0,"editable fitted forklift hood casts its own shadow")
				check(editable_forklift.rolling_wheels == editable_wheels,"editable forklift preserves rolling pivots with "+hood+" hood")
			editable_forklift.queue_free()
		if id == "hovercraft":
			check(simple.rolling_wheels.is_empty() and simple.body.get_node_or_null("FanRotor") != null,id+" independent fan with no wheel frames")
		elif id == "forklift":
			var rear_pivots: Dictionary = {}
			for rotor: Node3D in simple.rolling_wheels:
				if rotor.get_parent() in simple.rear_wheels: rear_pivots[rotor.get_parent()] = true
			check(simple.rolling_wheels.size() == 4 and simple.front_wheels.is_empty() and simple.rear_wheels.size() == 2 and rear_pivots.size() == 2,id+" four rolling wheels with two independent rear-steering pivots")
		else:
			check(simple.rolling_wheels.size() == 4 and simple.front_wheels.size() == 2,id+" independent wheel frames")
		var livery: Dictionary = VehicleLivery.defaults(id)
		livery.colors.body = "804439"
		simple.apply_livery(livery)
		check(detailed.paint_materials.body.albedo_color != simple.paint_materials.body.albedo_color,id+" materials remain local to each car")
		var state := VehicleState.new()
		state.tick = 1
		state.steering = 0.4
		if id == "electric": state.velocity = Vector2(0,10)
		simple.present(Vector2.ZERO,0,state,DriveFrame.sample(0,0,1))
		if id == "forklift":
			var correct_steering: bool = true
			for rotor: Node3D in simple.rolling_wheels:
				var pivot: Node3D = rotor.get_parent() as Node3D
				if pivot in simple.rear_wheels: correct_steering = correct_steering and not is_zero_approx(pivot.rotation.y) and pivot.position.z > 0.0
				else: correct_steering = correct_steering and is_zero_approx(pivot.rotation.y) and pivot.position.z < 0.0
			check(correct_steering,"forklift rear wheels steer independently while front wheels remain straight")
		check(simple.brake_material.albedo_color == Color("f17158"),id+" brake material still responds")
		if id == "electric":
			state.velocity = Vector2.ZERO
			state.tick += 1
			simple.present(Vector2.ZERO,0,state,DriveFrame.sample(0,0,1))
			check(not simple.rear_braking and simple.brake_material.albedo_color == Color("802d2b"),"electric idle retains the existing no-regeneration light state")
		var condition := VehicleWeathering.new()
		condition.configure(simple,"desert",VehicleCatalog.config(id))
		check(not condition.materials.is_empty(),id+" local weathering binds")
		var ghost: ArrayMesh = PersonalGhost.mesh_for(simple)
		check(ghost.get_faces().size()/3 == reduced.triangles,id+" ghost excludes shadow proxies")
		var decorated: Dictionary = VehicleLivery.defaults(id)
		for pattern: Dictionary in LiveryCatalog.patterns:
			if pattern.id != "plain": decorated.pattern = pattern.id; break
		simple.apply_livery(decorated)
		check(not simple.graphics.bindings.is_empty() and bool(simple.graphics.bindings[0].finish.get_shader_parameter("graphics_enabled")),id+" simpler model retains livery graphics")
		var decorated_condition := VehicleWeathering.new()
		decorated_condition.configure(simple,"desert",VehicleCatalog.config(id))
		var graphic_finish: bool = false
		for material: ShaderMaterial in decorated_condition.materials:
			if material.get_shader_parameter("graphics_enabled") == true: graphic_finish = true
		check(graphic_finish,id+" weathering retains graphics on simpler geometry")
		decorated_condition.reset()
		check(simple.graphics.bindings[0].node.get_active_material(simple.graphics.bindings[0].index) == simple.graphics.bindings[0].finish,id+" clean restore returns the decorated finish")
		var matching: Dictionary = VehicleLivery.defaults(id)
		for slot: String in VehicleLivery.SLOTS:
			if control.paint_materials.has(slot): matching.colors[slot] = control.paint_materials[slot].albedo_color.to_html(false)
		for car: CarVisual in [control,detailed,simple]:
			car.apply_livery(matching)
			car.present(Vector2.ZERO,0,state,DriveFrame.sample(0,0,1))
		control.hide(); detailed.hide(); simple.hide()
		if graphical:
			var references: Array[Image] = []
			for pose: int in range(2):
				camera.position = Vector3(-5,7,-9) if pose == 0 else Vector3(5,5,9)
				camera.look_at(Vector3.ZERO)
				references.append(await picture(control,id+"-control-"+str(pose)))
			# Use the same materials and car instance on both sides. Independent
			# duplicate materials change ordering at pre-existing coplanar seams.
			control.show()
			VisualGeometry.batch_car_parts(control)
			control.graphics = LiveryGraphics.new()
			control.graphics.configure(control)
			control.hide()
			for pose: int in range(2):
				camera.position = Vector3(-5,7,-9) if pose == 0 else Vector3(5,5,9)
				camera.look_at(Vector3.ZERO)
				var old: Image = references[pose]
				var current: Image = await picture(control,id+"-detailed-"+str(pose))
				var delta: int = 0
				var maximum: int = 0
				var locations: Array = []
				var a: PackedByteArray = old.get_data()
				var b: PackedByteArray = current.get_data()
				for index: int in range(a.size()):
					var difference: int = absi(int(a[index])-int(b[index]))
					if difference > 0: delta += 1
					maximum = maxi(maximum,difference)
					if difference > 2 and locations.size() < 32: locations.append([index/4%1280,index/4/1280,difference])
				print("RACING_BATCH_PIXELS ",id," pose=",pose," changed_channels=",delta," max=",maximum)
				if not locations.is_empty(): print("RACING_PIXEL_LOCATIONS ",locations)
				check(maximum <= 2,id+" detailed batching preserves rendered pixels")
				await picture(simple,id+"-simple-"+str(pose))
		metrics[id] = {"before":before,"detailed":after,"simple":reduced}
		print("RACING_MODEL_COUNTS ",id," ",metrics[id])
		control.queue_free(); detailed.queue_free(); simple.queue_free()
		await process_frame
	var fitted := CarVisual.new()
	fitted.simple_model = true
	fitted.customisation = VehicleCustomisation.defaults()
	fitted.customisation.aero = "wing"
	fitted.customisation.rims = "five"
	world.add_child(fitted)
	check(fitted.body.get_node_or_null("RaceShadowProxy") == null,"fitted aero retains actual silhouette casters")
	check(fitted.rolling_wheels[0].get_node_or_null("RaceShadowProxy") == null,"fitted rims retain their actual shadow casters")
	check(inspect(fitted).casters > 5,"fitted car keeps additional geometry shadowing")
	fitted.queue_free()
	await process_frame
	var records := LocalRecords.new("user://racing_models_"+TrackLibrary.unique_id()+".json")
	records.settings.simple_car_models = true
	check(records.save_records() == OK,"local graphics preference saves")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	check(reopened.settings.get("simple_car_models",false) == true,"graphics preference reloads")
	check(LocalRecords._normalize({"schema":2,"records":{},"settings":{"simple_car_models":"yes"}}).is_empty(),"reject non-boolean graphics preference")
	var page := SettingsPage.new()
	page.records = records
	root.add_child(page)
	page._show_section("graphics")
	check(page.draft_simple_models and page.find_child("SimpleCarModels",true,false) != null,"Settings exposes saved graphics toggle")
	page._reset()
	check(not page.draft_simple_models and records.settings.simple_car_models,"graphics reset is staged")
	check(page._apply() and not records.settings.simple_car_models,"Apply saves disabled option")
	page.queue_free()
	for path: String in [records.path,records.path+".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	FileAccess.open(output.path_join("counts-"+RenderingServer.get_current_rendering_method()+".json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	print("RACING_MODEL_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

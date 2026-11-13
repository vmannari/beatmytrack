extends "res://tests/test_prepared_race_resources.gd"
## Exact live restoration of fitted Simple cars, including their original casters.

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func pixel_difference(a: PackedByteArray, b: PackedByteArray) -> Dictionary:
	var pixels: int = 0
	var maximum: int = 0
	for index: int in range(0,a.size(),4):
		var delta: int = 0
		for channel: int in range(4): delta = maxi(delta,absi(int(a[index+channel])-int(b[index+channel])))
		if delta>0: pixels += 1
		maximum = maxi(maximum,delta)
	return {"pixels":pixels,"maximum":maximum}

func fitted_case(id: String, parts: Dictionary, label: String) -> void:
	CARS.entries.clear(); CARS.enabled = true
	var livery: Dictionary = VehicleLivery.defaults(id)
	var began: int = Time.get_ticks_usec()
	var baseline: CarVisual = make_car(id,true,parts,livery)
	check(baseline.model_ready,label+" original model completes")
	var cold_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var expected: Array = geometry(baseline)
	var before: PackedByteArray = await photo(baseline,label+"-before",12)
	baseline.hide()
	var hits: int = CARS.hits
	began = Time.get_ticks_usec()
	var restored: CarVisual = make_car(id,true,parts,livery)
	var warm_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(CARS.hits==hits+1 and restored.model_ready,label+" exact fitted template restores")
	check(restored.model_yields==0,label+" restoration performs no procedural frame waits")
	first_diff(expected,geometry(restored),label)
	check(expected==geometry(restored),label+" every mesh, material, shadow caster and articulation frame is exact")
	var after: PackedByteArray = await photo(restored,label+"-after",12)
	if not before.is_empty():
		check(before==after,label+" native frame is byte-exact")
		if before!=after:
			restored.hide()
			CARS.enabled = false
			var control: CarVisual = make_car(id,true,parts,livery)
			var control_pixels: PackedByteArray = await photo(control,label+"-procedural-control",12)
			print("PIXEL_CONTROL ",label," cache=",JSON.stringify(pixel_difference(before,after))," original-repeat=",JSON.stringify(pixel_difference(before,control_pixels)))
			control.free(); CARS.enabled = true
			restored.show()
	check(baseline.body!=restored.body and baseline.paint_materials.body!=restored.paint_materials.body and baseline.brake_material!=restored.brake_material,label+" live nodes and mutable materials are independent")
	var paint: Dictionary = livery.duplicate(true)
	paint.colors.body = "#cb3049"
	restored.apply_livery(paint)
	check(restored.front_wheels.size()==baseline.front_wheels.size() and restored.rear_wheels.size()==baseline.rear_wheels.size() and restored.rolling_wheels.size()==baseline.rolling_wheels.size(),label+" vehicle-specific moving-part bindings are retained")
	for wheel: Node3D in restored.front_wheels+restored.rear_wheels: wheel.rotation.y = 0.31
	for wheel: Node3D in restored.rolling_wheels: wheel.rotation.x = 0.7
	restored.brake_material.albedo_color = Color.RED
	baseline.show()
	check(geometry(baseline)==expected,label+" paint, steering, roll and brakes cannot mutate the original")
	var fresh: CarVisual = make_car(id,true,parts,livery)
	check(geometry(fresh)==expected,label+" subsequent restore remains pristine")
	var ghost := PersonalGhost.new()
	stage.add_child(ghost); ghost.configure(fresh)
	check(ghost.mesh.surface_get_arrays(0)==PersonalGhost.mesh_for(fresh).surface_get_arrays(0),label+" ghost rest geometry is exact")
	ghost.free()
	var changed: CarVisual = CarVisual.new()
	changed.vehicle_id = id; changed.simple_model = true; changed.customisation = VehicleCustomisation.defaults()
	check(CARS.key_for(changed)!=CARS.key_for(fresh),label+" different fit cannot select this geometry")
	changed.free()
	var state := VehicleState.new()
	var frame := DriveFrame.new()
	for tick: int in range(6):
		state.tick = tick
		state.position = Vector2(tick*0.08,tick*0.15)
		state.velocity = Vector2(1.0,8.0)
		state.steering = sin(tick*0.8)
		frame.brake = 127 if tick%2 else 0
		frame.throttle = 0 if tick%2 else 127
		var canonical: Array = state.snapshot().duplicate(true)
		for car: CarVisual in [baseline,fresh]:
			car.present(state.position,0.15,state,frame)
			car.present_suspension(state,0.04)
		check(geometry(baseline)==geometry(fresh),label+" live presentation matches procedural original at tick "+str(tick))
		check(state.snapshot()==canonical,label+" presentation leaves canonical state unchanged at tick "+str(tick))
	var bytes: int = 0
	for entry: Dictionary in CARS.entries: bytes += int(entry.bytes)
	check(bytes<=CARS.MAX_BYTES and CARS.entries.size()<=CARS.MAX_ENTRIES,label+" existing memory and entry limits hold")
	metrics.append({"case":label,"cold_ms":cold_ms,"restore_ms":warm_ms,"bytes":bytes})
	print("FITTED_CASE ",JSON.stringify(metrics.back()))
	baseline.free(); restored.free(); fresh.free()
	await process_frame

func run() -> void:
	output = OS.get_environment("BMT_LOADING_FIX_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	root.position = Vector2i(10000,10000)
	viewport = SubViewport.new(); viewport.size = Vector2i(640,360); viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new(); viewport.add_child(stage)
	var camera := Camera3D.new(); stage.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 7.0; camera.position = Vector3(5.4,5.8,7.1); camera.look_at(Vector3(0,0.6,0)); camera.current = true
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-58,-35,0); light.shadow_enabled = true; stage.add_child(light)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new(); environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color("647158"); environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color = Color("bac8ce"); environment.environment.ambient_light_energy = 0.35; stage.add_child(environment)
	await fitted_case("compact",{"version":VehicleCustomisation.VERSION,"aero":"biwing","body":"wide","hood":"scoop","rims":"turbine"},"compact-tablet-fit")
	for id: String in VehicleCatalog.IDS:
		var parts: Dictionary = VehicleCustomisation.defaults()
		for category: String in VehicleCustomisation.CATEGORIES: parts[category] = str(VehicleCustomisation.options(category,id)[-1][0])
		await fitted_case(id,parts,id+"-fitted")
	var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	viewport.free()
	print("FITTED_SIMPLE_CACHE: ",checks," checks, ",failures," failures ",JSON.stringify(metrics))
	quit(1 if failures else 0)

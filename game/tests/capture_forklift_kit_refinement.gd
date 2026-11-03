extends SceneTree
## Fixed, settled native views in an unmodified Garage world. No owner state.

func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size=Vector2i(1280,960)
	root.content_scale_size=root.size
	var output: String="res://../docs/evidence/forklift-kit-refinement-2026-11-02/review-gl"
	var detail: bool="--cover-guard-detail" in OS.get_cmdline_user_args()
	if detail: output="res://../docs/evidence/forklift-cover-guard-variation-2026-11-03/detail"
	var before: bool="--before" in OS.get_cmdline_user_args()
	if before: output="res://../docs/evidence/forklift-kit-refinement-2026-11-02/before-review-gl"
	var only: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--only="): only=arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var showroom:=CarShowroom.new()
	showroom.vehicle_id="forklift"
	showroom.garage_mode=true
	showroom.livery=VehicleLivery.defaults("forklift")
	root.add_child(showroom)
	MenuStyle.fill(showroom)
	while not showroom.showroom_ready: await process_frame
	var count: int=0
	for category: String in VehicleCustomisation.CATEGORIES:
		if detail and category not in ["hood","aero"]: continue
		for choice: Array in VehicleCustomisation.options(category,"forklift"):
			if not only.is_empty() and category+"/"+str(choice[0]) not in only.split(","): continue
			var parts: Dictionary=VehicleCustomisation.defaults()
			parts[category]=choice[0]
			showroom.apply_customisation(parts)
			if before: await legacy_model(showroom,parts)
			var target: Vector3
			var offset: Vector3
			match category:
				"hood": target=Vector3(0,1.48,1.04); offset=Vector3(1.35,1.60,2.05)
				"aero": target=Vector3(0,0.65,1.60); offset=Vector3(1.90,0.85,2.20)
				"rims": target=Vector3(0.84,0.43,-0.98); offset=Vector3(1.20,0.28,-0.12)
				"body": target=Vector3(0,2.02,0.10); offset=Vector3(-2.70,1.80,2.80)
			if detail: offset=Vector3(1.65,0.40,1.85) if category=="hood" else Vector3(0,0.30,2.70)
			var at: Vector3=showroom.car.body.global_transform*target
			showroom.camera.look_at_from_position(at+showroom.car.body.global_transform.basis*offset,at)
			showroom.invalidate_render()
			if showroom.reflections!=null: showroom.reflections.sync()
			for i: int in range(5): await process_frame
			await RenderingServer.frame_post_draw
			var pixels: Image=showroom.showroom_viewport.get_texture().get_image()
			assert(pixels.save_png(output.path_join(category+"-"+str(choice[0])+".png"))==OK)
			count+=1
			print("FORKLIFT_KIT_CAPTURE ",category,"/",choice[0])
	showroom.free()
	print("FORKLIFT_KIT_REVIEW: ",count," captures")
	quit()

func legacy_model(showroom: CarShowroom, parts: Dictionary) -> void:
	# Restore task-start builders only inside this isolated review process.
	var model: GDScript=load("res://../docs/evidence/forklift-kit-refinement-2026-11-02/before/game/vehicle/forklift_model.gd")
	var kits: GDScript=load("res://../docs/evidence/forklift-kit-refinement-2026-11-02/before/game/vehicle/forklift_kits.gd")
	var car: CarVisual=showroom.car
	car.graphics.restore_originals()
	for category: String in VehicleCustomisation.CATEGORIES:
		for frame: Node3D in car.kit_frames.get(category,[]):
			frame.get_parent().remove_child(frame)
			frame.free()
	car.kit_frames.clear()
	var positions: Array[Vector3]=car.wheel_rest_positions.duplicate()
	var radii: Array[float]=car.wheel_radii.duplicate()
	for rotor: Node3D in car.rolling_wheels:
		var pivot: Node=rotor.get_parent()
		car.remove_child(pivot)
		pivot.free()
	car.front_wheels.clear(); car.rear_wheels.clear(); car.rolling_wheels.clear()
	car.wheel_radii.clear(); car.wheel_rest_positions.clear()
	for child: Node in car.body.get_children(): child.free()
	car.customisation=parts.duplicate(true)
	model.build(car)
	for i: int in range(positions.size()): model.wheel(car,positions[i],radii[i]/HandlingConfig.BODY_SCALE,0.32 if positions[i].z<0 else 0.25)
	for category: String in VehicleCustomisation.CATEGORIES: kits.build(car,category)
	await VisualGeometry.batch_static_parts(car)
	await VisualGeometry.batch_car_parts(car)
	car._update_rear_lights()
	car.graphics=LiveryGraphics.new()
	car.graphics.configure(car)
	showroom.weathering=VehicleWeathering.new()
	showroom.weathering.configure(car,"pine",VehicleCatalog.config("forklift"))
	if showroom.reflections!=null: showroom.reflections.mark_stage(showroom.turntable)
	showroom.invalidate_render()

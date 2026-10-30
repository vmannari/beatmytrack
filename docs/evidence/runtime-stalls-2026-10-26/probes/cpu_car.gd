extends "res://vehicle/car_visual.gd"
func _ready() -> void:
	_model_slice_started = Time.get_ticks_usec() if cooperative_build else 0
	scale = Vector3.ONE * HandlingConfig.BODY_SCALE
	if vehicle_id == "forklift": rear_steering_config = VehicleCatalog.config(vehicle_id)
	if not VehicleCustomisation.valid(customisation): customisation = VehicleCustomisation.defaults()
	if garage_template and preload("res://ui/garage_car_cache.gd").restore(self):
		if livery.is_empty(): livery = VehicleLivery.defaults(vehicle_id)
		apply_livery(livery)
		_update_rear_lights()
		graphics.configure(self)
		force_update_transform()
		for node: Node3D in find_children("*","Node3D",true,false): node.force_update_transform()
		model_ready = true
		return
	if preload("res://vehicle/prepared_car_cache.gd").restore(self):
		if livery.is_empty(): livery = VehicleLivery.defaults(vehicle_id)
		apply_livery(livery)
		_update_rear_lights()
		graphics.configure(self)
		force_update_transform()
		for node: Node3D in find_children("*","Node3D",true,false): node.force_update_transform()
		model_ready = true
		return
	if vehicle_id != "compact":
		VehicleModels.build(self, vehicle_id)
		if not livery.is_empty(): apply_livery(livery)
		_update_rear_lights()
		await _finish_render_model()
		model_ready = true
		return
	var paint := CompactFinish.paint(Color("e0d5b5"))
	var blue := CompactFinish.paint(Color("30627d"))
	paint_materials = {"body":blue, "accent":paint}
	var trim := CompactFinish.rubber(Color("171e21"))
	var glass := VisualGeometry.material(Color("1e3036"))
	var rim := CompactFinish.alloy(Color("657177"))
	brake_material = VisualGeometry.material(Color("802d2b"))
	body = Node3D.new()
	add_child(body)
	_model_stage = "body"
	var trace_cpu_main_body: int = Time.get_ticks_usec()
	CompactCoachwork.build_body(self,blue)
	(Engine.get_main_loop() as SceneTree).span("cpu_main_body",trace_cpu_main_body)
	if not await _model_checkpoint(): return
	# Three-door hatch: the cabin reaches the tail, with no sedan boot deck.
	_model_stage = "cabin"
	var trace_cpu_cabin: int = Time.get_ticks_usec()
	_hatchback(paint, glass, trim, blue)
	(Engine.get_main_loop() as SceneTree).span("cpu_cabin",trace_cpu_cabin)
	if not await _model_checkpoint(): return
	_model_stage = "wheels"
	for side: float in [-1.0, 1.0]:
		for axle: float in [-1.28, 1.28]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.83, 0.37, axle)
			add_child(pivot)
			var trace_cpu_tire: int = Time.get_ticks_usec()
			CompactDetail.tire(pivot, trim, simple_model)
			(Engine.get_main_loop() as SceneTree).span("cpu_tire",trace_cpu_tire)
			var rim_parent: Node3D = new_kit_frame("rims",pivot) if editable_kits else pivot
			if CompactKits.choice(self,"rims") == "stock":
				var hub := VisualGeometry.cylinder(rim_parent, 0.228, 0.16, Vector3.ZERO, trim,true)
				hub.rotation.z = PI * 0.5
				for spoke: int in range(8):
					var a: float = spoke*TAU/8.0
					_seam(rim_parent,Vector3(side*0.085,sin(a)*0.08,cos(a)*0.08),Vector3(side*0.148,sin(a)*0.222,cos(a)*0.222),0.032,rim)
			else: CompactKits.build_wheel(self,rim_parent,side)
			if axle < 0:
				front_wheels.append(pivot)
			register_rolling_wheel(pivot, 0.37)
			var brake_parent: Node3D = new_kit_frame("rims",pivot) if editable_kits else pivot
			if CompactKits.choice(self,"rims") != "stock": CompactKits.build_caliper(brake_parent,side)
			if not await _model_checkpoint(): return
	_model_stage = "details"
	await preload("res://../build/runtime-stall-investigation-2026-10-26/cpu_detail.gd").build(self, blue, paint, trim, rim,_model_checkpoint if cooperative_build else Callable())
	if not await _model_checkpoint(): return
	CompactKits.build_aero(self)
	CompactKits.build_body(self)
	if not livery.is_empty(): apply_livery(livery)
	_update_rear_lights()
	await _finish_render_model()
	model_ready = true

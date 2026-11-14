extends "res://tests/review_car_reductions_2026_11_13.gd"
## CTR01-CTR03: disposable candidates and native LOD observations; no asset writes.
const REVIEW_OUT = "res://../docs/evidence/car-triangle-review-2026-11-14"
var native_rows: Array = []

func _initialize() -> void:
	triangle_review.call_deferred()

func mesh_candidate(car: CarVisual, metric: float) -> Dictionary:
	var changes: Dictionary = {}
	var policy := preload("res://vehicle/car_mesh_lods.gd").new()
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null or not part.is_visible_in_tree(): continue
		if not policy.eligible(part,car.vehicle_id): continue
		var reduced: Mesh = lod_candidate(part.mesh,metric)
		if reduced != part.mesh: changes[part] = [part.mesh,reduced]
	return changes

func settle_view(view: CarShowroom) -> void:
	view.invalidate_render()
	for frame: int in range(8):
		await process_frame
		await RenderingServer.frame_post_draw

func save_view(view: CarShowroom, path: String) -> Dictionary:
	await settle_view(view)
	var image_data: Image = view.showroom_viewport.get_texture().get_image()
	check(image_data.save_png(path)==OK,"native capture "+path.get_file())
	return {
		"image":path.get_file(),
		"primitives":view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"draws":view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	}

func triangle_review() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("CTR native review requires a renderer")
		quit(1)
		return
	var directory: String = REVIEW_OUT.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for id: String in VehicleCatalog.IDS:
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.simple_model = true
		view.read_only = true
		view.livery = VehicleLivery.defaults(id)
		view.customisation = VehicleCustomisation.defaults()
		view.size = Vector2(1000,760)
		var hits: int = Base.hits
		root.add_child(view)
		var deadline: int = Time.get_ticks_msec()+60000
		while not view.showroom_ready or not view.car.model_ready:
			if Time.get_ticks_msec()>deadline:
				printerr("CTR model timeout ",id)
				quit(1)
				return
			await process_frame
		var baseline: Dictionary = detail_inventory(view.car)
		var variants: Array = []
		for specification: Array in [["mild",0.001],["medium",0.003],["coarse",0.01]]:
			var changes: Dictionary = mesh_candidate(view.car,specification[1])
			swap(changes,true)
			var count: Dictionary = inventory(view.car,false)
			swap(changes,false)
			check(inventory(view.car,false).triangles==baseline.triangles,"candidate restoration "+id)
			variants.append({"level":specification[0],"metric":specification[1],"changes":changes,"triangles":count.triangles,"surfaces":count.surfaces,"mesh_bytes":count.buffer_bytes,"captures":[]})
		var biases: Dictionary = {}
		for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
			biases[part] = part.lod_bias
		var observations: Array = []
		for shot: Array in [["front",-0.70,0.31,1.0],["rear",2.45,0.31,1.0],["distant",-0.4,1.02,3.1]]:
			view.yaw = shot[1]
			view.elevation = shot[2]
			view.zoom = float(shot[3])*(1.05 if id in ["compact","forklift"] else 0.85)
			view._orbit()
			var prefix: String = directory.path_join(id+"-"+shot[0])
			for part: MeshInstance3D in biases: part.lod_bias = biases[part]
			var production: Dictionary = await save_view(view,prefix+"-production.png")
			var lod_levels: Array = []
			for multiplier: float in [0.5,0.25]:
				for part: MeshInstance3D in biases: part.lod_bias = float(biases[part])*multiplier
				var sample: Dictionary = await save_view(view,prefix+"-bias"+str(multiplier)+".png")
				sample.bias_multiplier = multiplier
				lod_levels.append(sample)
			# Master comparisons deliberately disable distance selection on the car.
			# They assess the authored candidate, not its incremental race GPU benefit.
			for part: MeshInstance3D in biases: part.lod_bias = 100000.0
			var master: Dictionary = await save_view(view,prefix+"-master.png")
			for variant: Dictionary in variants:
				swap(variant.changes,true)
				variant.captures.append(await save_view(view,prefix+"-"+variant.level+".png"))
				swap(variant.changes,false)
			var restored: Dictionary = await save_view(view,prefix+"-restored.png")
			observations.append({"view":shot[0],"production":production,"master":master,"restored":restored,"lod_levels":lod_levels})
		for variant: Dictionary in variants: variant.erase("changes")
		var distinct_biases: Array = []
		for value: float in biases.values():
			if value not in distinct_biases: distinct_biases.append(value)
		native_rows.append({"vehicle":id,"base_hits":Base.hits-hits,"baseline":baseline,"biases":distinct_biases,"viewport_lod_threshold":view.showroom_viewport.mesh_lod_threshold,"candidates":variants,"views":observations})
		print("CTR_NATIVE ",id," current=",baseline.triangles," variants=",variants.map(func(v: Dictionary)->int: return v.triangles))
		view.free()
		candidate_cache.clear()
		generated_cache.clear()
		await process_frame
	var file := FileAccess.open(directory.path_join("native.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"requirements":["CTR01","CTR02","CTR03"],"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"checks":checks,"failures":failures,"rows":native_rows},"\t"))
	file.close()
	print("CTR_COMPLETE checks=",checks," failures=",failures)
	quit(1 if failures else 0)

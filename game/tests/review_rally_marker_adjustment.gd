extends SceneTree
## RSM02: exact retained-member migration and native side-marker review.
const Detail = preload("res://vehicle/car_detail_reduction.gd")
const Surface = preload("res://vehicle/car_surface_reduction.gd")
const OUT: String = "res://../docs/evidence/rally-marker-adjustment-2026-11-15"
var registry: Dictionary = {}
var migrations: Dictionary = {}
var mode: String = "before"
var marker_observations: int = 0

func _initialize() -> void: run.call_deferred()

func marker(part: MeshInstance3D) -> bool:
	return part.mesh.get_aabb().size.is_equal_approx(Vector3(0.020,0.032,0.066))

func inspect(group: Dictionary, layer: String) -> void:
	var others: Array = []
	var markers: Array = []
	for entry: Dictionary in group.entries:
		if marker(entry.part): markers.append(entry)
		else: others.append(entry.code)
	if not markers.is_empty():
		assert(markers.size()==2,"Both symmetric side markers must be present")
		others.sort()
		var key: String = layer+var_to_bytes(others).hex_encode().sha256_text()
		var folder: String = Detail.ROOT if layer=="detail" else Surface.ROOT
		var path: String = folder.path_join("compact_"+group.code+".json")
		var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		if mode=="before":
			for entry: Dictionary in markers: assert(not recipe.get("parts",{}).has(entry.code),"Marker has no reduction row")
			registry[key] = {"context":group.code,"recipe":recipe,"others":others}
		else:
			assert(registry.has(key),"Every non-marker member, finish and pose remains exact")
			var prior: Dictionary = registry[key]
			if not prior.recipe.is_empty():
				var migrated: Dictionary = prior.recipe.duplicate(true)
				migrated.context = group.code
				if mode=="migrate":
					assert(not FileAccess.file_exists(path) or recipe==migrated,"Preserve existing recipes")
					FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(migrated,"  "))
				else: assert(recipe==migrated,"All retained reduction rows exact")
				migrations[path] = {"old_context":prior.context,"retained_members":others.size(),"retained_rows":migrated.parts.size()}
				if layer=="detail": Detail.recipes["compact_"+group.code] = migrated
				else: Surface.recipes["compact_"+group.code] = migrated
			for entry: Dictionary in markers:
				assert(is_equal_approx(entry.pose.origin.y,0.870),"Marker lowered 25 mm from prior review")
				assert(is_equal_approx(entry.pose.origin.z,-0.940),"Marker moved rearward 50 mm")
				# Conservative envelope includes the widest squared kit shoulder.
				var nearest: Vector2 = Vector2(entry.pose.origin.y-0.016-0.37,absf(entry.pose.origin.z+1.28)-0.033)
				assert(nearest.length()>0.492+0.065+0.010,"At least 10 mm beyond every fitted fender envelope")
				marker_observations += 1
	if layer=="detail": Detail.apply_group(group)
	else: Surface.apply_group(group,Detail)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode=argument.trim_prefix("--mode=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if mode!="before": registry=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("registry.json")))
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	Detail.offline=func(group: Dictionary) -> void: inspect(group,"detail")
	Surface.offline=func(group: Dictionary) -> void: inspect(group,"surface")
	for editable: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="compact";car.simple_model=true;car.editable_kits=editable;car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		car.free();await process_frame
	if mode=="before": FileAccess.open(OUT.path_join("registry.json"),FileAccess.WRITE).store_string(JSON.stringify(registry,"  "))
	else: FileAccess.open(OUT.path_join("migration.json"),FileAccess.WRITE).store_string(JSON.stringify(migrations,"  "))
	Detail.offline=Callable();Surface.offline=Callable()
	if DisplayServer.get_name()!="headless":
		var prepared: bool="--prepared" in OS.get_cmdline_user_args()
		preload("res://vehicle/modular_car_base.gd").enabled=prepared
		preload("res://vehicle/modular_car_kits.gd").enabled=prepared
		preload("res://vehicle/prepared_car_cache.gd").enabled=prepared
		for body: String in ["stock","rally","wide"]:
			var view:=CarShowroom.new()
			view.vehicle_id="compact";view.simple_model=true;view.read_only=true;view.size=Vector2(1000,760)
			view.customisation=VehicleCustomisation.defaults();view.customisation.body=body
			var hits: int=preload("res://vehicle/modular_car_base.gd").hits
			root.add_child(view)
			while not view.showroom_ready or not view.car.model_ready: await process_frame
			if prepared: assert(preload("res://vehicle/modular_car_base.gd").hits==hits+1,"Actual prepared model consumed")
			for side: float in [-1.0,1.0]:
				view.camera.position=Vector3(side*3.6,1.12,-0.82)
				view.camera.look_at(Vector3(0,0.75,-1.05))
				for frame: int in range(12):
					view.invalidate_render();await process_frame;await RenderingServer.frame_post_draw
				var image: Image=view.showroom_viewport.get_texture().get_image()
				assert(image.save_png(OUT.path_join("%s-%s-%s-%s.png"%[mode,RenderingServer.get_current_rendering_method(),body,str(side)]))==OK)
			view.queue_free();await process_frame
	print("RALLY_MARKER ",mode," retained frames=",registry.size()," migrated recipes=",migrations.size()," measured markers=",marker_observations)
	quit()

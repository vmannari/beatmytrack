extends SceneTree
## Compare stock simple Forklift's visible geometry and shadows with/without proxies.
## Isolated diagnostic; it never edits player data or generated resources.

class ProceduralControl extends CarVisual:
	func _ready() -> void:
		scale = Vector3.ONE * HandlingConfig.BODY_SCALE
		rear_steering_config = VehicleCatalog.config(vehicle_id)
		customisation = VehicleCustomisation.defaults()
		VehicleModels.build(self,vehicle_id)
		if not livery.is_empty(): apply_livery(livery)
		_update_rear_lights()
		RacingCarModels._reduce_primitives(self)
		await VisualGeometry.batch_static_parts(self)
		await VisualGeometry.batch_car_parts(self)
		if livery.is_empty(): livery = VehicleLivery.defaults(vehicle_id)
		graphics.configure(self)
		model_ready = true

var out: String = "res://../build/forklift-shadow-review"
var candidate_body: String = ""
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func metrics(car: CarVisual) -> Dictionary:
	var result := {"visible_triangles":0,"casters":0,"caster_triangles":0,"proxy_triangles":0,"proxies":0}
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null or not node.visible: continue
		var triangles: int = 0
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: result.visible_triangles += triangles
		else: result.proxies += 1; result.proxy_triangles += triangles
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: result.casters += 1; result.caster_triangles += triangles
	return result

func compare(a: Image, b: Image) -> Dictionary:
	var left: PackedByteArray = a.get_data()
	var right: PackedByteArray = b.get_data()
	if a.get_size() != b.get_size() or a.get_format() != b.get_format() or left.size() != right.size(): return {"invalid":true}
	var stride: int = left.size()/(a.get_width()*a.get_height())
	var changed: int = 0
	var max_delta: int = 0
	var sum: int = 0
	var min_x: int = a.get_width(); var min_y: int = a.get_height(); var max_x: int = -1; var max_y: int = -1
	for pixel: int in range(a.get_width()*a.get_height()):
		var pixel_changed: bool = false
		for channel: int in range(mini(stride,3)):
			var delta: int = absi(int(left[pixel*stride+channel])-int(right[pixel*stride+channel]))
			max_delta = maxi(max_delta,delta); sum += delta
			pixel_changed = pixel_changed or delta > 0
		if pixel_changed:
			changed += 1
			var x: int = pixel%a.get_width(); var y: int = pixel/a.get_width()
			min_x = mini(min_x,x); min_y = mini(min_y,y); max_x = maxi(max_x,x); max_y = maxi(max_y,y)
	return {"changed_pixels":changed,"max_channel_delta":max_delta,"mean_rgb_delta":float(sum)/(a.get_width()*a.get_height()*3),"bounds":[min_x,min_y,max_x,max_y]}

func shadow_overlap(no_shadow: Image, original: Image, optimized: Image) -> Dictionary:
	var background: PackedByteArray = no_shadow.get_data()
	var before: PackedByteArray = original.get_data()
	var after: PackedByteArray = optimized.get_data()
	var pixels: int = original.get_width()*original.get_height()
	var stride: int = background.size()/pixels
	var original_count: int = 0; var optimized_count: int = 0; var both: int = 0; var union: int = 0
	for pixel: int in range(pixels):
		var original_darkening: int = 0; var optimized_darkening: int = 0
		for channel: int in range(3):
			var index: int = pixel*stride+channel
			original_darkening += maxi(0,int(background[index])-int(before[index]))
			optimized_darkening += maxi(0,int(background[index])-int(after[index]))
		var a: bool = original_darkening >= 12
		var b: bool = optimized_darkening >= 12
		if a: original_count += 1
		if b: optimized_count += 1
		if a and b: both += 1
		if a or b: union += 1
	return {"threshold_total_rgb":12,"original_pixels":original_count,"proxy_pixels":optimized_count,"intersection":both,"union":union,"intersection_over_union":float(both)/maxi(1,union),"original_coverage":float(both)/maxi(1,original_count),"proxy_precision":float(both)/maxi(1,optimized_count)}

func snapshot(car: CarVisual, other: CarVisual, path: String) -> Image:
	other.hide(); car.show()
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var result: Image = root.get_texture().get_image()
	check(result != null and result.save_png(out.path_join(path)) == OK,"saved "+path)
	return result

func shadow_only(car: CarVisual) -> Dictionary:
	var saved: Dictionary = {}
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		saved[node] = [node.visible,node.cast_shadow]
		if node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			node.visible = false
		else: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return saved

func restore_shadow_modes(saved: Dictionary) -> void:
	for node: MeshInstance3D in saved:
		node.visible = saved[node][0]
		node.cast_shadow = saved[node][1]

func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Graphical renderer required"); quit(1); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
		if arg.begins_with("--candidate-body="): candidate_body = arg.trim_prefix("--candidate-body=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size = Vector2i(1280,720)
	root.positional_shadow_atlas_size = 2048
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/modular_car_base.gd").enabled = false
	if not candidate_body.is_empty():
		var candidate_mesh: ArrayMesh = load(candidate_body) as ArrayMesh
		if candidate_mesh == null: push_error("Candidate body mesh could not be loaded: "+candidate_body); quit(1); return
		RacingCarModels.shadow_meshes[RacingCarModels.ASSET_ROOT.path_join("forklift_shadow_0.res")] = candidate_mesh
	var world := Node3D.new(); root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("52606b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.18
	world.add_child(environment)
	var light := DirectionalLight3D.new(); light.shadow_enabled = true; light.light_energy = 0.8
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 30.0
	world.add_child(light)
	var spot := SpotLight3D.new(); spot.position = Vector3(3,7,3); spot.shadow_enabled = true
	spot.spot_range = 20.0; spot.spot_angle = 55.0; spot.light_energy = 6.0
	world.add_child(spot); spot.look_at(Vector3.ZERO)
	var floor_material := StandardMaterial3D.new(); floor_material.albedo_color = Color(0.24,0.25,0.24); floor_material.roughness = 1.0
	var floor: MeshInstance3D = VisualGeometry.box(world,Vector3(36,0.1,36),Vector3(0,-0.05,0),floor_material)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 9.0
	world.add_child(camera); camera.position = Vector3(-6,7,-9); camera.look_at(Vector3.ZERO)
	var control := ProceduralControl.new(); control.vehicle_id = "forklift"; control.simple_model = true; control.livery = VehicleLivery.defaults("forklift")
	world.add_child(control)
	while not control.model_ready: await process_frame
	var candidate := CarVisual.new(); candidate.vehicle_id = "forklift"; candidate.simple_model = true; candidate.livery = VehicleLivery.defaults("forklift")
	world.add_child(candidate)
	while not candidate.model_ready: await process_frame
	var original: Dictionary = metrics(control); var optimized: Dictionary = metrics(candidate)
	print("FORKLIFT_SHADOW_CONTROL ",JSON.stringify(original))
	print("FORKLIFT_SHADOW_PROXY ",JSON.stringify(optimized))
	check(original.visible_triangles == optimized.visible_triangles,"visible geometry triangle counts agree")
	check(optimized.proxies == 5 and optimized.casters == 5,"five articulated shadow proxies used")
	check(optimized.caster_triangles < original.caster_triangles,"shadow triangles reduced")
	check(control.rolling_wheels.size() == 4 and candidate.rolling_wheels.size() == 4 and control.rear_wheels.size() == 2 and candidate.rear_wheels.size() == 2,"wheel frames intact")
	var rows: Array = []
	for configuration: Array in [["high",-70.0,0.0,Vector3(1,9,1)],["medium",-35.0,0.0,Vector3(3,7,3)],["low",-15.0,0.0,Vector3(7,3,5)],["steered",-35.0,0.55,Vector3(3,7,3)]]:
		var label: String = configuration[0]
		camera.size = 13.0 if label == "low" else 9.0
		light.rotation_degrees = Vector3(configuration[1],35,0)
		spot.position = configuration[3]; spot.look_at(Vector3.ZERO)
		for car: CarVisual in [control,candidate]:
			for wheel: Node3D in car.rear_wheels: wheel.rotation.y = configuration[2]
			for node: Node3D in car.find_children("*","Node3D",true,false): node.force_update_transform()
		var before: Image = await snapshot(control,candidate,label+"-procedural.png")
		var after: Image = await snapshot(candidate,control,label+"-proxy.png")
		var repeat: Image = await snapshot(control,candidate,label+"-procedural-repeat.png")
		var row: Dictionary = {"case":label,"comparison":compare(before,after),"control_repeat":compare(before,repeat)}
		var original_modes: Dictionary = shadow_only(control)
		var optimized_modes: Dictionary = shadow_only(candidate)
		var isolated_before: Image = await snapshot(control,candidate,label+"-shadow-procedural.png")
		var isolated_after: Image = await snapshot(candidate,control,label+"-shadow-proxy.png")
		var isolated_repeat: Image = await snapshot(control,candidate,label+"-shadow-repeat.png")
		row.shadow_only = compare(isolated_before,isolated_after)
		row.shadow_control_repeat = compare(isolated_before,isolated_repeat)
		for node: MeshInstance3D in original_modes:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visible = false
		var no_shadow: Image = await snapshot(control,candidate,label+"-shadow-disabled.png")
		row.shadow_on_vs_off = compare(isolated_before,no_shadow)
		row.shadow_overlap = shadow_overlap(no_shadow,isolated_before,isolated_after)
		var shadow_pixels: int = int(row.shadow_on_vs_off.get("changed_pixels",0))
		check(shadow_pixels > 100 and shadow_pixels < root.size.x*root.size.y/2,"scene actually renders a localized shadow "+label)
		restore_shadow_modes(original_modes); restore_shadow_modes(optimized_modes)
		rows.append(row); print("FORKLIFT_SHADOW_VIEW ",JSON.stringify(row))
	var report: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),"control":original,"proxy":optimized,"views":rows,"checks":checks,"failures":failures,"note":"Desktop raster comparisons; changed pixels include control instability. Does not measure phone performance."}
	var file := FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	if file == null: push_error("Unable to write report"); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	control.free(); candidate.free(); world.free()
	print("FORKLIFT_SHADOW_VISUAL: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

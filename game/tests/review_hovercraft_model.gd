extends SceneTree
## Matched native views and production geometry/material/identity checks.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/hovercraft-model-rebuild-2026-10-28/"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func inspect(car: CarVisual) -> Dictionary:
	var result: Dictionary = {"triangles":0,"meshes":0,"finite":true,"unit_normals":true,"degenerate":0,"bounds":AABB(),"has_bounds":false}
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		result.meshes += 1
		var box: AABB = car.global_transform.affine_inverse()*node.global_transform*node.mesh.get_aabb()
		result.bounds = result.bounds.merge(box) if result.has_bounds else box
		result.has_bounds = true
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			result.triangles += (indices.size() if not indices.is_empty() else vertices.size())/3
			for p: Vector3 in vertices: result.finite = result.finite and p.is_finite()
			for n: Vector3 in normals: result.unit_normals = result.unit_normals and n.is_finite() and absf(n.length()-1.0) < 0.01
			if not indices.is_empty():
				for index: int in range(0,indices.size(),3):
					if (vertices[indices[index+1]]-vertices[indices[index]]).cross(vertices[indices[index+2]]-vertices[indices[index]]).length_squared() < 1e-16: result.degenerate += 1
	return result
func settle() -> void:
	for frame: int in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func run() -> void:
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	output = output.path_join(("before-" if baseline else "after-")+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://ui/garage_car_cache.gd").enabled = false
	root.size = Vector2i(1280,720)
	var rows: Array = []
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	car.vehicle_id = "hovercraft"
	car.cache_rest_pose = false
	world.add_child(car)
	while not car.model_ready: await process_frame
	var detailed: Dictionary = inspect(car)
	check(car.body.get_meta("hovercraft_revision",0) >= 2,"rebuilt production hull replaces the starter assembly")
	check(detailed.triangles > 20000 and detailed.triangles <= 80000,"authored detail fits the 80000-triangle desktop/showroom budget")
	check(detailed.finite and detailed.unit_normals and detailed.degenerate == 0,"valid smooth geometry without invalid or degenerate triangles")
	check(car.paint_materials.body.roughness < 0.6 and car.paint_materials.body.clearcoat_enabled,"controlled automotive hull finish")
	check(car.body.get_node_or_null("FanRotor") != null and car.body.get_node_or_null("RudderLeft") != null,"fan and steering vanes remain articulated")
	check(car.rolling_wheels.is_empty(),"no cosmetic road wheels introduced")
	var old_colour: Color = car.paint_materials.body.albedo_color
	var other := CarVisual.new()
	other.vehicle_id = "hovercraft"
	other.simple_model = true
	other.cache_rest_pose = false
	world.add_child(other)
	while not other.model_ready: await process_frame
	var reduced: Dictionary = inspect(other)
	check(reduced.triangles < detailed.triangles*0.7 and reduced.triangles <= 30000,"racing LOD retains silhouette at a lower geometry cost")
	check(reduced.finite and reduced.unit_normals and reduced.degenerate == 0,"racing LOD has finite, normalized, nondegenerate surfaces")
	var paint: Dictionary = VehicleLivery.defaults("hovercraft")
	paint.colors.body = "844b42"
	other.apply_livery(paint)
	check(car.paint_materials.body.albedo_color == old_colour,"livery materials remain instance-local")
	other.free()
	var raw := CarVisual.new()
	raw.vehicle_id = "hovercraft"
	raw.batch_parts = false
	raw.cache_rest_pose = false
	world.add_child(raw)
	while not raw.model_ready: await process_frame
	check(raw.body.find_children("SkirtFinger*","MeshInstance3D",false,false).size() == 52,"individually shaped fabric fingers survive construction")
	check(raw.body.find_children("GuardRing*","MeshInstance3D",false,false).size() == 6,"both fan faces have complete protective cages")
	var maximum_blade_radius: float = 0.0
	for blade: MeshInstance3D in raw.body.get_node("FanRotor").find_children("Airfoil*","MeshInstance3D",false,false):
		for p: Vector3 in blade.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: maximum_blade_radius = maxf(maximum_blade_radius,Vector2(p.x,p.y).length())
	check(maximum_blade_radius < 0.54,"swept propeller has at least 13mm clearance inside the 553mm duct")
	var Model = preload("res://vehicle/hovercraft_model.gd")
	var maximum_deck_gap: float = 0.0
	for index: int in range(256):
		var p: Vector3 = Model._outline(index*TAU/256.0,0.92,0.82)
		maximum_deck_gap = maxf(maximum_deck_gap,absf(p.y-Model._deck_y(p.x,p.z)))
	check(maximum_deck_gap < 0.00001,"crowned deck closes against the hull around the entire perimeter")
	var maximum_cabin_gap: float = 0.0
	for index: int in range(65):
		var v: float = index/64.0
		maximum_cabin_gap = maxf(maximum_cabin_gap,Model._windshield(1.0,v).distance_to(Model._side(1.0,0.0,v)))
	check(maximum_cabin_gap < 0.000001,"front and side glazing frames share one continuous shell")
	var maximum_lip_height: float = 0.0
	for p: Vector3 in raw.body.get_node("FormedCompositeHull").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: maximum_lip_height = maxf(maximum_lip_height,p.y)
	check(maximum_lip_height <= 0.820001,"rolled hull cannot overshoot and flicker through the deck")
	var roof_join_up: bool = true
	for label: String in ["CurvedWindshieldFrame","ArchedCanopy","CabinRear"]:
		var arrays: Array = raw.body.get_node(label).mesh.surface_get_arrays(0)
		for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
			if absf(arrays[Mesh.ARRAY_VERTEX][index].y-1.36) < 0.000001: roof_join_up = roof_join_up and arrays[Mesh.ARRAY_NORMAL][index].dot(Vector3.UP) > 0.99
	check(roof_join_up,"actual shell and canopy normals meet smoothly at the roof")
	var frame := VehicleState.new()
	frame.tick = 123
	frame.steering = 0.6
	raw.present(Vector2.ZERO,0,frame,DriveFrame.sample(0.6,1,0))
	check(not is_zero_approx(raw.body.get_node("FanRotor").rotation.z) and raw.body.get_node("RudderLeft").rotation.y < 0.0,"fan and steering foils animate after batching")
	raw.set_night_headlights(true)
	check(raw.headlights != null and raw.road_headlight != null and not raw.road_headlight.shadow_enabled,"fitted night lenses retain one bounded road light")
	raw.free()
	ShowroomStudio.build(world,car)
	var camera := Camera3D.new()
	camera.fov = 35.0
	world.add_child(camera)
	camera.current = true
	if DisplayServer.get_name() != "headless":
		for view: Array in [["front",Vector3(-4.5,3.1,-5.8),Vector3(0,1,0)],["rear",Vector3(4.4,3.0,5.6),Vector3(0,1,0)],["side",Vector3(-6.1,2.4,0),Vector3(0,1,0)],["overhead",Vector3(-3,6,-4.2),Vector3(0,0.8,0)],["bow-detail",Vector3(-1.8,1.5,-3.0),Vector3(0,0.9,-1.15)],["fan-detail",Vector3(1.9,2.2,3.4),Vector3(0,1.3,1.2)],["skirt-detail",Vector3(-2.2,0.8,-2.7),Vector3(-0.5,0.45,-1.1)]]:
			camera.position = view[1]
			camera.look_at(view[2])
			await settle()
			check(root.get_texture().get_image().save_png(output.path_join(view[0]+".png")) == OK,"saved "+view[0])
	rows.append({"detailed":detailed,"simple":reduced})
	var file := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"models":rows},"\t"))
	file.close()
	world.free()
	await process_frame
	print("HOVERCRAFT_MODEL_REVIEW: %d checks, %d failures; full=%d simple=%d" % [checks,failures,detailed.triangles,reduced.triangles])
	quit(1 if failures else 0)

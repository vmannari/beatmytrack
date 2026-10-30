extends SceneTree
## Matched native views and actual-geometry checks for the sports redesign.
const EVIDENCE: String = "res://../docs/evidence/hovercraft-concept-2026-10-29"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func inspect(car: CarVisual) -> Dictionary:
	var result: Dictionary = {"meshes":0,"triangles":0,"finite":true,"unit_normals":true,"degenerate":0,"bounds":AABB(),"has_bounds":false,"bow_half_width":0.0,"mid_half_width":0.0}
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		result.meshes += 1
		var pose: Transform3D = inverse*node.global_transform
		var box: AABB = pose*node.mesh.get_aabb()
		result.bounds = result.bounds.merge(box) if result.has_bounds else box
		result.has_bounds = true
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			result.triangles += (indices.size() if not indices.is_empty() else vertices.size())/3
			for point: Vector3 in vertices:
				result.finite = result.finite and point.is_finite()
				var p: Vector3 = pose*point
				if p.z < -1.50: result.bow_half_width = maxf(result.bow_half_width,absf(p.x))
				if absf(p.z) < 0.35: result.mid_half_width = maxf(result.mid_half_width,absf(p.x))
			for normal: Vector3 in normals:
				result.unit_normals = result.unit_normals and normal.is_finite() and absf(normal.length()-1.0) < 0.01
			if not indices.is_empty():
				for index: int in range(0,indices.size(),3):
					if (vertices[indices[index+1]]-vertices[indices[index]]).cross(vertices[indices[index+2]]-vertices[indices[index]]).length_squared() < 1e-16: result.degenerate += 1
	var bounds: AABB = result.bounds
	result.bounds_position = [bounds.position.x,bounds.position.y,bounds.position.z]
	result.bounds_size = [bounds.size.x,bounds.size.y,bounds.size.z]
	result.maximum_height = bounds.end.y
	result.erase("bounds")
	return result

func settle() -> void:
	for frame: int in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	var method: String = RenderingServer.get_current_rendering_method()
	var output: String = EVIDENCE.path_join(("before-" if before else "after-")+method)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	preload("res://ui/garage_car_cache.gd").enabled = false
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	car.vehicle_id = "hovercraft"
	car.cache_rest_pose = false
	car.batch_parts = false
	world.add_child(car)
	while not car.model_ready: await process_frame
	var detailed: Dictionary = inspect(car)
	var other := CarVisual.new()
	other.vehicle_id = "hovercraft"
	other.simple_model = true
	other.cache_rest_pose = false
	world.add_child(other)
	while not other.model_ready: await process_frame
	var reduced: Dictionary = inspect(other)
	if not before:
		check(car.body.get_meta("hovercraft_revision",0) >= 3,"new sports revision is installed")
		check(detailed.maximum_height <= 1.50,"full model is at most 1.50 metres high")
		check(detailed.bow_half_width > 0.0 and detailed.mid_half_width > 0.0 and detailed.bow_half_width < detailed.mid_half_width*0.72,"bow tapers distinctly relative to the midbody")
		check(detailed.finite and detailed.unit_normals and detailed.degenerate == 0,"full geometry is finite, normalized and nondegenerate")
		check(reduced.finite and reduced.unit_normals and reduced.degenerate == 0,"racing geometry is finite, normalized and nondegenerate")
		check(detailed.triangles <= 80000 and reduced.triangles <= 30000 and reduced.triangles < detailed.triangles*0.70,"full and racing geometry fit budgets")
		for side: int in [-1,1]:
			check(car.body.get_node_or_null("SportNacelleFairing%d"%side) == null,"forward fan face is unobstructed")
			check(car.body.get_node_or_null("SportFanMount%d_-1"%side) != null and car.body.get_node_or_null("SportFanMount%d_1"%side) != null,"both open fan braces exist")
			check(car.body.get_node_or_null("SportGuardRing%d_-242"%side) != null and car.body.get_node_or_null("SportGuard%d_-1_7"%side) != null,"front fan grille has a ring and eight spokes")
		check(car.body.get_node_or_null("SportSkirtSeam47") != null,"skirt has 48 divisions")
		check(car.rolling_wheels.is_empty() and other.rolling_wheels.is_empty(),"hovercraft has no road wheels")
		var left: Node3D = other.body.get_node_or_null("FanRotor/FanRotorLeft")
		var right: Node3D = other.body.get_node_or_null("FanRotor/FanRotorRight")
		var left_rudder: Node3D = other.body.get_node_or_null("RudderLeft")
		var right_rudder: Node3D = other.body.get_node_or_null("RudderRight")
		check(left != null and right != null and left != right and left_rudder != null and right_rudder != null,"two independent fans and steering vanes exist")
		if left != null and right != null and left_rudder != null and right_rudder != null:
			var left_before: Vector3 = left.rotation
			var right_before: Vector3 = right.rotation
			var state := VehicleState.new()
			state.tick = 123
			state.steering = 0.6
			other.present(Vector2.ZERO,0.0,state,DriveFrame.sample(0.6,1.0,0.0))
			check(left.rotation.distance_to(left_before) > 0.001 and right.rotation.distance_to(right_before) > 0.001,"both fans animate from the simulated tick")
			check(not is_zero_approx(left_rudder.rotation.y) and not is_zero_approx(right_rudder.rotation.y),"both vanes respond to steering")
			var right_pose: Vector3 = right.rotation
			left.rotation.z += 0.2
			check(right.rotation == right_pose,"each fan has its own transform")
		var old_colour: Color = car.paint_materials.body.albedo_color
		var saved_paint: Dictionary = VehicleLivery.defaults("hovercraft")
		saved_paint.colors = {"body":"698d87","accent":"d9d0b7","detail":"c78e4c"}
		check(VehicleLivery.normalize(saved_paint,"hovercraft") == saved_paint,"existing saved hovercraft colours survive the factory palette change")
		var paint: Dictionary = VehicleLivery.defaults("hovercraft")
		paint.colors.body = "844b42"
		other.apply_livery(paint)
		check(car.paint_materials.body.albedo_color == old_colour,"paint remains instance-local")
		other.set_night_headlights(true)
		check(other.headlights != null and other.road_headlight != null and not other.road_headlight.shadow_enabled,"fitted night lenses retain one bounded road light")
	other.free()
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
	var file := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":method,"before":before,"checks":checks,"failures":failures,"full":detailed,"simple":reduced},"\t"))
	file.close()
	world.free()
	await process_frame
	print("HOVERCRAFT_SPORT_REVIEW %s %s: %d checks, %d failures, full=%d, simple=%d, height=%.3f" % ["before" if before else "after",method,checks,failures,detailed.triangles,reduced.triangles,detailed.maximum_height])
	quit(1 if failures else 0)

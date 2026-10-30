extends SceneTree
## Actual mesh-plane sections detect reverse turns in the hood/nose silhouette.
const COACH = preload("res://vehicle/electric_coachwork.gd")
const EVIDENCE: String = "res://../docs/evidence/electric-smooth-nose-2026-10-25"
var output: String = EVIDENCE
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func section(car: CarVisual, x: float, hood: bool) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		var name_value: String = str(mesh.name)
		var selected: bool = name_value == "ClamshellHood" or name_value.begins_with("HoodSurround")
		if not hood: selected = name_value.begins_with("FormedFront")
		if not selected: continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for index: int in range(0,faces.size(),3):
			for edge: int in range(3):
				var a: Vector3 = faces[index+edge]
				var b: Vector3 = faces[index+(edge+1)%3]
				if absf(a.x-x) < 0.000001: points.append(Vector2(a.z,a.y))
				if (a.x-x)*(b.x-x) < 0:
					var point: Vector3 = a.lerp(b,(x-a.x)/(b.x-a.x))
					points.append(Vector2(point.z,point.y))
	if hood: points.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x > b.x)
	else: points.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.y > b.y)
	var unique: Array[Vector2] = []
	for point: Vector2 in points:
		if unique.is_empty() or point.distance_to(unique[-1]) > 0.0001: unique.append(point)
	return unique

func curvature(points: Array[Vector2]) -> Dictionary:
	# Compare equal 20 mm arcs of the real section. Individual triangle
	# diagonals can create sub-millimetre direction noise, especially in LOD.
	var sampled: Array[Vector2] = [points[0]]
	var remaining: float = 0.02
	for index: int in range(points.size()-1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index+1]
		var length_value: float = a.distance_to(b)
		while length_value >= remaining:
			a = a.lerp(b,remaining/length_value)
			sampled.append(a)
			length_value = a.distance_to(b)
			remaining = 0.02
		remaining -= length_value
	var previous: float = -INF
	var reverse: float = 0
	var rising: float = 0
	var segments: int = 0
	for index: int in range(sampled.size()-1):
		var delta: Vector2 = sampled[index+1]-sampled[index]
		if delta.length() < 0.0001: continue
		var angle: float = rad_to_deg(atan2(-delta.y,-delta.x))
		if is_finite(previous): reverse = maxf(reverse,previous-angle)
		rising = maxf(rising,delta.y)
		previous = angle
		segments += 1
	return {"segments":segments,"arc_sample_metres":0.02,"maximum_reverse_turn_degrees":reverse,"maximum_upward_step":rising}

func settle() -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw

func seam_normals(car: CarVisual) -> Dictionary:
	var lid: MeshInstance3D = car.body.get_node("ClamshellHood")
	var arrays: Array = lid.mesh.surface_get_arrays(0)
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for mesh: MeshInstance3D in car.body.find_children("HoodSurround*","MeshInstance3D",true,false):
		var other: Array = mesh.mesh.surface_get_arrays(0)
		for index: int in range(other[Mesh.ARRAY_VERTEX].size()):
			if (other[Mesh.ARRAY_TEX_UV][index] as Vector2).y != 0: continue
			points.append(other[Mesh.ARRAY_VERTEX][index])
			normals.append(other[Mesh.ARRAY_NORMAL][index])
	var angles: Array[float] = []
	for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
		var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][index]
		if uv.x != 0 and uv.x != 1 and uv.y != 0 and uv.y != 1: continue
		var closest: int = 0
		var distance: float = INF
		for candidate: int in range(points.size()):
			var current: float = points[candidate].distance_squared_to(arrays[Mesh.ARRAY_VERTEX][index])
			if current < distance:
				distance = current
				closest = candidate
		angles.append(rad_to_deg((arrays[Mesh.ARRAY_NORMAL][index] as Vector3).angle_to(normals[closest])))
	angles.sort()
	return {"samples":angles.size(),"p95_degrees":angles[floori((angles.size()-1)*0.95)],"maximum_degrees":angles[-1]}

func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	if before:
		output += "/before"
		var author: GDScript = COACH
		author.source_code = FileAccess.get_file_as_string(output+"/game/vehicle/electric_coachwork.gd").replace("res://assets/vehicles/electric_coachwork_v6",output+"/electric_coachwork_v6")
		assert(author.reload() == OK)
	if "--local-normals" in OS.get_cmdline_user_args():
		output += "/local-normals"
		var author: GDScript = COACH
		author.source_code = author.source_code.replace("if normal_uv.is_valid():","if false:")
		assert(author.reload() == OK)
		COACH.use_baked = false
		COACH.meshes.clear()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var label: String = "simple" if simple else "full"
		var shading: Dictionary = seam_normals(car)
		metrics[label+"_seam_normals"] = shading
		check(shading.samples > 80 and shading.p95_degrees < 3 and shading.maximum_degrees < 15,"neighbouring lid and surround normals shade smoothly across the gap, "+label)
		var lid: MeshInstance3D = car.body.get_node("ClamshellHood")
		var arrays: Array = lid.mesh.surface_get_arrays(0)
		var widths: Array[float] = []
		for target: float in [0.10,0.90]:
			var closest: float = 1
			for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]: closest = minf(closest,absf(uv.y-target))
			var left: float = INF
			var right: float = -INF
			for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
				if absf((arrays[Mesh.ARRAY_TEX_UV][index] as Vector2).y-target) > closest+0.00001: continue
				left = minf(left,arrays[Mesh.ARRAY_VERTEX][index].x)
				right = maxf(right,arrays[Mesh.ARRAY_VERTEX][index].x)
			widths.append(right-left)
		metrics[label+"_hood_taper"] = {"front_width":widths[0],"rear_width":widths[1],"ratio":widths[0]/widths[1]}
		check(is_finite(widths[0]) and widths[0] > widths[1]*0.72 and widths[0] < widths[1]*0.90,"actual bonnet narrows toward the nose instead of flaring, "+label)
		for x: float in [0.0,0.40,0.65]:
			var points: Array[Vector2] = section(car,x,true)
			points.append_array(section(car,x,false))
			var values: Dictionary = curvature(points)
			var coordinates: Array = []
			for point: Vector2 in points: coordinates.append([point.x,point.y])
			values["points"] = coordinates
			metrics[label+"_"+str(x)] = values
			check(values.segments > 25,"actual longitudinal mesh section is populated, "+label+" x="+str(x))
			check(values.maximum_upward_step < 0.0002,"hood flows downward into the nose without a dip and rise, "+label+" x="+str(x))
			check(values.maximum_reverse_turn_degrees < 1.0,"convex hood/nose section has no visible S turn, "+label+" x="+str(x))
		car.free()
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,960)
		var viewport := SubViewport.new()
		viewport.size = root.size
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		for simple: bool in [false,true]:
			var world := Node3D.new()
			viewport.add_child(world)
			var car := CarVisual.new()
			car.vehicle_id = "electric"
			car.simple_model = simple
			car.livery = VehicleLivery.defaults("electric")
			car.livery.colors.body = "263f55"
			car.livery.colors.accent = "d7e0e2"
			world.add_child(car)
			ShowroomStudio.build(world,car)
			var camera := Camera3D.new()
			world.add_child(camera)
			camera.current = true
			camera.fov = 30
			var shots: Array = [
				["owner-angle",Vector3(4.6,2.7,-2.3),Vector3(0,0.72,-1.05)],
				["side",Vector3(5,1.4,-1.3),Vector3(0,0.72,-1.3)],
				["head-on",Vector3(0,1.35,-5.2),Vector3(0,0.72,-0.35)],
				["hood-top",Vector3(0.8,4.3,-4.8),Vector3(0,0.72,-0.7)],
				["front",Vector3(3.0,2.2,-4.7),Vector3(0,0.72,-0.9)]]
			for shot: Array in shots:
				camera.position = shot[1]
				camera.look_at(shot[2])
				await settle()
				check(viewport.get_texture().get_image().save_png(output.path_join(("simple-" if simple else "full-")+shot[0]+".png")) == OK,"native smooth nose review "+str(shot[0]))
			world.free()
		viewport.free()
	var report := FileAccess.open(output+"/smooth-nose.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"before":before,"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_SMOOTH_NOSE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends SceneTree
## Verify actual prepared hood surfaces, perimeter returns and native review poses.
const COACH = preload("res://vehicle/electric_coachwork.gd")
var output: String = "res://../docs/evidence/electric-lucid-hood-2026-10-25"
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func faces(car: CarVisual) -> PackedVector3Array:
	var result := PackedVector3Array()
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name).begins_with("Hood") or str(mesh.name) == "ClamshellHood":
			result.append_array(mesh.mesh.get_faces())
	return result

func height(triangles: PackedVector3Array, x: float, z: float) -> float:
	var y: float = -INF
	for index: int in range(0,triangles.size(),3):
		var point: Variant = Geometry3D.ray_intersects_triangle(Vector3(x,2,z),Vector3.DOWN,triangles[index],triangles[index+1],triangles[index+2])
		if point != null: y = maxf(y,point.y)
	return y

func settle() -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
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
		var triangles: PackedVector3Array = faces(car)
		check(not triangles.is_empty(),"actual prepared clamshell exists, "+label)
		var panel: MeshInstance3D = car.body.get_node("ClamshellHood")
		var panel_vertices: PackedVector3Array = panel.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var joins: int = 0
		var misses: int = 0
		for edge: int in range(4):
			var returns: MeshInstance3D = car.body.get_node("HoodReturn"+str(edge)+"false")
			var arrays: Array = returns.mesh.surface_get_arrays(0)
			for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][index]
				var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]+Vector3.UP*0.005*uv.y
				var distance: float = INF
				for candidate: Vector3 in panel_vertices: distance = minf(distance,point.distance_to(candidate))
				if distance < 0.000001:
					if uv.y == 0: joins += 1
				else: misses += 1
			var uv: Vector2 = COACH.hood_edge_uv(edge,0.5).lerp(COACH.hood_edge_uv(edge,0.5,0.006),0.5)
			var point: Vector3 = COACH.hood_point(uv.x,uv.y)
			var depth: float = point.y-height(triangles,point.x,point.z)
			metrics[label+"_gap_"+str(edge)] = depth
			check(is_finite(depth) and depth > 0.0035 and depth < 0.0065,"ray reaches the recessed reveal on edge "+str(edge)+", "+label)
		check(joins > 80 and misses == 0,"all prepared lid returns join the exact panel boundary, "+label)
		metrics[label+"_return_vertices"] = {"joined":joins,"unmatched":misses}
		for z: float in [-1.85,-1.6,-1.3]:
			var center: float = height(triangles,0,z)
			var left: float = height(triangles,-0.66,z)
			var right: float = height(triangles,0.66,z)
			metrics[label+"_profile_"+str(z)] = {"center":center,"left":left,"right":right}
			# Owner's smooth-nose correction supersedes the raised-shoulder dip.
			check(is_finite(center) and absf(left-center) < 0.025,"restrained continuous transverse crown, "+label+" z="+str(z))
			check(absf(left-right) < 0.00001,"actual shoulder geometry is symmetric, "+label+" z="+str(z))
		var boundary_error: float = 0
		for mesh: MeshInstance3D in car.body.find_children("HoodSurround*","MeshInstance3D",true,false):
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			for index: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][index]
				if uv.y < 0.9999: continue
				var edge: int = str(mesh.name).trim_prefix("HoodSurround").to_int()
				var expected_uv: Vector2 = COACH.hood_surround_outer_uv(edge,uv.x)
				boundary_error = maxf(boundary_error,(arrays[Mesh.ARRAY_VERTEX][index] as Vector3).distance_to(COACH.hood_point(expected_uv.x,expected_uv.y)))
		check(boundary_error < 0.00001,"surround retains shared nose/cowl/wing boundary, "+label)
		metrics[label+"_boundary_error"] = boundary_error
		var nose: MeshInstance3D = car.body.get_node("FormedFrontHoodJoin")
		var nose_vertices: PackedVector3Array = nose.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var surround: MeshInstance3D = car.body.get_node("HoodSurround0")
		var surround_arrays: Array = surround.mesh.surface_get_arrays(0)
		var join_error: float = 0
		var join_count: int = 0
		for index: int in range(surround_arrays[Mesh.ARRAY_VERTEX].size()):
			if (surround_arrays[Mesh.ARRAY_TEX_UV][index] as Vector2).y < 0.9999: continue
			var distance: float = INF
			for point: Vector3 in nose_vertices: distance = minf(distance,point.distance_to(surround_arrays[Mesh.ARRAY_VERTEX][index]))
			join_error = maxf(join_error,distance)
			join_count += 1
		check(join_count > 20 and join_error < 0.000001,"every actual hood/nose vertex joins without a crack, "+label)
		metrics[label+"_nose_join"] = {"vertices":join_count,"maximum_error":join_error}
		car.free()
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
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
			world.add_child(car)
			ShowroomStudio.build(world,car)
			var camera := Camera3D.new()
			world.add_child(camera)
			camera.current = true
			camera.fov = 32
			var shots: Array = [
				["hood",Vector3(-2.5,2.4,-4.3),Vector3(0,0.75,-1.1)],
				["nose",Vector3(0,1.6,-5),Vector3(0,0.72,-1.0)],
				["overhead",Vector3(0,6,-2.7),Vector3(0,0.65,-0.6)]]
			for shot: Array in shots:
				camera.position = shot[1]
				camera.look_at(shot[2])
				await settle()
				check(viewport.get_texture().get_image().save_png(output.path_join(("simple-" if simple else "full-")+shot[0]+".png")) == OK,"native hood view "+str(shot[0]))
			world.free()
		viewport.free()
	var report := FileAccess.open(output+"/hood.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("ELECTRIC_HOOD: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

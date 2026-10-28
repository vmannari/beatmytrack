extends SceneTree
## Regression for the four defects found in the native kart review.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-model-fixes-2026-10-25/final"
var measurements: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func outer_radius(x: float) -> float:
	if x <= 0.076: return 0.22
	if x <= 0.105: return lerpf(0.22,0.217,(x-0.076)/0.029)
	if x <= 0.129: return lerpf(0.217,0.202,(x-0.105)/0.024)
	return lerpf(0.202,0.175,(x-0.129)/0.008)

func parts(car: CarVisual, prefix: String) -> Array[MeshInstance3D]:
	# Godot replaces duplicate sibling names; identify both sides by their mesh keys.
	var resources: Array[Mesh] = []
	var cache: Dictionary = preload("res://vehicle/kart_geometry.gd").meshes
	for key: String in cache:
		if key.get_slice("|",0).begins_with(prefix): resources.append(cache[key])
	var result: Array[MeshInstance3D] = []
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh in resources: result.append(part)
	return result

func contacts(car: CarVisual, angle: float) -> Dictionary:
	for pivot: Node3D in car.front_wheels: pivot.rotation.y = angle
	var collisions: Dictionary = {}
	for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		for wheel: int in range(car.rolling_wheels.size()):
			var pivot: Node3D = car.rolling_wheels[wheel].get_parent()
			var transform: Transform3D = pivot.global_transform.affine_inverse()*part.global_transform
			for point: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var local: Vector3 = transform*point
				var x: float = absf(local.x)
				if x >= 0.137: continue
				var radius: float = Vector2(local.y,local.z).length()
				var inner: float = 0.12 if x <= 0.135 else lerpf(0.12,0.175,(x-0.135)/0.002)
				var depth: float = minf(0.137-x,minf(outer_radius(x)-radius,radius-inner))
				if depth <= 0.0001: continue
				var key: String = str(part.name)+"/wheel"+str(wheel)
				collisions[key] = maxf(float(collisions.get(key,0)),depth)
	return collisions

func ray(part: MeshInstance3D, triangles: TriangleMesh, origin: Vector3, direction: Vector3, body: Node3D) -> Dictionary:
	var transform: Transform3D = body.global_transform.affine_inverse()*part.global_transform
	var inverse: Transform3D = transform.affine_inverse()
	var hit: Dictionary = triangles.intersect_ray(inverse*origin,inverse.basis*direction)
	if not hit.is_empty(): hit.position = transform*hit.position
	return hit

func clamp_fit(car: CarVisual) -> Dictionary:
	var chamber: MeshInstance3D = car.find_child("ExpansionChamber",true,false)
	var chamber_triangles: TriangleMesh = chamber.mesh.generate_triangle_mesh()
	var gaps: Array[float] = []
	for strap: MeshInstance3D in parts(car,"ExhaustStrap"):
		var strap_triangles: TriangleMesh = strap.mesh.generate_triangle_mesh()
		var center := Vector3(strap.mesh.get_aabb().get_center().x,0.38,1.02)
		for step: int in range(16):
			var a: float = TAU*(step+0.25)/16
			var direction := Vector3(0,sin(a),cos(a))
			var shell: Dictionary = ray(chamber,chamber_triangles,center+direction*0.15,-direction,car.body)
			var band: Dictionary = ray(strap,strap_triangles,center,direction,car.body)
			check(not shell.is_empty() and not band.is_empty(),"chamber and retaining band have actual ray surfaces")
			if not shell.is_empty() and not band.is_empty(): gaps.append((band.position-shell.position).dot(direction))
	check(gaps.size() == 32,"both exhaust clamps sampled around their circumference")
	var minimum: float = gaps.min() if not gaps.is_empty() else INF
	var maximum: float = gaps.max() if not gaps.is_empty() else INF
	check(minimum >= -0.004 and maximum <= 0.003,"retaining bands contact the tapered exhaust without floating")
	return {"minimum_model_m":minimum,"maximum_model_m":maximum}

func piping_fit(car: CarVisual) -> Dictionary:
	var sleeves: Array[MeshInstance3D] = parts(car,"UpperSleeve")+parts(car,"LowerSleeve")
	var cloth: Array[Dictionary] = []
	for sleeve: MeshInstance3D in sleeves:
		cloth.append({"part":sleeve,"triangles":sleeve.mesh.generate_triangle_mesh()})
	var minimum: float = INF
	var maximum: float = -INF
	var samples: int = 0
	var misses: int = 0
	for piping: MeshInstance3D in parts(car,"SleevePiping"):
		var vertices: PackedVector3Array = piping.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for index: int in range(0,vertices.size(),2):
			var point: Vector3 = car.body.global_transform.affine_inverse()*piping.global_transform*vertices[index]
			var outward := Vector3(signf(point.x),0.35,-0.15).normalized()
			var nearest: float = INF
			for item: Dictionary in cloth:
				var hit: Dictionary = ray(item.part,item.triangles,point+outward*0.2,-outward,car.body)
				if not hit.is_empty(): nearest = minf(nearest,(point+outward*0.2-hit.position).dot(outward))
			if is_finite(nearest):
				var gap: float = nearest-0.2
				minimum = minf(minimum,gap)
				maximum = maxf(maximum,gap)
				samples += 1
			else: misses += 1
	check(samples >= 50,"both sleeve strips have sampled cloth backing")
	check(misses == 0,"every sampled piping point has cloth backing")
	check(minimum >= -0.0005 and maximum <= 0.009,"sleeve piping stays on the actual cloth surface")
	return {"samples":samples,"misses":misses,"minimum_model_m":minimum,"maximum_model_m":maximum}

func inlay_fit(car: CarVisual) -> Dictionary:
	var result: Dictionary = {}
	for pair: Array in [["NoseCenterInlay","SculptedFrontFairing"],["FairingCenterInlay","NassauFairing"]]:
		var shell: MeshInstance3D = car.find_child(pair[1],true,false)
		var triangles: TriangleMesh = shell.mesh.generate_triangle_mesh()
		var inlay: MeshInstance3D = car.find_child(pair[0],true,false)
		var faces: PackedVector3Array = inlay.mesh.get_faces()
		var misses: int = 0
		var minimum: float = INF
		var maximum: float = -INF
		for face: int in range(faces.size()/3):
			var center: Vector3 = (faces[face*3]+faces[face*3+1]+faces[face*3+2])/3
			var hit: Dictionary = ray(shell,triangles,center+Vector3.UP*0.05,Vector3.DOWN,car.body)
			if hit.is_empty():
				misses += 1
				continue
			minimum = minf(minimum,center.y-hit.position.y)
			maximum = maxf(maximum,center.y-hit.position.y)
		check(not faces.is_empty() and misses == 0,"every stripe triangle has actual fairing backing "+str(pair[0]))
		check(minimum >= 0.0005 and maximum <= 0.0025,"whole stripe remains above the fairing surface "+str(pair[0]))
		result[pair[0]] = {"triangles":faces.size()/3,"misses":misses,"minimum_model_m":minimum,"maximum_model_m":maximum}
	return result

func settle() -> void:
	for frame: int in range(8): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	if "--unbaked" in OS.get_cmdline_user_args(): preload("res://vehicle/kart_geometry.gd").use_baked = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for simple: bool in [false,true]:
		var label: String = "simple" if simple else "full"
		var world := Node3D.new()
		viewport.add_child(world)
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		world.add_child(car)
		var poses: Dictionary = {}
		for step: int in range(25):
			var angle: float = lerpf(-0.6,0.6,step/24.0)
			var found: Dictionary = contacts(car,angle)
			poses[str(angle)] = found
			check(found.is_empty(),"all body vertices clear solid tyre volumes, %s steering %.2f" % [label,angle])
		var compliant: Dictionary = {}
		for tilt: Vector2 in [Vector2(-0.03,-0.036),Vector2(-0.03,0.036),Vector2(0.03,-0.036),Vector2(0.03,0.036)]:
			car.body.rotation = Vector3(tilt.x,0,tilt.y)
			for angle: float in [-0.6,0.0,0.6]:
				var found: Dictionary = contacts(car,angle)
				compliant[str(tilt)+"/"+str(angle)] = found
				check(found.is_empty(),"body pitch/roll still clear tyres, %s %s steering %.2f" % [label,str(tilt),angle])
		car.body.rotation = Vector3.ZERO
		# A longitudinal separating plane protects whole fairing triangles between samples.
		var rear: float = -INF
		for part: MeshInstance3D in car.find_children("*FrontFairing*","MeshInstance3D",true,false)+car.find_children("NoseLowerReturn*","MeshInstance3D",true,false):
			for point: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: rear = maxf(rear,point.z)
		var wheel_front: float = car.front_wheels[0].position.z-sqrt(0.22*0.22+0.137*0.137)
		check(wheel_front-rear > 0.04,"whole nose clears the complete steering envelope by four model centimetres")
		var engine: MeshInstance3D = car.find_child("EngineMount",true,false)
		var engine_edge: float = engine.position.x+engine.mesh.get_aabb().end.x
		var engine_gap: float = car.front_wheels[1].position.x-0.137-engine_edge
		check(engine_gap > 0.02,"engine base has at least two model centimetres of tyre clearance")
		measurements[label] = {"steering_contacts":poses,"body_tilt_contacts":compliant,"nose_gap_model_m":wheel_front-rear,"engine_gap_model_m":engine_gap,"clamps":clamp_fit(car),"piping":piping_fit(car),"inlays":inlay_fit(car)}
		if DisplayServer.get_name() != "headless":
			ShowroomStudio.build(world,car)
			var camera := Camera3D.new()
			camera.fov = 32
			world.add_child(camera)
			camera.current = true
			for angle: float in [-0.6,0.0,0.6]:
				for pivot: Node3D in car.front_wheels: pivot.rotation.y = angle
				camera.position = Vector3(-1.8,1,-2.5)
				camera.look_at(Vector3(0,0.26,-0.65))
				await settle()
				check(viewport.get_texture().get_image().save_png(output.path_join(label+"-steering-"+str(angle)+".png")) == OK,"native steering capture")
			for pivot: Node3D in car.front_wheels: pivot.rotation.y = 0
			for shot: Array in [["controls",Vector3(-1.4,0.85,-0.55),Vector3(0,0.48,-0.22)],["engine",Vector3(1.4,0.95,1.7),Vector3(0.2,0.3,0.8)],["side",Vector3(-3,0.8,0),Vector3(0,0.38,0)]]:
				camera.position = shot[1]
				camera.look_at(shot[2])
				await settle()
				check(viewport.get_texture().get_image().save_png(output.path_join(label+"-"+str(shot[0])+".png")) == OK,"native close-up capture")
		world.free()
	viewport.free()
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements,"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	print("KART_MODEL_FIXES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends SceneTree
## Native review of the production kart, independent of player records.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-refinement-2026-10-25/model"
var counts: Dictionary = {}
var closure: Dictionary = {}
var mechanical: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func triangles(node: Node) -> int:
	var total: int = 0
	if node is MeshInstance3D and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: total += node.mesh.get_faces().size()/3
	for child: Node in node.get_children(): total += triangles(child)
	return total

func settle() -> void:
	for tick: int in range(8): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func boundary_edges(mesh: Mesh) -> int:
	var edges: Dictionary = {}
	var faces: PackedVector3Array = mesh.get_faces()
	for triangle: int in range(faces.size()/3):
		for corner: int in range(3):
			var a: Vector3 = faces[triangle*3+corner].snapped(Vector3.ONE*0.00001)
			var b: Vector3 = faces[triangle*3+(corner+1)%3].snapped(Vector3.ONE*0.00001)
			if a == b: continue
			var key: String = str(a)+":"+str(b) if a < b else str(b)+":"+str(a)
			edges[key] = int(edges.get(key,0))+1
	var total: int = 0
	for uses: int in edges.values():
		if uses != 2: total += 1
	return total

func tyre_clearance(car: CarVisual, labels: Array[String]) -> float:
	var minimum: float = INF
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for label: String in labels:
		for part: MeshInstance3D in car.find_children(label+"*","MeshInstance3D",true,false):
			for point: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var model: Vector3 = inverse*part.global_transform*point
				for wheel: Node3D in car.rolling_wheels:
					var center: Vector3 = inverse*wheel.global_position
					var across: float = absf(model.x-center.x)-0.137
					var radial: float = Vector2(model.y-center.y,model.z-center.z).length()-0.22
					minimum = minf(minimum,maxf(across,radial))
	return minimum

func run() -> void:
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	if "--unbaked" in OS.get_cmdline_user_args(): preload("res://vehicle/kart_geometry.gd").use_baked = false
	if not baseline and "--unbaked" not in OS.get_cmdline_user_args():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/kart_refined_v1/manifest.json"))
		check(manifest.geometry_sha256 == FileAccess.get_sha256("res://vehicle/kart_geometry.gd") and manifest.model_sha256 == FileAccess.get_sha256("res://vehicle/kart_model.gd"),"prepared meshes match exact final sources")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var raw: int = triangles(car)
		counts["simple" if simple else "full"] = raw
		if not baseline:
			var finite: bool = true
			for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
				for surface: int in range(mesh.mesh.get_surface_count()):
					var arrays: Array = mesh.mesh.surface_get_arrays(surface)
					for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: finite = finite and point.is_finite()
					if arrays[Mesh.ARRAY_NORMAL] != null:
						for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: finite = finite and normal.is_finite() and normal.length_squared() > 0.5
			check(finite,"finite geometry and unit normals, simple="+str(simple))
			check(raw > 10000 and raw < 95000,"bounded model triangles, simple="+str(simple))
			check(car.front_wheels.size() == 2 and car.rolling_wheels.size() == 4,"four rolling wheels and two steering uprights")
			var config: HandlingConfig = VehicleCatalog.config("kart")
			check(is_equal_approx(absf(car.front_wheels[0].position.x)*2*HandlingConfig.BODY_SCALE,config.track_width),"canonical wheel track")
			check(is_equal_approx(absf(car.front_wheels[0].position.z)*2*HandlingConfig.BODY_SCALE,config.wheelbase),"canonical wheelbase")
			check(car.paint_materials.body.clearcoat_enabled and car.paint_materials.body.roughness >= 0.38,"restrained automotive paint")
			for label: String in ["MouldedSeatBucket","SculptedFrontFairing","NassauFairing","FormedSidePod"]:
				var parts: Array[Node] = car.find_children(label+"*","MeshInstance3D",true,false)
				check(not parts.is_empty(),"production shell exists "+label)
				for part: MeshInstance3D in parts:
					var open: int = boundary_edges(part.mesh)
					closure[label+("-simple" if simple else "-full")] = open
					check(open == 0,"closed watertight shell "+label+", simple="+str(simple))
			check(car.find_children("HelmetChinBar*","MeshInstance3D",true,false).is_empty(),"helmet has one integrated shell")
			check(car.find_children("KneeReinforcement*","MeshInstance3D",true,false).is_empty() and car.find_children("ContinuousTrouserLeg*","MeshInstance3D",true,false).size() == 2,"knees belong to continuous trouser legs")
			var bumper_gap: float = tyre_clearance(car,["RearProtection","RearBumperChassisMount","RearBumperEndCap"])
			var exhaust_gap: float = tyre_clearance(car,["ExpansionChamber","ExhaustHeader","ExhaustStinger","SilencerCan","HollowExhaustOutlet"])
			mechanical["simple" if simple else "full"] = {"bumper_tyre_gap_model_m":bumper_gap,"exhaust_tyre_gap_model_m":exhaust_gap}
			check(bumper_gap > 0.05,"rear bumper clears tyre envelopes by at least five model centimetres")
			check(exhaust_gap > 0.05,"exhaust clears tyre envelopes by at least five model centimetres")
			var steering: Node3D = car.body.get_node("SteeringAssembly")
			check(steering.basis.y.y < 0.5 and steering.basis.y.z > 0.8,"upright wheel plane faces the seated driver")
			var assembled := CarVisual.new()
			assembled.vehicle_id = "kart"
			assembled.simple_model = simple
			root.add_child(assembled)
			check(raw == triangles(assembled),"production batching retains every triangle")
			var original: Transform3D = assembled.front_wheels[0].transform
			var state := VehicleState.new()
			assembled.present(Vector2.ZERO,0,state,DriveFrame.new())
			state.tick = 1
			state.steering = 0.5
			assembled.present(Vector2(0,0.2),0,state,DriveFrame.new())
			check(not assembled.front_wheels[0].transform.is_equal_approx(original),"steering remains live")
			check(absf(assembled.rolling_wheels[0].rotation.x) > 0.1,"rim rolls independently")
			assembled.free()
		car.free()
	if not baseline: check(int(counts.simple) < int(counts.full)*0.65,"simpler model reduces geometry by at least 35 percent")
	if DisplayServer.get_name() != "headless":
		for simple: bool in [false,true]:
			var world := Node3D.new()
			viewport.add_child(world)
			var car := CarVisual.new()
			car.vehicle_id = "kart"
			car.simple_model = simple
			car.livery = VehicleLivery.defaults("kart")
			world.add_child(car)
			ShowroomStudio.build(world,car)
			var camera := Camera3D.new()
			world.add_child(camera)
			camera.current = true
			camera.fov = 32
			var shots: Array = [
				["front",Vector3(-2.8,1.7,-4.1),Vector3(0,0.38,0)],
				["rear",Vector3(2.7,1.65,3.9),Vector3(0,0.38,0)],
				["rear-left",Vector3(-2.7,1.65,3.9),Vector3(0,0.38,0)],
				["side",Vector3(-4.4,0.95,0),Vector3(0,0.40,0)],
				["top",Vector3(0,4.8,0.001),Vector3(0,0.35,0)],
				["driver",Vector3(-1.1,1.1,-1.6),Vector3(0,0.62,0.05)],
				["engine",Vector3(1.6,1.0,1.9),Vector3(0.3,0.28,0.7)]]
			for shot: Array in shots:
				camera.position = shot[1]
				camera.look_at(shot[2])
				await settle()
				check(viewport.get_texture().get_image().save_png(output.path_join(("simple-" if simple else "full-")+str(shot[0])+".png")) == OK,"actual production model capture "+str(shot[0]))
			world.free()
	viewport.free()
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"triangles":counts,"open_edges":closure,"mechanical":mechanical,"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	print("KART_MODEL: %d checks, %d failures, triangles %s" % [checks,failures,JSON.stringify(counts)])
	quit(1 if failures else 0)

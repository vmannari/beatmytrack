extends "res://tests/review_forklift_model.gd"
## Regression for the four native model-review defects, in both detail variants.
var checks: int = 0
var failures: int = 0
var before: bool = false
var evidence_root: String = "res://../docs/evidence/forklift-model-fixes-2026-10-25"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func make_car(simple: bool, batch: bool = false) -> CarVisual:
	var car := CarVisual.new()
	car.vehicle_id = "forklift"; car.simple_model = simple; car.batch_parts = batch
	root.add_child(car)
	if before:
		car.graphics.restore_originals()
		for child: Node in car.body.get_children(): child.free()
		load("res://../docs/evidence/forklift-model-fixes-2026-10-25/before/game__vehicle__forklift_model.gd").build(car)
		car.graphics = LiveryGraphics.new()
		car.graphics.configure(car)
	return car

func merged_mesh(parent: Node3D) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	for part: MeshInstance3D in parent.find_children("*","MeshInstance3D",true,false):
		for surface: int in range(part.mesh.get_surface_count()):
			tool.append_from(part.mesh,surface,parent.global_transform.affine_inverse()*part.global_transform)
	var result := MeshInstance3D.new()
	result.mesh = tool.commit()
	return result

func ray_hits(part: MeshInstance3D, a: Vector3, b: Vector3) -> bool:
	var vertices: PackedVector3Array = part.mesh.get_faces()
	var direction: Vector3 = (b-a).normalized()
	for index: int in range(0,vertices.size(),3):
		# Normalize before the engine's determinant tolerance: a short segment
		# otherwise rejects the small but valid triangles of the exhaust lip.
		var hit: Variant = Geometry3D.ray_intersects_triangle(a,direction,vertices[index],vertices[index+1],vertices[index+2])
		if hit != null and (hit-a).dot(direction)<=a.distance_to(b)+0.000001: return true
	return false

func solid(part: MeshInstance3D, label: String) -> Dictionary:
	var data: Dictionary = topology(part)
	check(data.boundary_edges == 0 and data.inconsistent_edges == 0,label+" is a closed consistently wound solid")
	check(data.normal_disagreements == 0 and absf(data.signed_volume)>0.000001,label+" exterior faces match outward normals")
	return data

func geometry(simple: bool) -> void:
	var car: CarVisual = make_car(simple)
	var data: Dictionary = {}
	for pattern: String in ["ForgedFork*","Formed*","RolledWheelArch*"]:
		for part: MeshInstance3D in car.find_children(pattern,"MeshInstance3D",true,false): data[part.name] = solid(part,str(part.name))
	var rim: MeshInstance3D = car.find_child("SteeringWheelRim",true,false)
	check(rim != null,"steering rim has independent solid geometry")
	if rim != null:
		data.steering_rim = solid(rim,"steering rim")
		check(rim.mesh.get_aabb().size.y>0.03,"steering grip has round-section thickness")
		check((rim.get_active_material(0) as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_BACK,"closed rim retains ordinary exterior culling")
		var point := Vector3(cos(0.37)*0.202,0,sin(0.37)*0.202)
		check(ray_hits(rim,point+Vector3.UP*0.08,point-Vector3.UP*0.08),"rim has a surface above the wheel plane")
		check(ray_hits(rim,point-Vector3.UP*0.08,point+Vector3.UP*0.08),"rim has a surface below the wheel plane")
	for side: String in ["Left","Right"]:
		var chain: MeshInstance3D = car.find_child("LiftChain"+side,true,false)
		check(chain != null,"continuous "+side+" leaf chain replaces detached blocks")
		if chain == null: continue
		data["chain_"+side] = solid(chain,side+" chain plates")
		var x: float = -0.31 if side=="Left" else 0.31
		# Sample between detail pins: the continuous side plates carry the route.
		for point: Vector3 in [Vector3(x,1.833,-1.11),Vector3(x,1.833,-1.35),Vector3(x,2.585,-1.23)]:
			check(ray_hits(chain,point-Vector3.RIGHT*0.08,point+Vector3.RIGHT*0.08),side+" chain has both vertical runs and a pulley wrap")
		var fixed: MeshInstance3D = car.find_child("FixedChainAnchor"+side,true,false)
		var moving: MeshInstance3D = car.find_child("CarriageChainAnchor"+side,true,false)
		check(fixed != null and moving != null,side+" chain has fixed and moving anchors")
		if fixed != null and moving != null:
			var fixed_box: AABB = car.body.global_transform.affine_inverse()*fixed.global_transform*fixed.mesh.get_aabb()
			var moving_box: AABB = car.body.global_transform.affine_inverse()*moving.global_transform*moving.mesh.get_aabb()
			check(fixed_box.has_point(Vector3(x,0.47,-1.11)),side+" fixed chain termination reaches its anchor")
			check(moving_box.has_point(Vector3(x,1.70,-1.35)) and moving.get_parent().name == "RaisedForkCarriage",side+" front chain reaches the raised carriage anchor")
	check(car.find_children("LiftChainLink*","MeshInstance3D",true,false).is_empty(),"detached old chain blocks are absent")
	var stack: Node3D = car.find_child("HollowExhaustStack",true,false)
	check(stack != null,"upper stack has a hollow wall assembly")
	if stack != null:
		var exhaust: MeshInstance3D = merged_mesh(stack)
		data.exhaust_wall = solid(exhaust,"exhaust wall and annular ends")
		var end := Vector3(0.59,2.12,1.02)
		var axis: Vector3 = (end-Vector3(0.62,2.03,0.98)).normalized()
		var u: Vector3 = Vector3.RIGHT.slide(axis).normalized()
		check(not ray_hits(exhaust,end+axis*0.04,end-axis*0.045),"exhaust bore stays open below its outlet")
		for angle: float in [0.31,0.97]:
			# Avoid the exact shared edge between neighbouring lip triangles.
			var radial: Vector3 = (u*cos(angle)+axis.cross(u)*sin(angle))*0.028
			check(ray_hits(exhaust,end+radial+axis*0.04,end+radial-axis*0.045),"exhaust opening retains an annular metal lip")
		exhaust.free()
	metrics["racing" if simple else "detailed"] = data
	car.free()
	await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	before = "--before" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence_root = argument.trim_prefix("--evidence-dir=")
	graphical = DisplayServer.get_name() != "headless"
	output = ProjectSettings.globalize_path(evidence_root).path_join(("before-" if before else "")+(RenderingServer.get_current_rendering_method() if graphical else "headless"))
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,960)
	var config: Dictionary = VehicleCatalog.config("forklift").snapshot()
	for simple: bool in [false,true]: await geometry(simple)
	if graphical:
		var world := Node3D.new()
		root.add_child(world)
		var car: CarVisual = make_car(false)
		car.reparent(world)
		var value: Dictionary = VehicleLivery.defaults("forklift")
		value.stickers.hood.id = "crest"; value.stickers.hood.size = 0.95
		car.apply_livery(value)
		ShowroomStudio.build(world,car)
		camera = Camera3D.new()
		world.add_child(camera); camera.current = true; camera.fov = 35
		await capture("front-overview",Vector3(-5.4,3.6,-6.4),Vector3(0,1.25,-0.38))
		await capture("rear-overview",Vector3(-4.7,3.2,5.2),Vector3(0,1.22,0.15))
		await capture("side-left",Vector3(-2.8,1.65,0.35),Vector3(-0.78,1.0,0.10))
		await capture("side-right",Vector3(2.8,1.65,0.35),Vector3(0.78,1.0,0.10))
		await capture("mast-front",Vector3(-1.7,1.95,-4.2),Vector3(0,1.65,-1.35))
		await capture("mast-pulley",Vector3(-1.1,2.85,-2.55),Vector3(-0.20,2.43,-1.23))
		await capture("cockpit-top",Vector3(-1.6,3.4,1.5),Vector3(-0.05,1.45,-0.23))
		await capture("cockpit-low",Vector3(-1.9,1.33,-0.05),Vector3(-0.16,1.61,-0.40))
		await capture("exhaust-outlet",Vector3(1.25,2.74,1.85),Vector3(0.61,1.99,1.0))
		await capture("fork-underside",Vector3(-1.6,0.38,-3.4),Vector3(0,0.89,-2.05))
		await capture("fork-side",Vector3(-2.8,1.0,-2.1),Vector3(-0.43,0.98,-1.95))
		VisualGeometry.batch_static_parts(car)
		await capture("batched-fork-side",Vector3(-2.8,1.0,-2.1),Vector3(-0.43,0.98,-1.95))
		await capture("batched-cockpit-low",Vector3(-1.9,1.33,-0.05),Vector3(-0.16,1.61,-0.40))
		await capture("batched-mast-front",Vector3(-1.7,1.95,-4.2),Vector3(0,1.65,-1.35))
		await capture("batched-exhaust-outlet",Vector3(1.25,2.74,1.85),Vector3(0.61,1.99,1.0))
		world.free()
	check(config == VehicleCatalog.config("forklift").snapshot(),"model corrections leave the versioned handling unchanged")
	var report := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("FORKLIFT_MODEL_FINISH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

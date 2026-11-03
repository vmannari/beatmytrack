extends SceneTree
## Check the actual rotating tire buffers against the sprung wheel openings.
const BODY = preload("res://vehicle/electric_reference_body.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",message)

func tire_in(rotor: Node3D) -> MeshInstance3D:
	for part: MeshInstance3D in rotor.find_children("*","MeshInstance3D",true,false):
		var mat := part.material_override as ShaderMaterial
		if mat != null and mat.shader.resource_path.ends_with("compact_tire.gdshader"): return part
	return null

func run() -> void:
	var control: bool = "--control" in OS.get_cmdline_user_args()
	var car := CarVisual.new()
	car.vehicle_id = "electric"
	car.batch_parts = false
	car.cache_rest_pose = false
	root.add_child(car)
	while not car.model_ready: await process_frame
	var state := VehicleState.new()
	state.tick = 1
	car.last_tick = 1
	var cases: Array = [
		["rest",Vector3.ZERO,Vector4.ZERO,0.0],
		["braking",Vector3(-0.07,-0.12,0.0),Vector4.ZERO,0.4],
		["acceleration",Vector3(-0.06,0.12,0.0),Vector4.ZERO,-0.4],
		["cornering",Vector3(-0.05,0.05,0.12),Vector4.ZERO,0.4],
		["kerb",Vector3(-0.03,-0.08,-0.08),Vector4(0.10,0.0,0.0,0.0),-0.4],
		["speed bump",Vector3(-0.04,0.08,0.04),Vector4.ZERO,0.4,Vector4(0.08,0.08,0.0,0.0)],
	]
	for scenario: Array in cases:
		car.suspension = scenario[1]
		for wheel: Node3D in car.front_wheels: wheel.rotation.y = scenario[3]
		var before: Array = state.snapshot()
		var bump: Vector4 = scenario[4] if scenario.size()>4 else Vector4.ZERO
		# The shared compact presentation has the same unbounded compliance and
		# skips the electric-specific fix; the electric geometry stays in place.
		if control: car.vehicle_id = "compact"
		car.present_suspension(state,0.0,true,0.0,scenario[2],bump)
		car.vehicle_id = "electric"
		check(state.snapshot()==before,"simulation state unchanged "+scenario[0])
		for index: int in range(car.rolling_wheels.size()):
			var pivot: Node3D = car.rolling_wheels[index].get_parent()
			var rest: Vector3 = car.wheel_rest_positions[index]
			var slot: int = (0 if rest.z<0.0 else 2)+(0 if rest.x<0.0 else 1)
			check(absf(pivot.position.y-(rest.y+(scenario[2][slot]+bump[slot])/HandlingConfig.BODY_SCALE))<0.00001,"wheel retains its contact height "+scenario[0])
		print("ELECTRIC_WHEEL_POSE ",scenario[0]," body_y=",car.body.position.y)
		if scenario[0]=="rest": check(absf(car.body.position.y)<0.001,"stationary ride height unchanged")
		for rotor: Node3D in car.rolling_wheels:
			var tire: MeshInstance3D = tire_in(rotor)
			check(tire!=null,"tire exists "+scenario[0])
			if tire==null: continue
			var worst := -INF
			for roll: float in [0.0,PI/64.0,PI/32.0]:
				rotor.rotation.x = roll
				var transform: Transform3D = car.body.global_transform.affine_inverse()*tire.global_transform
				for vertex: Vector3 in tire.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					var point: Vector3 = transform*vertex
					if point.y>0.24: worst = maxf(worst,point.y-BODY.wheel_bottom(point.z))
			check(worst<0.001,"tire clears wheel opening "+scenario[0]+" "+str(rotor.get_parent().name)+" penetration="+str(worst))
			rotor.rotation.x = 0.0
	print("ELECTRIC_WHEEL_CLEARANCE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

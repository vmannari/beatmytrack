extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ",label)

func pose(h: Vector4, config: HandlingConfig) -> Vector3:
	return Vector3((h.x+h.y+h.z+h.w)*0.25,atan2((h.x+h.y-h.z-h.w)*0.5,config.wheelbase),atan2((h.y+h.w-h.x-h.z)*0.5,config.track_width))

func run() -> void:
	var track := NativeTrack.new()
	track.cell_size = 1.0; track.grid_width = 200; track.grid_height = 200
	track.half_extent = Vector2(100,100); track.cells.resize(40000); track.cells.fill(1)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var state := VehicleState.new(); state.position = Vector2(3.0,4.0); state.velocity = Vector2(0,12)
	var initial: Vector4 = track.off_road_suspension_heights(state,config)
	check(initial != Vector4.ZERO and initial.x != initial.y and initial.x != initial.z,"individual wheels encounter different ground heights")
	var snapshot: Array = state.snapshot()
	state.tick += 100
	check(track.off_road_suspension_heights(state,config) == initial,"same ground position gives same heights at a later tick")
	state.tick -= 100
	check(state.snapshot() == snapshot,"terrain sampling leaves canonical state untouched")
	var minima: float = 1.0; var maxima: float = -1.0
	for n: int in range(40):
		var average: float = 0.0
		for sample: int in range(20):
			state.position = Vector2(3.0,4.0+n*0.5+sample*0.025)
			average += track.off_road_suspension_heights(state,config).x/20.0
		minima = minf(minima,average); maxima = maxf(maxima,average)
	check(maxima-minima > 0.06,"broad terrain variations remain after averaging finer bumps")
	state.position = Vector2(0,0)
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width/2,track.grid_width): track.cells[y*track.grid_width+x] = 0
	var split: Vector4 = track.off_road_suspension_heights(state,config)
	check(split.x != 0.0 and split.z != 0.0 and split.y == 0.0 and split.w == 0.0,"only wheels on loose ground receive terrain movement")
	state.track_elevated = true
	check(track.off_road_suspension_heights(state,config) == Vector4.ZERO,"bridge deck has no ground response")
	state.track_elevated = false; state.jump_height = 1.0
	check(track.off_road_suspension_heights(state,config) == Vector4.ZERO,"airborne wheels have no ground response")
	state.jump_height = 0.0; state.roll_ticks = 1
	check(track.off_road_suspension_heights(state,config) == Vector4.ZERO,"rolling vehicle has no ground response")
	state.roll_ticks = 0; state.velocity = Vector2.ZERO
	check(track.off_road_suspension_heights(state,config) == Vector4.ZERO,"standing still has no artificial oscillation")
	state.velocity = Vector2(0,12)
	var hover: HandlingConfig = VehicleCatalog.config("hovercraft")
	check(track.off_road_suspension_heights(state,hover) == Vector4.ZERO,"air cushion does not receive wheel suspension")
	var car := CarVisual.new(); car.vehicle_id = "compact"; root.add_child(car)
	state.tick = 0; car.present_suspension(state,0.0,true,0.0,Vector4.ZERO,Vector4.ZERO,false,Vector3.ZERO,split,pose(split,config))
	for n: int in range(1,121):
		state.tick = n
		car.present_suspension(state,0.0,true,0.0,Vector4.ZERO,Vector4.ZERO,false,Vector3.ZERO,split,pose(split,config))
	check(car.terrain_suspension.length() > 0.001 and absf(car.body.rotation.z) > 0.001,"uneven wheel contacts drive a damped body roll")
	var wheel: Node3D = car.rolling_wheels[0].get_parent() as Node3D
	var rest: Vector3 = car.wheel_rest_positions[0]
	var slot: int = (0 if rest.z < 0.0 else 2)+(0 if rest.x < 0.0 else 1)
	check(absf(wheel.position.y-rest.y-split[slot]/HandlingConfig.BODY_SCALE) < 0.0001,"wheel follows its own terrain height")
	for n: int in range(121,361):
		state.tick = n; car.present_suspension(state,0.0)
	check(car.terrain_suspension.length() < 0.0001,"body settles after leaving rough ground")
	car.queue_free()
	print("OFF_ROAD_SUSPENSION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

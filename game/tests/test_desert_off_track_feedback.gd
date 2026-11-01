extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500,500)
	track.cells.resize(10000)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
	track.metadata["theme"] = "desert"
	for row: int in range(50,100):
		for col: int in range(50,100): track.cells[row*100+col] = 2
	var config := HandlingConfig.new()
	var state := VehicleState.new()
	state.position = Vector2(-0.2,0.2)
	check(track.off_road_rumble(state,config) == 0.25,"one loose wheel gives proportional feedback")
	state.position = Vector2(-0.2,-10)
	check(track.off_road_rumble(state,config) == 0.5,"two loose wheels give proportional feedback")
	state.position = Vector2(10,-10)
	check(track.off_road_rumble(state,config) == 1.0,"four loose wheels give full feedback")
	state.track_elevated = true
	check(track.off_road_rumble(state,config) == 0.0,"bridge deck does not inherit ground feedback")
	state.track_elevated = false
	var desert := VehicleSimulation.new(config)
	var repeat := VehicleSimulation.new(config)
	var control := VehicleSimulation.new(config)
	desert.reset(Vector2(-0.2,0.2))
	repeat.reset(desert.state.position)
	control.reset(desert.state.position)
	for sim: VehicleSimulation in [desert,repeat,control]: sim.state.velocity = Vector2(0,24)
	var input := DriveFrame.sample(1.0,0.0,0.0)
	desert.step(input,track)
	repeat.step(input,track)
	check(desert.state.snapshot() == repeat.state.snapshot(),"desert simulation replays exactly")
	track.metadata["theme"] = "pine"
	control.step(input,track)
	check(desert.state.steering < control.state.steering,"one loose wheel slows steering buildup")
	check(desert.state.velocity.length() < control.state.velocity.length(),"one loose wheel increases resistance")
	track.metadata["theme"] = "desert"
	for i: int in range(120):
		desert.step(DriveFrame.sample(0.2,0.7,0),track)
		repeat.step(DriveFrame.sample(0.2,0.7,0),track)
	check(desert.state.snapshot() == repeat.state.snapshot(),"desert edge replays deterministically")
	track.metadata["theme"] = "desert"
	track.cells.fill(2)
	for id: String in VehicleCatalog.IDS:
		var escape := VehicleSimulation.new(VehicleCatalog.config(id))
		for i: int in range(240): escape.step(DriveFrame.sample(0,1,0),track)
		check(escape.state.velocity.length() > 1.0,id+" can escape loose sand from rest")
	print("DESERT_OFF_TRACK_FEEDBACK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

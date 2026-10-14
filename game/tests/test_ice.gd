extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func _initialize() -> void:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500,500)
	track.cells.resize(10000)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
	var state := VehicleState.new()
	for kind: int in range(8):
		track.cells.fill(kind)
		track.metadata = {"theme":"pine"}
		var dry: Vector2 = track.surface_factors(state)
		track.metadata.theme = "winter"
		var icy: Vector2 = track.surface_factors(state)
		check(icy.x < dry.x and icy.x > dry.x * 0.5 if kind == 0 else icy == dry,"ice changes asphalt traction only: "+str(kind))
	track.cells.fill(0)
	check(track.tire_pickup(state) == 0.0,"ice is not loose dirt and cannot trigger soil rollovers")
	track.deck_cells.fill(0)
	state.track_elevated = true
	check(is_equal_approx(track.surface_factors(state).x, NativeTrack.WINTER_ROAD_GRIP),"elevated asphalt is icy too")
	track.deck_cells.fill(-1)
	for car: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(car)
		var distances: Array[float] = []
		var slides: Array[float] = []
		var acceleration: Array[float] = []
		for theme: String in ["pine","winter"]:
			track.metadata.theme = theme
			var braking := VehicleSimulation.new(config)
			braking.state.velocity = Vector2(0,20)
			for tick: int in range(1200):
				braking.step(DriveFrame.sample(0,0,1),track)
				if braking.state.velocity.length() < 0.1: break
			check(braking.state.velocity.length() < 0.1,car+" stops on "+theme)
			distances.append(braking.state.position.y)
			var slide := VehicleSimulation.new(config)
			slide.state.velocity = Vector2(10,15)
			for tick: int in range(60): slide.step(DriveFrame.new(),track)
			slides.append(slide.state.position.x)
			var launch := VehicleSimulation.new(config)
			for tick: int in range(120): launch.step(DriveFrame.sample(0,1,0),track)
			acceleration.append(launch.state.velocity.length())
		print("ICE_METRIC ",car," braking_m=",distances," slide_m=",slides," launch_mps=",acceleration)
		check(distances[1] >= distances[0],car+" never brakes in less distance on ice")
		check(slides[1] > slides[0]*1.1,car+" slides farther on ice")
		check(acceleration[1] <= acceleration[0] and acceleration[1] > acceleration[0]*0.8,car+" retains at least 80 percent of dry launch speed")
		var original := VehicleSimulation.new(config)
		var frames: Array = []
		for tick: int in range(480):
			var input: DriveFrame = DriveFrame.sample(0.6 if tick > 120 else 0.0,1.0 if tick < 300 else 0.0,1.0 if tick >= 360 else 0.0)
			frames.append(input.packed())
			original.step(input,track)
		var decoded: Array = JSON.parse_string(JSON.stringify(frames))
		for batch: int in [1,2,4,8]:
			var replay := VehicleSimulation.new(config)
			for offset: int in range(0,decoded.size(),batch):
				for index: int in range(offset,mini(offset+batch,decoded.size())):
					var input := DriveFrame.new()
					input.steer = int(decoded[index][0])
					input.throttle = int(decoded[index][1])
					input.brake = int(decoded[index][2])
					replay.step(input,track)
			check(replay.state.snapshot() == original.state.snapshot(),car+" exact winter JSON replay batch "+str(batch))
	_check_snow_banks()
	print("ICE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _check_snow_banks() -> void:
	var track := NativeTrack.new()
	track.cell_size = 0.5
	track.grid_width = 80
	track.grid_height = 80
	track.half_extent = Vector2(20,20)
	track.cells.resize(6400)
	track.deck_cells.resize(6400)
	track.deck_cells.fill(-1)
	track.cells.fill(1)
	track.route = PackedVector2Array([Vector2(0,-18),Vector2(0,18)])
	track.metadata = {"theme":"winter"}
	for y: int in range(80):
		for x: int in range(80):
			if x >= 30 and x < 50 or y >= 32 and y < 48:
				track.cells[y*80+x] = 0
	track.snow_banks.build(track)
	check(not track.snow_banks.triangles.is_empty(),"winter road edges generate shared snowbank geometry")
	check(track.snow_banks.height_at(Vector2(5.5,10)) > 0.2,"low ridge rises outside the road")
	check(track.snow_banks.height_at(Vector2(-5.5,10)) > 0.2,"snowbank on both sides")
	check(track.snow_banks.height_at(Vector2(0,10)) == 0.0,"road center stays unobstructed")
	check(track.snow_banks.height_at(Vector2(5.5,0)) == 0.0,"intersection opening has no bank across the road")
	check(track.snow_banks.height_at(Vector2(8,10)) == 0.0,"bank has bounded width")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var contact := VehicleState.new()
	contact.position = Vector2(4.8,10)
	contact.velocity = Vector2(20,0)
	track.snow_banks.slow_car(contact,contact.position,config,VehicleSimulation.STEP)
	check(track.cell_at(contact.position) == 0 and contact.velocity.length() < 20.0,"wheel contact slows outward slide while center is still on the road")
	check(contact.velocity.x > 0.0 and contact.collision_count == 0,"soft bank does not bounce or count a wall crash")
	for elevated: bool in [false,true]:
		var clear := VehicleState.new()
		clear.position = Vector2(4.8,10)
		clear.velocity = Vector2(20,0)
		clear.track_elevated = elevated
		clear.jump_height = 0.0 if elevated else 1.0
		track.snow_banks.slow_car(clear,clear.position,config,VehicleSimulation.STEP)
		check(clear.velocity == Vector2(20,0),"ground snowbank does not catch an airborne/elevated car")
	var escape := VehicleSimulation.new(config)
	escape.reset(Vector2(4.8,10),PI*0.5)
	# The owner replaces the soft two-second crossing with difficult packed snow.
	# Preserve recovery from rest, allowing time for the intentionally slow crawl.
	for tick: int in range(960): escape.step(DriveFrame.sample(0,1,0),track)
	check(escape.state.position.x > 8.0,"car can slowly power through packed snowbank from rest")
	var slower := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	slower.reset(Vector2(3.8,10),PI*0.5)
	replay.reset(Vector2(3.8,10),PI*0.5)
	slower.state.velocity = Vector2(20,0)
	replay.state.velocity = Vector2(20,0)
	for tick: int in range(36): slower.step(DriveFrame.new(),track)
	for batch: int in range(9):
		for tick: int in range(4): replay.step(DriveFrame.new(),track)
	check(slower.state.snapshot() == replay.state.snapshot(),"snowbank contact replays exactly in different batches")
	track.snow_banks.triangles.clear()
	var bare := VehicleSimulation.new(config)
	bare.reset(Vector2(3.8,10),PI*0.5)
	bare.state.velocity = Vector2(20,0)
	for tick: int in range(36): bare.step(DriveFrame.new(),track)
	print("SNOWBANK_METRIC speed_with=",slower.state.velocity.length()," without=",bare.state.velocity.length()," escape_x=",escape.state.position.x)
	check(slower.state.velocity.length() < bare.state.velocity.length()-1.0,"crossing bank removes meaningful speed beyond off-road drag")
	track.metadata.theme = "pine"
	track.snow_banks.build(track)
	check(track.snow_banks.triangles.is_empty(),"non-winter biomes never generate snowbanks")

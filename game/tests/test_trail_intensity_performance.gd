extends SceneTree
## Repeatable arithmetic equivalence and focused desktop timing, not a frame-rate benchmark.

func _initialize() -> void:
	var state := VehicleState.new()
	var frame := DriveFrame.new()
	var checks: int = 0
	for index: int in range(2400):
		state.heading = float(index % 101) * 0.071 - 3.5
		state.velocity = Vector2(float(index % 77) - 38.0, float(index % 63) - 31.0)
		state.yaw_rate = float(index % 51) * 0.1 - 2.5
		state.tire_dirt = float(index % 101) / 100.0
		frame.brake = index % 256
		var a: int = index % 13 - 1
		var b: int = (index * 3) % 13 - 1
		var c: int = (index * 7) % 13 - 1
		var d: int = (index * 11) % 13 - 1
		var actual := SkidTrails._four_intensities(state,frame,a,b,c,d)
		var expected := [SkidTrails.physics_intensity(state,frame,a,-1.0,-1.0), SkidTrails.physics_intensity(state,frame,b,1.0,-1.0), SkidTrails.physics_intensity(state,frame,c,-1.0,1.0), SkidTrails.physics_intensity(state,frame,d,1.0,1.0)]
		for wheel: int in range(4):
			if actual[wheel] != expected[wheel]:
				printerr("Intensity mismatch at %d/%d: %s != %s" % [index,wheel,actual[wheel],expected[wheel]])
				quit(1)
				return
			checks += 1
	# Alternate variants to reduce sensitivity to warmup and scheduling.
	var baseline_us: int = 0
	var shared_us: int = 0
	var checksum: float = 0.0
	for round: int in range(6):
		var start: int = Time.get_ticks_usec()
		for index: int in range(20000):
			checksum += SkidTrails.physics_intensity(state,frame,index%12,-1.0,-1.0)
			checksum += SkidTrails.physics_intensity(state,frame,(index+1)%12,1.0,-1.0)
			checksum += SkidTrails.physics_intensity(state,frame,(index+2)%12,-1.0,1.0)
			checksum += SkidTrails.physics_intensity(state,frame,(index+3)%12,1.0,1.0)
		baseline_us += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		for index: int in range(20000):
			var strengths := SkidTrails._four_intensities(state,frame,index%12,(index+1)%12,(index+2)%12,(index+3)%12)
			checksum += strengths[0] + strengths[1] + strengths[2] + strengths[3]
		shared_us += Time.get_ticks_usec() - start
	print("trail intensity: %d exact checks; old=%d us shared=%d us for 120000 four-wheel calls; checksum=%s" % [checks,baseline_us,shared_us,checksum])
	quit(0)

extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for reaction: int in [0,9,10,21,22,35,36,53,54,55,120]:
		var expected: String = "Jumped start" if reaction < 10 else ("Perfect start" if reaction < 22 else ("Great start" if reaction < 36 else ("Good start" if reaction < 54 else "")))
		for id: String in VehicleCatalog.IDS:
			var sim := VehicleSimulation.new(VehicleCatalog.config(id))
			var replay := VehicleSimulation.new(VehicleCatalog.config(id))
			for tick: int in range(240):
				var frame := DriveFrame.sample(0,1 if tick >= reaction else 0,0)
				if tick == 0: frame.launch_start = 1
				var packed: Array = JSON.parse_string(JSON.stringify(frame.packed()))
				var restored := DriveFrame.new()
				restored.steer = int(packed[0]); restored.throttle = int(packed[1]); restored.brake = int(packed[2])
				restored.handbrake = int(packed[3]) if packed.size() >= 4 else 0
				restored.launch_start = int(packed[4]) if packed.size() == 5 else 0
				sim.step(frame); replay.step(restored)
				check(sim.state.snapshot() == replay.state.snapshot(),id+" exact launch replay")
			check(sim.state.launch_result == expected,"window at tick %d" % reaction)
			var saved: Dictionary = RewindHistory.properties(sim.state)
			var recovered := VehicleState.new()
			RewindHistory.restore(recovered,saved)
			check(recovered.snapshot() == sim.state.snapshot(),"rewind preserves launch state")
	for id: String in VehicleCatalog.IDS:
		var boosted := VehicleSimulation.new(VehicleCatalog.config(id))
		var normal := VehicleSimulation.new(VehicleCatalog.config(id))
		for tick: int in range(95):
			var f := DriveFrame.sample(0,1 if tick >= 12 else 0,0)
			if tick == 0: f.launch_start = 1
			boosted.step(f)
			f.launch_start = 0
			normal.step(f)
		check(boosted.state.velocity.length() > normal.state.velocity.length()*1.09,id+" actual acceleration reward")
		check(boosted.state.launch_end_tick == 96,"perfect expires after 84 ticks")
	var early := VehicleSimulation.new(VehicleCatalog.config("compact"))
	for tick: int in range(72):
		var f := DriveFrame.sample(0,1,0)
		if tick == 0: f.launch_start = 2
		early.step(f)
	check(early.state.position == Vector2.ZERO,"early pedal held stationary for 0.6 seconds")
	early.step(DriveFrame.sample(0,1,0))
	check(early.state.velocity.length() > 0,"early penalty ends")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(fixture.document)
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.driver.set_touch(91,&"accelerate")
	var origin: Vector2 = game.sim.state.position
	for tick: int in range(360): game._physics_process(1.0/120)
	check(game.frame.throttle == 255,"countdown accelerator reaches presentation")
	check(game.sim.state.tick == 0 and game.sim.state.position == origin,"red lights hold canonical car stationary")
	check(game.race_cues.stage == 0,"lights extinguish at countdown boundary")
	game._physics_process(1.0/120)
	check(game.sim.state.launch_result == "Jumped start" and game.online_frames[0][4] == 2,"early press recorded and penalized")
	check(int(game.rewind_history.entries[0].state.launch_delay_until) == 72,"tick-zero rewind checkpoint retains early penalty")
	game.restart()
	check(not game.launch_early and not game.launch_countdown_seen,"restart clears launch latch")
	game.queue_free()
	await process_frame
	print("LAUNCH_START ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)

extends SceneTree
## Actual kart handling on winter asphalt, with prior-tune and verifier controls.

const VerificationTrack = preload("res://backend/verification_track.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func track_for(theme: String, kind: int) -> NativeTrack:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500, 500)
	track.cells.resize(10000)
	track.cells.fill(kind)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(kind)
	track.route = PackedVector2Array([Vector2(0, -400), Vector2(0, 400)])
	track.metadata = {"theme": theme}
	return track

func simulate(config: HandlingConfig, track: NativeTrack, elevated: bool, steer: float, throttle: float, lateral: float, ticks: int) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	sim.state.velocity = Vector2(lateral, 15.0)
	sim.state.track_elevated = elevated
	var peak_slip: float = 0.0
	for tick: int in range(ticks):
		sim.step(DriveFrame.sample(steer, throttle, 0), track)
		peak_slip = maxf(peak_slip, absf(rad_to_deg(sim.state.slip_angle())))
	return {"state": sim.state.snapshot(), "slide": sim.state.position.x, "peak_slip": peak_slip, "speed": sim.state.velocity.length()}

func _initialize() -> void:
	var live: HandlingConfig = VehicleCatalog.config("kart")
	check(live.version == "kart-12", "changed handling gets its own replay identity")
	# Compare the original winter tune without the later corner-speed change.
	var kart: HandlingConfig = live.duplicate() as HandlingConfig
	kart.version = "kart-9"
	kart.low_speed_steering_scale = 1.0
	kart.turn_speed_reduction = 0.0
	var prior: HandlingConfig = kart.duplicate() as HandlingConfig
	prior.version = "kart-8"
	prior.winter_lateral_grip = 1.0
	check(kart.version == "kart-9", "historical winter handling identity is preserved")
	check(is_equal_approx(kart.winter_lateral_grip, 0.8), "winter lateral grip is reduced to 80 percent")
	var prior_fields: Dictionary = prior.snapshot()
	var new_fields: Dictionary = kart.snapshot()
	for key: String in ["version", "winter_lateral_grip"]:
		prior_fields.erase(key)
		new_fields.erase(key)
	check(prior_fields == new_fields, "other kart handling fields are unchanged")
	for theme: String in ["pine", "winter"]:
		for kind: int in [0, 1, 2, 5, 6]:
			for elevated: bool in [false, true]:
				var track := track_for(theme, kind)
				var changed: Dictionary = simulate(kart, track, elevated, 0.5, 0.5, 0, 60)
				var old: Dictionary = simulate(prior, track, elevated, 0.5, 0.5, 0, 60)
				var affected: bool = theme == "winter" and kind == 0
				check((changed.state != old.state) == affected, "only winter asphalt changes %s kind=%d elevated=%s" % [theme, kind, elevated])
				var frozen: NativeTrack = VerificationTrack.frozen(track)
				check(changed.state == simulate(kart, frozen, elevated, 0.5, 0.5, 0, 60).state, "verification track matches %s kind=%d elevated=%s" % [theme, kind, elevated])
	for hazard: String in ["oil", "puddle"]:
		var hazard_track := track_for("winter", 0)
		hazard_track.hazard_objects = [{"kind": hazard, "position": [0, 0], "rotation": 0, "scale": 2.0}]
		var changed: Dictionary = simulate(kart, hazard_track, false, 0, 0, 10, 60)
		check(changed.state != simulate(prior, hazard_track, false, 0, 0, 10, 60).state, hazard + " retains the winter handling effect")
		check(changed.state == simulate(kart, VerificationTrack.frozen(hazard_track), false, 0, 0, 10, 60).state, hazard + " verifier parity")
	var winter := track_for("winter", 0)
	for braking: bool in [false, true]:
		var old_straight := VehicleSimulation.new(prior)
		var new_straight := VehicleSimulation.new(kart)
		if braking:
			old_straight.state.velocity = Vector2(0, 20)
			new_straight.state.velocity = Vector2(0, 20)
		var exact: bool = true
		for tick: int in range(120):
			var frame: DriveFrame = DriveFrame.sample(0, 0 if braking else 1, 1 if braking else 0)
			old_straight.step(frame, winter)
			new_straight.step(frame, winter)
			exact = exact and old_straight.state.snapshot() == new_straight.state.snapshot()
		check(exact, "straight winter %s remains identical at every tick" % ("braking" if braking else "launch"))
	var before: Dictionary = simulate(prior, winter, false, 0, 0, 10, 60)
	var after: Dictionary = simulate(kart, winter, false, 0, 0, 10, 60)
	check(after.slide > before.slide * 1.2, "kart carries at least 20 percent more sideways momentum on winter road")
	print("KART_WINTER_COAST distance_m=", [before.slide, after.slide])
	for steer: float in [-1.0, 1.0]:
		before = simulate(prior, winter, false, steer, 0.65, 0, 120)
		after = simulate(kart, winter, false, steer, 0.65, 0, 120)
		check(after.peak_slip > before.peak_slip * 1.2, "powered winter steering slides at least 20 percent more direction %s" % steer)
		check(after.speed > 1.0, "kart keeps moving in powered turn direction %s" % steer)
		print("KART_WINTER_TURN steer=", steer, " peak_slip_deg=", [before.peak_slip, after.peak_slip], " end_speed_mps=", [before.speed, after.speed])
	print("KART_WINTER_GRIP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

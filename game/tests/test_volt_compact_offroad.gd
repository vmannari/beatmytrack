extends SceneTree

const BEFORE = "res://../docs/evidence/volt-compact-offroad-2026-10-29/before/electric.tres"
const FIELDS = ["loose_surface_grip", "soil_drag_multiplier", "dirty_tire_grip_loss", "tire_pickup_distance", "tire_clean_distance", "wheel_soil_drag"]
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func field(kind: int) -> NativeTrack:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500, 500)
	track.cells.resize(10000)
	track.cells.fill(kind)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0, -400), Vector2(0, 400)])
	return track

func travel(config: HandlingConfig, ground: NativeTrack, start_dirt: float, distance: float) -> Dictionary:
	var sim := VehicleSimulation.new(config)
	var replay := VehicleSimulation.new(config)
	sim.state.tire_dirt = start_dirt
	replay.state.tire_dirt = start_dirt
	var exact := true
	while sim.state.position.y < distance:
		sim.state.velocity = Vector2(0, 12)
		replay.state.velocity = sim.state.velocity
		var frame := DriveFrame.sample(0, 0.5, 0)
		sim.step(frame, ground)
		replay.step(frame, ground)
		exact = exact and sim.state.snapshot() == replay.state.snapshot()
	return {"distance": sim.state.position.y, "dirt": sim.state.tire_dirt, "exact": exact}

func run() -> void:
	var compact: HandlingConfig = VehicleCatalog.config("compact")
	var volt: HandlingConfig = (load("res://tests/fixtures/volt_turn_reference/electric_26.tres") as HandlingConfig).duplicate()
	var old: HandlingConfig = load(BEFORE) as HandlingConfig
	check(old.version == "electric-25" and volt.version == "electric-26", "handling identity advances")
	for name: String in FIELDS:
		check(volt.get(name) == compact.get(name), "Compact setting matches: " + name)
	for name: String in old.snapshot():
		if name == "version" or name in FIELDS: continue
		check(old.get(name) == volt.get(name), "unrelated Volt setting retained: " + name)
	for kind: int in [1, 2]:
		var soil := field(kind)
		var sample := travel(volt, soil, 0.0, 10.0)
		var earlier := travel(old, soil, 0.0, 10.0)
		var rate: float = 0.5 if kind == 1 else 1.0
		check(absf(sample.dirt - sample.distance * rate / 20.0) < 0.0001, "matching pickup distance on surface " + str(kind))
		check(sample.dirt < earlier.dirt and sample.exact, "less contamination and exact replay on surface " + str(kind))
	var road := field(0)
	var cleaned := travel(volt, road, 1.0, 40.0)
	check(absf(cleaned.dirt - (1.0 - cleaned.distance / 80.0)) < 0.0001 and cleaned.exact, "cleaning follows 80 m distance and replays")
	check(is_equal_approx(VehicleSimulation.dirt_grip_loss(1.0, volt.dirty_tire_grip_loss), 0.5), "full coating removes half the road grip")
	check(VehicleSimulation.dirt_grip_loss(0.5, volt.dirty_tire_grip_loss) < VehicleSimulation.dirt_grip_loss(0.5, old.dirty_tire_grip_loss), "partial coating has a smaller road penalty")
	var clean_before := VehicleSimulation.new(old)
	var clean_after := VehicleSimulation.new(volt)
	for tick: int in range(600):
		var frame := DriveFrame.sample(sin(tick * 0.03) * 0.5, 0.7, 0)
		clean_before.step(frame, road)
		clean_after.step(frame, road)
		check(clean_before.state.snapshot() == clean_after.state.snapshot(), "clean road behavior stays exact at tick " + str(tick))
	print("VOLT_COMPACT_OFFROAD: ", checks, " checks, ", failures, " failures; hash=", JSON.stringify(volt.snapshot(), "", true).sha256_text())
	quit(1 if failures else 0)

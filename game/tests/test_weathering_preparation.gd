extends SceneTree
## Actual car surfaces, pixels and frozen race state across preparation rendering.
var checks: int = 0
var failures: int = 0
var output: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func settle(frames: int = 4) -> void:
	for index: int in range(frames):
		if DisplayServer.get_name() == "headless": await process_frame
		else: await RenderingServer.frame_post_draw

func surfaces(effect: VehicleWeathering) -> Array[Material]:
	var result: Array[Material] = []
	for binding: Dictionary in effect.bindings:
		result.append(binding.node.material_override if binding.override else binding.node.get_surface_override_material(binding.index))
	return result

func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/race-hitch-recurrence-2026-10-13/preparation-" + RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	var cars: Array[String] = []
	cars.assign(VehicleCatalog.IDS)
	cars.append("compact")
	for case_index: int in range(cars.size()):
		var id: String = cars[case_index]
		var case_name: String = id + ("-decorated" if case_index == cars.size() - 1 else "")
		var game: Node = load("res://core/game.tscn").instantiate()
		if case_index == cars.size() - 1:
			var livery: Dictionary = VehicleLivery.defaults(id)
			livery.pattern = LiveryCatalog.patterns[0].id
			livery.stickers.hood.id = "crest"
			var records := LocalRecords.new(output.path_join("fixture-records.json"))
			records.settings.vehicle_liveries = {id: livery}
			game.preference_records = records
		game.vehicle_id = id
		game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
		game.production_mode = true
		root.add_child(game)
		game.hitch_diagnostics.persist_enabled = false
		game.paused = true
		game._process(0.0)
		game.process_mode = Node.PROCESS_MODE_DISABLED
		# Let the original Mobile shader finish background specialization before
		# comparing it with the same restored shader, preserving exact pixel checks.
		await settle(120 if DisplayServer.get_name() != "headless" else 4)
		var effect: VehicleWeathering = game.car_weathering
		var condition: Dictionary = effect.snapshot()
		var state: Dictionary = RewindHistory.properties(game.sim.state)
		var original: Array[Material] = surfaces(effect)
		var before: Image
		if DisplayServer.get_name() != "headless": before = root.get_texture().get_image()
		check(not effect.installed and effect.begin_render_warmup(), id + " clean finish enters preparation")
		check(effect.installed and effect.snapshot() == condition, id + " real finish renders without cosmetic mutation")
		check(not effect.begin_render_warmup(), id + " repeated preparation does not nest")
		await settle()
		effect.end_render_warmup()
		await settle()
		check(not effect.installed and surfaces(effect) == original, id + " exact clean surface bindings restored")
		check(effect.snapshot() == condition, id + " wash/grime/cosmetic data retained exactly")
		check(RewindHistory.properties(game.sim.state) == state and game.countdown_ticks == 360, id + " no physics tick or countdown consumed")
		if before != null:
			var after: Image = root.get_texture().get_image()
			check(after.get_data() == before.get_data(), id + " preparation preserves exact rendered appearance")
			check(before.save_png(output.path_join(case_name + "-before.png")) == OK and after.save_png(output.path_join(case_name + "-after.png")) == OK, case_name + " paired pixel evidence saved")
		effect.dirt_amount = 0.25
		effect.melt(0.0)
		var dirty: Dictionary = effect.snapshot()
		var dirty_surfaces: Array[Material] = surfaces(effect)
		check(not effect.begin_render_warmup(), id + " retained dirty finish uses normal preparation draw")
		effect.end_render_warmup()
		check(effect.installed and effect.snapshot() == dirty and surfaces(effect) == dirty_surfaces, id + " dirty finish remains exact")
		effect.reset()
		effect.restore(condition)
		check(effect.begin_render_warmup(), id + " clean preparation can be cancelled")
		effect.reset()
		effect.end_render_warmup()
		check(not effect.installed and not effect._render_warming, id + " reset cancels preparation safely")
		game.free()
		await process_frame
	print("WEATHERING_PREPARATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

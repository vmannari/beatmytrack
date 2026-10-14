extends SceneTree
## Isolate the material transition observed in the owner's live freeze.
## No inputs, particles, condition saves or player storage during measurement.
var game: Node
var rows: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func rendered_frames(count: int) -> void:
	for index: int in range(count): await RenderingServer.frame_post_draw

func measure(label: String, effect: VehicleWeathering, dirt: float) -> void:
	var started: int = Time.get_ticks_usec()
	effect.dirt_amount = dirt
	effect.melt(0.0)
	var bind_us: int = Time.get_ticks_usec() - started
	await RenderingServer.frame_post_draw
	var first_us: int = Time.get_ticks_usec() - started
	var draw_us: int = game.hitch_diagnostics._draw_us
	rows.append({"phase": label, "first_frame_ms": first_us / 1000.0, "draw_ms": draw_us / 1000.0, "bind_ms": bind_us / 1000.0, "installed": effect.installed, "bindings": effect.bindings.size(), "materials": effect.materials.size()})
	await rendered_frames(6)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("First-use probe needs a graphical renderer")
		quit(1)
		return
	game = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	game.production_mode = true
	game.paused = true
	root.add_child(game)
	game.paused = true
	game.hitch_diagnostics.persist_enabled = false
	game.set_physics_process(false)
	await rendered_frames(30)
	var effect: VehicleWeathering = game.car_weathering
	await measure("initial_clean", effect, 0.0)
	if "--particles" in OS.get_cmdline_user_args():
		var emitters: Array = game.sand_dust.clipping_emitters + game.sand_dust.mud_emitters
		var started: int = Time.get_ticks_usec()
		for emitter: GPUParticles3D in emitters:
			emitter.position = game.car.position
			emitter.emitting = true
		await rendered_frames(1)
		rows.append({"phase": "first_grass_particles", "first_frame_ms": (Time.get_ticks_usec() - started) / 1000.0, "draw_ms": game.hitch_diagnostics._draw_us / 1000.0, "weathering_installed": effect.installed})
		for emitter: GPUParticles3D in emitters: emitter.emitting = false
		await rendered_frames(30)
	if "--warm" in OS.get_cmdline_user_args():
		var before: Dictionary = effect.snapshot()
		var started: int = Time.get_ticks_usec()
		effect.begin_render_warmup()
		await rendered_frames(2)
		effect.end_render_warmup()
		rows.append({"phase": "loading_warmup", "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0, "cosmetics_exact": effect.snapshot() == before, "restored_clean": not effect.installed})
		await rendered_frames(6)
	await measure("first_dirty", effect, 0.12)
	await measure("restore_clean", effect, 0.0)
	await measure("repeat_dirty", effect, 0.12)
	var report: Dictionary = {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "tick": game.sim.state.tick, "rows": rows}
	print("WEATHERING_FIRST_USE ", JSON.stringify(report))
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/race-hitch-recurrence-2026-10-13")
	var file := FileAccess.open(folder.path_join("first-use-%s-%d.json" % [report.renderer, OS.get_process_id()]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report)); file.close()
	game.free()
	quit()

extends "res://tests/profile_track_load_stages.gd"
## Exploratory only: same-process control and strict-state grouped repeat draws.
var interruption_mode := ""
var interruption_observed := false

func instrumented_app() -> GDScript:
	var script := super.instrumented_app()
	if script == null: return null
	var needle := 'var effect_preparation = preload("res://vehicle/effect_render_preparation.gd")'
	var source := script.source_code
	if source.count(needle) != 1: push_error("App effect anchor changed"); return null
	source = source.replace(needle,'var effect_preparation = load("res://tests/profile_effect_batch_experiment.gd").effect_script(_batch_experiment)')
	source += '\nvar _batch_experiment: bool = false\n'
	script.source_code = source
	if script.reload() != OK: push_error("Experiment App compile failed"); return null
	return script

static func effect_script(experiment: bool) -> GDScript:
	var source := FileAccess.get_file_as_string("res://vehicle/effect_render_preparation.gd")
	if experiment:
		var start := source.find('\tfor source_ref: WeakRef in sources:')
		var end := source.find('\tprepared.complete = true',start)
		if start < 0 or end <= start: push_error("Effect loop anchor changed"); return null
		source = source.substr(0,start)+_loop()+source.substr(end)
		source += _helpers()
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK: push_error("Experiment effect compile failed"); return null
	return script

static func _loop() -> String:
	return """
	# Only reorder a complete set of retained nodes; otherwise use singleton groups.
	var labels: Dictionary = {}
	for entry: Dictionary in pool.entries: labels[entry.label] = true
	var all_reused := not sources.is_empty()
	for source_ref: WeakRef in sources:
		var s: GPUParticles3D = source_ref.get_ref()
		if s == null or not labels.has("Covered"+str(s.name)): all_reused = false
	var groups: Dictionary = {}
	var unique_index := 0
	for source_ref: WeakRef in sources:
		var s: GPUParticles3D = source_ref.get_ref()
		if s == null: return prepared
		var mesh: Mesh = s.get_draw_pass_mesh(0) if s.draw_passes > 0 else null
		var material: Material = mesh.surface_get_material(0) if mesh != null and mesh.get_surface_count() > 0 else null
		var shader: Shader = material.shader if material is ShaderMaterial else null
		print("BATCH_IDENTITY ",JSON.stringify({"name":str(s.name),"process":s.process_material.get_instance_id() if s.process_material != null else 0,"mesh":mesh.get_instance_id() if mesh != null else 0,"material":material.get_instance_id() if material != null else 0,"shader":shader.get_instance_id() if shader != null else 0}))
		var key: String = _probe_key(s) if all_reused else str(unique_index)
		unique_index += 1
		if not groups.has(key): groups[key] = []
		groups[key].append(source_ref)
	var group_sizes: Array = []
	for group: Array in groups.values():
		group_sizes.append(group.size())
		var batch: Array[GPUParticles3D] = []
		for source_ref: WeakRef in group:
			if not _current(world,camera,current) or not is_instance_valid(pool): return prepared
			var s: GPUParticles3D = source_ref.get_ref()
			if s == null: return prepared
			var particles: GPUParticles3D = pool.take("Covered"+str(s.name))
			if bool(particles.get_meta("preparation_reused",false)): prepared.reused += 1
			_configure_particle(particles,s,world,camera)
			particles.one_shot = false
			pool.measure(particles)
			prepared.nodes.append(particles)
			prepared.particles += 1
			batch.append(particles)
		if not draw.is_valid() or not bool(await draw.call()): return prepared
		if not _current(world,camera,current): return prepared
		for particles: GPUParticles3D in batch:
			if is_instance_valid(particles): prepared.initialized[particles.get_instance_id()] = true
	print("BATCH_EXPERIMENT ",JSON.stringify({"all_reused":all_reused,"groups":group_sizes,"proxies":sources.size()}))
"""

static func _helpers() -> String:
	return """
static func _probe_key(source: GPUParticles3D) -> String:
	var values: Array = [source.process_material,source.draw_passes]
	for name: String in ["lifetime","fixed_fps","fract_delta","interpolate","local_coords","draw_order","collision_base_size","transform_align","cast_shadow","layers"]: values.append(source.get(name))
	for index: int in range(source.draw_passes): values.append(source.get_draw_pass_mesh(index))
	values.append(source.visibility_aabb)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes_with_objects(values))
	return context.finish().hex_encode()
"""

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size=Vector2i(1280,720)
	var folder := "user://effect-batch-profile-"+TrackLibrary.unique_id()
	preload("res://track/road_mesh_disk_cache.gd").directory=folder.path_join("roads")
	var script := instrumented_app()
	if script == null: quit(1); return
	app=script.new()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled=false
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	app.race_profile_enabled=true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var track: NativeTrack=TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string(TRACK_PATH)))
	if track == null: quit(1); return
	track.metadata.cloud_version="effect-batch-fixture"
	preload("res://track/prepared_world_cache.gd").entries.clear()
	for cycle: int in range(4):
		app._batch_experiment = cycle == 2
		app._show_screen("tracks"); app.selected_track=track
		app._load_probe_marks.clear()
		var begin := Time.get_ticks_usec()
		await app._start_race(track,false,true)
		if not is_instance_valid(app.game) or not app.game.preparation_complete: push_error("Race not ready"); quit(1); return
		app.game.set_physics_process(false)
		print("BATCH_RACE ",JSON.stringify({"cycle":cycle,"experimental":app._batch_experiment,"wall_ms":(Time.get_ticks_usec()-begin)/1000.0,"effect_ms":app.game.bridge_preparation_ms,"counts":app.game.effect_preparation_counts,"marks":app._load_probe_marks}))
		var first := await _first_emission(app.game)
		if not first.state_exact: push_error("First emission changed canonical state"); quit(1); return
		print("BATCH_FIRST_EMISSION ",JSON.stringify({"cycle":cycle,"experimental":app._batch_experiment,"result":first}))
		app._leave_race()
		await process_frame
	# An interruption can only fire once a genuinely grouped batch is present.
	for mode: String in ["navigation","replenish","pressure"]:
		app._batch_experiment = mode != "replenish"
		interruption_mode = mode
		interruption_observed = false
		app._show_screen("tracks"); app.selected_track=track
		process_frame.connect(_interrupt_observer)
		await app._start_race(track,false,true)
		process_frame.disconnect(_interrupt_observer)
		if mode == "navigation":
			if not interruption_observed or is_instance_valid(app.game) or app.cloud_starting or is_instance_valid(app.race_loading):
				push_error("Grouped navigation cancellation failed"); quit(1); return
		else:
			if not is_instance_valid(app.game) or not app.game.preparation_complete: push_error("Interruption race not ready"); quit(1); return
			if mode == "pressure":
				var pool: Node = app.get_node_or_null("EffectPreparationPool")
				if not interruption_observed or pool == null or int(pool.get("bytes")) != 0:
					push_error("Grouped pressure cleanup failed"); quit(1); return
			app._leave_race()
		print("BATCH_INTERRUPTION ",JSON.stringify({"mode":mode,"observed":interruption_observed,"success":true}))
		for _frame: int in range(4): await process_frame
	app.queue_free(); app=null; script=null; track=null
	for _frame: int in range(8): await process_frame
	quit()

func _interrupt_observer() -> void:
	if interruption_observed or interruption_mode == "replenish" or not is_instance_valid(app) or not is_instance_valid(app.game): return
	var world: Node = app.game.get_node_or_null("World")
	if world == null or world.find_children("Covered*","GPUParticles3D",true,false).size() < 2: return
	interruption_observed = true
	if interruption_mode == "navigation": app._show_screen("settings")
	elif interruption_mode == "pressure": app.notification(NOTIFICATION_OS_MEMORY_WARNING)

func _first_emission(game: Node) -> Dictionary:
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for _frame: int in range(3): await process_frame
	var state: Dictionary = RewindHistory.properties(game.sim.state)
	var originals: Array[Dictionary] = []
	for source: GPUParticles3D in game.sand_dust.get_children():
		originals.append({"node":source,"pose":source.transform,"ratio":source.amount_ratio,"speed":source.speed_scale,"emitting":source.emitting})
		source.global_position = game.camera.global_position-game.camera.global_basis.z*10.0
		source.amount_ratio=1.0; source.speed_scale=1.0; source.emitting=true
	var waits: Array[float] = []
	if DisplayServer.get_name() != "headless":
		for _frame: int in range(3):
			var began := Time.get_ticks_usec()
			await process_frame; await RenderingServer.frame_post_draw
			waits.append((Time.get_ticks_usec()-began)/1000.0)
	var exact: bool = RewindHistory.properties(game.sim.state)==state
	for original: Dictionary in originals:
		var source: GPUParticles3D = original.node
		source.restart(true); source.emitting=original.emitting
		source.transform=original.pose; source.amount_ratio=original.ratio; source.speed_scale=original.speed
	return {"state_exact":exact,"waits_ms":waits,"emitters":originals.size()}

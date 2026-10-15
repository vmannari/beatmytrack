extends SceneTree
## First-use resource creation, actual instanced/particle draw coverage and exact
## restore. All vehicle/track/records fixtures belong to this test.
const EFFECTS = preload("res://vehicle/effect_render_preparation.gd")
const TRAILS = preload("res://vehicle/trail_render_preparation.gd")
var checks: int = 0
var failures: int = 0
var metrics: Array[Dictionary] = []
var output: String
var world: Node3D
var camera: Camera3D

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func frames(count: int = 3) -> void:
	for i: int in range(count):
		if DisplayServer.get_name() == "headless": await process_frame
		else: await RenderingServer.frame_post_draw

func value(v: Variant) -> Variant:
	if v is Shader: return v.code
	if v is CurveTexture: return value(v.curve)
	if v is GradientTexture1D: return value(v.gradient)
	if v is Texture2D:
		var pixels: Image = v.get_image()
		return pixels.get_data() if pixels != null else [v.get_class(),v.get_width(),v.get_height()]
	if v is Resource:
		var data: Dictionary = {"type":v.get_class()}
		for property: Dictionary in v.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"):
				data[property.name] = value(v.get(property.name))
		return data
	if v is Array:
		var data: Array = []
		for item: Variant in v: data.append(value(item))
		return data
	if v is Dictionary:
		var data: Dictionary = {}
		for key: Variant in v: data[key] = value(v[key])
		return data
	return v

func emitters(effects: Node3D) -> Array:
	var data: Array = []
	for source: GPUParticles3D in effects.get_children():
		var entry: Dictionary = {"name":str(source.name),"pose":source.transform,"process":value(source.process_material),"mesh":source.draw_pass_1.surface_get_arrays(0),"material":value(source.draw_pass_1.surface_get_material(0))}
		for field: String in ["amount","amount_ratio","lifetime","fixed_fps","fract_delta","interpolate","local_coords","visibility_aabb","emitting","speed_scale","one_shot","explosiveness","randomness","cast_shadow","layers"]: entry[field] = source.get(field)
		data.append(entry)
	return data

func ring(trails: SkidTrails) -> PackedByteArray:
	return var_to_bytes([trails.instances.instance_count,trails.instances.visible_instance_count,trails.instances.buffer,trails.cursor,trails.active,trails.mark_transforms,trails.mark_colors,trails.mark_custom,trails._previous_marks,trails._previous_ends,trails._previous_sides,trails._previous_types])

func case(theme: String, bridge: bool, legacy: GDScript) -> void:
	var label: String = theme+("-bridge" if bridge else "-ground")
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = theme
	if bridge: track.bridge_height = 2.0
	var state := VehicleState.new(); state.position = track.spawn; state.velocity = Vector2(0,12)
	var frame: DriveFrame = DriveFrame.sample(0,1,0)
	var expected: Node3D = legacy.new(); world.add_child(expected)
	var effects := SandDust.new(); world.add_child(effects)
	var began: int = Time.get_ticks_usec()
	check(effects.snow_burst_count == 0,"initial impact count is empty")
	effects.prepare_track(track)
	var prepare_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var prepared_count: int = effects.get_child_count()
	# Compare with the approved original resource routines at their first use.
	expected._bind_bridges(track); expected._set_desert_profile(theme == "desert")
	if theme == "winter": expected._ensure_snow()
	if theme == "storm": expected._ensure_water()
	if bridge: expected._ensure_deck_clouds()
	check(value(emitters(effects)) == value(emitters(expected)),label+" prepared emitters have exact original geometry, process/materials and budgets")
	check(effects.snow_burst_count == 0 and not effects.snow_previous_valid and effects.last_strengths == PackedFloat32Array([0,0,0,0]),label+" resource preparation advances no effects/impact state")
	var poses: Dictionary = RewindHistory.properties(state)
	began = Time.get_ticks_usec(); effects.sample(state,frame,track)
	var first_sample_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(effects.get_child_count() == prepared_count,label+" first driving sample allocates no emitter nodes")
	check(RewindHistory.properties(state) == poses,label+" resource and effect sampling leave the vehicle unchanged")
	effects.clear(); expected.free()
	var trails := SkidTrails.new(); world.add_child(trails)
	var original_ring: PackedByteArray = ring(trails)
	var before: Array = emitters(effects)
	var camera_pose: Transform3D = camera.transform
	await frames(8)
	var image: Image = root.get_texture().get_image() if DisplayServer.get_name() != "headless" else null
	var start_draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	began = Time.get_ticks_usec()
	var prepared: Dictionary = EFFECTS.begin(world,effects,camera)
	var trail: MultiMeshInstance3D = TRAILS.begin(trails,camera,track,state)
	check(prepared.particles == (prepared_count if image != null else 0),label+" loading prepares every existing particle pipeline")
	check((trail != null) == (image != null),label+" tire preparation uses an actual MultiMesh draw on graphical renderers")
	if image != null:
		check(trail.multimesh.mesh == trails.instances.mesh and trail.multimesh.instance_count == 1,label+" tire proxy retains the exact parallel ribbon mesh and one slot")
		check((trail.material_override as ShaderMaterial).shader == trails._bridge_material.shader,label+" tire proxy retains the exact live shader")
		for index: int in range(prepared.particles):
			var proxy: GPUParticles3D = prepared.nodes[index]; var source: GPUParticles3D = effects.get_child(index)
			check(proxy.process_material == source.process_material and proxy.draw_pass_1 == source.draw_pass_1 and proxy.amount == 1 and proxy.process_mode == Node.PROCESS_MODE_ALWAYS,label+" bounded particle proxy uses the live compute/draw material while Game is disabled")
	await frames(3)
	var draw_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var warm_draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if image != null: check(warm_draws > start_draws,label+" preparation produced real particle/instanced draw calls")
	TRAILS.end(trail); EFFECTS.end(prepared); EFFECTS.end(prepared)
	world.process_mode = Node.PROCESS_MODE_INHERIT
	await frames(3)
	check(emitters(effects) == before,label+" original particle poses/resources/emission and budgets restore exactly")
	check(ring(trails) == original_ring and trails.instances.instance_count == 16384,label+" original complete tire ring and sampling state are byte exact")
	check(camera.transform == camera_pose and RewindHistory.properties(state) == poses,label+" render preparation preserves camera and vehicle state")
	if image != null:
		var after: Image = root.get_texture().get_image()
		check(image.get_data() == after.get_data(),label+" no temporary marks, particles or shadows remain in restored pixels")
		image.save_png(output.path_join(label+"-before.png")); after.save_png(output.path_join(label+"-after.png"))
	var first_live_draw_ms: float = 0.0
	var live_draw_delta: float = 0.0
	if image != null:
		var draw_pipelines: float = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		var pulse: Array[Dictionary] = []
		var center: Vector3 = camera.global_position-camera.global_basis.z*10.0
		began = Time.get_ticks_usec()
		for source: GPUParticles3D in effects.get_children():
			pulse.append({"node":source,"pose":source.transform,"ratio":source.amount_ratio,"speed":source.speed_scale})
			source.global_position = center
			source.speed_scale = 1.0
			source.amount_ratio = 1.0
			source.emitting = true
		await frames(1)
		first_live_draw_ms = (Time.get_ticks_usec()-began)/1000.0
		live_draw_delta = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)-draw_pipelines
		if RenderingServer.get_current_rendering_method() != "gl_compatibility": check(live_draw_delta == 0,label+" first live emission needs no new on-demand draw pipeline")
		for entry: Dictionary in pulse:
			entry.node.restart(true); entry.node.emitting = false
			entry.node.transform = entry.pose; entry.node.amount_ratio = entry.ratio; entry.node.speed_scale = entry.speed
		await frames(3)
		check(emitters(effects) == before,label+" actual first-live emission leaves the original resources/budgets intact")
	var cancel: Dictionary = EFFECTS.begin(world,effects,camera)
	for node: Node in cancel.nodes: node.free()
	EFFECTS.end(cancel)
	check(cancel.is_empty(),label+" restoration handles deleted temporary nodes")
	metrics.append({"case":label,"emitters":prepared_count,"prepare_resources_ms":prepare_ms,"first_sample_ms":first_sample_ms,"covered_three_draws_ms":draw_ms,"draws_before":start_draws,"draws_prepared":warm_draws,"first_live_draw_ms":first_live_draw_ms,"live_draw_pipeline_delta":live_draw_delta})
	trails.free(); effects.free(); await frames(1)

func inactive_batches() -> void:
	var debris := Node3D.new(); world.add_child(debris)
	BreakablePropVisual.ensure_debris(debris)
	var kit := NativeTrackVisual.new()
	var props: Array[Node3D] = []
	for kind: String in ["hay_bale","crate"]:
		var node := Node3D.new(); node.position = Vector3(50,0,0); debris.add_child(node)
		BreakablePropVisual.build(node,kit,kind,1.0); props.append(node)
	kit.free()
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json"); track.metadata.theme = "winter"
	var weather := WinterSnowWind.new(); world.add_child(weather); weather.configure(track)
	var impact := ImpactCracks.new(); world.add_child(impact)
	var damage: Vector4 = impact.side_damage
	var impact_material: Material = impact.material
	var originals: Array[Dictionary] = []
	for node: Node in world.find_children("*","MultiMeshInstance3D",true,false):
		originals.append({"node":node,"mesh":node.multimesh.mesh,"buffer":node.multimesh.buffer,"count":node.multimesh.instance_count,"visible_count":node.multimesh.visible_instance_count,"material":node.material_override})
	var phases: Array[Dictionary] = []
	for prop: Node3D in props:
		for node: MeshInstance3D in prop.get_children(): phases.append({"node":node,"visible":node.visible,"margin":node.extra_cull_margin,"mesh":node.mesh,"material":node.material_override,"pose":node.transform})
	await frames(8)
	var image: Image = root.get_texture().get_image() if DisplayServer.get_name() != "headless" else null
	var prepared: Dictionary = EFFECTS.begin(world,null,camera,impact)
	check(prepared.canvas == (1 if image != null else 0),"normally hidden crash glass gets its actual canvas shader preparation")
	check(prepared.batches == (5 if image != null else 0),"empty wood/hay and all three original winter batches receive instanced preparation")
	check(prepared.damage_meshes == (6 if image != null else 0),"hidden original hay/crate damage phases prepare under cover")
	await frames(3)
	EFFECTS.end(prepared)
	await frames(3)
	for row: Dictionary in originals:
		check(row.node.multimesh.mesh == row.mesh and row.node.multimesh.buffer == row.buffer and row.node.multimesh.instance_count == row.count and row.node.multimesh.visible_instance_count == row.visible_count and row.node.material_override == row.material,"weather/debris mesh, complete buffer, populations and material ownership restore exactly")
	for row: Dictionary in phases:
		check(row.node.mesh == row.mesh and row.node.material_override == row.material and row.node.transform == row.pose and row.node.visible == row.visible and row.node.extra_cull_margin == row.margin,"damage phase visibility, geometry, finish, transform and cull margins restore exactly")
	check(not impact.visible and impact.side_damage == damage and impact.strength == 0 and impact.material == impact_material,"crash-glass preparation preserves actual damage, visibility and material ownership")
	if image != null:
		var after: Image = root.get_texture().get_image()
		check(after.get_data() == image.get_data(),"inactive debris/weather and damage preparation restore exact pixels")
		image.save_png(output.path_join("batches-before.png")); after.save_png(output.path_join("batches-after.png"))
	prepared = EFFECTS.begin(world,null,camera,impact)
	debris.free(); weather.free(); impact.free()
	EFFECTS.end(prepared)
	check(prepared.is_empty(),"deleted original phase and temporary batch nodes are safe to restore")

func ring_costs() -> void:
	var trails := SkidTrails.new(); world.add_child(trails); trails.set_process(false)
	var written: int = 0
	var rows: Array[Dictionary] = []
	for target: int in [511,1023,1024,4096,16384,16385]:
		var began: int = Time.get_ticks_usec()
		var peak: int = 0
		while written < target:
			var at := Vector3((written/512)*100+(written%512)*0.016,0.03,0)
			var start: int = Time.get_ticks_usec()
			trails._mark(at,at+Vector3(0,0,0.32),0.0,2,0.58)
			peak = maxi(peak,Time.get_ticks_usec()-start)
			written += 1
		var append_ms: float = (Time.get_ticks_usec()-began)/1000.0
		began = Time.get_ticks_usec()
		trails.trail_visibility.present(camera,trails.mark_colors,trails.mark_custom,trails.global_transform)
		var view_ms: float = (Time.get_ticks_usec()-began)/1000.0
		check(trails.instances.instance_count == 16384 and trails.get_child_count() == 1,"visibility threshold/wrap retains the full single-batch tire ring")
		check(trails.trail_visibility.retained_count == mini(target,16384),"visibility threshold/wrap preserves every retained tire slot")
		rows.append({"written":target,"append_block_ms":append_ms,"slowest_append_ms":peak/1000.0,"view_ms":view_ms,"drawn":trails.instances.visible_instance_count})
	trails.free()
	FileAccess.open(output.path_join("ring-costs.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))

func app_launch() -> void:
	OS.set_environment("BMT_API_URL","")
	var folder: String = ProjectSettings.globalize_path("res://../build/dynamic-preparation-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder); app.records = LocalRecords.new(folder.path_join("records.json")); app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json"); track.metadata.theme = "storm"
	track.metadata.cloud_version = "isolated-effect-preparation"
	app.selected_track = track
	var condition := VehicleWeathering.new(); condition.deposit_color = VehicleWeathering.COLORS.storm; condition.dirt_amount = 0.125
	check(VehicleCondition.save(app.records,VehicleCatalog.selected,condition.snapshot()) == OK,"disposable app starts with real existing local condition")
	var saved_condition: Dictionary = app.records.settings.vehicle_conditions.duplicate(true)
	app._start_race(track,false,true)
	var revealed: Dictionary = {}
	app.race_loading.tree_exiting.connect(func() -> void:
		if is_instance_valid(app.game): revealed.tick = app.game.sim.state.tick; revealed.countdown = app.game.countdown_ticks)
	var started: int = Time.get_ticks_msec()
	while app.cloud_starting and Time.get_ticks_msec()-started < 15000: await process_frame
	check(is_instance_valid(app.game) and not app.cloud_starting,"actual covered dynamic preparation completes")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		check(revealed.get("tick",-1) == 0 and revealed.get("countdown",-1) == 360 and app.game.track_session.target_laps == 5,"actual reveal retains tick zero, full countdown and five ordinary laps")
		check(app.game.effects_prepared == (DisplayServer.get_name() != "headless") and app.game.effect_preparation_counts.particles == (24 if DisplayServer.get_name() != "headless" else 0),"actual loading reports graphical preparation with all water/ordinary effect families")
		check(app.game.effect_preparation_counts.canvas == (1 if DisplayServer.get_name() != "headless" else 0) and not app.game.impact_cracks.visible and app.game.impact_cracks.side_damage == Vector4.ZERO,"actual loading prepares the crash shader without claiming an impact")
		check(app.game.sand_dust.water_drops.size() == 4 and not app.game.sand_dust.get_children().any(func(node: GPUParticles3D) -> bool: return node.emitting),"water resources exist while the actual race starts with no artificial emissions")
		check(app.game.get_node("World").find_children("Covered*","",true,false).is_empty(),"actual reveal contains no temporary preparation nodes")
		check(app.game.trails.cursor == 0 and app.game.trails.instances.visible_instance_count == 0 and app.game.trails.instances.instance_count == 16384,"actual reveal retains empty complete tire ring")
		check(app.records.settings.vehicle_conditions == saved_condition,"loading preserves actual saved local condition")
		app._leave_race()
	app.free(); await process_frame

func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/dynamic-first-use-2026-10-14/"+("headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()))
	if "--components-only" in OS.get_cmdline_user_args(): output = output.path_join("components")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(640,360)
	world = Node3D.new(); root.add_child(world)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 20; world.add_child(camera); camera.position = Vector3(0,15,10); camera.look_at(Vector3.ZERO); camera.current = true
	var light := DirectionalLight3D.new(); light.shadow_enabled = true; light.rotation_degrees = Vector3(-58,-35,0); world.add_child(light)
	VisualGeometry.box(world,Vector3(40,0.1,40),Vector3(0,-0.1,0),VisualGeometry.material(Color("647158")))
	var legacy := GDScript.new()
	legacy.source_code = FileAccess.get_file_as_string("res://../docs/evidence/dynamic-first-use-2026-10-14/before/game/vehicle/sand_dust.gd").replace("class_name SandDust","")
	check(legacy.reload() == OK,"original resource builder compiles as a diagnostic copy")
	for theme: String in TrackTheme.IDS:
		await case(theme,false,legacy)
		await case(theme,true,legacy)
	await inactive_batches()
	ring_costs()
	world.free()
	if not ("--components-only" in OS.get_cmdline_user_args()): await app_launch()
	var file := FileAccess.open(output.path_join("resources.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"));file.close()
	print("DYNAMIC_PREPARATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

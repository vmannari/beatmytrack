extends SceneTree
## Real Winter contacts must use debris draw paths already submitted under cover.
const EFFECTS = preload("res://vehicle/effect_render_preparation.gd")
const NAMES: Array[String] = ["LooseHayFragments","WoodFragments","SnowChunks","IceShards","SnowPowder"]
var checks: int = 0
var failures: int = 0
var output: String
var metrics: Array[Dictionary] = []
var preparation: GDScript = EFFECTS
var graphical: bool

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func frames(count: int = 3) -> void:
	for i: int in range(count):
		if graphical: await RenderingServer.frame_post_draw
		else: await process_frame

func capture(name: String) -> Image:
	if not graphical: return null
	var pixels: Image = root.get_texture().get_image()
	check(pixels.save_png(output.path_join(name+".png")) == OK,name+" capture saved")
	return pixels

func clear(_p: Vector2, _r: float, _d: bool) -> Vector3: return Vector3.ZERO

func advance(state: VehicleState, props: Array) -> void:
	var config: HandlingConfig = VehicleCatalog.config("compact")
	LightProps.step(state,props,clear,state.position-Vector2(0.35,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
	state.tick += 1

func hit(state: VehicleState, props: Array, index: int) -> void:
	state.position = Vector2(props[index].position[0]-0.20,props[index].position[1])
	state.velocity = Vector2(12,0); state.heading = PI*0.5
	advance(state,props)

func batches() -> void:
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 12
	camera.look_at_from_position(Vector3(0,12,9),Vector3.ZERO); camera.current = true
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-58,-35,0); world.add_child(sun)
	VisualGeometry.box(world,Vector3(30,0.1,30),Vector3(0,-0.10,0),VisualGeometry.material(Color("b9cedb")))
	var props: Array = []
	for i: int in range(PropWinterCraft.BREAKABLE.size()):
		props.append({"kind":PropWinterCraft.BREAKABLE[i],"position":[(i-1)*3,0],"rotation":0})
	var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":props}}
	var visual := NativeTrackVisual.new(); visual.theme_id = "winter"
	world.add_child(visual); visual._build_placed_objects(track)
	var state := VehicleState.new(); state.position = Vector2(100,100); advance(state,props)
	visual.update_light_props(state)
	var original: Array = state.snapshot()
	var camera_pose: Transform3D = camera.transform
	var retained: Array[Dictionary] = []
	for name: String in NAMES:
		var node: MultiMeshInstance3D = visual.get_node(name)
		retained.append({"node":node,"resource":node.multimesh,"mesh":node.multimesh.mesh,"buffer":node.multimesh.buffer,"count":node.multimesh.instance_count,"visible":node.multimesh.visible_instance_count,"material":node.material_override})
	await frames(5)
	var intact: Image = capture("intact-before")
	var prepared: Dictionary = preparation.begin(world,null,camera)
	check(prepared.batches == (5 if graphical else 0),"all five existing debris batches prepare before the first impact")
	for name: String in NAMES:
		var proxy: MultiMeshInstance3D = world.get_node_or_null("Covered"+name)
		check((proxy != null) == graphical,name+" gets an actual covered instanced draw")
		if proxy == null: continue
		var source: MultiMeshInstance3D = visual.get_node(name)
		check(proxy.multimesh.mesh == source.multimesh.mesh and proxy.material_override == source.material_override,name+" reuses the live mesh and shader material")
		check(proxy.multimesh.use_custom_data == source.multimesh.use_custom_data and proxy.multimesh.transform_format == source.multimesh.transform_format,name+" uses the live instancing format")
		check(proxy.multimesh.instance_count == 1 and camera.is_position_in_frustum(proxy.to_global(proxy.multimesh.get_instance_transform(0).origin)),name+" submits one instance inside the actual camera")
		if name == "SnowPowder": check(proxy.multimesh.get_instance_custom_data(0).a > 0,"covered powder has visible lifetime data")
	await frames()
	preparation.end(prepared)
	await frames()
	check(prepared.is_empty() and world.find_children("Covered*","",true,false).is_empty(),"covered draw releases all temporary nodes")
	for row: Dictionary in retained:
		check(row.node.multimesh == row.resource and row.node.multimesh.mesh == row.mesh and row.node.multimesh.buffer == row.buffer and row.node.multimesh.instance_count == row.count and row.node.multimesh.visible_instance_count == row.visible and row.node.material_override == row.material,"covered draw preserves the original debris resource, buffers, counts and material")
	check(state.snapshot() == original and camera.transform == camera_pose,"covered preparation never advances or changes canonical state or camera")
	var restored: Image = capture("intact-after")
	if graphical: check(intact.get_data() == restored.get_data(),"clean reveal has exactly the original pixels")
	for index: int in range(props.size()):
		var before_hit: Dictionary = RewindHistory.properties(state)
		var pipelines: float = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		var began: int = Time.get_ticks_usec()
		hit(state,props,index)
		var contact_us: int = Time.get_ticks_usec()-began
		check(state.prop_destruction[index][0] == 0.0,props[index].kind+" breaks on a real contact")
		var snapshot: Array = state.snapshot()
		began = Time.get_ticks_usec(); visual.update_light_props(state)
		var present_us: int = Time.get_ticks_usec()-began
		began = Time.get_ticks_usec(); await frames(1)
		var draw_us: int = Time.get_ticks_usec()-began
		var added: float = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)-pipelines
		if graphical and RenderingServer.get_current_rendering_method() != "gl_compatibility":
			check(added == 0,props[index].kind+" first impact compiles no new on-demand draw pipeline")
		check(state.snapshot() == snapshot and not visual.light_instances[index].visible,props[index].kind+" draw hides the intact object and flame without mutating the collision snapshot")
		await capture(props[index].kind+"-broken")
		RewindHistory.restore(state,before_hit); visual.update_light_props(state)
		check(visual.light_instances[index].visible,props[index].kind+" rewind restores the intact object and candle")
		hit(state,props,index); visual.update_light_props(state)
		check(state.snapshot() == snapshot,props[index].kind+" impact repeats exactly after rewind")
		metrics.append({"kind":props[index].kind,"contact_us":contact_us,"presentation_us":present_us,"first_draw_us":draw_us,"on_demand_draw_pipelines":added})
	visual.update_light_props(VehicleState.new())
	for name: String in NAMES: check(visual.get_node(name).multimesh.instance_count == 0,"retry immediately clears "+name)
	for node: Node3D in visual.light_instances: check(node.visible,"retry restores the intact Winter prop")
	state.position = Vector2(100,100); state.velocity = Vector2.ZERO
	for i: int in range(400): advance(state,props)
	visual.update_light_props(state)
	check(state.prop_fragments.is_empty(),"original finite debris lifetime remains exact")
	prepared = preparation.begin(world,null,camera)
	visual.free()
	for node: Variant in prepared.nodes:
		if is_instance_valid(node): node.free()
	preparation.end(prepared)
	check(prepared.is_empty(),"cancellation tolerates freed original and temporary nodes")
	world.free(); await process_frame

func app_launch() -> void:
	OS.set_environment("BMT_API_URL","")
	var folder: String = "user://winter_break_preparation_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder); app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud"); root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+30000
	while not app.startup_complete and Time.get_ticks_msec() < deadline: await process_frame
	check(app.startup_complete,"disposable offline App completes startup")
	if not app.startup_complete: app.free(); return
	app._show_screen("tracks")
	var doc: Dictionary = TrackDocument.create_default(); doc.theme = "winter"; doc["automatic_scenery"] = false
	doc.objects = [{"kind":"ice_lantern","position":[0,0],"rotation":0}]
	doc.paint = [{"surface":0,"width":20.0,"shape":"square","points":[[0,0]]}]
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"actual Winter race fixture compiles: "+str(TrackDocument.validate(doc)))
	if track == null: app.free(); return
	track.metadata.cloud_version = "isolated-winter-break-preparation"; app.selected_track = track
	app._start_race(track,false,true)
	var revealed: Dictionary = {}
	app.race_loading.tree_exiting.connect(func() -> void:
		if is_instance_valid(app.game): revealed.tick = app.game.sim.state.tick; revealed.countdown = app.game.countdown_ticks)
	deadline = Time.get_ticks_msec()+45000
	while app.cloud_starting and Time.get_ticks_msec() < deadline: await process_frame
	check(is_instance_valid(app.game) and not app.cloud_starting,"actual covered Winter race loading completes")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		check(revealed.get("tick",-1) == 0 and revealed.get("countdown",-1) == 360 and app.game.track_session.target_laps == 5,"actual reveal preserves tick zero, full countdown and five laps")
		check(app.game.effect_preparation_counts.batches >= (5 if graphical else 0),"actual race loading covers every Winter breakup batch")
		check(app.game.get_node("World").find_children("Covered*","",true,false).is_empty(),"actual race reveal retains no preparation nodes")
		check(app.game.sim.state.prop_fragments.is_empty(),"actual race begins without invented impacts or debris")
		app._leave_race()
	app.free(); await process_frame

func run() -> void:
	var task_config:=ConfigFile.new()
	task_config.set_value("backend","url","")
	assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	graphical = DisplayServer.get_name() != "headless"
	output = ProjectSettings.globalize_path("res://../build/runtime-loading-fixes-2026-10-27/outputs/accepted-winter-mobile/"+(RenderingServer.get_current_rendering_method() if graphical else "headless"))
	if "--original" in OS.get_cmdline_user_args():
		preparation = GDScript.new()
		preparation.source_code = FileAccess.get_file_as_string("res://../docs/evidence/ice-lantern-hitch-2026-10-18/before/game/vehicle/effect_render_preparation.gd.txt")
		check(preparation.reload() == OK,"saved original preparation helper loads")
		output = output.path_join("original")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960,540); root.content_scale_size = root.size
	await batches()
	if "--components-only" not in OS.get_cmdline_user_args(): await app_launch()
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")); file.close()
	print("WINTER_BREAK_PREPARATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

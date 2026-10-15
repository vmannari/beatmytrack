extends SceneTree
const Preparation = preload("res://track/night_render_preparation.gd")
var checks: int = 0
var failures: int = 0
var output: String
class ProbeApp extends "res://core/app.gd":
	var cancel_night: bool = false
	func _prepare_night_lighting(loading_id: int, prepared_game: Node) -> Dictionary:
		if cancel_night:
			cancel_night = false
			_show_screen.call_deferred("tracks")
		return await super._prepare_night_lighting(loading_id,prepared_game)
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func frames(count: int = 4) -> void:
	for index: int in range(count):
		if DisplayServer.get_name() == "headless": await process_frame
		else: await RenderingServer.frame_post_draw
func fixture() -> NativeTrack:
	var document: Dictionary = TrackDocument.create_default()
	document.theme = "night_city"
	for point: Vector2 in [Vector2(-20,10),Vector2(20,-10)]:
		document.objects.append({"kind":"light","position":[point.x,point.y],"rotation":0.0,"scale":1.0})
	return TrackCompiler.compile(document)
func run() -> void:
	output = ProjectSettings.globalize_path("res://../docs/evidence/night-hitch-2026-10-14/preparation-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(output)
	var track: NativeTrack = fixture()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	game.preference_records = LocalRecords.new(output.path_join("disposable.json"))
	root.add_child(game)
	game.hitch_diagnostics.persist_enabled = false
	game.paused = true
	game.call("_process",0.0)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(120 if DisplayServer.get_name() != "headless" else 4)
	var state: Dictionary = RewindHistory.properties(game.sim.state)
	var condition: Dictionary = game.car_weathering.snapshot()
	var pose: Transform3D = game.camera.transform
	var size: float = game.camera.size
	var lights: Array[Dictionary] = []
	for light: Node in game.get_node("World").find_children("*","Light3D",true,false):
		lights.append({"node":light,"pose":light.transform,"visible":light.visible,"energy":light.light_energy,"mask":light.light_cull_mask,"shadow":light.shadow_enabled})
	var snapshots: Array[Dictionary] = []
	for node: Node in game.get_node("World").find_children("*","GeometryInstance3D",true,false):
		snapshots.append({"node":node,"margin":node.extra_cull_margin,"pose":node.transform,"visible":node.visible,"layers":node.layers,"shadow":node.cast_shadow,"material":node.material_override,"mesh":node.mesh if node is MeshInstance3D else null,"multimesh":node.multimesh if node is MultiMeshInstance3D else null})
	var buffer: PackedFloat32Array = game.trails.instances.buffer
	var cursor: int = game.trails.cursor
	var before: Image
	if DisplayServer.get_name() != "headless": before = root.get_texture().get_image()
	var prepared: Dictionary = Preparation.begin(game.get_node("World"),game.camera)
	var expected: bool = DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility"
	check((prepared.items > 0) == expected and prepared.items <= Preparation.MAX_ITEMS, "Night preparation is graphical Compatibility-only and bounded")
	for context: int in range(Preparation.CONTEXTS):
		Preparation.set_context(prepared,context)
		if expected:
			check(prepared.nodes[0].visible == ((context & 1) != 0) and prepared.nodes[1].visible == ((context & 2) != 0), "local light presence combination "+str(context))
		await frames(2)
	Preparation.end(prepared)
	Preparation.end(prepared)
	await frames()
	check(game.camera.transform == pose and game.camera.size == size, "camera remains exact")
	check(RewindHistory.properties(game.sim.state) == state and game.countdown_ticks == 360 and game.car_weathering.snapshot() == condition, "canonical state, countdown and condition remain exact")
	check(game.trails.instances.buffer == buffer and game.trails.cursor == cursor, "original tire GPU buffer and ring cursor remain exact")
	check(snapshots.all(func(s: Dictionary) -> bool: return s.node.extra_cull_margin == s.margin and s.node.transform == s.pose and s.node.visible == s.visible and s.node.layers == s.layers and s.node.cast_shadow == s.shadow and s.node.material_override == s.material and (not s.node is MeshInstance3D or s.node.mesh == s.mesh) and (not s.node is MultiMeshInstance3D or s.node.multimesh == s.multimesh)), "geometry, material bindings, culling and visibility remain exact")
	check(lights.all(func(s: Dictionary) -> bool: return s.node.transform == s.pose and s.node.visible == s.visible and s.node.light_energy == s.energy and s.node.light_cull_mask == s.mask and s.node.shadow_enabled == s.shadow), "original lights remain exact")
	check(game.find_children("CoveredNight*","Light3D",true,false).is_empty(), "temporary lights are released")
	if before != null:
		var after: Image = root.get_texture().get_image()
		check(before.get_data() == after.get_data(), "restored framebuffer is byte-exact")
		before.save_png(output.path_join("before.png"));after.save_png(output.path_join("after.png"))
	var cancelled: Dictionary = Preparation.begin(game.get_node("World"),game.camera)
	game.free()
	Preparation.end(cancelled)
	check(cancelled.nodes.is_empty() and cancelled.geometry.is_empty(), "destroyed-scene cleanup is safe")
	await app_checks(track,expected)
	print("NIGHT_PREPARATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func app_checks(track: NativeTrack, expected: bool) -> void:
	OS.set_environment("BMT_API_URL", "")
	var folder: String = ProjectSettings.globalize_path("res://../build/night-hitch-2026-10-14/app-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.set_script(ProbeApp)
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	track.metadata.cloud_version = "isolated-night"
	app.selected_track = track
	app._start_race(track,false,true)
	var revealed: Dictionary = {}
	app.race_loading.tree_exiting.connect(func() -> void:
		if is_instance_valid(app.game):
			revealed.tick = app.game.sim.state.tick
			revealed.countdown = app.game.countdown_ticks
			revealed.night = app.game.night_preparation.duplicate())
	var deadline: int = Time.get_ticks_msec()+40000
	while app.cloud_starting and Time.get_ticks_msec()<deadline: await process_frame
	check(is_instance_valid(app.game) and app.race_loading == null and not app.cloud_starting, "actual Night start completes")
	check(revealed.get("tick",-1) == 0 and revealed.get("countdown",-1) == 360, "actual Night cover reveals the full frozen countdown")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		check(revealed.night.drawn == expected and revealed.night.contexts == (8 if expected else 0), "actual start records weathered and clean light contexts")
		check(app.game.find_children("CoveredNight*","Light3D",true,false).is_empty(), "actual start releases the temporary lights")
		check(not app.game.car_weathering._render_warming, "actual start restores clean finish bindings")
		app._leave_race()
	if expected:
		await frames(1)
		app.cancel_night = true
		app._start_race(track,false,true)
		while app.cloud_starting and Time.get_ticks_msec()<deadline: await process_frame
		await frames(2)
		check(app.game == null and app.race_loading == null and app.root_ui.visible, "navigation during Night preparation restores menus and cancels the frozen scene")
	app.free()
	await frames(1)

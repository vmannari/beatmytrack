extends SceneTree
const NightPreparation = preload("res://track/night_render_preparation.gd")
## Exact public Night track, frozen simulation and disposable local records.
var game: Node
var rows: Array[Dictionary] = []
var draw_start: int = 0
var draw_us: int = 0
func _initialize() -> void: run.call_deferred()
func pre_draw() -> void: draw_start = Time.get_ticks_usec()
func post_draw() -> void: draw_us = Time.get_ticks_usec() - draw_start
func frames(count: int) -> void:
	for index: int in range(count): await RenderingServer.frame_post_draw
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280, 720)
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/night-hitch-2026-10-14")
	var document: Dictionary = TrackLibrary.new().import_document(ProjectSettings.globalize_path("res://../build/night-hitch-2026-10-14/track.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	game = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	game.preference_records = LocalRecords.new(ProjectSettings.globalize_path("res://../build/night-hitch-2026-10-14/disposable-records.json"))
	root.add_child(game)
	game.paused = true
	game.hitch_diagnostics.persist_enabled = false
	game.call("_process", 0.0)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var state: Dictionary = RewindHistory.properties(game.sim.state)
	var condition: Dictionary = game.car_weathering.snapshot()
	var roles: Dictionary = {}
	for node: Node in game.get_node("World").find_children("*", "MeshInstance3D", true, false):
		var material: Material = node.material_override
		if not material is ShaderMaterial: continue
		var key: String = material.shader.code.sha256_text()
		if not roles.has(key): roles[key] = {"meshes":0,"shader_ids":[],"material_ids":[],"source":material.shader.resource_path}
		roles[key].meshes += 1
		if material.shader.get_rid().get_id() not in roles[key].shader_ids: roles[key].shader_ids.append(material.shader.get_rid().get_id())
		if material.get_rid().get_id() not in roles[key].material_ids: roles[key].material_ids.append(material.get_rid().get_id())
	RenderingServer.frame_pre_draw.connect(pre_draw)
	RenderingServer.frame_post_draw.connect(post_draw)
	await frames(60)
	var preparation: Array[Dictionary] = []
	if "--warm" in OS.get_cmdline_user_args():
		var prepared: Dictionary = NightPreparation.begin(game.get_node("World"),game.camera)
		for index: int in range(NightPreparation.CONTEXTS):
			NightPreparation.set_context(prepared,index)
			var started: int = Time.get_ticks_usec()
			await frames(2)
			preparation.append({"context":index,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"last_draw_ms":draw_us/1000.0,"items":prepared.items})
		NightPreparation.end(prepared)
		await frames(4)
	var camera: Camera3D = game.camera
	var pose: Transform3D = camera.transform
	var car_pose: Transform3D = game.car.transform
	var start: Vector3 = game.car.position
	var indices: Array[int] = []
	var live: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("race-1792001705-19920-2419928861447.json")))
	for event: Dictionary in live.events:
		var index: int = event.frame.route_index
		for offset: int in [-6, 0, 6]:
			var selected: int = posmod(index + offset, track.route.size())
			if selected not in indices: indices.append(selected)
	for pass_index: int in range(2):
		for index: int in indices:
			var point: Vector2 = track.route[index]
			var shift: Vector3 = VisualGeometry.world(point) - start
			camera.transform = pose
			camera.position += shift
			game.car.transform = car_pose
			game.car.position += shift
			for frame: int in range(4):
				var started: int = Time.get_ticks_usec()
				await RenderingServer.frame_post_draw
				rows.append({"pass":pass_index,"route_index":index,"frame":frame,"frame_ms":(Time.get_ticks_usec()-started)/1000.0,"draw_ms":draw_us/1000.0})
	var report: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),"track_hash":track.content_hash,"matches_live_track":track.content_hash=="9762bcaabbc226d7f18e45769207f9e8bcd0d43e82041cc7ce0de2189e03a391","roles":roles,"rows":rows,"preparation":preparation,"canonical_exact":RewindHistory.properties(game.sim.state)==state,"condition_exact":game.car_weathering.snapshot()==condition,"countdown_ticks":game.countdown_ticks}
	var file := FileAccess.open(folder.path_join("night-probe-%d.json" % OS.get_process_id()),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	var first_max: float = 0.0
	var repeat_max: float = 0.0
	for row: Dictionary in rows:
		if row.pass == 0: first_max = maxf(first_max, row.draw_ms)
		else: repeat_max = maxf(repeat_max, row.draw_ms)
	print("NIGHT_FIRST_USE ",JSON.stringify({"matched":report.matches_live_track,"first_max_draw_ms":first_max,"repeat_max_draw_ms":repeat_max,"shader_roles":roles.size(),"preparation":preparation,"canonical_exact":report.canonical_exact,"condition_exact":report.condition_exact,"countdown":game.countdown_ticks}))
	camera.transform = pose
	game.car.transform = car_pose
	game.free()
	quit(0 if report.matches_live_track and report.canonical_exact and report.condition_exact else 1)

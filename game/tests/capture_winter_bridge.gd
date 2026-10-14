extends SceneTree
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if "--fresh-roads" in OS.get_cmdline_user_args(): NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	root.size = Vector2i(1440,900)
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "winter"
	var points: Array[Vector2] = [Vector2(-48,0),Vector2(-30,0),Vector2(30,0),Vector2(50,26),Vector2(0,42),Vector2(0,-42),Vector2(-50,-26)]
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var piece: Dictionary = RoadPieces.create("bridge" if i == 1 else "straight",a,fposmod(rad_to_deg((b-a).angle()),360),14)
		piece.length = a.distance_to(b)
		doc.pieces.append(piece)
	var result: Dictionary = RoadPieces.route_from_pieces(doc)
	if not result.ok:
		push_error(str(result))
		quit(1)
		return
	var track: NativeTrack = TrackCompiler.compile(result.document)
	var cells: PackedInt32Array = track.cells.duplicate()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	game.set("countdown_ticks",0)
	game.get("race_cues").hide()
	var sim: VehicleSimulation = game.get("sim")
	sim.reset(Vector2.ZERO,PI*0.5)
	sim.state.track_elevated = true
	game.set("previous_position",Vector2.ZERO)
	var camera: FollowCamera = game.get("camera")
	camera.follow(Vector2.ZERO,Vector2.ZERO,PI*0.5,0.0,true)
	var folder: String = "res://../docs/evidence/winter-bridges/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): folder = argument.trim_prefix("--output-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for frame: int in range(8):
		game.call("_process",0.016)
		await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"gameplay.png") == OK)
	# Wider inspection view is evidence only, never a gameplay camera change.
	game.set_process(false)
	camera.size = 48.0
	camera.position = Vector3(7,37,34)
	camera.look_at(Vector3(0,1.5,0))
	for frame: int in range(3): await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"overview.png") == OK)
	if "--approaches" in OS.get_cmdline_user_args():
		game.hud.visible = false
		for entry: bool in [true,false]:
			var focus := Vector3(-30 if entry else 30,0,0)
			camera.size = 24.0
			camera.position = focus+Vector3(0,22,18)
			camera.look_at(focus)
			for frame: int in range(3): await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(folder+("entry-bank.png" if entry else "exit-bank.png")) == OK)
	assert(cells == track.cells)
	if "--check-joins" in OS.get_cmdline_user_args():
		var near_count: int = 0
		var near_high: float = -INF
		var far_high: float = -INF
		var underpass_high: float = -INF
		var finite: bool = true
		for bank: Node in game.track_ground.find_children("WinterSnowBanks","MeshInstance3D",true,false):
			var arrays: Array = bank.mesh.surface_get_arrays(0)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				finite = finite and is_finite(vertex.x) and is_finite(vertex.y) and is_finite(vertex.z)
				if absf(vertex.z) >= 6.5 and absf(vertex.z) <= 12.5:
					if vertex.x >= -30.6 and vertex.x <= -29.8:
						near_count += 1
						near_high = maxf(near_high,vertex.y)
					if vertex.x >= -39 and vertex.x <= -35: far_high = maxf(far_high,vertex.y)
				if vertex.x >= 6.5 and vertex.x <= 12.5 and absf(vertex.z) < 6.0:
					underpass_high = maxf(underpass_high,vertex.y)
		check(near_count >= 12,"actual bridge-mouth bank samples exist")
		check(near_high <= 0.05,"bridge-mouth bank and clumps settle into ground without a raised cut face")
		check(far_high >= 0.60,"normal bank height remains away from the bridge mouth")
		check(underpass_high >= 0.60,"ground banks beneath the unrelated bridge crossing remain raised")
		check(finite,"bridge transition contains finite mesh vertices")
		check(cells == track.cells,"bridge bank changes preserve actual collision cells")
		print("WINTER_BRIDGE_JOIN_METRICS: mouth_samples=",near_count," mouth_max=",near_high," far_max=",far_high," underpass_max=",underpass_high)
		print("WINTER_BRIDGE_JOINS: ",checks," checks, ",failures," failures")
	print("WINTER_BRIDGE_CAPTURE: ",(4 if "--approaches" in OS.get_cmdline_user_args() else 2)," views saved; collision cells preserved")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

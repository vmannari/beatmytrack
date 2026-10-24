extends SceneTree
## Normal-route weather coverage: no hand-picked crest or forced gust.
var checks: int = 0
var failures: int = 0
var out: String = "res://../docs/evidence/desert-sand-gameplay-2026-10-23/"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func run() -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "desert"
	var point := Vector2(-50, -35)
	var heading: float = 0.0
	for kind: String in ["straight", "hairpin", "straight", "hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind, point, heading)
		piece.length = 100.0 if kind == "straight" else 0.0
		piece.radius = 35.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		point = pose.position
		heading = pose.heading
	var track: NativeTrack = TrackCompiler.compile(RoadPieces.route_from_pieces(doc).document)
	check(track.metadata.get("theme") == "desert", "coverage fixture compiles a valid Desert circuit")
	if track.metadata.get("theme") != "desert":
		quit(1)
		return
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 30000:
		game.set_process(false)
		game.set_physics_process(false)
		if game.preparation_complete: break
		await process_frame
		await create_timer(0.005).timeout
	check(game.desert_sand_wind != null, "ordinary creator race prepares the wind effect")
	if game.desert_sand_wind == null:
		quit(1)
		return
	var fx: DesertSandWind = game.desert_sand_wind
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var rows: Array[Dictionary] = []
	var covered: int = 0
	var starved: int = 0
	for i: int in range(80):
		var focus: Vector2 = track.route[floori(float(i) / 80.0 * track.route.size())]
		fx.present(1.0 / 60.0, focus, 0.0, false, false)
		var nearest: float = INF
		var selected: float = INF
		for source: Vector2 in fx.anchor_heights: nearest = minf(nearest, source.distance_to(focus))
		for source: Vector2 in fx.sources: selected = minf(selected, source.distance_to(focus))
		if selected < 18.0: covered += 1
		if nearest < 14.0 and selected >= 20.0: starved += 1
		rows.append({"focus": focus, "nearest_crest": nearest, "selected_distance": selected, "sources": fx.sources.size()})
	print("SAND_ROUTE_COVERAGE: covered=", covered, "/80 starved=", starved, " anchors=", fx.anchor_heights.size())
	check(starved == 0, "nearby crests are not starved by distant retained sites")
	check(covered >= 64, "ordinary road positions have nearby wind sources")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var receipt := FileAccess.open(out + "coverage.json", FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"covered": covered, "starved": starved, "anchors": fx.anchor_heights.size(), "samples": rows}, "\t"))
	receipt.close()
	if DisplayServer.get_name() != "headless": await capture(game, track, fx)
	game.queue_free()
	await process_frame
	print("DESERT_SAND_GAMEPLAY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func draw(game: Node, fx: DesertSandWind) -> void:
	game.paused = false
	game.hud.pause_menu.hide()
	game.hud.message_label.hide()
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.desert_ambience.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await RenderingServer.frame_post_draw

func capture(game: Node, track: NativeTrack, fx: DesertSandWind) -> void:
	var folder: String = out + RenderingServer.get_current_rendering_method() + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1280, 720)
	game.race_cues.hide()
	game.desert_ambience.rng.seed = 231023
	game.desert_ambience.reset()
	fx.reset()
	var distances := PackedFloat32Array([0.0])
	for i: int in range(track.route.size()):
		distances.append(distances[-1] + track.route[i].distance_to(track.route[(i + 1) % track.route.size()]))
	var frames: Array[String] = []
	var samples: Array[Dictionary] = []
	var visible_samples: int = 0
	var peak: int = 0
	for i: int in range(270):
		var distance: float = fposmod(float(i) / 15.0 * 14.0, distances[-1])
		var segment: int = mini(track.route.size() - 1, maxi(0, distances.bsearch(distance) - 1))
		var from: Vector2 = track.route[segment]
		var to: Vector2 = track.route[(segment + 1) % track.route.size()]
		var at: Vector2 = from.lerp(to, (distance - distances[segment]) / maxf(0.0001, distances[segment + 1] - distances[segment]))
		var velocity: Vector2 = (to - from).normalized() * 14.0
		game.sim.state.position = at
		game.previous_position = at
		game.sim.state.velocity = velocity
		game.sim.state.heading = atan2(velocity.x, velocity.y)
		game.previous_heading = game.sim.state.heading
		game.paused = false
		fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		game.desert_ambience.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		game.call("_process", 1.0 / 15.0)
		if i == 0: game.camera.follow(at, velocity, game.sim.state.heading, 0.0, true)
		if i % 15 == 0:
			fx.hide()
			for settle: int in range(3): await draw(game, fx)
			var before: Image = root.get_texture().get_image()
			fx.show()
			for settle: int in range(3): await draw(game, fx)
			var after: Image = root.get_texture().get_image()
			var pixels: int = 0
			for y: int in range(720):
				for x: int in range(1280):
					var a: Color = before.get_pixel(x, y)
					var b: Color = after.get_pixel(x, y)
					if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) >= 0.01: pixels += 1
			if pixels >= 1000: visible_samples += 1
			if pixels > peak:
				peak = pixels
				after.save_png(folder + "driving.png")
			samples.append({"seconds": (i + 1) / 15.0, "pixels": pixels, "wind": game.desert_ambience.strength, "strength": fx.intensity, "position": at})
		else: await draw(game, fx)
		frames.append("data:image/jpeg;base64," + Marshalls.raw_to_base64(root.get_texture().get_image().save_jpg_to_buffer(0.94)))
	check(visible_samples >= 9, "normal moving-camera weather has readable sand in at least half of route samples")
	check(peak >= 3000, "normal moving-camera weather produces a clearly readable local burst")
	print("SAND_GAMEPLAY_PIXELS: visible=", visible_samples, "/18 peak=", peak)
	var receipt := FileAccess.open(folder + "driving.json", FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"visible_samples": visible_samples, "peak_pixels": peak, "samples": samples}, "\t"))
	receipt.close()
	var preview := FileAccess.open(folder + "motion.html", FileAccess.WRITE)
	preview.store_string("<!doctype html><meta charset='utf-8'><title>Desert sand during driving</title><style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:1280px;margin:32px auto}img{width:100%}button{padding:10px}</style><p>Actual game presentation: moving driving camera and normal seeded wind; scripted route at 50 km/h</p><img id='view'><button id='toggle'>Pause</button><script>const frames=" + JSON.stringify(frames) + ";let frame=0,playing=true;view.src=frames[0];toggle.onclick=()=>{playing=!playing;toggle.textContent=playing?'Pause':'Play'};setInterval(()=>{if(playing){frame=(frame+1)%frames.length;view.src=frames[frame]}},1000/15)</script>")
	preview.close()

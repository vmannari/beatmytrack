extends SceneTree
## Full Desert deformation/partition/cache integration, including Egyptian props.
var checks: int = 0
var failures: int = 0
const OUT: String = "res://../docs/evidence/desert-visibility-regression-2026-10-24/"
var app: Node

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ", message)

func circuit() -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "desert"
	doc["automatic_scenery"] = false
	var point := Vector2(-28, -18)
	var heading: float = 0.0
	for kind: String in ["straight", "hairpin", "straight", "hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind, point, heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		point = pose.position; heading = pose.heading
	doc.objects = []
	for row: Array in [["egypt_pyramid", -38, 0], ["egypt_pyramid", 38, 0], ["egypt_obelisk", 0, 0], ["egypt_column", 15, 3], ["egypt_wall", -15, 3], ["rock", 0, 26]]:
		doc.objects.append({"kind":row[0], "position":[row[1],row[2]], "rotation":0.0, "scale":1.0})
	var routed: Dictionary = RoadPieces.route_from_pieces(doc)
	print("DOCUMENT_VALIDATION: ", TrackDocument.validate(routed.document))
	check(TrackDocument.validate(routed.document).is_empty(), "regression circuit is a valid current-format Desert document")
	return TrackCompiler.compile(routed.document)

func run() -> void:
	var track: NativeTrack = circuit()
	if track == null: quit(1); return
	var canonical: PackedByteArray = var_to_bytes([track.cells, track.deck_cells, track.route, track.metadata, track.content_hash])
	check(track.metadata.get("theme") == "desert", "compile keeps Desert biome")
	var visual := NativeTrackVisual.new()
	visual.theme_id = "desert"; visual.colors = TrackTheme.DESERT.duplicate()
	visual.preserve_relief_surfaces = true
	root.add_child(visual)
	var bridge := BridgePresentation.new(track)
	visual.ground_support = bridge.road_surface; visual.desert_relief = bridge.visual_relief
	await visual._build_placed_objects(track)
	var egypt: MeshInstance3D = visual.get_node_or_null("EgyptianStonework")
	check(egypt != null, "all authored Egyptian objects build before world preparation")
	if egypt == null: quit(1); return
	var before: int = egypt.mesh.surface_get_array_index_len(0)
	var original_mesh: Mesh = egypt.mesh
	var ends: PackedInt32Array = egypt.get_meta("spatial_object_ends")
	print("DESERT_PROP_BEFORE: corners=", before, " range_end=", ends[-1])
	check(ends[-1] == before, "source assembly ranges cover the complete prop stream")
	await visual.desert_relief.apply(visual, true)
	var after: int = egypt.mesh.surface_get_array_index_len(0)
	ends = egypt.get_meta("spatial_object_ends")
	print("DESERT_PROP_AFTER: corners=", after, " range_end=", ends[-1])
	check(ends[-1] == after, "Desert deformation preserves ordered prop assembly ranges")
	var original_script := GDScript.new()
	original_script.source_code = FileAccess.get_file_as_string(OUT + "before/desert_road_relief.gd")
	check(original_script.reload() == OK, "task-original Desert deformation compiles for exact control")
	var original_relief: RefCounted = original_script.new(track)
	var reference: Mesh = original_relief.deform(original_mesh, Transform3D.IDENTITY, true)
	check(reference.surface_get_arrays(0) == egypt.mesh.surface_get_arrays(0), "range repair preserves every original deformed vertex, index and attribute")
	# Do not enter an invalid range assertion in the downstream partitioner.
	if ends[-1] == after:
		await visual._partition_bank_meshes()
		check(not visual.find_children("EgyptianStonework*", "MeshInstance3D", true, false).is_empty(), "pyramid family remains attached after spatial preparation")
	# A stale older packet must still attach its complete source, even before
	# the deformation-side repair has had a chance to refresh its ranges.
	var stale := MeshInstance3D.new()
	stale.mesh = reference; stale.material_override = PropEgypt.material()
	stale.set_meta("spatial_object_ends", PackedInt32Array([before]))
	stale.set_meta("spatial_object_centres", PackedVector3Array([Vector3.ZERO]))
	var retained: Array[MeshInstance3D] = SpatialMeshChunks.add(visual, stale, true, false, false)
	check(retained == [stale] and stale.get_parent() == visual and stale.mesh == reference, "stale ranges retain the complete staged mesh without losing geometry")
	visual.queue_free()
	await process_frame
	var lease_test := DesertSandWind.new()
	root.add_child(lease_test); lease_test.configure(track)
	var focus := Vector2(0, -18)
	# All six are outside the shader fade including their downwind hop, but
	# inside the old radial 36m lease that exhausted the bounded source pool.
	lease_test.sources = PackedVector2Array([focus+Vector2(26,-20),focus+Vector2(30,-12),focus+Vector2(33,-4),focus+Vector2(33,4),focus+Vector2(30,12),focus+Vector2(26,20)])
	lease_test.center = (focus / DesertSandWind.SPACING).floor() * DesertSandWind.SPACING
	lease_test._place(focus)
	var nearest: float = INF
	for source: Vector2 in lease_test.sources: nearest = minf(nearest, source.distance_to(focus))
	check(nearest < 20.0, "invisible retained sites release slots for nearby driving sand")
	lease_test.queue_free(); await process_frame
	await actual_app(track)
	track.metadata.erase("cloud_version")
	check(canonical == var_to_bytes([track.cells, track.deck_cells, track.route, track.metadata, track.content_hash]), "geometry repair and complete race presentation preserve canonical track data")
	print("DESERT_VISIBILITY_REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func actual_app(track: NativeTrack) -> void:
	OS.set_environment("BMT_API_URL", "")
	# Published-track marker used by the existing offline App install fixtures.
	track.metadata.cloud_version = "desert-visibility-local-fixture"
	var folder: String = "user://desert_visibility_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	NativeTrackVisual.ROAD_DISK_CACHE.directory = folder.path_join("roads")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	NativeTrackVisual.PREPARED_WORLDS.entries.clear()
	var cold_mesh: Mesh
	for pass_index: int in range(2):
		app._show_screen("tracks")
		app.selected_track = track
		await app._start_race(track, false, true)
		check(is_instance_valid(app.game) and app.game.preparation_complete, "actual App race installation completes: " + str(pass_index))
		if not is_instance_valid(app.game): break
		var game: Node = app.game
		game.set_physics_process(false); game.set_process(false)
		check(game.track_ground != null and game.track_ground.world_built, "actual App publishes a complete Desert world: " + str(pass_index))
		var families: Array[Node] = game.track_ground.find_children("EgyptianStonework*", "MeshInstance3D", true, false)
		check(not families.is_empty(), "actual App retains pyramids and Egyptian scenery: " + str(pass_index))
		if not families.is_empty():
			if pass_index == 0: cold_mesh = families[0].mesh
			else: check(families[0].mesh == cold_mesh, "cached race retains the actual prepared pyramid mesh")
		var fx: DesertSandWind = game.desert_sand_wind
		check(fx != null and not fx.anchor_heights.is_empty(), "actual App wind retains prepared crest support: " + str(pass_index))
		check(game.process_mode == Node.PROCESS_MODE_INHERIT, "loading releases the actual race process mode")
		if DisplayServer.get_name() != "headless": await capture(game, track, pass_index)
		app._leave_race()
		await process_frame
	app.queue_free()
	await process_frame

func draw(game: Node) -> void:
	game.paused = false
	game.hud.pause_menu.hide(); game.hud.message_label.hide()
	game.desert_sand_wind.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.desert_ambience.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await RenderingServer.frame_post_draw

func capture(game: Node, track: NativeTrack, pass_index: int) -> void:
	var folder: String = OUT + RenderingServer.get_current_rendering_method() + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1280, 720)
	game.race_cues.hide()
	var families: Array[Node] = game.track_ground.find_children("EgyptianStonework*", "MeshInstance3D", true, false)
	for side: int in [-1, 1]:
		var target := Vector2(side * 38.0, 0)
		var at: Vector2 = track.route[0]
		for point: Vector2 in track.route:
			if point.distance_squared_to(target) < at.distance_squared_to(target): at = point
		game.sim.state.position = at; game.previous_position = at
		game.sim.state.velocity = Vector2.ZERO
		game.call("_process", 0.0)
		game.camera.follow(at, Vector2.ZERO, 0.0, 0.0, true)
		for settle: int in range(3): await draw(game)
		var visible_image: Image = root.get_texture().get_image()
		for family: Node3D in families: family.hide()
		for settle: int in range(3): await draw(game)
		var hidden_image: Image = root.get_texture().get_image()
		check(changes(visible_image, hidden_image) > 1000, "pyramid is actually drawn from the road: pass%d side%d" % [pass_index, side])
		visible_image.save_png(folder + "pyramid-%d-%d.png" % [pass_index, side])
		for family: Node3D in families: family.show()
	if pass_index != 1: return
	game.desert_ambience.rng.seed = 231023; game.desert_ambience.reset()
	var fx: DesertSandWind = game.desert_sand_wind
	fx.reset()
	var cumulative := PackedFloat32Array([0.0])
	for index: int in range(track.route.size()): cumulative.append(cumulative[-1] + track.route[index].distance_to(track.route[(index + 1) % track.route.size()]))
	var rows: Array[Dictionary] = []
	var visible_samples: int = 0
	var clear_samples: int = 0
	var peak: int = 0
	var clear_peak: int = 0
	for sample: int in range(18):
		for step: int in range(15):
			var distance: float = fposmod((sample + float(step) / 15.0) * 14.0, cumulative[-1])
			var index: int = clampi(cumulative.bsearch(distance) - 1, 0, track.route.size() - 1)
			var from: Vector2 = track.route[index]; var to: Vector2 = track.route[(index + 1) % track.route.size()]
			var at: Vector2 = from.lerp(to, (distance - cumulative[index]) / maxf(0.0001, cumulative[index + 1] - cumulative[index]))
			game.sim.state.position = at; game.previous_position = at; game.sim.state.velocity = (to - from).normalized() * 14.0
			game.sim.state.heading = atan2(game.sim.state.velocity.x, game.sim.state.velocity.y); game.previous_heading = game.sim.state.heading
			await draw(game)
			game.call("_process", 1.0 / 15.0)
		fx.hide()
		for settle: int in range(3): await draw(game)
		var before: Image = root.get_texture().get_image()
		fx.show()
		for settle: int in range(3): await draw(game)
		var after: Image = root.get_texture().get_image()
		var pixels: int = changes(before, after)
		var clear_pixels: int = changes(before, after, 0.02)
		if pixels >= 1000: visible_samples += 1
		if clear_pixels >= 1000: clear_samples += 1
		clear_peak = maxi(clear_peak, clear_pixels)
		if pixels > peak:
			peak = pixels
			after.save_png(folder + "sand-in-race.png")
			before.save_png(folder + "sand-hidden.png")
		rows.append({"seconds": sample + 1, "pixels": pixels, "clear_pixels": clear_pixels, "wind": game.desert_ambience.strength, "sources": fx.sources.size()})
	check(visible_samples >= 9 and peak >= 3000, "cached App race shows readable natural-wind sand along the route")
	check(clear_samples >= 9 and clear_peak >= 3000, "natural-wind sand retains clear contrast in at least half the driving samples")
	print("APP_DESERT_SAND: samples=", visible_samples, "/18 peak=", peak, " clear_samples=", clear_samples, " clear_peak=", clear_peak)
	var receipt := FileAccess.open(folder + "race.json", FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"visible_samples": visible_samples, "peak_pixels": peak, "clear_samples": clear_samples, "clear_peak": clear_peak, "samples": rows}, "\t")); receipt.close()

func changes(a: Image, b: Image, threshold: float = 0.01) -> int:
	var pixels: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var first: Color = a.get_pixel(x, y); var second: Color = b.get_pixel(x, y)
			if maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b))) >= threshold: pixels += 1
	return pixels

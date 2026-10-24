extends SceneTree
## Wind lifecycle, canonical isolation and native before/after motion evidence.
const FX = preload("res://track/desert_sand_wind.gd")
var checks: int = 0
var failures: int = 0
var out: String = "res://../docs/evidence/desert-sand-terrain-2026-10-23/"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func circuit() -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "desert"
	var point := Vector2(-28, -18)
	var heading: float = 0.0
	for kind: String in ["straight", "hairpin", "straight", "hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind, point, heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		point = pose.position
		heading = pose.heading
	return TrackCompiler.compile(RoadPieces.route_from_pieces(doc).document)

func state(fx: DesertSandWind) -> Array:
	return [fx.elapsed, fx.intensity, fx.center, fx.sources.duplicate()]

func run() -> void:
	var track: NativeTrack = circuit()
	var canonical: String = var_to_bytes([track.cells, track.deck_cells, track.route, track.metadata, track.content_hash]).hex_encode().sha256_text()
	var fx := FX.new()
	root.add_child(fx)
	fx.configure(track)
	for i: int in range(180): fx.present(1.0 / 60.0, Vector2(0, -18), 1.0, false, false)
	check(fx.plumes.multimesh.instance_count == 48 and fx.sources.size() > 0 and fx.sources.size() <= 6, "sparse patches within the bounded fine-powder pool")
	for source: Vector2 in fx.sources:
		check(track.cell_at(source) in [1, 2] and not track.has_overhead_bridge(source, false), "source is loose sand with no bridge overhead")
		for other: Vector2 in fx.sources:
			if source == other: continue
			check(source.distance_to(other) >= 8.0, "patches leave real empty ground between sources")
	var original_sites: PackedVector2Array = fx.sources.duplicate()
	var next_focus := Vector2(14, -18)
	fx.present(1.0 / 60.0, next_focus, 1.0, false, false)
	for source: Vector2 in original_sites:
		if source.distance_to(next_focus) < 20.0:
			check(fx.sources.has(source), "visible sites stay fixed when the collection cell changes")
	fx.present(1.0 / 60.0, Vector2(0, -18), 1.0, false, false)
	var before: Array = state(fx)
	fx.present(0.25, Vector2(1000, 1000), 0.0, true, false)
	check(state(fx) == before, "pause freezes clock and placement")
	fx.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	fx.present(0.25, Vector2.ZERO, 1.0, false, false)
	check(state(fx) == before, "background freezes clock and placement")
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(NAN, Vector2.ZERO, 1.0, false, false)
	fx.present(0.1, Vector2(INF, 0), 1.0, false, false)
	fx.present(0.1, Vector2.ZERO, NAN, false, false)
	check(state(fx) == before, "invalid presentation inputs are rejected")
	fx.hide()
	fx.present(0.25, Vector2.ZERO, 1.0, false, false)
	check(state(fx) == before, "hidden effect does no work")
	fx.show()
	for i: int in range(180): fx.present(1.0 / 60.0, Vector2(0, -18), 0.0, false, false)
	check(fx.intensity < float(before[1]) and fx.intensity > 0.0, "sand settles during a wind lull")
	for i: int in range(180): fx.present(1.0 / 60.0, Vector2(0, -18), 1.0, false, true)
	check(fx.intensity == 0.0, "finish fades sand away")
	fx.reset()
	check(fx.intensity == 0.0 and fx.sources.is_empty() and fx.plumes.multimesh.visible_instance_count == 0, "retry clears all local wind state")
	track.metadata.theme = "pine"
	fx.configure(track)
	check(not fx.enabled and not fx.visible, "other biomes disable sand")
	track.metadata.theme = "desert"
	fx.queue_free()
	await process_frame
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	var ready_frames: int = 0
	while game.desert_sand_wind == null and ready_frames < 600:
		await process_frame
		ready_frames += 1
		game.set_physics_process(false)
		game.set_process(false)
	check(game.desert_sand_wind != null, "cooperative race build reaches weather installation")
	if game.desert_sand_wind == null:
		game.queue_free()
		await process_frame
		quit(1)
		return
	game.race_cues.hide()
	game.paused = true
	fx = game.desert_sand_wind
	check(fx != null and fx.get_parent() == game.get_node("World"), "actual Desert race owns the effect")
	check(fx.relief == game.track_ground.desert_relief, "wind shares prepared visual ground support")
	check(not fx.anchor_heights.is_empty(), "real race powder starts on prepared exposed bank crests")
	check(fx.source_samples > 0 and fx.source_samples <= 8192 and fx.anchor_heights.size() <= 512, "crest discovery stays within its fixed work and anchor bounds")
	var simulation: Array = game.sim.state.snapshot().duplicate(true)
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	for i: int in range(240): fx.present(1.0 / 60.0, Vector2(0, -18), 1.0, false, false)
	check(game.sim.state.snapshot() == simulation, "wind leaves actual driving snapshot exact")
	if DisplayServer.get_name() != "headless": await capture(game, fx)
	game.restart()
	check(fx.elapsed == 0.0 and fx.intensity == 0.0, "actual retry resets sand")
	var released: WeakRef = weakref(fx)
	track.metadata.theme = "pine"
	game.call("_update_weather")
	await process_frame
	check(game.desert_sand_wind == null and released.get_ref() == null, "biome change frees sand resources")
	track.metadata.theme = "desert"
	check(canonical == var_to_bytes([track.cells, track.deck_cells, track.route, track.metadata, track.content_hash]).hex_encode().sha256_text(), "canonical track data remains exact")
	game.queue_free()
	await process_frame
	print("DESERT_SAND_WIND: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func capture(game: Node, fx: DesertSandWind) -> void:
	out += RenderingServer.get_current_rendering_method() + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size = Vector2i(1280, 720)
	var camera: Camera3D = game.camera
	var focus := Vector2(0, -18)
	game.sim.state.position = focus
	game.previous_position = focus
	game.paused = false
	game.call("_process", 0.0)
	camera.follow(focus, Vector2.ZERO, 0.0, 0.0, true)
	var gameplay_transform: Transform3D = camera.transform
	var gameplay_size: float = camera.size
	for i: int in range(4): await draw(game, fx)
	fx.hide()
	for i: int in range(3): await draw(game, fx)
	var baseline: Image = root.get_texture().get_image()
	check(baseline.save_png(out + "before.png") == OK, "before screenshot")
	fx.show()
	fx.reset()
	var peak: int = -1
	var quiet: int = 1000000
	var peak_time: float = 0.0
	var peak_image: Image
	var timeline: Array[Dictionary] = []
	for sample: int in range(24):
		for step: int in range(30): fx.present(1.0 / 60.0, focus, 1.0, false, false)
		for i: int in range(2): await draw(game, fx)
		var current: Image = root.get_texture().get_image()
		var changed: int = pixel_changes(baseline, current)
		timeline.append({"seconds": fx.elapsed, "changed_pixels": changed})
		if changed > peak:
			peak = changed
			peak_time = fx.elapsed
			peak_image = current
		quiet = mini(quiet, changed)
	check(peak >= 2000 and peak < 1280 * 720 * 0.08, "soft local powder is visible while most of the driving view stays clear")
	check(quiet < peak * 0.35, "independent bursts leave quiet intervals even in steady strong wind")
	check(peak_image.save_png(out + "gust.png") == OK, "peak powder screenshot")
	print("SAND_PLUME_PIXELS: peak=", peak, " quiet=", quiet, " seconds=", peak_time)
	fx.intensity = 0.30
	fx.elapsed = peak_time
	fx.present(0.000001, focus, 0.0, false, false)
	for i: int in range(3): await draw(game, fx)
	var calm: Image = root.get_texture().get_image()
	var calm_pixels: int = pixel_changes(baseline, calm)
	check(calm_pixels >= 600, "ordinary calm wind has readable powder at the normal driving zoom")
	check(calm.save_png(out + "calm.png") == OK, "ordinary wind screenshot")
	print("SAND_CALM_PIXELS: ", calm_pixels)
	var receipt := FileAccess.open(out + "timeline.json", FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"peak_pixels": peak, "quiet_pixels": quiet, "calm_pixels": calm_pixels, "peak_seconds": peak_time, "sources": fx.sources, "samples": timeline}, "\t"))
	receipt.close()
	fx.intensity = 0.95
	fx.elapsed = peak_time
	fx.present(0.000001, focus, 1.0, false, false)
	await occlusion(game, fx, focus)
	# Aim the detail camera at the patch that actually emitted in this frame;
	# cosmetic shader phases need not match between GL and Vulkan hardware.
	var centroid := Vector2.ZERO
	for y: int in range(720):
		for x: int in range(1280):
			if baseline.get_pixel(x, y) != peak_image.get_pixel(x, y): centroid += Vector2(x, y)
	centroid /= maxi(1, peak)
	var detail_focus: Vector2 = fx.sources[0] + DesertSandWind.WIND * 2.0
	var nearest_pixel: float = INF
	for source: Vector2 in fx.sources:
		var screen: Vector2 = camera.unproject_position(VisualGeometry.world(source + DesertSandWind.WIND * 2.0))
		if screen.distance_squared_to(centroid) < nearest_pixel:
			nearest_pixel = screen.distance_squared_to(centroid)
			detail_focus = source + DesertSandWind.WIND * 2.0
	camera.position = VisualGeometry.world(detail_focus) + Vector3(0, 18, 13)
	camera.look_at(VisualGeometry.world(detail_focus))
	camera.size = 14.0
	fx.hide()
	for i: int in range(3): await draw(game, fx)
	var detail_base: Image = root.get_texture().get_image()
	fx.show()
	for i: int in range(3): await draw(game, fx)
	check(pixel_changes(detail_base, root.get_texture().get_image()) > 100, "detail camera shows the patch that actually emitted")
	check(root.get_texture().get_image().save_png(out + "detail.png") == OK, "closer overhead sand view")
	await palette_probe(game, fx)
	var frames: Array[String] = []
	camera.transform = gameplay_transform
	camera.size = gameplay_size
	fx.elapsed = peak_time - 0.5
	fx.present(0.000001, focus, 1.0, false, false)
	for i: int in range(3): await draw(game, fx)
	for frame: int in range(90):
		fx.present(1.0 / 15.0, focus, 1.0 if frame < 45 else 0.0, false, false)
		await draw(game, fx)
		frames.append("data:image/jpeg;base64," + Marshalls.raw_to_base64(root.get_texture().get_image().save_jpg_to_buffer(0.94)))
	var preview := FileAccess.open(out + "motion.html", FileAccess.WRITE)
	preview.store_string("<!doctype html><meta charset='utf-8'><title>Desert sand reference revision</title><style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:1280px;margin:32px auto}img{width:100%}button{padding:10px}</style><p>Desert sand - actual Godot frames at the normal driving zoom; gust then ordinary wind</p><img id='view'><button id='toggle'>Pause</button><script>const frames=" + JSON.stringify(frames) + ";let frame=0,playing=true;view.src=frames[0];toggle.onclick=()=>{playing=!playing;toggle.textContent=playing?'Pause':'Play'};setInterval(()=>{if(playing){frame=(frame+1)%frames.length;view.src=frames[frame]}},1000/15)</script>")
	preview.close()

func pixel_changes(before: Image, after: Image) -> int:
	var count: int = 0
	for y: int in range(before.get_height()):
		for x: int in range(before.get_width()):
			if before.get_pixel(x, y) != after.get_pixel(x, y): count += 1
	return count

func palette_probe(game: Node, fx: DesertSandWind) -> void:
	# Neutral ground under the actual Desert light isolates powder colour from
	# the already warm dune artwork. Only this disposable fixture is changed.
	var original_ground: Node3D = game.track_ground
	var original_car: Node3D = game.car
	var sun_veil: Node3D = game.cloud_shadow
	var veil_was_visible: bool = sun_veil != null and sun_veil.visible
	if sun_veil != null: sun_veil.hide()
	original_ground.hide()
	original_car.hide()
	var floor_node := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(400, 400)
	floor_node.mesh = mesh
	floor_node.position.y = -0.02
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.22, 0.22, 0.22)
	floor_node.material_override = mat
	game.get_node("World").add_child(floor_node)
	fx.hide()
	for i: int in range(3): await draw(game, fx)
	var base: Image = root.get_texture().get_image()
	fx.show()
	for i: int in range(3): await draw(game, fx)
	var powder: Image = root.get_texture().get_image()
	var pixels: int = 0
	var colour := Color(0, 0, 0, 0)
	var saturation: float = 0.0
	var bright_specks: int = 0
	var contrast: Array[float] = []
	for y: int in range(720):
		for x: int in range(1280):
			var before: Color = base.get_pixel(x, y)
			var after: Color = powder.get_pixel(x, y)
			var delta: float = maxf(absf(after.r - before.r), maxf(absf(after.g - before.g), absf(after.b - before.b)))
			if delta < 0.008: continue
			pixels += 1
			colour += after
			saturation += after.s
			contrast.append(delta)
			if after.r > 0.88 and after.s > 0.35: bright_specks += 1
	contrast.sort()
	var p99: float = contrast[mini(contrast.size() - 1, floori(contrast.size() * 0.99))] if not contrast.is_empty() else 1.0
	var mean_saturation: float = saturation / maxi(1, pixels)
	# Compare the requested warm terrain hue while retaining the accepted
	# mutedness, soft-contrast and bright-core limits.
	var mean_colour: Color = colour / maxi(1, pixels)
	var hue_error: float = absf(wrapf(mean_colour.h - TrackTheme.DESERT[2].h, -0.5, 0.5))
	check(pixels > 1000 and mean_saturation < 0.16 and hue_error < 0.04, "actual powder shares the warm terrain hue without saturated cores")
	check(bright_specks == 0 and p99 < 0.20, "soft powder contains no bright yellow specks or hard opaque cores")
	check(powder.save_png(out + "palette.png") == OK, "native muted-powder palette fixture")
	var receipt := FileAccess.open(out + "palette.json", FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"pixels": pixels, "mean_saturation": mean_saturation, "mean_rgb": mean_colour, "terrain_hue_error": hue_error, "bright_specks": bright_specks, "contrast_p99": p99}, "\t"))
	receipt.close()
	print("SAND_PALETTE: ", pixels, " pixels saturation=", mean_saturation, " bright=", bright_specks, " contrast_p99=", p99)
	floor_node.queue_free()
	original_ground.show()
	original_car.show()
	if sun_veil != null: sun_veil.visible = veil_was_visible
	await process_frame

func draw(game: Node, fx: DesertSandWind) -> void:
	# The desktop OS may focus the chat during capture. A pause menu contains
	# a frozen world screenshot, which cannot measure the current effect.
	game.paused = false
	game.hud.pause_menu.hide()
	game.hud.message_label.hide()
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await RenderingServer.frame_post_draw

func occlusion(game: Node, fx: DesertSandWind, focus: Vector2) -> void:
	var nearest: Vector2 = fx.sources[0]
	for source: Vector2 in fx.sources:
		if source.distance_squared_to(focus) < nearest.distance_squared_to(focus): nearest = source
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 2.0, 2.0)
	box.mesh = mesh
	box.position = VisualGeometry.world(nearest + DesertSandWind.WIND * 2.0) + Vector3.UP
	box.material_override = VisualGeometry.material(Color(0.25, 0.25, 0.25))
	# Isolate the roof above the maximum loft. Powder in front of a low box's
	# side is physically visible and must not count as opaque overpainting.
	var roof := MeshInstance3D.new()
	var roof_mesh := PlaneMesh.new()
	roof_mesh.size = Vector2(2.0, 2.0)
	roof.mesh = roof_mesh
	roof.position.y = 1.003
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.0, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	roof.material_override = mat
	box.add_child(roof)
	game.get_node("World").add_child(box)
	fx.hide()
	for i: int in range(3): await draw(game, fx)
	var baseline: Image = root.get_texture().get_image()
	fx.show()
	for i: int in range(3): await draw(game, fx)
	var lifted: Image = root.get_texture().get_image()
	var samples: int = 0
	var overpainted: int = 0
	var polygon := PackedVector2Array()
	for corner: Vector3 in [Vector3(-0.65, 0, -0.65), Vector3(0.65, 0, -0.65), Vector3(0.65, 0, 0.65), Vector3(-0.65, 0, 0.65)]:
		polygon.append(game.camera.unproject_position(roof.to_global(corner)))
	for y: int in range(720):
		for x: int in range(1280):
			# Projected roof interior is independent of renderer fog/tonemapping.
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
				samples += 1
				if baseline.get_pixel(x, y) != lifted.get_pixel(x, y): overpainted += 1
	check(lifted.save_png(out + "occlusion.png") == OK, "opaque roof depth fixture")
	print("SAND_OPAQUE_SAMPLES: ", samples, " changed=", overpainted)
	check(samples > 100 and overpainted == 0, "wind cannot overpaint an opaque roof above its loft")
	box.queue_free()
	await process_frame

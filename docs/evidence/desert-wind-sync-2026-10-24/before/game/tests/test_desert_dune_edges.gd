extends "res://tests/test_desert_visibility_regression.gd"
const EDGES = preload("res://track/desert_dune_edges.gd")
const EVIDENCE: String = "res://../docs/evidence/desert-dune-edges-2026-10-24/"

func _initialize() -> void:
	capture_out = EVIDENCE
	super._initialize()

func actual_app(track: NativeTrack) -> void:
	check(FileAccess.get_sha256("res://assets/textures/desert_sand_v2.png") == EDGES.SOURCE_SHA256, "edge guides match the exact visible artwork")
	var fx := DesertSandWind.new()
	root.add_child(fx); fx.configure(track)
	var valid_roots: bool = true
	var attached: bool = true
	var stable: bool = true
	var covered: int = 0
	for index: int in range(80):
		var focus: Vector2 = track.route[index * track.route.size() / 80]
		var previous: Dictionary = fx.anchor_roots.duplicate()
		fx.present(0.1, focus, 0.0, false, false)
		var nearest: float = INF
		for source: Vector2 in fx.sources:
			nearest = minf(nearest, source.distance_to(focus))
			if previous.has(source): stable = stable and previous[source] == fx.anchor_roots[source]
			var roots: PackedVector3Array = fx.anchor_roots[source]
			for puff: int in range(8):
				var at: Vector3 = roots[puff]
				var uv := Vector2(fposmod(at.x / EDGES.TILE, 1.0), fposmod(at.z / EDGES.TILE, 1.0))
				var found: bool = false
				for guide: Array in EDGES.ROOTS:
					if Vector2(guide[puff]).distance_to(uv) < 0.00001: found = true; break
				valid_roots = valid_roots and found
				attached = attached and absf(at.y - fx.ground_height - 0.025) < 0.00001
				attached = attached and track.cell_at(Vector2(at.x, -at.z)) in [1, 2] and not track.has_overhead_bridge(Vector2(at.x, -at.z), false)
				# The headless dummy renderer has no MultiMesh transform buffer.
				if DisplayServer.get_name() != "headless":
					var actual: Vector3 = fx.plumes.multimesh.get_instance_transform(fx.sources.find(source) * 8 + puff).origin
					valid_roots = valid_roots and actual.distance_to(at) < 0.00001
		if nearest < 20.0: covered += 1
	check(valid_roots, "every emitted particle root uses the artwork's exact repeated XZ/28 edge coordinates")
	check(attached, "birth roots stay on exposed loose ground without an initial airborne gap")
	check(stable, "retained visible sites preserve each individual root when camera cells change")
	check(covered >= 64, "edge-constrained sources remain near at least 80 percent of road positions")
	check(fx.anchor_heights.size() <= 512 and fx.source_samples <= 8192, "local guide discovery remains bounded on moving routes")
	print("DUNE_EDGE_COVERAGE: ", covered, "/80 roots=", EDGES.ROOTS.size() * 8)
	fx.queue_free(); await process_frame
	if DisplayServer.get_name() != "headless": await atlas_capture()
	await super.actual_app(track)

func atlas_capture() -> void:
	var previous_scale: Vector2i = root.content_scale_size
	root.content_scale_size = Vector2i(900, 900)
	root.size = Vector2i(900, 900)
	var guide_view := Control.new()
	root.add_child(guide_view)
	guide_view.draw.connect(func() -> void:
		guide_view.draw_texture_rect(NativeTrackVisual.DUNE_ALBEDO, Rect2(0, 0, 900, 900), false)
		for guide: Array in EDGES.ROOTS:
			for uv: Vector2 in guide:
				guide_view.draw_circle(uv * 900.0, 3.0, Color.WHITE)
				guide_view.draw_circle(uv * 900.0, 1.5, Color(0.8, 0.08, 0.05)))
	guide_view.queue_redraw()
	for settle: int in range(3): await RenderingServer.frame_post_draw
	var folder: String = EVIDENCE + RenderingServer.get_current_rendering_method() + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	check(root.get_texture().get_image().save_png(folder + "texture-roots.png") == OK, "actual artwork with emission-root overlay saved")
	guide_view.queue_free(); await process_frame
	root.content_scale_size = previous_scale

func capture(game: Node, track: NativeTrack, pass_index: int) -> void:
	var fx: DesertSandWind = game.desert_sand_wind
	var exposed: bool = true
	for roots: PackedVector3Array in fx.anchor_roots.values():
		for at: Vector3 in roots:
			var point := Vector2(at.x, -at.z)
			exposed = exposed and fx.source_surface.clear(point)
			exposed = exposed and absf(at.y - fx.ground_height - fx.relief.height(point) - 0.025) < 0.00001
	check(exposed, "actual cold/cached race roots avoid geometry that covers the dune artwork")
	await super.capture(game, track, pass_index)

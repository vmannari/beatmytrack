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
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	var cells: PackedInt32Array = track.cells.duplicate()
	var deck: PackedInt32Array = track.deck_cells.duplicate()
	var tufts := GrassTufts.new()
	tufts.audit_placements = true
	root.add_child(tufts)
	tufts.build(track,TrackTheme.PINE[1])
	var repeat := GrassTufts.new()
	repeat.audit_placements = true
	repeat.build(track,TrackTheme.PINE[1])
	check(tufts.tuft_count > 0,"grass clusters generated")
	check(tufts.tuft_count == repeat.tuft_count,"stable presentation density")
	var clear: bool = true
	var stable: bool = true
	var bounded: bool = true
	var shadows_off: bool = true
	# The headless dummy renderer does not retain MultiMesh transform buffers.
	# Audit the exact submitted placements there, and read GPU buffers in capture.
	for i: int in range(tufts.placements.size()):
		var pose: Transform3D = tufts.placements[i]
		clear = clear and GrassTufts._clear(track,Vector2(pose.origin.x,-pose.origin.z))
		stable = stable and pose == repeat.placements[i]
	for chunk: MultiMeshInstance3D in tufts.get_children():
		var other: MultiMeshInstance3D = repeat.get_child(chunk.get_index())
		var batch: MultiMesh = chunk.multimesh
		bounded = bounded and batch.instance_count <= 480 and batch.mesh.get_faces().size()/3 <= 14
		shadows_off = shadows_off and chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i: int in range(batch.instance_count):
			if DisplayServer.get_name() == "headless": break
			var pose: Transform3D = batch.get_instance_transform(i)
			var point: Vector3 = chunk.position+pose.origin
			clear = clear and GrassTufts._clear(track,Vector2(point.x,-point.z))
			stable = stable and pose == other.multimesh.get_instance_transform(i)
	check(clear,"every whole tuft footprint excludes roads, water, barriers and bridge decks")
	check(stable,"identical track produces identical tuft transforms")
	check(bounded,"batches <=480 tufts; five variants <=14 triangles")
	check(shadows_off,"all tuft shadow casting disabled")
	check(track.cells == cells and track.deck_cells == deck,"canonical ground/deck cells preserved")
	for theme: String in TrackTheme.IDS:
		var visual := NativeTrackVisual.new()
		visual.theme_id = theme
		var material := ShaderMaterial.new()
		material.shader = preload("res://track/ground.gdshader")
		visual._bind_grass(material)
		check(material.get_shader_parameter("hybrid_grass") == (theme in ["pine","storm"]),theme+" material isolation")
		visual.free()
	for texture: Texture2D in [NativeTrackVisual.GRASS_ALBEDO,NativeTrackVisual.GRASS_MACRO,NativeTrackVisual.GRASS_NORMAL]:
		check(texture.get_image().has_mipmaps(),"grass map has filtering mip chain")
	print("GRASS_BUDGET: %d tufts in %d spatial batches across fixture" % [tufts.tuft_count,tufts.get_child_count()])
	tufts.queue_free()
	repeat.free()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		var game: Node = load("res://core/game.tscn").instantiate()
		game.set("initial_track",track)
		game.set("production_mode",true)
		root.add_child(game)
		game.set_physics_process(false)
		game.set("paused",true)
		(game.get("race_cues") as Control).hide()
		for frame: int in range(8):
			game.call("_process",0.0)
			await RenderingServer.frame_post_draw
		var folder: String = "res://../docs/evidence/grass"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		check(root.get_texture().get_image().save_png(folder+"/hybrid-driving.png") == OK,"gameplay grass evidence saved")
		var visible_tufts: int = _visible_tufts(game,game.get("camera"))
		print("GRASS_VIEW: %d tuft origins inside driving viewport (not GPU timing)" % visible_tufts)
		# Dedicated close review camera; production camera configuration is untouched.
		var camera: Camera3D = game.get("camera")
		var focus: Vector3 = VisualGeometry.world(track.spawn)+Vector3(-8,0,0)
		camera.position = focus+Vector3(0,8,6)
		camera.look_at(focus)
		camera.size = 9.0
		game.set_process(false)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/hybrid-detail.png") == OK,"grass detail evidence saved")
		game.queue_free()
		await process_frame
	print("GRASS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _visible_tufts(node: Node, camera: Camera3D) -> int:
	var count: int = 0
	if node is GrassTufts:
		for chunk: MultiMeshInstance3D in node.get_children():
			for i: int in range(chunk.multimesh.instance_count):
				var point: Vector3 = chunk.global_transform*chunk.multimesh.get_instance_transform(i).origin
				if not camera.is_position_behind(point) and Rect2(Vector2.ZERO,Vector2(root.size)).has_point(camera.unproject_position(point)):
					count += 1
	else:
		for child: Node in node.get_children(): count += _visible_tufts(child,camera)
	return count

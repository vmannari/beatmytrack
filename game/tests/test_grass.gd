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
	var capture_track: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track="): capture_track = argument.trim_prefix("--track=")
	if not capture_track.is_empty():
		var document: Dictionary = TrackLibrary.new().load_document(capture_track)
		check(not document.is_empty(),"requested comparison track exists")
		if document.is_empty(): quit(1); return
		track = TrackCompiler.compile(document)
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
		if "--screen=static" in OS.get_cmdline_user_args():
			var folder: String = "res://../docs/evidence/grass-static"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			game.set_process(false)
			var cloud: Node = game.get("cloud_shadow")
			if cloud != null: cloud.set("visible",false)
			var probe = preload("res://diagnostics/surface_material_probe.gd").new()
			probe.collect(game.get("track_ground"))
			check(probe.grass_roots.is_empty(),"no generated grass blades in race scene")
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var before: Image = root.get_texture().get_image()
			check(before.save_png(folder+"/static-driving.png") == OK,"static meadow evidence saved")
			await create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			var after: Image = root.get_texture().get_image()
			check(after.save_png(folder+"/static-after.png") == OK,"later static meadow evidence saved")
			_check_static_pixels(before,after,game.get("camera"),track)
			game.queue_free()
			await process_frame
			print("GRASS: %d checks, %d failures" % [checks,failures])
			quit(1 if failures else 0)
			return
		var folder: String = "res://../docs/evidence/grass"
		if not capture_track.is_empty(): folder += "/"+capture_track.validate_filename()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		check(root.get_texture().get_image().save_png(folder+"/hybrid-driving.png") == OK,"gameplay grass evidence saved")
		var visible_tufts: int = _visible_tufts(game,game.get("camera"))
		print("GRASS_VIEW: %d tuft origins inside driving viewport (not GPU timing)" % visible_tufts)
		var probe = preload("res://diagnostics/surface_material_probe.gd").new()
		probe.collect(game.get("track_ground"))
		check(probe.grass_roots.is_empty(),"no generated grass blades in race scene")
		for mode: String in ["grass_original","grass_material","baseline"]:
			probe.apply(mode)
			await RenderingServer.frame_post_draw
			for grass: GrassTufts in probe.grass_roots:
				check(grass.visible == (mode == "baseline"),"comparison toggles only intended grass geometry")
			for entry: Dictionary in probe.entries:
				var active: ShaderMaterial = entry.mesh.material_override
				check(active.get_shader_parameter("hybrid_grass") == (mode != "grass_original"),"comparison restores intended grass material")
			check(root.get_texture().get_image().save_png(folder+"/"+mode+"-driving.png") == OK,"grass comparison evidence saved")
		probe.restore()
		# Dedicated close review camera; production camera configuration is untouched.
		var camera: Camera3D = game.get("camera")
		var focus: Vector3 = VisualGeometry.world(track.spawn)+Vector3(-8,0,0)
		camera.position = focus+Vector3(0,8,6)
		camera.look_at(focus)
		camera.size = 9.0
		game.set_process(false)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/hybrid-detail.png") == OK,"grass detail evidence saved")
		# Review actual wheel-driven debris in the rendered meadow, at driving
		# scale and a separate detail camera. Simulation and production camera stay untouched.
		var debris := SandDust.new()
		game.add_child(debris)
		var review_car := CarVisual.new()
		game.add_child(review_car)
		var state := VehicleState.new()
		state.velocity = Vector2(5,14)
		state.yaw_rate = 0.7
		var grass_position: Vector2 = track.spawn+Vector2(-8,0)
		var review_folder: String = "res://../docs/evidence/grass-clippings"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(review_folder))
		for view: String in ["driving","detail"]:
			debris.clear()
			camera.size = 28.0 if view == "driving" else 10.0
			for tick: int in range(60):
				state.position = grass_position + Vector2(0,-4+tick*0.08)
				debris.sample(state,DriveFrame.new(),track)
				review_car.present(state.position,0.0,state,DriveFrame.new())
				focus = VisualGeometry.world(state.position)
				camera.position = focus+Vector3(0,18,13)
				camera.look_at(focus)
				await create_timer(1.0/60.0).timeout
				await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(review_folder+"/"+view+".png") == OK,"clipping "+view+" evidence saved")
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

func _check_static_pixels(before: Image, after: Image, camera: Camera3D, track: NativeTrack) -> void:
	var samples: Array[int] = [0,0]
	var changed: Array[int] = [0,0]
	# Sample the uncluttered central viewport; classify by canonical surface.
	for y: int in range(180,480,3):
		for x: int in range(300,980,3):
			var pixel := Vector2(x,y)
			var origin: Vector3 = camera.project_ray_origin(pixel)
			var ray: Vector3 = camera.project_ray_normal(pixel)
			var world: Vector3 = origin-ray*(origin.y/ray.y)
			var point := Vector2(world.x,-world.z)
			var kind: int = track.cell_at(point)
			if kind not in [0,1]: continue
			if track.cell_at(point+Vector2(0.7,0)) != kind or track.cell_at(point-Vector2(0.7,0)) != kind: continue
			if track.cell_at(point+Vector2(0,0.7)) != kind or track.cell_at(point-Vector2(0,0.7)) != kind: continue
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			samples[kind] += 1
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > 0.02: changed[kind] += 1
	print("STATIC_PIXELS grass=%d/%d road=%d/%d" % [changed[1],samples[1],changed[0],samples[0]])
	check(samples[1] > 100 and changed[1] == 0,"owner-requested static grass stays still at driving scale")
	check(samples[0] > 100 and changed[0] < samples[0]*0.01,"road interior remains still")

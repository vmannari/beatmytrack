extends SceneTree
## Task-owned captures; does not overwrite historical desert evidence or player saves.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1600,900)
	var stage: String = "after"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="): stage = argument.trim_prefix("--stage=").validate_filename()
	var folder: String = "res://../docs/evidence/desert-refinement-2026-10-12/"+stage+"/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): folder = argument.trim_prefix("--evidence-root=").trim_suffix("/")+"/"+stage+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var doc: Dictionary = TrackLibrary.new().load_document("track_3e26605a8a90165e")
	if doc.is_empty(): doc = TrackDocument.create_default()
	doc.theme = "desert"
	var track: NativeTrack = TrackCompiler.compile(doc)
	var cells: PackedInt32Array = track.cells.duplicate()
	var hash_before: String = track.content_hash
	var race: Node = load("res://core/game.tscn").instantiate()
	race.initial_track = track
	race.production_mode = true
	root.add_child(race)
	race.set_physics_process(false)
	race.set("countdown_ticks",0)
	(race.get("race_cues") as Control).hide()
	var camera: FollowCamera = race.get("camera")
	var sim: VehicleSimulation = race.get("sim")
	if stage != "before":
		var visual: NativeTrackVisual = race.get("track_ground")
		assert(int(visual.get_meta("desert_clod_count",0)) > 0 and int(visual.get_meta("desert_clod_count",0)) <= 600)
		var bank_vertices: int = 0
		var toes: int = 0
		for mesh: Node in visual.get_children():
			if not mesh is MeshInstance3D or not mesh.mesh is ArrayMesh: continue
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				if arrays[Mesh.ARRAY_TEX_UV] == null: continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				for i: int in range(vertices.size()):
					if uvs[i].x >= -0.5: continue
					bank_vertices += 1
					assert(vertices[i].y <= 0.28 and vertices[i].y >= -0.026)
					assert(track.cell_at(Vector2(vertices[i].x,-vertices[i].z)) != 0,"sand bank encroaches on structural road")
					if vertices[i].y < -0.019: toes += 1
		assert(bank_vertices > 0 and toes > 0)
		print("DESERT_BANK_GEOMETRY: ",bank_vertices," vertices; low crowns, buried feet and road clearance checked")
	for fraction: float in [0.0,0.35,0.70]:
		var index: int = int(track.route.size()*fraction)
		var direction: Vector2 = (track.route[(index+1)%track.route.size()]-track.route[index]).normalized()
		sim.state.position = track.route[index]
		sim.state.heading = atan2(direction.x,direction.y)
		sim.state.velocity = Vector2.ZERO
		race.set("previous_position",sim.state.position)
		race.set("previous_heading",sim.state.heading)
		camera.follow(sim.state.position,Vector2.ZERO,sim.state.heading,0.0,true)
		for frame: int in range(8):
			if race.get("paused"): race.call("toggle_pause")
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder+"route-"+str(int(fraction*100))+".png") == OK)
		if fraction == 0.35:
			race.set_process(false)
			var size_before: float = camera.size
			camera.size *= 0.65
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(folder+"bank-detail.png") == OK)
			camera.size = size_before
			race.set_process(true)
	var effect: SandDust = race.get("sand_dust")
	var drive_index: int = int(track.route.size()*0.35)
	var drive_along: float = 0.0
	for frame: int in range(150):
		if race.get("paused"): race.call("toggle_pause")
		drive_along += 0.12
		while drive_along > track.route[drive_index].distance_to(track.route[(drive_index+1)%track.route.size()]):
			drive_along -= track.route[drive_index].distance_to(track.route[(drive_index+1)%track.route.size()])
			drive_index = (drive_index+1)%track.route.size()
		var direction: Vector2 = (track.route[(drive_index+1)%track.route.size()]-track.route[drive_index]).normalized()
		sim.state.velocity = direction*10.0
		sim.state.position = track.route[drive_index]+direction*drive_along
		sim.state.heading = atan2(direction.x,direction.y)
		race.set("previous_position",sim.state.position)
		race.set("previous_heading",sim.state.heading)
		effect.sample(sim.state,DriveFrame.sample(0,1,0),track)
		(race.get("trails") as SkidTrails).sample(sim.state,DriveFrame.sample(0,1,0),null,track)
		camera.follow(sim.state.position,sim.state.velocity,sim.state.heading,0.016,true)
		await create_timer(0.016).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"driving-dust.png") == OK)
	effect._stop()
	sim.state.velocity = Vector2.ZERO
	for frame: int in range(140):
		effect._stop()
		await create_timer(0.016).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"settled-dust.png") == OK)
	assert(cells == track.cells and hash_before == track.content_hash)
	print("DESERT_REFINEMENT_CAPTURE: ",stage," six views; canonical cells/hash unchanged; piles=",race.get("track_ground").get_meta("desert_clod_count",0))
	race.queue_free()
	await process_frame
	quit()

extends SceneTree
## Matched presentation witness; fixed document and no player/account writes.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var stage: String = "after"
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--before": stage = "before"
	if stage == "before":
		var source: GDScript = load("res://vehicle/sand_dust.gd")
		source.source_code = FileAccess.get_file_as_string("res://../docs/evidence/desert-rally-dust-2026-10-25/before/sand_dust.gd.txt")
		assert(source.reload() == OK)
	root.size = Vector2i(1600,900)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dust_cloud.json"))
	document.theme = "desert"
	var track: NativeTrack = TrackCompiler.compile(document)
	var race: Node = load("res://core/game.tscn").instantiate()
	race.initial_track = track
	race.production_mode = true
	root.add_child(race)
	race.set_physics_process(false)
	race.set_process(false)
	race.countdown_ticks = 0
	race.race_cues.hide()
	var state: VehicleState = race.sim.state
	var folder: String = "res://../docs/evidence/desert-rally-dust-2026-10-25/matched/"+stage+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var route_index: int = int(track.route.size()*0.35)
	var along: float = 0.0
	for frame: int in range(240):
		along += 10.0/30.0
		while along > track.route[route_index].distance_to(track.route[(route_index+1)%track.route.size()]):
			along -= track.route[route_index].distance_to(track.route[(route_index+1)%track.route.size()])
			route_index = (route_index+1)%track.route.size()
		var direction: Vector2 = (track.route[(route_index+1)%track.route.size()]-track.route[route_index]).normalized()
		state.position = track.route[route_index]+direction*along
		state.heading = atan2(direction.x,direction.y)
		state.velocity = direction*10.0
		race.previous_position = state.position
		race.previous_heading = state.heading
		race.paused = false
		race.call("_process",0.0)
		race.sand_dust.sample(state,DriveFrame.sample(0,1,0),track,race.bridge_presentation)
		race.camera.follow(state.position,state.velocity,state.heading,1.0/30.0,true)
		await create_timer(1.0/30.0).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"driving.png") == OK)
	var snapshot: Array = state.snapshot()
	race.sand_dust._stop()
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"fade.png") == OK)
	assert(snapshot == state.snapshot())
	print("RALLY_DUST_CAPTURE ",stage," two views; canonical state unchanged")
	race.free()
	quit()

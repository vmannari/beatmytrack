extends SceneTree
## Scripted per-wheel presentation samples, with a frozen race and no dust.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1600,900)
	var folder: String = "res://../docs/evidence/desert-tire-marks-2026-10-13/after/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = "desert"
	doc.objects = []
	doc["automatic_scenery"] = false
	var road: Dictionary = RoadPieces.create("straight",Vector2(-28,0),0.0,12.0)
	road.length = 56.0
	doc.pieces = [road]
	var track: NativeTrack = TrackCompiler.compile(doc)
	var cells: PackedInt32Array = track.cells.duplicate()
	var content: String = track.content_hash
	var race: Node = load("res://core/game.tscn").instantiate()
	race.initial_track = track
	race.production_mode = true
	# Frozen screenshots are not live race pacing samples.
	race.hitch_diagnostics_enabled = false
	root.add_child(race)
	race.set_physics_process(false)
	race.set_process(false)
	race.countdown_ticks = 0
	race.race_cues.hide()
	var trails: SkidTrails = race.trails
	var camera: FollowCamera = race.camera
	var canonical_state: VehicleState = race.sim.state
	var canonical_before: Array = canonical_state.snapshot()
	var state := VehicleState.new()
	race.sim.state = state
	for profile: String in ["rolling","braking","loose-sand"]:
		trails.clear()
		var drive: DriveFrame = DriveFrame.sample(0,0,0.75 if profile == "braking" else 0.0)
		for i: int in range(100):
			var t: float = float(i)/99.0
			var p := Vector2(-18.0+t*36.0, (9.0 if profile == "loose-sand" else 0.0)+sin(t*PI)*1.5)
			var tangent := Vector2(36.0,cos(t*PI)*PI*1.5).normalized()
			state.position = p
			state.velocity = tangent*16.0
			state.heading = atan2(tangent.x,tangent.y)
			state.yaw_rate = 0.0
			state.tire_dirt = 0.0
			trails.sample(state,drive,null,track)
		assert(trails.instances.visible_instance_count > 100)
		race.previous_position = state.position
		race.previous_heading = state.heading
		race.call("_process",0.0)
		camera.follow(Vector2(1,4 if profile == "loose-sand" else 0),Vector2.ZERO,PI*0.5,0.0,true)
		for frame: int in range(10): await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder+profile+".png") == OK)
		print("DESERT_TIRE_MARK_CAPTURE: ",profile," segments=",trails.instances.visible_instance_count," first_tint=",trails.mark_colors[0])
		trails.visible = false
		for frame: int in range(3): await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder+profile+"-surface.png") == OK)
		trails.visible = true
	race.sim.state = canonical_state
	assert(canonical_state.snapshot() == canonical_before and track.cells == cells and track.content_hash == content)
	print("DESERT_TIRE_MARK_CAPTURE: six views; canonical snapshot/cells/hash preserved; scripted cosmetic samples")
	race.queue_free()
	await process_frame
	quit()

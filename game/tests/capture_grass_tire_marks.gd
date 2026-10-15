extends SceneTree
## Matched native grass/road colour review using this task's saved renderer.
const OUTPUT: String = "res://../docs/evidence/grass-tire-colour-2026-10-14"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1600,900)
	var folder: String = OUTPUT+"/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var document: Dictionary = TrackDocument.create_blank()
	document.theme = "pine"
	document.objects = []
	document["automatic_scenery"] = false
	var road: Dictionary = RoadPieces.create("straight",Vector2(-28,0),0.0,12.0)
	road.length = 56.0
	document.pieces = [road]
	var track: NativeTrack = TrackCompiler.compile(document)
	var cells: PackedInt32Array = track.cells.duplicate()
	var content: String = track.content_hash
	var race: Node = load("res://core/game.tscn").instantiate()
	race.initial_track = track
	race.production_mode = true
	race.hitch_diagnostics_enabled = false
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	race.countdown_ticks = 0
	race.race_cues.hide()
	race.sand_dust.hide()
	if race.cloud_shadow != null: race.cloud_shadow.hide()
	race.camera.speed_zoom_enabled = false
	var canonical_state: VehicleState = race.sim.state
	var canonical_before: Array = canonical_state.snapshot()
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(OUTPUT+"/before/skid_trails.gd.txt").replace("\r\n","\n").replace("class_name SkidTrails\n","")
	assert(script.reload() == OK)
	var baseline: Node3D = script.new()
	baseline.wheelbase = race.trails.wheelbase
	baseline.track_width = race.trails.track_width
	race.add_child(baseline)
	var effects: Array[Node3D] = [baseline,race.trails]
	var state := VehicleState.new()
	race.sim.state = state
	for effect: Node3D in effects: effect.hide()
	for profile: String in ["grass-rolling","grass-braking","road-control"]:
		var pictures: Array[Image] = []
		for effect: Node3D in effects:
			effect.clear()
			effect.show()
			var drive: DriveFrame = DriveFrame.sample(0,0,0.75 if profile != "grass-rolling" else 0.0)
			for i: int in range(100):
				var t: float = float(i)/99.0
				state.position = Vector2(-18+t*36,(0.0 if profile == "road-control" else 10.0)+sin(t*PI)*1.5)
				var tangent := Vector2(36,cos(t*PI)*PI*1.5).normalized()
				state.velocity = tangent*16
				state.heading = atan2(tangent.x,tangent.y)
				state.yaw_rate = 0.0
				state.tire_dirt = 0.0
				effect.sample(state,drive,race.bridge_presentation,track)
			assert(effect.instances.visible_instance_count > 100)
			if effect == baseline:
				race.previous_position = state.position
				race.previous_heading = state.heading
				race.call("_process",0.0)
				race.camera.follow(Vector2(1,0 if profile == "road-control" else 9),Vector2.ZERO,PI*0.5,0.0,true)
			for frame: int in range(10):
				race.paused = false
				race.hud.pause_menu.hide()
				race.hud.message_label.text = ""
				await RenderingServer.frame_post_draw
			var picture: Image = root.get_texture().get_image()
			var tag: String = "before" if effect == baseline else "after"
			assert(picture.save_png(folder+"/"+profile+"-"+tag+".png") == OK)
			pictures.append(picture)
			print("GRASS_TIRE_CAPTURE: ",profile," ",tag," segments=",effect.instances.visible_instance_count," first_tint=",effect.mark_colors[0])
			effect.hide()
		if profile == "road-control":
			assert(pictures[0].get_data() == pictures[1].get_data())
			print("GRASS_TIRE_CAPTURE: road-control pixels exact")
		else:
			assert(pictures[0].get_data() != pictures[1].get_data())
	race.sim.state = canonical_state
	assert(canonical_state.snapshot() == canonical_before and track.cells == cells and track.content_hash == content)
	print("GRASS_TIRE_CAPTURE: six matched views; canonical snapshot/cells/hash preserved")
	race.queue_free()
	await process_frame
	quit()

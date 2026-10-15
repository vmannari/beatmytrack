extends SceneTree
## Actual grass-to-asphalt cleaning, compared with the previous native renderer.
const OUTPUT: String = "res://../docs/evidence/tire-cleaning-grip-2026-10-14"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1600,900)
	var folder: String = OUTPUT+"/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var document: Dictionary = TrackDocument.create_blank()
	document.objects = []
	document["automatic_scenery"] = false
	var road: Dictionary = RoadPieces.create("straight",Vector2(-20,0),0.0,12.0)
	road.length = 120.0
	document.pieces = [road]
	var track: NativeTrack = TrackCompiler.compile(document)
	var cells: PackedInt32Array = track.cells.duplicate()
	var hash_before: String = track.content_hash
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
	var original: VehicleState = race.sim.state
	var original_snapshot: Array = original.snapshot()
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(OUTPUT+"/before/skid_trails.gd.txt").replace("\r\n","\n").replace("class_name SkidTrails\n","")
	assert(script.reload() == OK)
	var baseline: Node3D = script.new()
	baseline.wheelbase = race.trails.wheelbase
	baseline.track_width = race.trails.track_width
	race.add_child(baseline)
	var effects: Array[Node3D] = [baseline,race.trails]
	for effect: Node3D in effects:
		effect.clear()
		effect.hide()
	var simulation := VehicleSimulation.new(race.handling)
	simulation.reset(Vector2(-80,0),PI*0.5)
	simulation.state.velocity = Vector2(16,0)
	race.sim.state = simulation.state
	var targets: Array[float] = [2.0,25.0,50.0,76.0,84.0]
	var target: int = 0
	var samples: Array[Dictionary] = []
	var full_pickup: bool = false
	for tick: int in range(3600):
		var drive: DriveFrame = DriveFrame.sample(0,1,0)
		simulation.step(drive,track)
		for effect: Node3D in effects: effect.sample(simulation.state,drive,race.bridge_presentation,track)
		if simulation.state.position.x < -22.0 and simulation.state.tire_dirt == 1.0: full_pickup = true
		if simulation.state.position.x+20.0 < targets[target]: continue
		race.previous_position = simulation.state.position
		race.previous_heading = simulation.state.heading
		race.call("_process",0.0)
		race.camera.follow(simulation.state.position-Vector2(8,0),Vector2.ZERO,PI*0.5,0.0,true)
		var pictures: Array[Image] = []
		for effect: Node3D in effects:
			effect.show()
			for frame: int in range(10):
				race.paused = false
				race.hud.pause_menu.hide()
				race.hud.message_label.text = ""
				await RenderingServer.frame_post_draw
			var picture: Image = root.get_texture().get_image()
			var tag: String = "before" if effect == baseline else "after"
			assert(picture.save_png(folder+"/road-%02d-"%int(targets[target])+tag+".png") == OK)
			pictures.append(picture)
			effect.hide()
		samples.append({"road_metres":simulation.state.position.x+20.0,"dirt":simulation.state.tire_dirt,"road_grip":1.0-VehicleSimulation.dirt_grip_loss(simulation.state.tire_dirt,race.handling.dirty_tire_grip_loss),"marks":race.trails.cursor})
		assert(pictures[0].get_data() != pictures[1].get_data())
		target += 1
		if target == targets.size(): break
	assert(full_pickup and target == targets.size() and simulation.state.tire_dirt == 0.0)
	# The last view still contains previously deposited faint marks. Continued
	# clean straight travel must emit none, while preserving that race history.
	var deposited: int = race.trails.cursor
	for tick: int in range(60):
		simulation.step(DriveFrame.sample(0,1,0),track)
		race.trails.sample(simulation.state,DriveFrame.sample(0,1,0),race.bridge_presentation,track)
	assert(race.trails.cursor == deposited)
	# Shader and instance-format changes must leave the other treatments exact.
	for kind: int in [0,1,2,7,8]:
		var pictures: Array[Image] = []
		for effect: Node3D in effects:
			effect.clear()
			for index: int in range(70):
				simulation.state.position = Vector2(2+index*0.4,0)
				simulation.state.velocity = Vector2(24,0)
				var p: Vector3 = VisualGeometry.world(simulation.state.position)+Vector3.UP*0.078
				for wheel: int in range(2):
					var offset := Vector3(0,0,race.trails.track_width*(wheel-0.5))
					effect._mark(p+offset,p+offset+Vector3(0.4,0,0),0.0,kind,0.8,wheel)
			if effect == baseline:
				race.previous_position = simulation.state.position
				race.previous_heading = simulation.state.heading
				race.call("_process",0.0)
				race.camera.follow(Vector2(21,0),Vector2.ZERO,PI*0.5,0.0,true)
			effect.show()
			for frame: int in range(10):
				race.paused = false
				race.hud.pause_menu.hide()
				race.hud.message_label.text = ""
				await RenderingServer.frame_post_draw
			var picture: Image = root.get_texture().get_image()
			assert(picture.save_png(folder+"/control-%d-"%kind+("before" if effect == baseline else "after")+".png") == OK)
			pictures.append(picture)
			effect.hide()
		assert(pictures[0].get_data() == pictures[1].get_data())
		print("TIRE_CLEANING_CONTROL: kind=",kind," exact pixels")
	race.sim.state = original
	assert(original.snapshot() == original_snapshot and track.cells == cells and track.content_hash == hash_before)
	var result := FileAccess.open(folder+"/cleaning.json",FileAccess.WRITE)
	result.store_string(JSON.stringify(samples,"\t"))
	print("TIRE_CLEANING_CAPTURE: ",JSON.stringify(samples),"; full grass pickup, clean finish/no new marks, original state/cells/hash retained")
	race.queue_free()
	await process_frame
	quit()

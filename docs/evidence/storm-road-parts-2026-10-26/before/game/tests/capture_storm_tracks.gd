extends SceneTree
## Native map review plus unchanged production-camera views for every circuit.
const IDS: Array[String] = ["storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"]
const OUTPUT: String = "res://../docs/evidence/storm-five-tracks-2026-10-25"

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i: int in range(12): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = OUTPUT+"/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var maps: Array[Image] = []
	for id: String in IDS:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/storm_tracks/"+id+".json"))
		var track: NativeTrack = TrackCompiler.compile(document)
		assert(track != null)
		var race: Node = preload("res://core/game.tscn").instantiate()
		race.initial_track = track
		race.production_mode = true
		root.add_child(race)
		race.set_physics_process(false)
		race.set_process(false)
		race.paused = true
		race.race_cues.hide()
		race.hud.hide()
		race._process(0.0)
		await settle()
		race.camera.follow(track.spawn,Vector2.ZERO,track.spawn_heading,0,true)
		await settle()
		assert(root.get_texture().get_image().save_png(folder+"/"+id+"-drive.png")==OK)
		if "--starts-only" in OS.get_cmdline_user_args():
			race.free()
			await process_frame
			print("STORM_TRACK_START_CAPTURE ",id," ",RenderingServer.get_current_rendering_method())
			continue
		var at: int = floori(track.route.size()*.42)
		var point: Vector2 = track.route[at]
		var direction: Vector2 = track.route[(at+1)%track.route.size()]-point
		race.sim.state.position = point
		race.sim.state.heading = atan2(direction.x,direction.y)
		race.previous_position = point
		race._process(0.0)
		race.camera.follow(point,Vector2.ZERO,race.sim.state.heading,0,true)
		await settle()
		assert(root.get_texture().get_image().save_png(folder+"/"+id+"-detail.png")==OK)
		# The map camera exists only in this offline review script.
		var camera: Camera3D = race.camera
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(track.half_extent.y*2,track.half_extent.x*2*720.0/1280.0)
		camera.position = Vector3(0,160,0)
		camera.rotation_degrees = Vector3(-90,0,0)
		camera.far = 350
		await settle()
		var picture: Image = root.get_texture().get_image()
		assert(picture.save_png(folder+"/"+id+"-map.png")==OK)
		picture.convert(Image.FORMAT_RGB8)
		picture.resize(640,360,Image.INTERPOLATE_LANCZOS)
		maps.append(picture)
		race.free()
		await process_frame
		print("STORM_TRACK_CAPTURE ",id," ",RenderingServer.get_current_rendering_method())
	if maps.is_empty():
		print("STORM_TRACK_START_CAPTURES: ",IDS.size()," tracks")
		quit()
		return
	var sheet := Image.create(1280,1080,false,Image.FORMAT_RGB8)
	sheet.fill(Color("151e24"))
	for i: int in range(maps.size()): sheet.blit_rect(maps[i],Rect2i(0,0,640,360),Vector2i(i%2*640,i/2*360))
	assert(sheet.save_png(folder+"/contact-sheet.png")==OK)
	print("STORM_TRACK_CAPTURES: ",maps.size()," tracks")
	quit()

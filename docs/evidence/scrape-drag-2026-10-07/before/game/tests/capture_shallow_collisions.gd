extends "res://tests/analyze_shallow_collisions.gd"
## Same pose/input comparison, using shipping car/camera/audio presenters.
const LEGACY = preload("res://tests/fixtures/legacy_contact_physics.gd")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("Capture requires TestScript -Graphical")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	var folder: String = ProjectSettings.globalize_path("res://../build/shallow-collision-fix/captures")
	DirAccess.make_dir_recursive_absolute(folder)
	var measurements: Dictionary = {}
	for historical: bool in [true,false]:
		var name: String = "before" if historical else "after"
		DirAccess.make_dir_recursive_absolute(folder+"/"+name)
		var world := Node3D.new()
		root.add_child(world)
		VisualGeometry.box(world,Vector3(400,0.1,400),Vector3(0,-0.1,0),VisualGeometry.material(Color("565d61")))
		VisualGeometry.box(world,Vector3(0.5,1.0,400),Vector3(0.25,0.5,0),VisualGeometry.material(Color("747f83")))
		for y: int in range(-140,140,4):
			VisualGeometry.box(world,Vector3(0.12,0.01,1.5),Vector3(-6,0.005,float(y)),VisualGeometry.material(Color("c4c3b3")))
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("526272")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("ced5dc")
		environment.environment.ambient_light_energy = 0.65
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55,-25,0)
		light.shadow_enabled = true
		world.add_child(light)
		var car := CarVisual.new()
		world.add_child(car)
		var camera := FollowCamera.new()
		camera.speed_zoom_enabled = false
		world.add_child(camera)
		var audio := VehicleAudio.new()
		root.add_child(audio)
		var config: HandlingConfig = VehicleCatalog.config("compact")
		audio.configure("compact",config)
		var track: NativeTrack = make_wall(Vector2.LEFT,0.5)
		if historical: track = LEGACY.copy_track(track)
		var sim: VehicleSimulation = LEGACY.Simulation.new(config) if historical else VehicleSimulation.new(config)
		sim.reset(Vector2(-config.collision_radius-0.002,0),deg_to_rad(2.0))
		sim.state.velocity = sim.state.forward()*30.0
		var frame := DriveFrame.new()
		var hud := Label.new()
		hud.position = Vector2(28,24)
		hud.add_theme_font_size_override("font_size",26)
		hud.add_theme_color_override("font_color",Color("ffe09b"))
		root.add_child(hud)
		var recorder := AudioEffectRecord.new()
		AudioServer.add_bus_effect(0,recorder)
		recorder.set_recording_active(true)
		var start: int = Time.get_ticks_usec()
		var stepping_us: int = 0
		for draw: int in range(120):
			if draw<60:
				for tick: int in range(2):
					var old_velocity: Vector2 = sim.state.velocity
					var old_contacts: int = sim.state.collision_count
					var begin: int = Time.get_ticks_usec()
					sim.step(frame,track)
					stepping_us += Time.get_ticks_usec()-begin
					var impact: Vector2 = sim.state.velocity-old_velocity if historical and sim.state.collision_count>old_contacts else sim.state.collision_impulse
					camera.add_collision_impact(impact)
					car.add_collision_impact(sim.state,impact)
					audio.collision(impact)
					if not historical:
						car.add_scrape(sim.state)
						audio.scrape(sim.state.scrape_strength,sim.state.scrape_speed)
					car.present_suspension(sim.state,0.0)
			car.present(sim.state.position,sim.state.heading,sim.state,frame)
			camera.follow(sim.state.position,sim.state.velocity,sim.state.heading,1.0/60.0,draw==0)
			audio.present(sim.state,frame,null,1.0/60.0,draw>=60)
			hud.text = "2° WALL BRUSH · %s\n%.0f KM/H     %.2f M ALONG WALL\nCOASTING · SAME 108 KM/H ENTRY" % ["PHYSICS 0.50" if historical else "PHYSICS 0.51",sim.state.velocity.length()*3.6,sim.state.position.y]
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+name+"/frame-%03d.png" % draw)
			if draw==59: root.get_texture().get_image().save_png(folder+"/"+name+".png")
		recorder.set_recording_active(false)
		var recording: AudioStreamWAV = recorder.get_recording()
		var pcm: PackedByteArray = recording.data
		var peak: int = 0
		for offset: int in range(0,pcm.size(),2): peak = maxi(peak,absi(pcm.decode_s16(offset)))
		recording.save_to_wav(folder+"/"+name+".wav")
		check(peak>0 and peak<32700)
		AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
		measurements[name] = {"final_speed_kmh":sim.state.velocity.length()*3.6,"progress_m":sim.state.position.y,"120_step_us":stepping_us,"wall_clock_ms":(Time.get_ticks_usec()-start)/1000.0,"pcm_peak":peak}
		hud.queue_free()
		audio.queue_free()
		world.queue_free()
		await process_frame
		await process_frame
	var file := FileAccess.open(folder+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t"))
	file.close()
	print("COLLISION_CAPTURE: ",JSON.stringify(measurements)," checks=",checks," failures=",failures)
	quit(1 if failures else 0)

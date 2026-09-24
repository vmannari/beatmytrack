extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func run() -> void:
	for id: String in ["compact","pickup","classic","formula","kart"]:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		car.set_night_headlights(false)
		check(car.headlights == null,"daytime allocates no lights: "+id)
		car.set_night_headlights(true)
		var lamps: Array[Node] = car.find_children("*","Light3D",true,false)
		check(lamps.size() == 1,"one shared light budget: "+id)
		var lamp := lamps[0] as SpotLight3D
		check(not lamp.shadow_enabled and lamp.spot_range <= 12.0,"short bounded shadow-free light: "+id)
		var hood_point := Vector3(0,0.8,-1.0)
		check((hood_point-lamp.position).dot(-lamp.basis.z) < 0,"hood stays behind the beam: "+id)
		check(lamp.position.z < 0 and lamp.transform.basis.z.y > 0,"beam faces nose and road: "+id)
		car.set_night_headlights(false)
		check(not lamp.is_visible_in_tree(),"off disables the beam: "+id)
		car.set_night_headlights(true)
		check(car.find_children("*","Light3D",true,false).size() == 1,"toggle reuses light: "+id)
		var state := VehicleState.new()
		car.present(Vector2.ZERO,0.0,state,DriveFrame.sample(0,0,0))
		var running_energy: float = car.brake_material.emission_energy_multiplier
		check(car.brake_material.emission_enabled and running_energy > 0 and running_energy < 0.5,"faint night rear lamps: "+id)
		car.present(Vector2.ZERO,0.0,state,DriveFrame.sample(0,0,1))
		check(car.brake_material.emission_energy_multiplier > running_energy*2,"braking remains clearly brighter: "+id)
		car.present(Vector2.ZERO,0.0,state,DriveFrame.sample(0,0,0))
		check(is_equal_approx(car.brake_material.emission_energy_multiplier,running_energy),"brake release restores faint lamps: "+id)
		car.set_night_headlights(false)
		check(not car.brake_material.emission_enabled,"daytime disables rear glow: "+id)
		car.free()
	var document: Dictionary = TrackDocument.create_default()
	document.theme = "night_city"
	var saved: Dictionary = TrackLibrary.new().load_document("track_c7ad183a78f7a033")
	if not saved.is_empty(): document = saved
	var game: Node = preload("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(document)
	root.size = Vector2i(1280,720)
	root.add_child(game)
	check(game.car.headlights != null and game.car.headlights.visible,"night race enables headlights")
	if "--capture" in OS.get_cmdline_user_args():
		var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/headlights-2026-09-24")
		DirAccess.make_dir_recursive_absolute(folder)
		game.set_physics_process(false)
		for enabled: bool in [false,true]:
			game.car.set_night_headlights(enabled)
			for i: int in range(8): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+("/on.png" if enabled else "/off.png"))
		var rear_folder: String = ProjectSettings.globalize_path("res://../docs/evidence/taillights-2026-09-24")
		DirAccess.make_dir_recursive_absolute(rear_folder)
		game.sim.state.heading = 0.0
		game.previous_heading = 0.0
		for braking: bool in [false,true]:
			game.frame = DriveFrame.sample(0,0,1 if braking else 0)
			for i: int in range(8): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(rear_folder+("/braking.png" if braking else "/running.png"))
	game.free()
	await process_frame
	print("Headlights: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

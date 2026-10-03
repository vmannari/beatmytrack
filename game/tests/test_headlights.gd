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
		check(car.brake_material.emission_enabled and car.brake_material.emission_energy_multiplier > 0,"rear lamps lit immediately: "+id)
		car.set_night_headlights(false)
		check(car.headlights == null,"daytime allocates no lights: "+id)
		car.set_night_headlights(true)
		var lamps: Array[Node] = car.find_children("*","Light3D",true,false)
		check(lamps.size() == 1,"one shared headlight beam: "+id)
		var lamp := lamps[0] as SpotLight3D
		check(not lamp.shadow_enabled and is_equal_approx(lamp.spot_range,12.0*1.7),"owner 1.7x range with no shadows: "+id)
		var hood_point := Vector3(0,0.8,-1.0)
		check((hood_point-lamp.position).dot(-lamp.basis.z) < 0,"hood stays behind the beam: "+id)
		check(lamp.position.z < 0 and lamp.transform.basis.z.y > 0,"beam faces nose and road: "+id)
		check(not car.road_headlight.shadow_enabled and car.road_headlight.light_cull_mask == 3,"headlight includes ordinary and bridge layers without shadow cost: "+id)
		car.set_headlight_bridge_occlusion(true)
		check(car.road_headlight.light_cull_mask == 1,"underpass excludes bridge geometry from the beam: "+id)
		car.set_headlight_bridge_occlusion(false)
		check(car.road_headlight.light_cull_mask == 3,"leaving underpass restores bridge lighting: "+id)
		car.set_night_headlights(false)
		check(not lamp.is_visible_in_tree(),"off disables the beam: "+id)
		car.set_night_headlights(true)
		check(car.find_children("*","Light3D",true,false).size() == 1,"toggle reuses the bounded light: "+id)
		var state := VehicleState.new()
		car.present(Vector2.ZERO,0.0,state,DriveFrame.sample(0,0,0))
		var running_energy: float = car.brake_material.emission_energy_multiplier
		check(car.brake_material.emission_enabled and running_energy > 0,"visible running rear lamps: "+id)
		car.present(Vector2.ZERO,0.0,state,DriveFrame.sample(0,0,1))
		check(car.brake_material.emission_energy_multiplier > running_energy*2,"braking remains clearly brighter: "+id)
		car.present(Vector2.ZERO,0.0,state,DriveFrame.sample(0,0,0))
		check(is_equal_approx(car.brake_material.emission_energy_multiplier,running_energy),"brake release restores faint lamps: "+id)
		car.set_night_headlights(false)
		check(car.brake_material.emission_enabled and is_equal_approx(car.brake_material.emission_energy_multiplier,running_energy),"daytime retains running rear lamps: "+id)
		car.free()
	var document: Dictionary = TrackDocument.create_default()
	document.theme = "night_city"
	var bridge_piece: Dictionary = RoadPieces.create("bridge",Vector2(-15,0),0,12)
	bridge_piece.length = 30.0
	document.pieces.append(bridge_piece)
	var game: Node = preload("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(document)
	root.size = Vector2i(1280,720)
	root.add_child(game)
	check(game.car.headlights != null and game.car.headlights.visible,"night race enables headlights")
	check(game.native_track.has_overhead_bridge(Vector2.ZERO,false),"ground-level car detects overhead bridge deck")
	check(not game.native_track.has_overhead_bridge(Vector2.ZERO,true),"car on bridge deck does not enable underside spill")
	game.set_physics_process(false)
	for elevated: bool in [false,true,false]:
		game.sim.state.track_elevated = elevated
		game.sim.state.position = Vector2(0,-12)
		game.previous_position = game.sim.state.position
		game._process(0.0)
		check(game.car.road_headlight.light_cull_mask == (3 if elevated else 1),"race presenter selects headlight layer by driving level outside bridge footprint")
	if "--capture" in OS.get_cmdline_user_args():
		game.sim.state.position = Vector2(-22,0)
		game.previous_position = game.sim.state.position
		game.sim.state.heading = PI*0.5
		game.previous_heading = PI*0.5
		for i: int in range(8): await process_frame
		var ramp_folder: String = ProjectSettings.globalize_path("res://../docs/evidence/night-bridge-headlights")
		DirAccess.make_dir_recursive_absolute(ramp_folder)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ramp_folder+"/ramp-approach.png")
		game.sim.state.position = Vector2(-9,0)
		game.previous_position = game.sim.state.position
		game.sim.state.track_elevated = true
		for i: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ramp_folder+"/ramp-crest.png")
		game.sim.state.track_elevated = false
		game.sim.state.position = Vector2(0,-12)
		game.previous_position = game.sim.state.position
		game.sim.state.heading = 0.0
		game.previous_heading = 0.0
		for i: int in range(8): await process_frame
		var approach_folder: String = ProjectSettings.globalize_path("res://../docs/evidence/night-bridge-headlights")
		DirAccess.make_dir_recursive_absolute(approach_folder)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(approach_folder+"/approach.png")
		game.set_physics_process(false)
		game.sim.state.position = Vector2.ZERO
		game.sim.state.track_elevated = false
		game.previous_position = Vector2.ZERO
		game.sim.state.heading = PI * 0.5
		game.previous_heading = PI * 0.5
		for i: int in range(8): await process_frame
		var bridge_folder: String = ProjectSettings.globalize_path("res://../docs/evidence/night-bridge-headlights")
		DirAccess.make_dir_recursive_absolute(bridge_folder)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(bridge_folder+"/occlusion-on.png")
		game.set_process(false)
		game.car.set_headlight_bridge_occlusion(false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(bridge_folder+"/occlusion-off.png")
		var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/headlights-2026-09-24")
		DirAccess.make_dir_recursive_absolute(folder)
		game.set_process(true)
		for enabled: bool in [false,true]:
			game.car.set_night_headlights(enabled)
			for i: int in range(8): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+("/on.png" if enabled else "/off.png"))
		var rear_folder: String = ProjectSettings.globalize_path("res://../docs/evidence/taillights-2026-09-29")
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

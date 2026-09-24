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
	root.size = Vector2i(1280,720)
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = "desert"
	doc.surface = "dirt"
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(doc.surface == "dirt", "compilation does not mutate player document")
	check(track.metadata.creator_document.surface == "asphalt", "desert dirt option resolves to firm road bed")
	var state := VehicleState.new()
	state.position = track.route[10]
	state.velocity = Vector2(0,12)
	check(track.cell_at(state.position) == 0, "desert route uses structural road cells")
	check(track.surface_factors(state) == Vector2(0.94,0.35), "packed sand grip and rolling resistance")
	check(track.tire_pickup(state) == 0.0, "firm road avoids deep-soil drag and trip mechanics")
	check(SkidTrails.surface_at(track,VisualGeometry.world(state.position),false) == 2, "road leaves sand trails")
	state.track_elevated = true
	check(track.surface_factors(state) == Vector2(0.94,0.35), "bridge has the same firm sand traction")
	state.track_elevated = false
	for car: String in VehicleCatalog.IDS:
		var original := VehicleSimulation.new(VehicleCatalog.config(car))
		var replay := VehicleSimulation.new(VehicleCatalog.config(car))
		original.state.position = state.position
		replay.state.position = state.position
		for tick: int in range(480):
			var frame := DriveFrame.sample(0.2 if tick > 120 else 0.0,1.0,0.0)
			original.step(frame,track)
			replay.step(frame,track)
		check(original.state.snapshot() == replay.state.snapshot(),car+" exact desert replay")
	# Compare actual powered travel against deep sand on an obstacle-free grid.
	var bed := NativeTrack.new()
	bed.cell_size = 10.0
	bed.grid_width = 100
	bed.grid_height = 100
	bed.half_extent = Vector2(500,500)
	bed.cells.resize(10000)
	bed.deck_cells.resize(10000)
	bed.deck_cells.fill(-1)
	bed.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
	bed.metadata = {"theme":"desert"}
	for car: String in VehicleCatalog.IDS:
		var speeds: Array[float] = []
		for kind: int in [0,2]:
			bed.cells.fill(kind)
			var drive := VehicleSimulation.new(VehicleCatalog.config(car))
			for tick: int in range(240): drive.step(DriveFrame.sample(0,1,0),bed)
			speeds.append(drive.state.velocity.length())
		check(speeds[0] > speeds[1]*1.25,car+" accelerates substantially better on packed road than deep sand")
		print("DESERT_LAUNCH ",car," packed/loose mps=",speeds)
	var dust := SandDust.new()
	root.add_child(dust)
	dust.sample(state,DriveFrame.new(),track)
	check(dust.dust_emitters[0].emitting and dust.last_strengths[0] > 0.9,"straight driving produces dense dust without sliding")
	check(dust.dust_emitters[0].lifetime == 9.0,"dust persists nine seconds")
	var cloud: ParticleProcessMaterial = dust.dust_emitters[0].process_material
	var growth: Curve = (cloud.scale_curve as CurveTexture).curve
	check(growth.sample(0.42) >= 4.0 and growth.sample(1.0) >= 7.0,"desert clouds grow into broad mature billows")
	check(cloud.spread > 90.0 and cloud.damping_max < 0.75,"desert dust spreads sideways rather than remaining at tyre width")
	dust._stop()
	check(not dust.dust_emitters[0].emitting,"stopping ends emission without restarting existing clouds")
	dust.queue_free()
	var environment := Environment.new()
	var light := DirectionalLight3D.new()
	TrackTheme.apply_lighting("desert",environment,light)
	check(is_equal_approx(light.rotation_degrees.x,-58) and light.light_color == Color("fff1d8"),"desert uses normal daylight per owner override")
	TrackTheme.apply_lighting("pine",environment,light)
	check(is_equal_approx(light.rotation_degrees.x,-58),"leaving desert restores daylight angle")
	light.free()
	for theme: String in TrackTheme.IDS:
		var visual := NativeTrackVisual.new()
		visual.theme_id = theme
		var material := ShaderMaterial.new()
		material.shader = preload("res://track/ground.gdshader")
		visual._bind_grass(material)
		check(material.get_shader_parameter("desert_dunes") == (theme == "desert"),theme+" dune material isolation")
		visual.free()
	check(NativeTrackVisual.DUNE_FACTORS.get_image().has_mipmaps(),"dune slope map is mip filtered")
	check(NativeTrackVisual.DUNE_ALBEDO.get_image().has_mipmaps(),"dune artwork is mip filtered")
	if "--capture" in OS.get_cmdline_user_args():
		var capture_track: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--track="): capture_track = argument.trim_prefix("--track=")
		if not capture_track.is_empty():
			var saved: Dictionary = TrackLibrary.new().load_document(capture_track)
			check(not saved.is_empty(),"saved desert capture track exists")
			if saved.is_empty(): quit(1); return
			track = TrackCompiler.compile(saved)
		var original_cells: PackedInt32Array = track.cells.duplicate()
		var race: Node = load("res://core/game.tscn").instantiate()
		race.initial_track = track
		race.production_mode = true
		root.add_child(race)
		await process_frame
		race.set_physics_process(false)
		race.set("countdown_ticks",0)
		(race.get("race_cues") as Control).hide()
		var effect: SandDust = race.get("sand_dust")
		var folder: String = "res://../docs/evidence/desert"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		for i: int in range(10): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/sunset-road.png") == OK,"sunset evidence")
		var comparison_folder: String = "res://../docs/evidence/desert-dunes"
		if not capture_track.is_empty(): comparison_folder += "/"+capture_track.validate_filename()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(comparison_folder))
		var probe = preload("res://diagnostics/surface_material_probe.gd").new()
		probe.collect(race.get("track_ground"))
		for mode: String in ["desert_original","baseline"]:
			probe.apply(mode)
			await RenderingServer.frame_post_draw
			for entry: Dictionary in probe.entries:
				var active: ShaderMaterial = entry.mesh.material_override
				check(active.get_shader_parameter("desert_dunes") == (mode == "baseline"),"dune comparison material binding")
			check(root.get_texture().get_image().save_png(comparison_folder+"/"+mode+".png") == OK,"dune comparison evidence")
		probe.restore()
		check(track.cells == original_cells,"dune presentation leaves canonical surfaces unchanged")
		var sim: VehicleSimulation = race.get("sim")
		state = sim.state
		var restored_position: Vector2 = state.position
		var restored_heading: float = state.heading
		var apron_folder: String = "res://../docs/evidence/desert-apron"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(apron_folder))
		check(root.get_texture().get_image().save_png(apron_folder+"/start-straight.png") == OK,"apron straight evidence")
		print("DESERT_CLODS: ",race.get("track_ground").get_meta("desert_clod_count",0))
		for fraction: float in [0.35,0.70]:
			var route_index: int = int(track.route.size()*fraction)
			state.position = track.route[route_index]
			var direction: Vector2 = (track.route[(route_index+1)%track.route.size()]-state.position).normalized()
			state.heading = atan2(direction.x,direction.y)
			race.set("previous_position",state.position)
			race.set("previous_heading",state.heading)
			(race.get("camera") as FollowCamera).follow(state.position,Vector2.ZERO,state.heading,0.0,true)
			for frame: int in range(5): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(apron_folder+"/route-"+str(int(fraction*100))+".png") == OK,"apron route evidence")
		state.position = restored_position
		state.heading = restored_heading
		race.set("previous_position",state.position)
		race.set("previous_heading",state.heading)
		(race.get("camera") as FollowCamera).follow(state.position,Vector2.ZERO,state.heading,0.0,true)
		state.velocity = state.forward()*12.0
		var start_index: int = track.nearest_route(state.position)
		for i: int in range(240):
			var index: int = (start_index + i/4) % track.route.size()
			state.position = track.route[index].lerp(track.route[(index+1)%track.route.size()],float(i%4)/4.0)
			var direction: Vector2 = (track.route[(index+1)%track.route.size()]-track.route[index]).normalized()
			state.heading = atan2(direction.x,direction.y)
			state.velocity = direction*12.0
			race.set("previous_position",state.position)
			race.set("previous_heading",state.heading)
			effect.sample(state,DriveFrame.new(),track)
			await create_timer(1.0/60.0).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/dense-dust.png") == OK,"dust obstruction evidence")
		effect._stop()
		await create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/lingering-dust.png") == OK,"lingering dust evidence")
		race.queue_free()
	await process_frame
	print("DESERT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


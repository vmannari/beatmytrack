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

func resume_capture(race: Node) -> void:
	# Desktop focus changes must not freeze particles or cover VFX evidence
	# with the automatic pause drawer. Physics is disabled in this fixture.
	if race.get("paused"): race.call("toggle_pause")

func check_cloud_footprint(mesh: Mesh) -> void:
	# Check the shipping geometry against the visible radial shader support,
	# rather than simply asserting a particular vertex/triangle count.
	check(mesh is ArrayMesh,"billowing cloud uses a trimmed footprint")
	if not mesh is ArrayMesh: return
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bounds: AABB = mesh.get_aabb()
	var mapping_ok: bool = vertices.size() == uvs.size()
	for i: int in range(vertices.size()):
		var expected := Vector2(vertices[i].x/bounds.size.x+0.5,0.5-vertices[i].y/bounds.size.y)
		mapping_ok = mapping_ok and expected.is_equal_approx(uvs[i])
	check(mapping_ok,"trimmed cloud preserves the full card's affine UV mapping")
	var area: float = 0.0
	for i: int in range(0,indices.size(),3):
		area += absf((uvs[indices[i+1]]-uvs[indices[i]]).cross(uvs[indices[i+2]]-uvs[indices[i]]))*0.5
	check(area > PI*0.25 and area <= 0.83,"cloud raster area falls at least 17 percent without shrinking visible support")
	var contains_circle: bool = true
	for angle: int in range(360):
		var point: Vector2 = Vector2(0.5,0.5)+Vector2.from_angle(deg_to_rad(float(angle)))*0.5
		var covered: bool = false
		for i: int in range(0,indices.size(),3):
			covered = covered or Geometry2D.point_is_inside_triangle(point,uvs[indices[i]],uvs[indices[i+1]],uvs[indices[i+2]])
		# Exact tangencies may round just outside; retry a subpixel inset.
		if not covered:
			point = point.lerp(Vector2(0.5,0.5),0.00001)
			for i: int in range(0,indices.size(),3):
				covered = covered or Geometry2D.point_is_inside_triangle(point,uvs[indices[i]],uvs[indices[i+1]],uvs[indices[i+2]])
		contains_circle = contains_circle and covered
	check(contains_circle,"every visible cloud rim remains inside the trimmed triangles")

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
	for emitter: GPUParticles3D in dust.dust_emitters + dust.tyre_emitters:
		check_cloud_footprint(emitter.draw_pass_1)
	check(dust.dust_emitters[0].amount == 64 and dust.tyre_emitters[0].amount == 48,"render optimization retains lingering and contact particle capacity")
	var cloud: ParticleProcessMaterial = dust.dust_emitters[0].process_material
	var growth: Curve = (cloud.scale_curve as CurveTexture).curve
	check(growth.sample(0.42) >= 1.5 and growth.sample(1.0) <= 2.5,"desert clouds expand within bounded overdraw budget")
	check(dust.dust_emitters[0].amount * 4 <= 384 and dust.tyre_emitters[0].emitting,"bounded lingering cloud population and separate tyre puffs")
	check(cloud.spread > 90.0 and cloud.damping_max < 0.75,"desert dust spreads sideways rather than remaining at tyre width")
	check((cloud.color_ramp as GradientTexture1D).gradient.sample(0.15 / 9.0).a > 0.8,"cloud becomes dense within 150 ms rather than trailing a second behind")
	check(growth.sample(0.25 / 9.0) >= 1.4,"cloud fills the near wake within 250 ms")
	bed.cells.fill(1)
	var offroad := VehicleState.new()
	offroad.velocity = Vector2(0,12)
	check(SkidTrails.surface_at(bed,Vector3.ZERO,false) == 2,"desert off-track soil presents sand tyre marks")
	dust.sample(offroad,DriveFrame.new(),bed)
	check(bed.cell_at(Vector2.ZERO) == 1,"desert effects preserve canonical off-track soil")
	for wheel: int in range(4):
		check(dust.dust_emitters[wheel].emitting and dust.tyre_emitters[wheel].emitting,"off-track wheel emits lingering sand and contact puff")
		check(not dust.clipping_emitters[wheel].emitting,"desert wheel never emits grass clippings")
	check(dust.spray_emitters[0].emitting and not dust.mud_emitters[0].emitting,"ordinary off-track driving throws sand grains without mud")
	bed.metadata.theme = "pine"
	bed.cells.fill(5)
	check(SkidTrails.surface_at(bed,Vector3.ZERO,false) == 5,"meadow kerbs retain rubber marks")
	bed.metadata.theme = "desert"
	check(SkidTrails.surface_at(bed,Vector3.ZERO,false) == 2,"desert sandy road edge uses sand grooves instead of dark kerb rubber")
	dust.sample(offroad,DriveFrame.new(),bed)
	check(dust.dust_emitters[0].emitting and not dust.smoke_emitters[0].emitting,"desert road edge emits sand dust instead of asphalt smoke")
	bed.cells.fill(1)
	bed.metadata.theme = "pine"
	dust.sample(offroad,DriveFrame.new(),bed)
	check(SkidTrails.surface_at(bed,Vector3.ZERO,false) == 1 and dust.clipping_emitters[0].emitting and not dust.dust_emitters[0].emitting,"leaving desert restores meadow effects")
	check(dust.dust_emitters[0].draw_pass_1 is QuadMesh and dust.dust_emitters[0].amount == 360 and dust.dust_emitters[0].lifetime == 5.2,"leaving desert restores the original irregular sand sprite profile")
	dust._stop()
	check(not dust.dust_emitters[0].emitting,"stopping ends emission without restarting existing clouds")
	dust.queue_free()
	var environment := Environment.new()
	var light := DirectionalLight3D.new()
	TrackTheme.apply_lighting("desert",environment,light)
	check(is_equal_approx(light.rotation_degrees.x,-46) and light.light_color == Color("ffedce") and is_equal_approx(light.light_energy,1.32) and environment.ambient_light_energy < 0.35,"desert directional daylight defines low sandbanks with stronger shade")
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
	check(NativeTrackVisual.DESERT_FINISH_COLORS == [Color("938267"),Color("635b4b")],"desert finish uses two subdued sand pigments instead of black and white")
	check(NativeTrackVisual.DESERT_FINISH_COLORS != NativeTrackVisual.STANDARD_FINISH_COLORS,"desert finish treatment is isolated from other biomes")
	var finish_visual := NativeTrackVisual.new()
	finish_visual.theme_id = "desert"
	finish_visual._build_finish(track)
	var desert_finish_light: MeshInstance3D = finish_visual.get_node_or_null("DesertSandFinishPale")
	var desert_finish_dark: MeshInstance3D = finish_visual.get_node_or_null("DesertSandFinishDark")
	check(desert_finish_light != null and desert_finish_dark != null,"desert builds two faded sand checker tones")
	if desert_finish_light != null and desert_finish_dark != null:
		check((desert_finish_light.material_override as ShaderMaterial).get_shader_parameter("pigment_color") == NativeTrackVisual.DESERT_FINISH_COLORS[0] and (desert_finish_dark.material_override as ShaderMaterial).get_shader_parameter("pigment_color") == NativeTrackVisual.DESERT_FINISH_COLORS[1],"desert finish mesh binds the biome pigments")
	finish_visual.free()
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
		resume_capture(race)
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
			resume_capture(race)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(apron_folder+"/route-"+str(int(fraction*100))+".png") == OK,"apron route evidence")
			if fraction == 0.35 and "--screen=bank-detail" in OS.get_cmdline_user_args():
				# Diagnostic close-up only; normal driving framing stays unchanged.
				var camera: Camera3D = race.get("camera")
				var normal_size: float = camera.size
				race.set_process(false)
				camera.size = normal_size*0.55
				resume_capture(race)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var detail_folder: String = "res://../docs/evidence/desert-even-banks-2026-10-05"
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(detail_folder))
				check(root.get_texture().get_image().save_png(detail_folder+"/fresh-closeup.png") == OK,"fresh bank detail evidence")
				camera.size = normal_size
				race.set_process(true)
		state.position = restored_position
		state.heading = restored_heading
		race.set("previous_position",state.position)
		race.set("previous_heading",state.heading)
		(race.get("camera") as FollowCamera).follow(state.position,Vector2.ZERO,state.heading,0.0,true)
		state.velocity = state.forward()*12.0
		var start_index: int = track.nearest_route(state.position)
		for i: int in range(240):
			resume_capture(race)
			var index: int = (start_index + i/4) % track.route.size()
			state.position = track.route[index].lerp(track.route[(index+1)%track.route.size()],float(i%4)/4.0)
			var direction: Vector2 = (track.route[(index+1)%track.route.size()]-track.route[index]).normalized()
			state.heading = atan2(direction.x,direction.y)
			state.velocity = direction*12.0
			race.set("previous_position",state.position)
			race.set("previous_heading",state.heading)
			effect.sample(state,DriveFrame.new(),track)
			if i == 239: check(effect.last_strengths[0] > 0.0,"captured moving plume is emitting")
			await create_timer(1.0/60.0).timeout
		resume_capture(race)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/dense-dust.png") == OK,"dust obstruction evidence")
		effect._stop()
		var linger_deadline: int = Time.get_ticks_usec()+3000000
		while Time.get_ticks_usec() < linger_deadline:
			resume_capture(race)
			await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/lingering-dust.png") == OK,"lingering dust evidence")
		effect.clear()
		var offtrack_origin: Vector2 = track.route[0]
		for offset: int in range(5,100):
			var candidate: Vector2 = track.route[0] + Vector2(offset,0)
			if track.cell_at(candidate) == 1 and track.cell_at(candidate+Vector2(0,20)) == 1:
				offtrack_origin = candidate
				break
		check(track.cell_at(offtrack_origin) == 1,"capture uses actual off-track soil")
		var trails := SkidTrails.new()
		race.add_child(trails)
		for i: int in range(150):
			resume_capture(race)
			state.position = offtrack_origin + Vector2(0,float(i)*0.12)
			state.heading = 0.0
			state.velocity = Vector2(0,12)
			race.set("previous_position",state.position)
			race.set("previous_heading",state.heading)
			effect.sample(state,DriveFrame.new(),track)
			trails.sample(state,DriveFrame.new(),null,track)
			await create_timer(1.0/60.0).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/off-track-dust.png") == OK,"off-track sand effects evidence")
		effect.clear()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/off-track-marks.png") == OK,"off-track sand tyre marks evidence")
		race.queue_free()
	await process_frame
	print("DESERT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


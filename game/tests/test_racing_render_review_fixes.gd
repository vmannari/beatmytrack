extends "res://tests/test_winter_snow_wind.gd"
## RRV01-RRV03: exact presentation, live fallback and synchronous contact sharing.
var folder := "res://../build/racing-render-fixes-2026-10-14"
var report: Dictionary = {}

func script_from(source: String) -> GDScript:
	var script := GDScript.new(); script.source_code = source
	check(script.reload() == OK,"diagnostic script compiles")
	return script

func instrument_wind(path: String) -> GDScript:
	var source := FileAccess.get_file_as_string(path).replace("\r\n","\n")
	source = source.substr(source.find("\n")+1)
	for name: String in ["_place_ground()", "_place_banks(focus: Vector2)"]:
		source = source.replace("func "+name+" -> void:\n","func "+name+" -> void:\n\tobserved_placements += 1\n")
	source = source.replace("\t\t\tvar arrays: Array = bank_mesh.mesh.surface_get_arrays(surface)","\t\t\tobserved_readbacks += 1\n\t\t\tvar arrays: Array = bank_mesh.mesh.surface_get_arrays(surface)")
	source = source.replace("\t# One anchor per spatial bucket", "\tobserved_contact_builds += 1\n\t# One anchor per spatial bucket")
	source += "\nvar observed_placements: int = 0\nvar observed_readbacks: int = 0\nvar observed_contact_builds: int = 0\n"
	return script_from(source)

func pixels(a: Image,b: Image) -> Dictionary:
	var left := a.get_data(); var right := b.get_data()
	check(left.size() == right.size(),"image dimensions remain equal")
	var changed: int = 0; var maximum: int = 0
	for index: int in range(left.size()):
		var delta := absi(int(left[index])-int(right[index]))
		maximum = maxi(maximum,delta)
		if delta: changed += 1
	return {"changed_bytes":changed,"maximum":maximum}

func picture() -> Image:
	for frame: int in range(20): await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image(); result.convert(Image.FORMAT_RGBA8)
	return result

func winter(track: NativeTrack) -> void:
	var before := instrument_wind("res://tests/fixtures/racing_render_fixes_before/winter_snow_wind.gd.txt")
	var after := instrument_wind("res://track/winter_snow_wind.gd")
	var world := Node3D.new(); root.add_child(world)
	var visual := NativeTrackVisual.new(); world.add_child(visual)
	await visual.build(track,BridgePresentation.new(track))
	var camera := Camera3D.new(); world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 32
	camera.position = Vector3(-12,23,5); camera.look_at(Vector3(0,0,18)); camera.make_current()
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55,-25,0); world.add_child(light)
	var frames: Array[Image] = []; var metrics: Array = []
	for repetition: int in range(4):
		for original: bool in ([true,false] if repetition%2 == 0 else [false,true]):
			var wind = (before if original else after).new(); world.add_child(wind)
			var began := Time.get_ticks_usec(); wind.configure(track,visual)
			var build_ms := (Time.get_ticks_usec()-began)/1000.0
			var reads: int = wind.observed_readbacks
			check(not wind.surface_materials.is_empty(),"completed native world integrates snow on actual materials")
			if not original: check(reads == 0 and wind.anchors.is_empty(),"integrated snow skips all unused bank readbacks/anchors")
			wind.observed_placements = 0; began = Time.get_ticks_usec()
			for frame: int in range(600): wind.present(1.0/60.0,Vector2(frame*0.3,-18),0.8,false,false)
			var elapsed_ms := (Time.get_ticks_usec()-began)/1000.0
			if not original: check(wind.observed_placements == 0,"integrated snow performs no fallback placements")
			check(wind.ground.multimesh.visible_instance_count == 0 and wind.powder.multimesh.visible_instance_count == 0,"integrated snow retains zero fallback draws")
			metrics.append({"original":original,"configure_ms":build_ms,"readbacks":reads,"placements":wind.observed_placements,"600_present_ms":elapsed_ms})
			wind.reset()
			for frame: int in range(90): wind.present(1.0/60.0,Vector2(0,-18),0.8,false,false)
			if repetition == 0 and DisplayServer.get_name() != "headless": frames.append(await picture())
			wind.free()
	if not frames.is_empty():
		var comparison := pixels(frames[0],frames[1]); report.winter_pixels = comparison
		check(comparison.maximum == 0,"original and optimized native Winter pixels match exactly")
		frames[0].save_png(folder.path_join("winter-before.png")); frames[1].save_png(folder.path_join("winter-after.png"))
	report.winter_timings = metrics
	# Standalone worlds keep the complete original fallback, including uploads.
	var old = before.new(); var fresh = after.new(); world.add_child(old); world.add_child(fresh)
	old.configure(track); fresh.configure(track)
	check(old.anchors == fresh.anchors and not fresh.anchors.is_empty(),"standalone fallback retains original contact anchors")
	for frame: int in range(80):
		var focus := Vector2(frame*0.3,-18)
		old.present(1.0/60.0,focus,0.8,false,false); fresh.present(1.0/60.0,focus,0.8,false,false)
	check(old.ground.multimesh.buffer == fresh.ground.multimesh.buffer and old.powder.multimesh.buffer == fresh.powder.multimesh.buffer,"standalone fallback retains exact instance buffers")
	check(old.active_banks == fresh.active_banks and old.elapsed == fresh.elapsed and old.travel == fresh.travel,"standalone fallback retains selection and presentation clocks")
	old.free(); fresh.free()
	var empty := NativeTrack.new(); empty.metadata = {"theme":"winter"}
	var no_banks = after.new(); world.add_child(no_banks); no_banks.configure(empty)
	for frame: int in range(120): no_banks.present(1.0/60.0,Vector2.ZERO,0.8,false,false)
	check(no_banks.observed_contact_builds == 1 and no_banks.anchors.is_empty(),"empty bank preparation stays bounded to one scan")
	no_banks.free()
	# A sliced world can acquire integrated materials after fallback was used.
	var late := NativeTrackVisual.new(); world.add_child(late)
	var wind = after.new(); world.add_child(wind); wind.configure(track,late)
	wind.present(0.1,Vector2(0,-18),0.8,false,false)
	check(wind.ground.multimesh.visible_instance_count == 49,"unfinished world retains the fallback")
	await late.build(track,BridgePresentation.new(track))
	wind.present(0.25,Vector2(0,-18),0.8,false,false)
	check(not wind.surface_materials.is_empty() and wind.ground.multimesh.visible_instance_count == 0 and wind.powder.multimesh.visible_instance_count == 0,"late integration disables the original fallback immediately at refresh")
	check(wind.observed_readbacks == 0,"late integration avoids visual bank readbacks")
	# Replacing a bound owner with the same root child count must rebind safely.
	var binding: Dictionary = wind.surface_bindings[0]
	var removed: MeshInstance3D = binding.node.get_ref(); var parent := removed.get_parent()
	var replacement := MeshInstance3D.new(); replacement.mesh = removed.mesh
	replacement.material_override = binding.original if binding.surface < 0 else removed.get_active_material(binding.surface)
	parent.remove_child(removed); removed.free(); parent.add_child(replacement)
	wind.present(0.25,Vector2(0,-18),0.8,false,false)
	check(wind.surface_bindings.any(func(row: Dictionary) -> bool: return row.node.get_ref() == replacement),"same-count mesh replacement gets a fresh run-owned binding")
	# Removing integration and changing biome must not strand stale materials.
	for child: Node in late.get_children(): child.free()
	wind.present(0.25,Vector2(0,-18),0.8,false,false)
	check(wind.surface_materials.is_empty() and wind.ground.multimesh.visible_instance_count == 49,"removed integration restores fallback at the same focus")
	var saved: Array = [wind.elapsed,wind.travel,wind.active_banks.duplicate()]
	wind.present(1.0,Vector2(300,300),0.1,true,false)
	check(saved == [wind.elapsed,wind.travel,wind.active_banks],"pause retains the exact fallback clock and pose")
	wind.configure(track,visual); wind.reset()
	check(wind.ground.multimesh.visible_instance_count == 0 and wind.elapsed == 0.0,"retry keeps integrated fallback undrawn")
	# Clearing a per-surface material touches renderer instance uniforms; the
	# dummy backend rejects a null material. Exercise this on both real backends.
	if DisplayServer.get_name() != "headless":
		var holder := Node3D.new(); world.add_child(holder)
		var panel := MeshInstance3D.new(); var shape := BoxMesh.new()
		shape.material = wind.surface_materials[0].duplicate(); panel.mesh = shape; holder.add_child(panel)
		wind.configure(track,holder)
		check(wind.surface_bindings.size() == 1 and wind.surface_bindings[0].surface == 0,"standalone material slot integrates snow")
		panel.mesh = null; wind.present(0.25,Vector2(0,-18),0.8,false,false)
		check(wind.surface_materials.is_empty() and wind.ground.multimesh.visible_instance_count == 49,"missing mesh resource safely restores fallback")
		panel.mesh = shape; wind.present(0.25,Vector2(0,-18),0.8,false,false)
		check(wind.surface_bindings.size() == 1 and wind.ground.multimesh.visible_instance_count == 0,"same-node mesh restoration safely reinstalls integrated snow")
	world.free(); await process_frame

func mix(model: SurfaceAudioModel) -> Array:
	return [model.pavement,model.grass,model.sand,model.gravel,model.water,model.kerb,model.drive,model.acceleration,model.last_speed,model.has_speed]

func contact_equivalence() -> void:
	var archived := FileAccess.get_file_as_string("res://tests/fixtures/racing_render_fixes_before/surface_audio_model.gd.txt").replace("\r\n","\n")
	var raw := script_from(archived.substr(archived.find("\n")+1))
	var current := script_from("extends SurfaceAudioModel\nvar queries: int = 0\nfunc sample_contacts(state: VehicleState, track: NativeTrack, grounded: bool) -> void:\n\tqueries += 1\n\tsuper.sample_contacts(state,track,grounded)\n")
	var state := VehicleState.new(); var frame := DriveFrame.sample(0.2,0.7,0.0)
	var track := NativeTrack.new(); track.metadata = {"theme":"winter"}; track.cell_size = 1.0
	track.grid_width = 20; track.grid_height = 20; track.half_extent = Vector2(10,10)
	track.cells.resize(400); track.cells.fill(0); track.deck_cells.resize(400); track.deck_cells.fill(2)
	for id: String in VehicleCatalog.IDS:
		for theme: String in ["pine","desert","winter","storm","night_city"]:
			track.metadata.theme = theme
			var shared := SurfaceAudioModel.new(); var audio: SurfaceAudioModel = current.new(); var old = raw.new()
			var config := VehicleCatalog.config(id); shared.configure(config); audio.configure(config); old.configure(config)
			for step: int in range(12):
				state.tick = step; state.heading = step*0.2; state.velocity = Vector2(step,step*2)
				state.track_elevated = step%2 == 0; state.tire_water = (step%3)*0.13
				track.cells.fill(step%8)
				var grounded: bool = step%3 != 0
				shared.sample_contacts(state,track,grounded)
				audio.sample(state,frame,track,1.0/60.0,grounded,shared); old.sample(state,frame,track,1.0/60.0,grounded)
				check(mix(audio) == [old.pavement,old.grass,old.sand,old.gravel,old.water,old.kerb,old.drive,old.acceleration,old.last_speed,old.has_speed],"shared contact mix and smoothing remain exact across cars/biomes/layers")
			check(audio.queries == 0,"compatible explicit samples remove all redundant receiver queries")
			audio.sample(state,frame,track,1.0/60.0,false,shared)
			check(audio.contacts_grounded == false,"grounded predicate remains consumer-specific")
			shared.sample_contacts(state,track,true); audio.track_width += 0.1
			var count: int = audio.queries; audio.sample(state,frame,track,1.0/60.0,true,shared)
			check(audio.queries == count+1,"different wheel dimensions use original fresh contact sampling")
	# No result is retained across calls: edits at an unchanged tick are immediate.
	var model: SurfaceAudioModel = current.new(); state.track_elevated = false; state.position = Vector2.ZERO
	track.metadata.theme = "pine"; track.cells.fill(1); model.sample(state,frame,track,0.01,true)
	check(model.grass == 1.0,"initial edited soil is sampled")
	track.cells.fill(2); model.sample(state,frame,track,0.01,true)
	check(model.sand == 1.0 and model.grass == 0.0,"same-tick cell edits cannot reuse a prior result")
	model.reset(); model.sample(state,frame,track,0.01,true)
	check(model.sand == 1.0,"reset uses a fresh result")
	state.tick = 0; track.metadata.theme = "desert"; track.cells.fill(0); model.sample(state,frame,track,0.01,true)
	check(model.sand == 1.0,"rewind/theme edits use a fresh result")

func game_contacts(track: NativeTrack) -> void:
	var observer := script_from("extends SurfaceAudioModel\nvar queries: int = 0\nfunc sample_contacts(state: VehicleState, track: NativeTrack, grounded: bool) -> void:\n\tqueries += 1\n\tsuper.sample_contacts(state,track,grounded)\n")
	var game = load("res://core/game.tscn").instantiate()
	game.initial_track = track; game.ai_enabled = true; game.attempt_practice = true
	root.add_child(game); game.process_mode = Node.PROCESS_MODE_DISABLED
	var audio: SurfaceAudioModel = observer.new(); audio.configure(game.handling); game.vehicle_audio.surface_model = audio
	var finish: SurfaceAudioModel = observer.new(); finish.configure(game.handling); game.car_weathering.contacts = finish
	for frame: int in range(120):
		game._physics_process(1.0/120.0); game._physics_process(1.0/120.0); game._present_frame(1.0/60.0)
	var queries: int = audio.queries+finish.queries
	report.game_contacts = {"original_queries":479,"queries":queries,"physics_ticks":game.sim.state.tick,"rendered_frames":120,"note":"Fresh physics contacts remain; rendered weathering shares only its just-computed result with audio."}
	check(queries == 360 and game.sim.state.tick == 240,"actual game removes 119 duplicate presentation queries without skipping physics")
	game.restart(); game.countdown_ticks = 0; game._physics_process(1.0/120.0); game._present_frame(1.0/60.0)
	check(game.sim.state.tick == 1,"retry resumes ordinary fixed-step simulation")
	game.free(); await process_frame

func run() -> void:
	folder = folder.path_join("headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1280,720); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 0
	contact_equivalence(); var track := make_track(); await winter(track); await game_contacts(track)
	report.engine = Engine.get_version_info().string; report.renderer = RenderingServer.get_current_rendering_method()
	report.visual_version = NativeTrackVisual.VERSION; report.wind_version = WinterSnowWind.VERSION
	report.source_sha256 = {}
	for path: String in ["core/game.gd","track/winter_snow_wind.gd","vehicle/surface_audio_model.gd","vehicle/vehicle_audio.gd","vehicle/vehicle_weathering.gd"]:
		report.source_sha256[path] = FileAccess.get_file_as_string("res://"+path).sha256_text()
	report.checks = checks; report.failures = failures
	FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RACING_RENDER_FIXES: ",checks," checks, ",failures," failures")
	for frame: int in range(3): await process_frame
	quit(1 if failures else 0)

extends SceneTree
## Task-owned equivalence/culling/cache checks and alternating desktop profiles.
const BEFORE: String = "res://../build/biome-performance-followup-2026-10-13/before/"
var output: String = "res://../docs/evidence/biome-performance-followup-2026-10-13"
var checks: int = 0
var failures: int = 0
var report: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func legacy(path: String, classname: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(BEFORE+path).replace("\r\n","\n").replace("class_name "+classname+"\n","")
	check(script.reload() == OK,"saved pre-task " + classname + " compiles")
	return script

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	output += "/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	report = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"scope":"Explicit unscored fixtures; no account or score adapters"}
	await weathering()
	await trails()
	await preparation()
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BIOME_FOLLOWUP: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func bed(theme: String) -> NativeTrack:
	var track := NativeTrack.new()
	track.metadata = {"theme":theme}
	track.cell_size = 10.0
	track.grid_width = 20
	track.grid_height = 20
	track.half_extent = Vector2(100,100)
	track.cells.resize(400)
	track.cells.fill(2 if theme == "desert" else 0)
	track.deck_cells.resize(400)
	track.deck_cells.fill(-1)
	return track

func weathering() -> void:
	var old: GDScript = legacy("game/vehicle/vehicle_weathering.gd","VehicleWeathering")
	var profiles: Array[Dictionary] = []
	for id: String in VehicleCatalog.IDS:
		var left := CarVisual.new()
		var right := CarVisual.new()
		left.vehicle_id = id
		right.vehicle_id = id
		root.add_child(left)
		root.add_child(right)
		for theme: String in ["winter","desert"]:
			var before: RefCounted = old.new()
			var after := VehicleWeathering.new()
			before.configure(left,theme,VehicleCatalog.config(id))
			after.configure(right,theme,VehicleCatalog.config(id))
			var track: NativeTrack = bed(theme)
			var state := VehicleState.new()
			state.velocity = Vector2(0,20)
			for tick: int in range(1,601):
				state.tick = tick
				before.present(state,track,false)
				after.present(state,track,false)
				if tick%60 == 0:
					check(before.snapshot() == after.snapshot(),id+" "+theme+" exact local condition state")
			var retained: Dictionary = after.snapshot()
			before.restore(retained)
			after.restore(retained)
			before.melt(0.73)
			after.melt(0.73)
			before.wash(Vector3.ZERO,0.3)
			after.wash(Vector3.ZERO,0.3)
			check(before.snapshot() == after.snapshot(),id+" exact melt/wash/restore")
			var uploads: int = after.parameter_uploads
			for repeat: int in range(20): after._update_finish()
			check(after.parameter_uploads == uploads,"unchanged finish values perform no uploads")
			var timings: Array[Dictionary] = []
			for label: String in ["before","after","before","after"]:
				var effect: RefCounted = before if label == "before" else after
				var start: int = Time.get_ticks_usec()
				for repeat: int in range(1000): effect._update_finish()
				timings.append({"mode":label,"us_per_unchanged_update":float(Time.get_ticks_usec()-start)/1000.0})
			profiles.append({"car":id,"theme":theme,"materials":after.materials.size(),"stages":timings})
			before.reset()
			after.reset()
		left.free()
		right.free()
	report["weathering"] = profiles
	print("FOLLOWUP_WEATHERING: five cars, exact state and unchanged-upload checks complete")

func trails() -> void:
	var old: GDScript = legacy("game/vehicle/skid_trails.gd","SkidTrails")
	var before: Node3D = old.new()
	var after := SkidTrails.new()
	root.add_child(before)
	root.add_child(after)
	var stages: Array[Dictionary] = []
	for index: int in range(SkidTrails.CAPACITY+37):
		var page: int = (index%SkidTrails.CAPACITY)/TrailVisibility.PAGE_SIZE
		var local: int = index%TrailVisibility.PAGE_SIZE
		var x: float = (local%32-16)*0.4 + page*140.0
		var z: float = (local/32-8)*0.55
		var a := Vector3(x,0.028,z)
		var b: Vector3 = a+Vector3(0.16,0,0.27)
		var strength: float = 0.15 + (local%7)*0.1
		before._mark(a,b,0.3,index%3,strength)
		after._mark(a,b,0.3,index%3,strength)
	print("FOLLOWUP_RING_PARITY: cursor=",before.cursor == after.cursor," transforms=",before.mark_transforms == after.mark_transforms," colours=",before.mark_colors == after.mark_colors," custom=",before.mark_custom == after.mark_custom)
	for index: int in range(SkidTrails.CAPACITY):
		if before.mark_transforms[index] != after.mark_transforms[index]:
			print("FOLLOWUP_RING_FIRST_DIFFERENCE: ",index," before=",before.mark_transforms[index]," after=",after.mark_transforms[index])
			break
	check(before.cursor == after.cursor and before.mark_transforms == after.mark_transforms and before.mark_colors == after.mark_colors and before.mark_custom == after.mark_custom,"complete ring overwrite preserves all segment state")
	check(after.trail_visibility.retained_count == SkidTrails.CAPACITY,"offscreen marks remain stored at original ring capacity")
	check(after.instances.instance_count == SkidTrails.CAPACITY and after.get_child_count() == 1,"single GPU draw and allocation retain the original fixed ring budget")
	var cpu: Dictionary = {}
	var state := VehicleState.new()
	var input := DriveFrame.sample(0,0,1)
	for effect: Node3D in [before,after]:
		var values: Array[float] = []
		for repeat: int in range(3):
			effect.clear()
			var start: int = Time.get_ticks_usec()
			for index: int in range(2000):
				var angle: float = index*0.02
				state.position = Vector2(sin(angle),cos(angle))*22.0
				state.heading = angle+PI*0.5
				state.velocity = state.forward()*25.0+state.right()*8.0
				effect.sample(state,input)
			values.append(float(Time.get_ticks_usec()-start)/2000.0)
		values.sort()
		cpu["before" if effect == before else "after"] = values[1]
	report["trail_sampling_us"] = cpu
	print("FOLLOWUP_TRAIL_SAMPLE_US: ",JSON.stringify(cpu))
	# Restore the exact wide-field ring after the isolated emission benchmark.
	before.clear()
	after.clear()
	for index: int in range(SkidTrails.CAPACITY):
		var page: int = index/TrailVisibility.PAGE_SIZE
		var local: int = index%TrailVisibility.PAGE_SIZE
		var a := Vector3((local%32-16)*0.4+page*140.0,0.028,(local/32-8)*0.55)
		before._mark(a,a+Vector3(0.16,0,0.27),0.3,index%3,0.15+(local%7)*0.1)
		after._mark(a,a+Vector3(0.16,0,0.27),0.3,index%3,0.15+(local%7)*0.1)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1600,900)
		root.content_scale_size = root.size
		root.msaa_3d = Viewport.MSAA_2X
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 24
		camera.position = Vector3(0,20,15)
		camera.look_at(Vector3.ZERO)
		var light := DirectionalLight3D.new()
		root.add_child(light)
		light.rotation_degrees = Vector3(-58,-35,0)
		var environment := WorldEnvironment.new()
		root.add_child(environment)
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.2,0.2,0.2)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_energy = 0.5
		var ground := MeshInstance3D.new()
		ground.mesh = PlaneMesh.new()
		ground.mesh.size = Vector2(30,30)
		ground.material_override = VisualGeometry.material(Color(0.65,0.67,0.68))
		root.add_child(ground)
		var saved: Array[Transform3D] = after.mark_transforms.duplicate()
		var counts: Array[int] = []
		for position: float in [0.0,1400.0,0.0]:
			camera.position = Vector3(position,20,15)
			camera.look_at(Vector3(position,0,0))
			after.trail_visibility.present(camera,after.mark_colors,after.mark_custom)
			counts.append(after.instances.visible_instance_count)
			check(counts[-1] > 0 and counts[-1] <= TrailVisibility.PAGE_SIZE*2,"conservative frustum groups retain local marks and cull remote marks")
			if position == 1400.0:
				check(after.instances.get_instance_transform(0).is_equal_approx(after.mark_transforms[5120]),"compacted remote group uploads its exact ribbon transform")
				print("FOLLOWUP_REMOTE_BUFFER: colour=",after.instances.get_instance_color(0)," reference=",before.instances.get_instance_color(5120)," custom=",after.instances.get_instance_custom_data(0)," reference_custom=",before.instances.get_instance_custom_data(5120))
				check(after.instances.get_instance_color(0).is_equal_approx(before.instances.get_instance_color(5120)),"compacted remote group preserves renderer pigment precision")
				check(after.instances.get_instance_custom_data(0).is_equal_approx(before.instances.get_instance_custom_data(5120)),"compacted remote group preserves renderer endpoint-pressure precision")
		check(after.mark_transforms == saved and counts[0] == counts[2],"moving away and returning restores the same retained marks")
		camera.position = Vector3(0,20,15)
		camera.look_at(Vector3.ZERO)
		var viewport: RID = root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(viewport,true)
		var images: Array[Image] = []
		for label: String in ["before","after","before","after"]:
			before.visible = label == "before"
			after.visible = label == "after"
			await measure(viewport,0.5)
			var stage: Dictionary = await measure(viewport,1.0)
			stage["mode"] = label
			stage["retained"] = after.trail_visibility.retained_count
			stage["submitted"] = after.instances.visible_instance_count if label == "after" else before.instances.visible_instance_count
			stages.append(stage)
			var captured: Image = root.get_texture().get_image()
			captured.convert(Image.FORMAT_RGBA8)
			captured.save_png(output+"/trails-"+label+".png")
			if images.size() < 3: images.append(captured)
			print("FOLLOWUP_TRAIL_STAGE: ",JSON.stringify(stage))
		var delta: Dictionary = pixel_delta(images[0],images[1])
		check(delta.maximum <= 2,"culled trail pages preserve visible pixels within 2/255")
		check(pixel_delta(images[0],images[2]).changed == 0,"trail reference pixels are stable")
		report["trail_pixels"] = delta
		after.clear()
		for index: int in range(1024):
			var a := Vector3((index%16)*0.3+(0.0 if index < 512 else 1400.0),0.028,(index%32)*0.1)
			after._mark(a,a+Vector3(0,0,0.3),0.3,2,0.8)
		after.trail_visibility.present(camera,after.mark_colors,after.mark_custom)
		check(after.instances.visible_instance_count == 512 and after.trail_visibility.retained_count == 1024,"draw view retains a separate full stored count")
		after._mark(Vector3(0,0.028,1),Vector3(0,0.028,1.3),0.3,2,0.8)
		after.trail_visibility.present(camera,after.mark_colors,after.mark_custom)
		check(after.instances.visible_instance_count == 513 and after.instances.get_instance_transform(512).is_equal_approx(after.mark_transforms[1024]),"new occupied visible group appears immediately after compaction")
		after._mark(Vector3(1,0.028,1),Vector3(1,0.028,1.3),0.3,2,0.8)
		after.trail_visibility.present(camera,after.mark_colors,after.mark_custom)
		check(after.instances.visible_instance_count == 514 and after.instances.get_instance_transform(513).is_equal_approx(after.mark_transforms[1025]),"append to a compacted partial group extends its draw count")
		after.clear()
		check(after.instances.visible_instance_count == 0 and after.trail_visibility.retained_count == 0,"attempt reset clears storage and compacted visibility immediately")
		camera.free()
		light.free()
		environment.free()
		ground.free()
	report["trail_stages"] = stages
	before.free()
	after.free()

func preparation() -> void:
	var worlds = NativeTrackVisual.PREPARED_WORLDS
	var rows: Array[Dictionary] = []
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	for theme: String in ["winter","desert"]:
		worlds.entries.clear()
		NativeTrackVisual._road_mesh_cache.clear()
		var doc: Dictionary = TrackDocument.create_default()
		doc.theme = theme
		var track: NativeTrack = TrackCompiler.compile(doc)
		var cells: PackedInt32Array = track.cells.duplicate()
		var preview := NativeTrackVisual.new()
		preview.cache_race_world = true
		root.add_child(preview)
		var start: int = Time.get_ticks_usec()
		await preview.build(track,BridgePresentation.new(track),true)
		var preview_ms: float = float(Time.get_ticks_usec()-start)/1000.0
		check(worlds.entries.size() == 1,"sliced preview admits a completed prepared world")
		var expected: PackedByteArray = mesh_digest(preview)
		var uncached := NativeTrackVisual.new()
		root.add_child(uncached)
		start = Time.get_ticks_usec()
		await uncached.build(track,BridgePresentation.new(track))
		var uncached_ms: float = float(Time.get_ticks_usec()-start)/1000.0
		var race := NativeTrackVisual.new()
		race.cache_race_world = true
		root.add_child(race)
		start = Time.get_ticks_usec()
		await race.build(track,BridgePresentation.new(track))
		var reused_ms: float = float(Time.get_ticks_usec()-start)/1000.0
		check(mesh_digest(race) == expected and mesh_digest(uncached) == expected,"preview/cold/reused mesh buffers exactly agree")
		check(track.cells == cells,"presentation reuse leaves canonical cells unchanged")
		check(race.light_instances.size() == preview.light_instances.size(),"prepared props bind to fresh race nodes")
		if not preview.light_instances.is_empty():
			var original: Vector3 = race.light_instances[0].position
			preview.light_instances[0].position += Vector3.ONE*10
			check(race.light_instances[0].position == original,"preview and race props remain isolated")
		rows.append({"theme":theme,"preview_build_ms":preview_ms,"first_race_without_world_reuse_ms":uncached_ms,"first_race_using_preview_ms":reused_ms,"cache_bytes":worlds.entries[0].bytes,"note":"Road resources already exist from preview in both first-race paths; measures reuse of prepared terrain/scenery, not a fresh-install cold build."})
		preview.free()
		uncached.free()
		race.free()
		print("FOLLOWUP_PREPARATION: ",JSON.stringify(rows[-1]))
	report["preparation"] = rows
	worlds.entries.clear()

func mesh_digest(visual: Node) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for node: Node in visual.find_children("*","MeshInstance3D",true,false):
		hash.update(var_to_bytes(node.transform))
		for surface: int in range(node.mesh.get_surface_count()): hash.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
	return hash.finish()

func pixel_delta(a: Image, b: Image) -> Dictionary:
	var maximum: int = 0
	var changed: int = 0
	var left: PackedByteArray = a.get_data()
	var right: PackedByteArray = b.get_data()
	for pixel: int in range(a.get_width()*a.get_height()):
		var difference: int = 0
		for channel: int in range(3): difference = maxi(difference,absi(left[pixel*4+channel]-right[pixel*4+channel]))
		maximum = maxi(maximum,difference)
		if difference > 0: changed += 1
	return {"maximum":maximum,"changed":changed}

func measure(viewport: RID, duration: float) -> Dictionary:
	var frames: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	while Time.get_ticks_usec()-start < duration*1000000.0:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		previous = now
	frames.sort()
	gpu.sort()
	cpu.sort()
	return {"frame_ms":frames[frames.size()/2],"gpu_ms":gpu[gpu.size()/2],"render_cpu_ms":cpu[cpu.size()/2],"samples":frames.size(),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}

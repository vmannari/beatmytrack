extends "res://tests/test_winter_snow_wind.gd"
var ENV_OUT: String = "res://../docs/evidence/winter-soft-ice-raised-banks-2026-10-11"+("/mobile" if RenderingServer.get_current_rendering_method() == "mobile" else "")

func run() -> void:
	var track: NativeTrack = super.make_track()
	var markers: Array[Dictionary] = WinterScenery.marker_sites(track)
	check(markers.size() > 0 and markers.size() <= 40,"bounded and sparse distance-based marker stakes")
	var spacing_ok: bool = true
	for i: int in range(markers.size()):
		for j: int in range(i):
			var a: Dictionary = markers[i]
			var b: Dictionary = markers[j]
			var minimum: float = maxf(a.spacing,b.spacing) if a.side == b.side else 7.5
			if a.position.distance_to(b.position) < minimum: spacing_ok = false
	check(spacing_ok,"marker spacing respects longer inner-curve clearance")
	var bank := NativeTrackVisual.new()
	var join_ok: bool = true
	for p: Vector2 in [Vector2.ZERO,Vector2(11,23),Vector2(-31,12)]:
		if bank._winter_pile_height(p,1.0) >= -0.06 or absf(bank._winter_pile_height(p,1.0)-bank._winter_pile_height(p,0.999)) > 0.001: join_ok = false
	check(join_ok,"bank apron meets terrain below its surface with a flat outer slope")
	bank.free()
	print("WINTER_MARKERS: ",markers.size())
	var artwork: Image = NativeTrackVisual.WINTER_ICE.get_image()
	var finish: Image = NativeTrackVisual.WINTER_ICE_FINISH.get_image()
	print("WINTER_TEXTURES: ",artwork.get_size()," mips=",artwork.has_mipmaps()," finish=",finish.get_size()," mips=",finish.has_mipmaps())
	check(artwork.get_width() <= 1024 and artwork.has_mipmaps(),"ice artwork is capped and mipmapped")
	check(finish.get_width() == 512 and finish.has_mipmaps(),"packed ice finish data is a bounded mipmapped texture")
	var scenery: Array = track.metadata.scenery_objects
	check(scenery.size() > 10 and scenery.size() <= 48,"bounded automatic Winter scenery on a creator circuit")
	var kinds: Dictionary = {}
	for object: Dictionary in scenery:
		kinds[object.kind] = true
		var point := Vector2(object.position[0],object.position[1])
		check(track.cell_at(point) == 4,"automatic Winter prop has a real collision footprint")
		check(not CreatorBridges.at_any(track.creator_bridges,point),"Winter prop avoids bridge decks")
	check(kinds.has("tree") and kinds.has("boulder") and kinds.has("fence"),"automatic spruce, boulder and wooden fence mix")
	var document: Dictionary = track.metadata.creator_document.duplicate(true)
	var target: Dictionary = scenery[0]
	document.hidden_scenery = [CreatorScenery.key(target)]
	document = JSON.parse_string(JSON.stringify(document))
	print("WINTER_HIDDEN_VALIDATION: ",TrackDocument.validate(document))
	var hidden: NativeTrack = TrackCompiler.compile(document)
	check(hidden.cell_at(Vector2(target.position[0],target.position[1])) != 4,"deleted scenery stays deleted after recompile")
	check(hidden.metadata.scenery_objects.size() == scenery.size()-1,"deletion preserves the other generated props")
	var cached: Dictionary = {"enabled":true}
	var first: NativeTrack = TrackCompiler.compile(document,cached)
	var second: NativeTrack = TrackCompiler.compile(document,cached)
	check(first.cells == second.cells and first.content_hash == second.content_hash,"preview cache and fresh compilation agree exactly")
	for path: String in ["res://tests/fixtures/spline_circuit.json","res://../backend/tests/fixtures/bridge_junction.json"]:
		var alternate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		alternate.theme = "winter"
		var compiled: NativeTrack = TrackCompiler.compile(alternate)
		check(compiled != null and not compiled.metadata.scenery_objects.is_empty(),"automatic Winter scenery adapts to "+path.get_file())
		var clear: bool = true
		for object: Dictionary in compiled.metadata.scenery_objects:
			var center := Vector2(object.position[0],object.position[1])
			for x: float in [-3.2,0.0,3.2]:
				for y: float in [-3.2,0.0,3.2]:
					var point: Vector2 = center+Vector2(x,y)
					if compiled.cell_at(point) in [0,2,3,6] or CreatorBridges.at_any(compiled.creator_bridges,point): clear = false
		check(clear,"Winter scenery clears actual road and bridge footprints on "+path.get_file())
	var approach := VehicleSimulation.new(VehicleCatalog.config("compact"))
	var at := Vector2(target.position[0],target.position[1])
	approach.reset(at-Vector2(0,4))
	approach.state.velocity = Vector2(0,8)
	for i: int in range(120): approach.step(DriveFrame.sample(0,1,0),track)
	check(approach.state.collision_count > 0,"generated Winter obstacle stops a driving car")
	var canvas := EditorCanvas.new()
	canvas.document = track.metadata.creator_document.duplicate(true)
	canvas.native_preview = track
	canvas.mode = "objects"
	root.add_child(canvas)
	canvas._begin(canvas.to_screen(at),-1)
	canvas._end(-1)
	check(canvas.selected_object >= 0 and canvas.document.hidden_scenery.has(CreatorScenery.key(target)),"Winter scenery can be selected and adopted into the creator document")
	canvas.document.objects.remove_at(canvas.selected_object)
	var removed: NativeTrack = TrackCompiler.compile(JSON.parse_string(JSON.stringify(canvas.document)))
	check(removed.cell_at(at) != 4,"creator deletion removes the Winter collider")
	canvas.queue_free()
	await process_frame
	await super.run()

func make_track() -> NativeTrack:
	var track: NativeTrack = super.make_track()
	var document: Dictionary = track.metadata.creator_document.duplicate(true)
	for point: Vector2 in [Vector2(30,0),Vector2(34,5),Vector2(24,8),Vector2(23,-6),Vector2(39,23),Vector2(50,25),Vector2(58,7),Vector2(64,-5),Vector2(60,-19),Vector2(36,-28),Vector2(4,-29),Vector2(-9,0)]:
		document.objects.append({"kind":"tree","position":[point.x,point.y],"rotation":fposmod(point.x*7.0,360.0),"scale":0.72+fposmod(point.x,4.0)*0.16})
	for point: Vector2 in [Vector2(33,-5),Vector2(23,3),Vector2(51,20),Vector2(35,-29)]:
		document.objects.append({"kind":"boulder","position":[point.x,point.y],"rotation":point.x,"scale":0.70})
	document.objects.append({"kind":"fence","position":[62,13],"rotation":90.0,"length":9.0,"scale":1.0})
	document = JSON.parse_string(JSON.stringify(document))
	print("WINTER_FIXTURE_VALIDATION: ",TrackDocument.validate(document))
	return TrackCompiler.compile(document)

func capture(game: Node, fx: WinterSnowWind) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ENV_OUT))
	root.size = Vector2i(1280,720)
	var focus := Vector3(34,0,10)
	game.camera.position = focus + Vector3(0,20,15)
	game.camera.look_at(focus)
	game.camera.size = 36.0
	fx.present(1.0,Vector2(34,-10),1.0,false,false)
	for i: int in range(8): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ENV_OUT+"/bend.png") == OK,"Winter environment bend capture")
	fx.visible = false
	for i: int in range(3): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ENV_OUT+"/materials.png")
	fx.visible = true
	game.camera.position = focus+Vector3(22,20,0)
	game.camera.look_at(focus)
	for i: int in range(3): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ENV_OUT+"/rotated.png")
	game.camera.follow(game.sim.state.position,Vector2.ZERO,game.sim.state.heading,1.0)
	game.call("_process",0.0)
	for i: int in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ENV_OUT+"/gameplay.png")
	root.size = Vector2i(960,540)
	for i: int in range(4): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ENV_OUT+"/compact.png")
	print("WINTER_ENVIRONMENT_RENDER: draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if "--video" in OS.get_cmdline_user_args(): await environment_motion(game,fx)
	if "--profile" in OS.get_cmdline_user_args(): await environment_profile(fx)

func environment_profile(fx: WinterSnowWind) -> void:
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var passes: Array[Dictionary] = []
	for enabled: bool in [false,true,true,false]:
		fx.visible = enabled
		for i: int in range(20): await RenderingServer.frame_post_draw
		var gpu: Array[float] = []
		var cpu: Array[float] = []
		for i: int in range(60):
			await RenderingServer.frame_post_draw
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		gpu.sort(); cpu.sort()
		passes.append({"wind_enabled":enabled,"gpu_ms_median":gpu[30],"gpu_ms_p95":gpu[57],"cpu_ms_median":cpu[30],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	fx.visible = true
	var output := FileAccess.open(ENV_OUT+"/profile-"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"device":RenderingServer.get_video_adapter_name(),"viewport":[root.size.x,root.size.y],"passes":passes},"\t"))
	print("WINTER_ENVIRONMENT_PROFILE: ",JSON.stringify(passes))

func environment_motion(game: Node, fx: WinterSnowWind) -> void:
	var original: VehicleSimulation = game.sim
	var drive := VehicleSimulation.new(game.handling)
	drive.reset(Vector2(24,-18),PI*0.5)
	var driver := RouteDriver.new()
	game.sim = drive
	game.paused = false
	var frames: Array[String] = []
	for frame: int in range(150):
		var input := DriveFrame.new()
		for tick: int in range(4):
			input = driver.sample(drive.state,game.native_track,game.handling)
			drive.step(input,game.native_track)
			game.trails.sample(drive.state,input,game.bridge_presentation,game.native_track)
			game.sand_dust.sample(drive.state,input,game.native_track,game.bridge_presentation)
		game.previous_position = drive.state.position
		game.previous_heading = drive.state.heading
		game.frame = input
		fx.present(1.0/30.0,drive.state.position,1.0 if frame < 100 else 0.0,false,false)
		game.call("_process",0.0)
		game.camera.follow(drive.state.position,drive.state.velocity,drive.state.heading,1.0/30.0)
		game.hud.update_values(drive.state,input,1.0/30.0,false,false)
		await RenderingServer.frame_post_draw
		frames.append("data:image/jpeg;base64,"+Marshalls.raw_to_base64(root.get_texture().get_image().save_jpg_to_buffer(0.92)))
		if frame == 135: root.get_texture().get_image().save_png(ENV_OUT+"/driving.png")
	check(game.trails.instances.visible_instance_count > 0,"real driving leaves layered Winter tire marks")
	var output := FileAccess.open(ENV_OUT+"/driving-motion.html",FileAccess.WRITE)
	output.store_string("<!doctype html><meta charset='utf-8'><title>Winter environment review</title><style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:1100px;margin:32px auto}img{width:100%}button{padding:10px;margin:12px 0}</style><p>Actual Godot render and canonical driving fixture · normal camera · 5 seconds at 30 fps</p><img id='view'><button id='toggle'>Pause</button><script>const frames="+JSON.stringify(frames)+";let frame=0,playing=true;const view=document.getElementById('view'),button=document.getElementById('toggle');view.src=frames[0];button.onclick=()=>{playing=!playing;button.textContent=playing?'Pause':'Play'};setInterval(()=>{if(playing){frame=(frame+1)%frames.length;view.src=frames[frame]}},1000/30)</script>")
	output.close()
	game.sim = original
	game.paused = true
	game.frame = DriveFrame.new()
	game.trails.clear()

extends SceneTree
const OLD_SIM = preload("res://tests/fixtures/snow_bank_simulation_055.gd")
const OLD_BANKS = preload("res://tests/fixtures/soft_snow_banks_055.gd")
var checks: int = 0
var failures: int = 0
var measurements: Array[Dictionary] = []
var output: String = "res://../docs/evidence/winter-snow-clouds-2026-10-12"

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=").trim_suffix("/")
	run.call_deferred()

func make_track(soft: bool = false) -> NativeTrack:
	var track := NativeTrack.new()
	track.cell_size = 0.5
	track.grid_width = 80
	track.grid_height = 80
	track.half_extent = Vector2(20,20)
	track.cells.resize(6400)
	track.deck_cells.resize(6400)
	track.cells.fill(1)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-18),Vector2(0,18)])
	track.metadata = {"theme":"winter"}
	for y: int in range(80):
		for x: int in range(30,50): track.cells[y*80+x] = 0
	if soft: track.snow_banks = OLD_BANKS.new()
	track.snow_banks.build(track)
	return track

func run() -> void:
	if RenderingServer.get_current_rendering_method() == "mobile": output += "/mobile"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var track: NativeTrack = make_track()
	var old: NativeTrack = make_track(true)
	check(var_to_bytes(track.snow_banks.triangles) == var_to_bytes(old.snow_banks.triangles),"packed banks retain exact prepared contact geometry")
	check_height_index(track)
	for car: String in VehicleCatalog.IDS:
		measure_car(car,track,old)
		replay_and_rewind(car,track)
		unchanged_off_bank(car)
	await presentation(track)
	profile_contact(track,old)
	if "--capture" in OS.get_cmdline_user_args(): await capture_motion()
	var file := FileAccess.open(output+"/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"physics":VehicleSimulation.PHYSICS_VERSION,"cars":measurements,"checks":checks,"failures":failures},"\t"))
	print("SNOW_BANK_BEHAVIOUR: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func measure_car(car: String, track: NativeTrack, old: NativeTrack) -> void:
	var config: HandlingConfig = VehicleCatalog.config(car)
	var impact := VehicleSimulation.new(config)
	var prior := VehicleSimulation.new(config)
	impact.reset(Vector2(3.8,10),PI*0.5)
	prior.reset(impact.state.position,impact.state.heading)
	impact.state.velocity = Vector2(20,0)
	prior.state.velocity = impact.state.velocity
	for tick: int in range(36):
		impact.step(DriveFrame.new(),track)
		prior.step(DriveFrame.new(),old)
	check(impact.state.velocity.length() < prior.state.velocity.length()*0.5,car+" packed impact removes over twice the speed of old soft bank")
	check(impact.state.velocity.x >= 0.0 and impact.state.collision_count == 0,car+" packed snow dissipates without wall bounce/crash")
	var crawl := VehicleSimulation.new(config)
	var soft_crawl := VehicleSimulation.new(config)
	crawl.reset(Vector2(5.6,8))
	soft_crawl.reset(crawl.state.position)
	for tick: int in range(240):
		crawl.step(DriveFrame.sample(0,1,0),track)
		soft_crawl.step(DriveFrame.sample(0,1,0),old)
	var crawl_distance: float = crawl.state.position.y-8.0
	var old_distance: float = soft_crawl.state.position.y-8.0
	check(crawl_distance > 0.25 and crawl_distance < old_distance*0.5,car+" crawling through bank is difficult but powered movement remains")
	var escape := VehicleSimulation.new(config)
	escape.reset(Vector2(4.8,10),PI*0.5)
	for tick: int in range(960): escape.step(DriveFrame.sample(0,1,0),track)
	check(escape.state.position.x > 8.0,car+" can power out of packed bank from rest")
	var reverse := VehicleSimulation.new(config)
	reverse.reset(Vector2(5.6,10),PI*0.5)
	for tick: int in range(960): reverse.step(DriveFrame.sample(0,0,1),track)
	check(reverse.state.position.x < 3.2,car+" can reverse back onto ice without being permanently stranded")
	for direction: float in [0.0,PI*0.5,PI,-PI*0.5]:
		var state := VehicleState.new()
		state.position = Vector2(5.6,10)
		state.velocity = Vector2.from_angle(direction)*20.0
		var before: Vector2 = state.velocity
		track.snow_banks.slow_car(state,state.position,config,VehicleSimulation.STEP)
		check(state.velocity.length() < before.length() and state.velocity.dot(before) >= 0.0,car+" snow drag dissipates every travel direction")
	for lifted: bool in [false,true]:
		var state := VehicleState.new()
		state.position = Vector2(5.6,10)
		state.velocity = Vector2(20,0)
		state.track_elevated = lifted
		state.jump_height = 0.0 if lifted else 1.0
		track.snow_banks.slow_car(state,state.position,config,VehicleSimulation.STEP)
		check(state.velocity == Vector2(20,0),car+" airborne/elevated car misses ground banks")
	measurements.append({"car":car,"entry_mps":20,"impact_after_0_3s_mps":impact.state.velocity.length(),"old_impact_mps":prior.state.velocity.length(),"crawl_2s_m":crawl_distance,"old_crawl_2s_m":old_distance,"escape_8s_x":escape.state.position.x,"reverse_8s_x":reverse.state.position.x})
	print("PACKED_SNOW_METRIC: ",JSON.stringify(measurements[-1]))

func check_height_index(track: NativeTrack) -> void:
	var original := RoadKerbs.new()
	for key: String in ["triangles","buckets","blocked","extent","cell_size","grid","maximum_height"]:
		original.set(key,track.snow_banks.get(key))
	for x: int in range(-72,73):
		for y: int in range(-46,47):
			var at := Vector2(float(x)*0.1,float(y)*0.4)
			check(track.snow_banks.height_at(at) == original.height_at(at),"fine bank index preserves exact legacy height at dense samples")
	for triangle: Dictionary in track.snow_banks.triangles:
		for point: Vector2 in triangle.points:
			check(track.snow_banks.height_at(point) == original.height_at(point),"fine bank index preserves exact triangle boundaries")
	var index: Dictionary = track.snow_banks._contact_buckets
	track.snow_banks._contact_buckets = {}
	check(track.snow_banks.height_at(Vector2(5.6,10)) == original.height_at(Vector2(5.6,10)),"old prepared snapshots without derived index retain exact contacts")
	track.snow_banks._contact_buckets = index

func replay_and_rewind(car: String, track: NativeTrack) -> void:
	var config: HandlingConfig = VehicleCatalog.config(car)
	var first := VehicleSimulation.new(config)
	first.reset(Vector2(3.8,10),PI*0.5)
	first.state.velocity = Vector2(20,0)
	var history := RewindHistory.new()
	var session := TrackSession.new()
	var captured: Dictionary = {}
	var frames: Array = []
	var states: Array = []
	for tick: int in range(720):
		var frame: DriveFrame = DriveFrame.sample(0,1 if tick < 360 else 0,1 if tick >= 360 else 0)
		frames.append(frame.packed())
		first.step(frame,track)
		states.append(first.state.snapshot())
		if tick == 23:
			history.capture(first.state,session)
			captured = history.entries[-1].duplicate(true)
	var decoded: Array = JSON.parse_string(JSON.stringify(frames))
	for batch: int in [1,2,4,8]:
		var replay := VehicleSimulation.new(config)
		replay.reset(Vector2(3.8,10),PI*0.5)
		replay.state.velocity = Vector2(20,0)
		for start: int in range(0,720,batch):
			for index: int in range(start,mini(start+batch,720)):
				var frame := DriveFrame.new()
				frame.steer = int(decoded[index][0]); frame.throttle = int(decoded[index][1]); frame.brake = int(decoded[index][2])
				replay.step(frame,track)
				check(replay.state.snapshot() == states[index],car+" packed-bank JSON trajectory exact at batch "+str(batch))
	var resumed := VehicleSimulation.new(config)
	RewindHistory.restore(resumed.state,captured.state)
	for index: int in range(24,720):
		var frame := DriveFrame.new()
		frame.steer = int(decoded[index][0]); frame.throttle = int(decoded[index][1]); frame.brake = int(decoded[index][2])
		resumed.step(frame,track)
		check(resumed.state.snapshot() == states[index],car+" rewind from packed-bank impact reproduces exact future")

func unchanged_off_bank(car: String) -> void:
	var config: HandlingConfig = VehicleCatalog.config(car)
	for theme: String in ["pine","desert","storm","night_city","winter"]:
		var track := NativeTrack.new()
		track.grid_width = 2; track.grid_height = 2; track.cell_size = 1000
		track.half_extent = Vector2(1000,1000)
		track.cells = PackedInt32Array([0,0,0,0]); track.deck_cells = PackedInt32Array([-1,-1,-1,-1])
		track.route = PackedVector2Array([Vector2(0,-900),Vector2(0,900)])
		track.metadata = {"theme":theme}
		var current := VehicleSimulation.new(config)
		var prior: RefCounted = OLD_SIM.new(config)
		for tick: int in range(360):
			var frame: DriveFrame = DriveFrame.sample(0.3 if tick > 100 else 0,1 if tick < 240 else 0,1 if tick >= 240 else 0)
			current.step(frame,track); prior.step(frame,track)
			check(current.state.snapshot() == prior.state.snapshot(),car+" off-bank "+theme+" physics exactly matches55")

func presentation(track: NativeTrack) -> void:
	var effects := SandDust.new()
	root.add_child(effects)
	var state := VehicleState.new()
	state.position = Vector2(3.9,10)
	state.heading = PI*0.5
	state.velocity = Vector2(0.3,0)
	var before: Array = state.snapshot()
	effects.sample(state,DriveFrame.sample(0,1,0),track)
	check(state.snapshot() == before,"pushed-snow presentation never mutates canonical state")
	check(effects.snow_push.size() == 2 and effects.snow_push[0].emitting,"slow bumper contact pushes snow below previous0.8m/s threshold")
	check(track.snow_banks.height_at(effects.snow_push_position) > 0.035,"push emission attaches to actual bank contact")
	check(effects.snow_push[0].amount+effects.snow_push[1].amount <= 48,"pushed snow has bounded48-fragment pool")
	check(effects.snow_push[0].draw_pass_1 is ArrayMesh and bool(effects.snow_push[0].draw_pass_1.surface_get_material(0).get_shader_parameter("billowing")),"pushed snow uses the textured cloud renderer requested by owner")
	var first: ParticleProcessMaterial = effects.snow_push[0].process_material
	var second: ParticleProcessMaterial = effects.snow_push[1].process_material
	check(first.gravity.y < 0.0 and effects.snow_push[0].lifetime < 0.8,"snow powder settles quickly instead of rising/lingering like dust")
	check(first.direction.z*second.direction.z < 0.0,"pushed fragments spread to opposite sides of travel")
	state.track_elevated = true; effects.sample(state,DriveFrame.new(),track)
	check(not effects.snow_push[0].emitting,"ground push stops on elevated decks")
	state.track_elevated = false; state.jump_height = 1; effects.sample(state,DriveFrame.new(),track)
	check(not effects.snow_push[0].emitting,"ground push stops while airborne")
	state.jump_height = 0; state.velocity = Vector2.ZERO; effects.sample(state,DriveFrame.new(),track)
	check(not effects.snow_push[0].emitting,"stationary car does not continuously push snow")
	state.velocity = Vector2(0.3,0); effects.sample(state,DriveFrame.new(),track)
	effects.clear()
	check(not effects.snow_push[0].emitting and effects.snow_push_position == Vector2.INF,"restart/rewind clears pushed snow")
	state.position = Vector2.ZERO; effects.sample(state,DriveFrame.new(),track)
	check(not effects.snow_push[0].emitting,"clear ice never emits pushed bank chunks")
	var changed_track: NativeTrack = make_track()
	changed_track.creator_bridges.append({"heading":0.0,"position":[50,50],"length":40.0,"width":10.0})
	state.position = Vector2(3.9,10)
	effects.sample(state,DriveFrame.new(),changed_track)
	check(int(effects.snow_push[0].draw_pass_1.surface_get_material(0).get_shader_parameter("dust_bridge_count")) == 1,"snow clouds rebind bridge protection when changing user tracks")
	effects.queue_free()
	await process_frame

func profile_contact(track: NativeTrack, old: NativeTrack) -> void:
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var state := VehicleState.new()
	state.position = Vector2(5.6,10)
	state.heading = PI*0.5
	var results: Array[Dictionary] = []
	for banks: SnowBanks in [old.snow_banks,track.snow_banks]:
		var started: int = Time.get_ticks_usec()
		for index: int in range(6000):
			state.velocity = Vector2(20,0)
			banks.slow_car(state,state.position,config,VehicleSimulation.STEP)
		results.append({"model":"soft" if banks == old.snow_banks else "packed","us_per_tick":float(Time.get_ticks_usec()-started)/6000.0})
	var file := FileAccess.open(output+"/contact-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"iterations":6000,"scope":"stationary crest contact at20m/s; standalone function, not whole-frame timing","results":results},"\t"))
	print("SNOW_CONTACT_PROFILE: ",JSON.stringify(results))

func capture_motion() -> void:
	root.size = Vector2i(1280,720)
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	var document: Dictionary = TrackDocument.create_blank()
	document.theme = "winter"
	var position := Vector2(-28,-18)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading,10)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		document.pieces.append(piece)
		var end: Dictionary = RoadPieces.end_pose(piece)
		position = end.position; heading = end.heading
	document = RoadPieces.route_from_pieces(document).document
	document.start_line = {"position":[0.0,-18.0],"heading":0.0}
	document = JSON.parse_string(JSON.stringify(document))
	check(TrackDocument.validate(document).is_empty(),"bank effect capture uses a valid creator track")
	var track: NativeTrack = TrackCompiler.compile(document)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track); game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false); game.set_process(false)
	game.set("countdown_ticks",0)
	game.get("race_cues").hide()
	var drive: VehicleSimulation = game.get("sim")
	drive.reset(Vector2(0,-18),0.0)
	drive.state.velocity = Vector2(0,14)
	var effects: SandDust = game.get("sand_dust")
	var bake_start: int = Time.get_ticks_usec()
	effects.configure_snow_surface(game.get("track_ground"))
	print("SNOW_SURFACE_BAKE_US: ",Time.get_ticks_usec()-bake_start)
	print("SNOW_BANK_HEIGHT_CELLS: ",effects._bank_visual_heights.size())
	check(not effects._bank_visual_heights.is_empty(),"actual visible bank supplies particle surface heights")
	var frames: Array[String] = []
	var push_frames: int = 0
	var impact_count: int = 0
	var first_push: int = -1
	for index: int in range(180):
		if game.get("paused"): game.call("toggle_pause")
		game.get("hud").pause_menu.hide()
		if game.get("winter_snow_wind").suspended: game.get("winter_snow_wind").notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		var input: DriveFrame = DriveFrame.sample(0,1 if index < 95 else 0,1 if index >= 95 else 0)
		for tick: int in range(4):
			drive.step(input,track)
			effects.sample(drive.state,input,track,game.get("bridge_presentation"))
			game.get("trails").sample(drive.state,input,game.get("bridge_presentation"),track)
		game.set("previous_position",drive.state.position)
		game.set("previous_heading",drive.state.heading)
		game.set("frame",input); game.set("paused",false)
		effects.set_water_paused(false)
		var before: Array = drive.state.snapshot()
		game.call("_process",0.0)
		check(drive.state.snapshot() == before,"actual bank-drive presentation preserves canonical state")
		var camera: FollowCamera = game.get("camera")
		camera.follow(drive.state.position,drive.state.velocity,drive.state.heading,1.0,true)
		camera.size = 18.0 # Inspection only; runtime camera contract remains.
		game.get("hud").update_values(drive.state,input,1.0/30.0,false,false)
		await create_timer(1.0/30.0).timeout
		if game.get("paused"):
			game.call("toggle_pause")
			game.call("_process",0.0)
		game.get("hud").pause_menu.hide()
		await RenderingServer.frame_post_draw
		frames.append("data:image/jpeg;base64,"+Marshalls.raw_to_base64(root.get_texture().get_image().save_jpg_to_buffer(0.9)))
		impact_count = maxi(impact_count,effects.snow_burst_count)
		if effects.snow_push[0].emitting:
			push_frames += 1
			if first_push < 0: first_push = index
			if index == first_push+12:
				check(root.get_texture().get_image().save_png(output+"/pushing-snow.png") == OK,"pushing snow capture saved")
				await gpu_push_probe(effects,camera,game)
		if index == 55: check(root.get_texture().get_image().save_png(output+"/bank-crawl.png") == OK,"packed bank crawl capture saved")
		if index == 150: check(root.get_texture().get_image().save_png(output+"/reverse-out.png") == OK,"reverse recovery capture saved")
	check(push_frames > 30,"real driving sustains visible snow push while inside bank")
	check(impact_count > 0,"real driving into bank throws entry fragments")
	var movie := FileAccess.open(output+"/motion.html",FileAccess.WRITE)
	movie.store_string("<!doctype html><meta charset='utf-8'><title>Packed snow driving</title><style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:1280px;margin:24px auto}img{width:100%}button{padding:10px;margin:12px 0}</style><p>Actual Godot canonical driving: bank entry, powered crawl, reverse recovery. Inspection camera; runtime camera unchanged.</p><img id='view'><button id='toggle'>Pause</button><script>const frames="+JSON.stringify(frames)+";let frame=0,playing=true;const view=document.getElementById('view'),button=document.getElementById('toggle');view.src=frames[0];button.onclick=()=>{playing=!playing;button.textContent=playing?'Pause':'Play'};setInterval(()=>{if(playing){frame=(frame+1)%frames.length;view.src=frames[frame]}},1000/30)</script>")
	print("SNOW_PUSH_CAPTURE: frames=180 active_push_frames=",push_frames," entry_bursts=",impact_count)
	game.queue_free()
	await process_frame

func gpu_push_probe(effects: SandDust, camera: Camera3D, game: Node) -> void:
	effects.set_water_paused(true)
	for emitter: GPUParticles3D in effects.snow_push: emitter.visible = false
	for index: int in range(3):
		if game.get("paused"): game.call("toggle_pause")
		game.get("hud").pause_menu.hide()
		effects.set_water_paused(true)
		await RenderingServer.frame_post_draw
	var hidden: Image = root.get_texture().get_image()
	for emitter: GPUParticles3D in effects.snow_push: emitter.visible = true
	for index: int in range(3):
		if game.get("paused"): game.call("toggle_pause")
		game.get("hud").pause_menu.hide()
		effects.set_water_paused(true)
		await RenderingServer.frame_post_draw
	var shown: Image = root.get_texture().get_image()
	var focus: Vector2 = camera.unproject_position(effects.snow_push[0].global_position)
	var changed: int = 0
	for y: int in range(maxi(0,int(focus.y)-100),mini(shown.get_height(),int(focus.y)+100)):
		for x: int in range(maxi(0,int(focus.x)-100),mini(shown.get_width(),int(focus.x)+100)):
			var a: Color = hidden.get_pixel(x,y)
			var b: Color = shown.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.025: changed += 1
	shown.save_png(output+"/push-visible.png")
	hidden.save_png(output+"/push-hidden.png")
	var report := FileAccess.open(output+"/push-gpu.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"visible_fragment_pixels":changed,"contact":effects.snow_push_position,"screen_contact":focus,"renderer":RenderingServer.get_current_rendering_method()},"\t"))
	print("SNOW_PUSH_GPU: visible_fragment_pixels=",changed)
	check(changed > 12,"actual GPU draws visible powder at bank contact")
	await profile_powder(effects,game)
	effects.set_water_paused(false)

func profile_powder(effects: SandDust, game: Node) -> void:
	# Fixed contact/particle positions isolate the entire bank-cloud rendering.
	# Short alternating stages reduce timing/order bias; no phone claim.
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	var reports: Array[Dictionary] = []
	for visible: bool in [false,true,true,false]:
		for emitter: GPUParticles3D in effects.snow_push+effects.snow_impacts: emitter.visible = visible
		var gpu: Array[float] = []
		for index: int in range(40):
			if game.get("paused"): game.call("toggle_pause")
			game.get("hud").pause_menu.hide()
			effects.set_water_paused(true)
			await RenderingServer.frame_post_draw
			if index >= 10: gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		gpu.sort()
		reports.append({"powder_visible":visible,"gpu_ms_median":gpu[15],"gpu_ms_p95":gpu[28],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	for emitter: GPUParticles3D in effects.snow_push+effects.snow_impacts: emitter.visible = true
	var file := FileAccess.open(output+"/powder-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":[root.size.x,root.size.y],"scope":"whole-scene fixed-contact GPU comparison, paused particle positions; not active frame pacing or isolated shader instruction cost","stages":reports},"\t"))
	print("SNOW_POWDER_PROFILE: ",JSON.stringify(reports))

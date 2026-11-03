extends SceneTree
## Distance-based undulations must survive the actual sprung-body damping.

const OUTPUT = "res://../docs/evidence/offtrack-broad-height-2026-11-02"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func field(kind: int) -> NativeTrack:
	var track := NativeTrack.new()
	track.cell_size = 1.0
	track.grid_width = 400
	track.grid_height = 400
	track.half_extent = Vector2(200,200)
	track.cells.resize(160000)
	track.cells.fill(kind)
	return track

func old_heights(state: VehicleState, config: HandlingConfig) -> Vector4:
	# Exact task-start profile, retained only as a comparison control.
	var heights := Vector4.ZERO
	var index: int = 0
	for axle: float in [0.5,-0.5]:
		for side: float in [-0.5,0.5]:
			var p: Vector2 = state.position+state.forward()*config.wheelbase*axle+state.right()*config.track_width*side
			heights[index] = 0.048*sin(p.x*0.36+p.y*0.48)+0.028*sin(p.x*0.27-p.y*0.34+1.1)+0.012*sin(p.x*2.1+p.y*2.7)+0.008*sin(p.x*3.4-p.y*2.2+0.7)
			index += 1
	return heights

func pose(h: Vector4, config: HandlingConfig) -> Vector3:
	return Vector3((h.x+h.y+h.z+h.w)*0.25,atan2((h.x+h.y-h.z-h.w)*0.5,config.wheelbase),atan2((h.y+h.w-h.x-h.z)*0.5,config.track_width))

func run() -> void:
	var track := field(1)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var metrics: Array = []
	var car := CarVisual.new()
	car.vehicle_id = "compact"
	root.add_child(car)
	for speed: float in [5.0,12.0,22.0]:
		for heading: float in [0.0,0.8,1.6,2.4]:
			var state := VehicleState.new()
			state.heading = heading
			state.velocity = state.forward()*speed
			var low := Vector3(INF,INF,INF)
			var high := Vector3(-INF,-INF,-INF)
			var old_low := Vector3(INF,INF,INF)
			var old_high := Vector3(-INF,-INF,-INF)
			var exact: bool = true
			var frozen: bool = true
			var last_smoothed: float = 0.0
			var smoothed: float = 0.0
			var slow_travel: float = 0.0
			var total_travel: float = 0.0
			var max_step: float = 0.0
			var last_height: float = 0.0
			for tick: int in range(1441):
				state.tick = tick
				state.position = Vector2(3,4)+state.forward()*speed*float(tick)/120.0
				var snapshot: Array = state.snapshot()
				var h: Vector4 = track.off_road_suspension_heights(state,config)
				car.present_suspension(state,0.0,true,0.0,Vector4.ZERO,Vector4.ZERO,false,Vector3.ZERO,h,pose(h,config))
				var current: Vector3 = car.terrain_suspension
				car.present_suspension(state,0.0,true,0.0,Vector4.ZERO,Vector4.ZERO,false,Vector3.ZERO,h,pose(h,config))
				frozen = frozen and current == car.terrain_suspension
				exact = exact and snapshot == state.snapshot()
				if tick > 120:
					low = low.min(current)
					high = high.max(current)
					var earlier: Vector3 = pose(old_heights(state,config),config)
					old_low = old_low.min(earlier)
					old_high = old_high.max(earlier)
					# Average over 2.4 m at every speed; a fixed time window would
					# incorrectly reject the same spatial profile at higher speeds.
					smoothed = lerpf(smoothed,current.x,speed/(120.0*2.4))
					if tick > 240:
						slow_travel += absf(smoothed-last_smoothed)
						total_travel += absf(current.x-last_height)
						max_step = maxf(max_step,absf(current.x-last_height))
					last_smoothed = smoothed
					last_height = current.x
			var span: Vector3 = high-low
			check(span.x > 0.15 and span.x > (old_high.x-old_low.x)*1.7,"broad heave survives damping at speed=%s heading=%s" % [speed,heading])
			check(maxf(span.y,span.z) > deg_to_rad(2.0),"body visibly pitches or rolls")
			check(slow_travel/total_travel > 0.65,"slow undulations dominate body travel")
			check(max_step < 0.012 and maxf(absf(low.x),absf(high.x)) < 0.24,"smooth bounded body travel")
			check(exact and frozen,"sampling preserves canonical state and duplicate snapshots freeze")
			metrics.append({"speed_m_s":speed,"heading":heading,"body_heave_span_m":span.x,"pitch_span_deg":rad_to_deg(span.y),"roll_span_deg":rad_to_deg(span.z),"slow_travel_ratio":slow_travel/total_travel,"old_undamped_heave_span_m":old_high.x-old_low.x})
	var state := VehicleState.new()
	state.position = Vector2(3,4)
	state.velocity = Vector2(0,12)
	var grass: Vector4 = track.off_road_suspension_heights(state,config)
	track.cells.fill(2)
	check(track.off_road_suspension_heights(state,config) == grass,"both loose-ground types share the broad profile")
	for kind: int in [0,3,4,5,6,7]:
		track.cells.fill(kind)
		check(track.off_road_suspension_heights(state,config) == Vector4.ZERO,"protected surface remains flat: "+str(kind))
	car.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var report := FileAccess.open(OUTPUT+"/motion-metrics.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics,"\t"))
	report.close()
	if "--capture" in OS.get_cmdline_user_args():
		await capture()
	print("OFFTRACK_BROAD_HEIGHT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture() -> void:
	# Staged native comparison: identical distance samples and actual car springs.
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("526752")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.6
	environment.environment = settings
	world.add_child(environment)
	var ground: StandardMaterial3D = VisualGeometry.material(Color("526752"))
	VisualGeometry.box(world,Vector3(40,0.1,40),Vector3(0,-0.15,0),ground)
	var line: StandardMaterial3D = VisualGeometry.material(Color("7b8d71"))
	for z: int in range(-10,11,2):
		VisualGeometry.box(world,Vector3(16,0.005,0.018),Vector3(0,-0.09,z),line)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-30,0)
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(7,12,10)
	camera.look_at(Vector3(0,0.5,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.5
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var title := Label.new()
	title.text = "OFF-TRACK SUSPENSION  |  12 m/s  |  staged native comparison"
	title.position = Vector2(22,18)
	overlay.add_child(title)
	var track := field(1)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var cars: Array[CarVisual] = []
	for i: int in range(2):
		var car := CarVisual.new()
		car.vehicle_id = "compact"
		world.add_child(car)
		car.position.x = -3.2 if i == 0 else 3.2
		cars.append(car)
		var label := Label3D.new()
		label.text = "Before" if i == 0 else "Broader undulations"
		label.position = Vector3(car.position.x,1.7,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		world.add_child(label)
	for car: CarVisual in cars:
		while not car.model_ready: await process_frame
	var state := VehicleState.new()
	state.velocity = Vector2(0,12)
	var destination: String = ProjectSettings.globalize_path(OUTPUT).path_join("frames")
	DirAccess.make_dir_recursive_absolute(destination)
	for tick: int in range(721):
		state.tick = tick
		state.position = Vector2(3,4+float(tick)*0.1)
		for i: int in range(2):
			var h: Vector4 = old_heights(state,config) if i == 0 else track.off_road_suspension_heights(state,config)
			cars[i].present_suspension(state,0.0,true,0.0,Vector4.ZERO,Vector4.ZERO,false,Vector3.ZERO,h,pose(h,config))
		if tick >= 120 and tick%10 == 0:
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(destination.path_join("%03d.png" % ((tick-120)/10))) == OK,"native comparison capture")
	world.queue_free()
	overlay.queue_free()
	await process_frame

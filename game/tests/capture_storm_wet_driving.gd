extends SceneTree
## Controlled moving presentation, with matched frozen spray-on/off images.
const OUTPUT: String = "res://../docs/evidence/storm-wet-driving-2026-10-09/"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var document: Dictionary = TrackDocument.create_blank()
	document.theme = "storm"
	var position := Vector2(-28,-18)
	var heading: float = 0.0
	for kind: String in ["straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		document.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position
		heading = pose.heading
	document = RoadPieces.route_from_pieces(document).document
	document.start_line = {"position":[0.0,-18.0],"heading":0.0}
	document = JSON.parse_string(JSON.stringify(document))
	check(TrackDocument.validate(document).is_empty(),"valid automatic-route Storm fixture")
	var race: Node = load("res://core/game.tscn").instantiate()
	race.initial_track = TrackCompiler.compile(document)
	race.production_mode = true
	root.add_child(race)
	race.set_physics_process(false)
	race.set_process(false)
	race.paused = true
	(race.race_cues as Control).hide()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = size
		for speed: float in [7.0,18.0]:
			var state := VehicleState.new()
			state.heading = race.sim.state.heading
			state.velocity = state.forward()*speed
			var origin := Vector2(0,-18)
			race.sim.state = state
			race.sand_dust.clear()
			for tick: int in range(96):
				state.position = origin+state.forward()*speed*(float(tick-95)/120.0)
				race.previous_position = state.position
				race.previous_heading = state.heading
				race.call("_process",1.0/120.0)
				race.sand_dust.set_water_paused(false)
				race.sand_dust.sample(state,DriveFrame.new(),race.native_track,race.bridge_presentation)
				await create_timer(1.0/120.0).timeout
				await RenderingServer.frame_post_draw
			race.sand_dust.set_water_paused(true)
			check(race.sand_dust.water_drops.all(func(e: GPUParticles3D) -> bool: return e.emitting),"all tires on wet road")
			check(state.position == origin,"capture movement has a fixed final pose")
			var label: String = "%dx%d-%dkmh" % [size.x,size.y,roundi(speed*3.6)]
			var wet: Image = await _capture(label+"-spray")
			for drops: GPUParticles3D in race.sand_dust.water_drops: drops.hide()
			var dry: Image = await _capture(label+"-without-spray")
			var changed: int = 0
			var large: int = 0
			for y: int in range(size.y):
				for x: int in range(size.x):
					var a: Color = wet.get_pixel(x,y)
					var b: Color = dry.get_pixel(x,y)
					var delta: float = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
					if delta > 0.008: changed += 1
					if delta > 0.25: large += 1
			print("WET_SPRAY_PIXELS ",label," visible=",changed," high_contrast=",large)
			check(changed > 12,"wet spray is visible at "+label)
			check(changed < size.x*size.y/500 and large < 12,"spray remains compact and restrained at "+label)
			for drops: GPUParticles3D in race.sand_dust.water_drops: drops.show()
	race.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	print("WET_DRIVING_CAPTURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _capture(label: String) -> Image:
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var captured: Image = root.get_texture().get_image()
	check(captured.save_png(ProjectSettings.globalize_path(OUTPUT+label+".png")) == OK,"saved "+label)
	return captured

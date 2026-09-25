extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String = "capture saved") -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var document: Dictionary = TrackDocument.create_blank()
	document.theme = "winter"
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
	var errors: Array[String] = TrackDocument.validate(document)
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	var track: NativeTrack = TrackCompiler.compile(document)
	var cells: PackedInt32Array = track.cells.duplicate()
	var banks: String = str(track.snow_banks.triangles)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	(game.get("race_cues") as Control).hide()
	for frame: int in range(8):
		game.call("_process",0.0)
		await RenderingServer.frame_post_draw
	check(track.cells == cells and str(track.snow_banks.triangles) == banks,"presentation preserves canonical surfaces and contacts")
	check(NativeTrackVisual.WINTER_SNOW.get_image().has_mipmaps(),"snow has mipmaps")
	check(NativeTrackVisual.WINTER_ICE.get_image().has_mipmaps(),"ice has mipmaps")
	var ground: Node = game.get("track_ground")
	for suffix: String in ["Pale","Dark"]:
		var marking: MeshInstance3D = ground.get_node_or_null("WinterSnowFinish"+suffix)
		check(marking != null,"winter worn checker mesh "+suffix)
		if marking != null:
			check(marking.material_override is ShaderMaterial,"winter finish uses abrasion shader")
	check(ground.get_node_or_null("FinishDark") == null,"winter omits opaque black finish")

	check(ground.get_node_or_null("WinterSnowBanks") != null,"snowbanks rendered")
	check(int(ground.get_meta("winter_smooth_sections",0)) > 0,"analytic smooth snowbank sections generated")
	check(int(ground.get_meta("winter_deposits",0)) > 0,"outer snow deposits generated")
	for child: Node in ground.get_children():
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			var material: ShaderMaterial = child.material_override
			if material.shader == NativeTrackVisual.CREATOR_ROAD_SHADER:
				check(not material.get_shader_parameter("road_marking"),"winter omits edge stripes")
	var folder: String = "res://../docs/evidence/winter-finish"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	check(root.get_texture().get_image().save_png(folder+"/driving.png") == OK)
	game.set_process(false)
	var camera: Camera3D = game.get("camera")
	var focus: Vector3 = Vector3(40,0,0)
	camera.position = focus+Vector3(0,20,15)
	camera.look_at(focus)
	camera.size = 29.0
	for frame: int in range(3): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/bend-detail.png") == OK)
	print("WINTER_CAPTURE: surfaces/contacts preserved, mipmaps, smooth banks, no edge stripes, two captures PASS; sections=",ground.get_meta("winter_smooth_sections"))
	await _snow_effects(game,track)
	game.queue_free()
	await process_frame
	print("WINTER_CHECKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


func _snow_effects(game: Node, track: NativeTrack) -> void:
	var probe := NativeTrack.new()
	probe.cell_size = 10.0
	probe.grid_width = 2
	probe.grid_height = 2
	probe.half_extent = Vector2(10,10)
	probe.cells.resize(4)
	probe.deck_cells.resize(4)
	probe.deck_cells.fill(-1)
	probe.metadata = {"theme":"winter"}
	for kind: int in range(8):
		probe.cells.fill(kind)
		check(SkidTrails.surface_at(probe,Vector3.ZERO,false) == [8,7,10,11,4,7,11,7][kind],"winter surface mapping "+str(kind))
	var effects: SandDust = game.get("sand_dust")
	var trails: SkidTrails = game.get("trails")
	var state := VehicleState.new()
	state.velocity = Vector2(3,-9)
	state.heading = PI
	var frame: DriveFrame = DriveFrame.sample(0,1,0)
	var folder: String = "res://../docs/evidence/winter-directional"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game.set_process(false)
	trails.clear()
	var camera: Camera3D = game.get("camera")
	camera.position = Vector3(0,22,42)
	camera.look_at(Vector3(0,0,24))
	camera.size = 23.0
	var captured_impact: bool = false
	var impact_frame: int = -100
	for index: int in range(105):
		state.tick = index*2
		state.position = Vector2(0,-18.0-float(index)*0.12)
		var before: Array = state.snapshot()
		effects.sample(state,frame,track,game.get("bridge_presentation"))
		trails.sample(state,frame,game.get("bridge_presentation"),track)
		check(state.snapshot() == before,"snow presentation leaves canonical snapshot unchanged")
		game.get("sim").state = state
		game.call("_process",0.0)
		camera.position = Vector3(0,22,42)
		camera.look_at(Vector3(0,0,24))
		camera.size = 23.0
		await create_timer(0.016).timeout
		await RenderingServer.frame_post_draw
		if not captured_impact and effects.snow_burst_count > 0:
			check(root.get_texture().get_image().save_png(folder+"/bank-contact.png") == OK)
			check(effects.snow_impact_position.distance_to(state.position) > effects.collision_radius-0.3,"impact originates on body perimeter")
			check(track.snow_banks.height_at(effects.snow_impact_position) > 0.035,"impact origin is actual bank contact")
			var impact_process: ParticleProcessMaterial = effects.snow_impacts[0].process_material
			check(impact_process.direction.dot(VisualGeometry.world(state.velocity.normalized())) > 0.8,"snow launches in impact travel direction")
			check(effects.snow_impacts[0].draw_pass_1 is SphereMesh,"impact uses snow fragments instead of cloud billboards")
			captured_impact = true
			impact_frame = index
		if index == impact_frame+1: check(root.get_texture().get_image().save_png(folder+"/bank-impact.png") == OK)
		if index == 20: check(root.get_texture().get_image().save_png(folder+"/ice-drift.png") == OK)
	check(effects.snow_burst_count > 0,"crossing bank emits impact snow")
	check(effects.snow_burst_count <= 3,"bank cloud cooldown prevents sustained burst spam")
	check(effects.snow_chips.size() == 4 and effects.snow_impacts.size() == 2,"bounded wheel emitters and impact pool")
	check(effects.snow_chips[0].emitting,"loose snow throws chips")
	check(not effects.clipping_emitters[0].emitting and not effects.dust_emitters[0].emitting,"winter suppresses green clippings and sand dust")
	check(root.get_texture().get_image().save_png(folder+"/snow-tracks.png") == OK)
	state.jump_height = 1.0
	effects.sample(state,frame,track)
	check(not effects.snow_chips[0].emitting,"airborne wheels stop snow spray")
	state.jump_height = 0.0
	state.track_elevated = true
	var bursts: int = effects.snow_burst_count
	effects.sample(state,frame,track)
	check(effects.snow_burst_count == bursts,"elevated wheels cannot strike ground snowbanks")
	effects.clear()
	check(effects.snow_burst_count == 0 and not effects.snow_impacts[0].emitting,"restart clears snow impacts")
	check(effects.snow_impacts[0].lifetime <= 0.45,"bank burst settles within half a second")
	check(effects.snow_impacts[0].explosiveness == 1.0,"impact particles spawn together immediately")
	var burst_process: ParticleProcessMaterial = effects.snow_impacts[0].process_material
	check((burst_process.color_ramp as GradientTexture1D).gradient.get_color(0).a > 0.5,"impact starts visible without dust fade-in")
	state.track_elevated = false
	state.position = Vector2.ZERO
	probe.cells.fill(0)
	state.velocity = Vector2(9,-9)
	effects.sample(state,frame,probe)
	var ice_spray: float = effects.snow_chips[0].amount_ratio
	check(not effects.snow_powder[0].emitting and not effects.smoke_emitters[0].emitting,"ice drift emits chips without tyre clouds")
	check(ice_spray > 0.3,"drifting on ice throws substantial snow chips")
	probe.cells.fill(1)
	effects.sample(state,frame,probe)
	check(absf(effects.snow_chips[0].amount_ratio-ice_spray) < 0.05,"full ice drift uses off-track snow emission strength")
	probe.cells.fill(0)
	state.velocity = state.forward()*12.0
	effects.sample(state,frame,probe)
	check(not effects.snow_chips[0].emitting,"straight ice driving does not spray loose snow")
	state.track_elevated = false
	state.position = Vector2.ZERO
	probe.cells.fill(1)
	probe.metadata.theme = "pine"
	effects.sample(state,frame,probe)
	check(not effects.snow_chips[0].emitting and not effects.snow_powder[0].emitting,"nonwinter theme stops winter emitters")
	check(effects.clipping_emitters[0].emitting,"grass keeps its original clippings")
	check(trails._surface_style(7,0.0).z > trails._surface_style(7,0.0).x,"loose snow marks stay cool rather than muddy")
	check(trails._surface_relief(7) > trails._surface_relief(8),"snow ruts have more relief than ice scuffs")

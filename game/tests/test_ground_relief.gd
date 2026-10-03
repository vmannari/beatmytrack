extends SceneTree
## Geometry/grounding invariants for cosmetic meadow relief, including captures.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var document: Dictionary = TrackDocument.create_default()
	document.id = "ground_relief_fixture"
	document.objects = [{"kind":"rock","position":[-30,5],"rotation":0.0,"scale":1.0},{"kind":"water","position":[28,0],"rotation":0.0,"scale":1.0},{"kind":"jump","position":[0,0],"rotation":30.0,"scale":1.0},{"kind":"oil","position":[12,0],"rotation":0.0,"scale":1.0}]
	var track: NativeTrack = TrackCompiler.compile(document)
	var cells: PackedInt32Array = track.cells.duplicate()
	var deck: PackedInt32Array = track.deck_cells.duplicate()
	var original_document: Dictionary = track.metadata.duplicate(true)
	var begin: int = Time.get_ticks_usec()
	var field: GroundRelief = GroundRelief.for_track(track)
	print("RELIEF_BUILD_MS: ",(Time.get_ticks_usec()-begin)/1000.0," vertices=",field.heights.size()," chunks=",field.meshes.size()," peak_m=",field.peak)
	check(field.peak > 0.30 and field.peak <= 0.50,"doubled-height mounds appear and remain <=50 cm")
	check(field.heights.size() <= GroundRelief.MAX_VERTICES,"terrain sampling has a fixed vertex budget")
	check(GroundRelief.for_track(track) == field,"repeat load reuses cached field and meshes")
	var repeat := GroundRelief.new()
	repeat._build(track)
	check(repeat.heights == field.heights,"fresh build produces identical heights")
	var maximum := Vector2.ZERO
	var maximum_height: float = 0.0
	var flat: bool = true
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			var point := Vector2((x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+0.5)*track.cell_size)
			var height: float = field.height_at(point)
			if track.cells[y*track.grid_width+x] != 1: flat = flat and height == 0.0
			if height > maximum_height: maximum_height = height; maximum = point
	check(flat,"all road, sand, water and solid cell centres stay exactly flat")
	for object: Dictionary in document.objects:
		if object.kind not in ["oil","jump"]: continue
		var point := Vector2(object.position[0],object.position[1])
		var protected: bool = field.height_at(point) == 0.0 and track.cell_at(point) == 1
		for corner: Vector2 in CreatorObjects.outline(object): protected = protected and field.height_at(corner) == 0.0
		check(protected,object.kind+" footprint remains flat without modifying grass cells")
	var border_flat: bool = true
	for i: int in range(track.route.size()):
		var tangent: Vector2 = (track.route[(i+1)%track.route.size()]-track.route[i]).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		for side: float in [-1.0,1.0]:
			border_flat = border_flat and field.height_at(track.route[i]+normal*side*(track.route_widths[i]*0.5+1.65)) == 0.0
	check(border_flat,"full 1.65 m sand shoulder remains flat along the route")
	var accurate: bool = true
	var upwards: bool = true
	for mesh: ArrayMesh in field.meshes:
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i: int in range(0,indices.size(),3):
			var a: Vector3 = vertices[indices[i]]
			var b: Vector3 = vertices[indices[i+1]]
			var c: Vector3 = vertices[indices[i+2]]
			var center: Vector3 = (a+b+c)/3.0
			accurate = accurate and absf(center.y-field.height_at(Vector2(center.x,-center.z))) < 0.00002
			upwards = upwards and (b-a).cross(c-a).y > 0.0
		for normal: Vector3 in normals: upwards = upwards and normal.y > 0.8 and absf(normal.length()-1.0) < 0.0001
	check(accurate,"ground sampler matches rendered triangle interiors")
	check(upwards,"triangles and smooth normals face upward")
	check(cells == track.cells and deck == track.deck_cells and original_document == track.metadata,"generation leaves all canonical/creator data unchanged")
	for theme: String in ["desert","winter","night_city","storm"]:
		var other: NativeTrack = TrackCompiler.compile(document.merged({"theme":theme},true))
		check(GroundRelief.for_track(other).height_at(maximum) == 0.0 and GroundRelief.for_track(other).meshes.is_empty(),theme+" retains approved terrain")
	for id: String in VehicleCatalog.IDS: await exercise_car(track,field,maximum,id)
	print("GROUND_RELIEF: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)

func exercise_car(track: NativeTrack, field: GroundRelief, point: Vector2, id: String) -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("vehicle_id",id)
	game.set("production_mode",true)
	root.size = Vector2i(1440,900)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	game.set("countdown_ticks",0)
	game.get("race_cues").hide()
	var sim: VehicleSimulation = game.get("sim")
	var car: CarVisual = game.get("car")
	var config: HandlingConfig = game.get("handling")
	sim.reset(point,0.3)
	game.set("previous_position",point)
	game.set("previous_heading",0.3)
	var snapshot: Array = sim.state.snapshot()
	game.call("_process",0.0)
	var contacts: Vector4 = field.contacts(point,0.3,config.wheelbase,config.track_width)
	var pose: Vector3 = GroundRelief.pose(contacts,config.wheelbase,config.track_width,field.height_at(point))
	check(absf(car.position.y-pose.x) < 0.0001 and car.position.y > 0.1,"off-road car follows real terrain support")
	check(car.position.y >= field.height_at(point),id+" chassis clears the crest between axles")
	check(absf(car.rotation.x-pose.y) < 0.0001 and absf(car.rotation.z-pose.z) < 0.0001,"car follows terrain pitch and roll")
	for i: int in range(car.rolling_wheels.size()):
		var rest: Vector3 = car.wheel_rest_positions[i]
		var wheel: Node3D = car.rolling_wheels[i].get_parent()
		var index: int = (0 if rest.z < 0.0 else 2)+(0 if rest.x < 0.0 else 1)
		var local: Vector3 = Vector3(rest.x,wheel.position.y,rest.z)
		var supported: Vector3 = car.basis*local+car.position
		check(absf(supported.y-(rest.y*HandlingConfig.BODY_SCALE+contacts[index])) < 0.001,"individual wheel contacts follow terrain")
	check((game.get("contact_shadow") as Node3D).position.y > 0.1,"car contact projection follows raised ground")
	check(snapshot == sim.state.snapshot(),"terrain pose never changes canonical driving state")
	var ghosts: Node3D = preload("res://vehicle/rewind_ghosts.gd").new()
	game.add_child(ghosts)
	var history: Array[Dictionary] = []
	ghosts.configure(car,track,game.get("bridge_presentation"),history,sim.state.tick,field,config)
	var recorded: Dictionary = {"position":point,"heading":0.3,"route_index":sim.state.route_index,"track_elevated":false,"jump_height":0.0}
	check(absf(ghosts.world(recorded).y-pose.x-0.05) < 0.0001,"rewind history markers use the same terrain support")
	var sample_state := VehicleState.new()
	sample_state.position = point
	sample_state.heading = 0.3
	sample_state.velocity = Vector2(8,12)
	var trails: SkidTrails = game.get("trails")
	trails.sample(sample_state,DriveFrame.new(),game.get("bridge_presentation"),track)
	var contact: Vector3 = trails.previous_left
	check(absf(contact.y-0.028-field.height_at(Vector2(contact.x,-contact.z))) < 0.0001,"off-road trails sit on the terrain")
	var cursor: int = trails.cursor
	trails.sample(sample_state,DriveFrame.new(),game.get("bridge_presentation"),track)
	check(trails.cursor == cursor,"unchanged raised-ground sample creates no extra trail segment")
	var dust: SandDust = game.get("sand_dust")
	dust.sample(sample_state,DriveFrame.new(),track,game.get("bridge_presentation"))
	check(absf(dust.clipping_emitters[0].position.y-0.045-field.height_at(Vector2(contact.x,-contact.z))) < 0.0001,"grass particle origin follows terrain")
	if DisplayServer.get_name() != "headless" and id == "compact":
		var camera: FollowCamera = game.get("camera")
		camera.follow(point,Vector2.ZERO,0.3,0.0,true)
		for frame: int in range(3):
			game.call("_process",0.0)
			await RenderingServer.frame_post_draw
		var path: String = "res://../build/ground-relief-gameplay.png"
		check(root.get_texture().get_image().save_png(path) == OK,"production-camera relief capture saved")
		game.get("hud").hide()
		camera.size = 30.0
		camera.position = VisualGeometry.world(point)+Vector3(12,14,18)
		camera.look_at(VisualGeometry.world(point))
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../build/ground-relief-detail.png") == OK,"diagnostic terrain/contact capture saved")
	game.queue_free()
	await process_frame

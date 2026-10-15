extends SceneTree

const HEIGHT = preload("res://track/road_surface_height.gd")
var checks: int = 0
var failures: int = 0
var measurements: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func _initialize() -> void:
	run.call_deferred()

func field(kind: int) -> NativeTrack:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500,500)
	track.cells.resize(10000)
	track.cells.fill(kind)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
	return track

func circuit(theme: String) -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = theme
	var points: Array[Vector2] = [Vector2(-48,0),Vector2(-30,0),Vector2(30,0),Vector2(50,26),Vector2(0,42),Vector2(0,-42),Vector2(-50,-26)]
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var piece: Dictionary = RoadPieces.create("bridge" if i == 1 else "straight",a,fposmod(rad_to_deg((b-a).angle()),360),10)
		piece.length = a.distance_to(b)
		doc.pieces.append(piece)
	var result: Dictionary = RoadPieces.route_from_pieces(doc)
	check(result.ok,"bridge circuit generates its ordinary route")
	return TrackCompiler.compile(result.document)

func run() -> void:
	var previous := GDScript.new()
	previous.source_code = FileAccess.get_file_as_string("res://../docs/evidence/grass-road-height-2026-10-14/before/game/vehicle/vehicle_simulation.gd").replace("\r\n","\n").replace("class_name VehicleSimulation\n","")
	check(previous.reload() == OK,"saved physics 0.56 loads for measured comparison")
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		for kind: int in [0,2]:
			var track: NativeTrack = field(kind)
			var current := VehicleSimulation.new(config)
			var old: RefCounted = previous.new(config)
			current.state.velocity = Vector2(0,24)
			old.state.velocity = current.state.velocity
			for tick: int in range(600):
				var frame: DriveFrame = DriveFrame.sample(sin(tick*0.031)*0.35,0.7 if tick < 200 else 0.0,0.4 if tick > 400 else 0.0)
				current.step(frame,track)
				old.step(frame,track)
			check(current.state.snapshot() == old.state.snapshot(),id+" road/sand physics remain exact, kind "+str(kind))
		var grass: NativeTrack = field(1)
		for direction: float in [-1.0,1.0]:
			var current := VehicleSimulation.new(config)
			var old: RefCounted = previous.new(config)
			var replay := VehicleSimulation.new(config)
			current.state.velocity = Vector2(0,24*direction)
			old.state.velocity = current.state.velocity
			replay.state.velocity = current.state.velocity
			var distance: float = 0.0
			var old_distance: float = 0.0
			var stopped: int = 0
			var old_stopped: int = 0
			for tick: int in range(1200):
				var before: Vector2 = current.state.position
				var old_before: Vector2 = old.state.position
				current.step(DriveFrame.new(),grass)
				replay.step(DriveFrame.new(),grass)
				old.step(DriveFrame.new(),grass)
				distance += current.state.position.distance_to(before)
				old_distance += old.state.position.distance_to(old_before)
				if stopped == 0 and current.state.velocity.length() == 0.0: stopped = tick+1
				if old_stopped == 0 and old.state.velocity.length() == 0.0: old_stopped = tick+1
			check(stopped > 0 and stopped < old_stopped*0.8,id+" grass stops at least 20% sooner in either direction")
			check(distance < old_distance*0.8,id+" grass stops over at least 20% less distance")
			check(current.state.snapshot() == replay.state.snapshot(),id+" new grass handling replays exactly")
			measurements.append({"car":id,"direction":direction,"old_seconds":old_stopped*VehicleSimulation.STEP,"seconds":stopped*VehicleSimulation.STEP,"old_metres":old_distance,"metres":distance})
		for pedal: DriveFrame in [DriveFrame.sample(0,1,0),DriveFrame.sample(0,0,1)]:
			var escape := VehicleSimulation.new(config)
			for tick: int in range(240): escape.step(pedal,grass)
			check(escape.state.position.length() > 0.5,id+" can drive forward and reverse out of grass from rest")
	var edge: NativeTrack = field(0)
	for y: int in range(50,100):
		for x: int in range(50,100): edge.cells[y*100+x] = 1
	var partial := VehicleSimulation.new(HandlingConfig.new())
	var old_partial: RefCounted = previous.new(partial.config)
	partial.reset(Vector2(-0.2,0.2))
	old_partial.reset(partial.state.position)
	partial.state.velocity = Vector2(0,24)
	old_partial.state.velocity = partial.state.velocity
	var contacts: Vector4 = partial._wheel_soil_contacts(edge)
	check(contacts.x+contacts.y+contacts.z+contacts.w == 0.5,"spatial fixture catches exactly one tyre on grass before the centre")
	partial.step(DriveFrame.new(),edge)
	old_partial.step(DriveFrame.new(),edge)
	check(partial.state.velocity.length() < old_partial.state.velocity.length()-0.03,"first grass wheel sheds more speed immediately before the centre leaves asphalt")
	check(is_equal_approx(HEIGHT.ROAD-HEIGHT.TERRAIN,0.05),"road datum is exactly five centimetres above terrain")
	var native: NativeTrack = field(1)
	for y: int in range(48,52):
		for x: int in range(40,60): native.cells[y*100+x] = 0
	var raster := NativeTrackVisual.new()
	root.add_child(raster)
	raster.colors = TrackTheme.palette("pine")
	await raster._build_terrain(native)
	var road: MeshInstance3D = raster.get_node("RasterRoadSurface")
	var verts: PackedVector3Array = road.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low: float = INF
	var high: float = -INF
	for p: Vector3 in verts:
		low = minf(low,p.y)
		high = maxf(high,p.y)
	check(is_equal_approx(high-low,0.05),"actual native road has closed five-centimetre edge faces")
	check(is_equal_approx(high,HEIGHT.ROAD) and is_equal_approx(low,HEIGHT.TERRAIN),"native raster road uses the same road and terrain datums")
	raster.queue_free()
	await process_frame
	for theme: String in ["pine","storm","winter","desert"]:
		var track: NativeTrack = circuit(theme)
		var bridge := BridgePresentation.new(track)
		var span: Dictionary = track.creator_bridges[0]
		for end: float in [0.0,float(span.length)]:
			var p := Vector2(span.position[0],span.position[1])+Vector2(end,0).rotated(deg_to_rad(span.heading))
			check(absf(CreatorBridgeVisual.vertex(span,end,0,HEIGHT.bridge_offset(end,span.length)).y-HEIGHT.ROAD) < 0.000001,theme+" actual bridge mouth meets ground mesh")
			check(absf(bridge.height_at(p,0,1)) < 0.000001,theme+" car support has no step at either bridge mouth")
		check(bridge.height_at(Vector2(-40,0),0,0) == 0.0,theme+" car/ghost/trail remain on raised ground road")
		check(is_equal_approx(bridge.height_at(Vector2(-40,8),0,0),-0.05),theme+" grass/terrain support follows lower datum")
		check(bridge.height_at(Vector2(-40,5.5),0,0) > -0.05,theme+" shoulder wheel support follows shallow slope")
		var world := NativeTrackVisual.new()
		world.cache_road_meshes = false
		world.cache_race_world = false
		root.add_child(world)
		await world.build(track,bridge)
		var found: bool = false
		for child: Node in world.get_children():
			if child is MeshInstance3D and child.mesh is PlaneMesh:
				found = true
				check(is_equal_approx(child.position.y,HEIGHT.TERRAIN),theme+" actual terrain mesh is at the five-centimetre datum")
		check(found,theme+" production terrain mesh inspected")
		if DisplayServer.get_name() != "headless": await capture(world,track,bridge,theme)
		world.queue_free()
		await process_frame
	print("GRASS_ROAD_MEASUREMENTS ",JSON.stringify(measurements))
	print("GRASS_ROAD_HEIGHT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture(world: Node3D, track: NativeTrack, bridge: BridgePresentation, theme: String) -> void:
	root.size = Vector2i(1280,720)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = TrackTheme.DESERT_SUN_ROTATION if theme == "desert" else Vector3(-48,-32,0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("aab8b8")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d9e4eb")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var car := CarVisual.new()
	world.add_child(car)
	var state := VehicleState.new()
	state.position = Vector2(-34,0)
	state.heading = PI*0.5
	car.present(state.position,state.heading,state,DriveFrame.new())
	car.position.y = bridge.height_at(state.position,0,0)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22.0
	world.add_child(camera)
	camera.current = true
	var folder: String = "res://../docs/evidence/grass-road-height-2026-10-14/"+RenderingServer.get_current_rendering_method()+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for view: String in ["overhead","seam"]:
		camera.position = Vector3(-37,21,18) if view == "overhead" else Vector3(-34,2.0,13)
		camera.look_at(Vector3(-30,0.3,0))
		for frame: int in range(5): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+theme+"-"+view+".png") == OK,"actual "+theme+" "+view+" capture saved")

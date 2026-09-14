extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+description)


func run() -> void:
	_check_import_boundary()
	_check_storage()
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creator_default.json"))
	check(golden == TrackDocument.create_default(),"starter authoring document matches checked-in golden fixture")
	for theme: String in TrackDocument.THEMES:
		var document: Dictionary = TrackDocument.create_default()
		document.theme = theme
		if theme == "desert":
			document.surface = "dirt"
			document.layout.surface = "dirt"
		var issues: Array[String] = TrackDocument.validate(document)
		check(issues.is_empty(),theme+" starter route validates: "+str(issues))
		var track: NativeTrack = TrackCompiler.compile(document)
		check(track != null,theme+" compiles")
		if track == null:
			continue
		check(track.metadata.theme == theme,theme+" theme passes through to the shared native data")
		check(track.metadata.name == document.name and track.metadata.title == document.name,theme+" friendly document title reaches menus and results")
		check(track.route == TrackDocument.smooth_points(document),theme+" preview and drive share the same route")
		var expected: int = 2 if document.surface == "dirt" else 0
		print("CREATOR_GEOMETRY ",theme," hash=",track.content_hash," grid=",track.grid_width,"x",track.grid_height," route_points=",track.route.size()," road_cells=",track.cells.count(expected))
		check(track.grid_width == 228 and track.grid_height == 188 and track.route.size() == 219 and track.cells.count(expected) == 8715,theme+" native geometry matches compiler-v1 golden dimensions and road area")
		if theme == "pine":
			check(track.content_hash == "5b02bb3d4c972346ac2650fe61dcda407dc03253a7824fcbe780ce6141501869","compiler-v8 canonical identity matches golden hash")
		var route_on_road: bool = true
		for point: Vector2 in track.route:
			route_on_road = route_on_road and track.cell_at(point) == expected
		check(route_on_road,theme+" entire route lies on the chosen road surface")
		var second: NativeTrack = TrackCompiler.compile(JSON.parse_string(JSON.stringify(document)))
		check(track.content_hash == second.content_hash and track.cells == second.cells and track.route == second.route,theme+" JSON round trip compiles to identical content")
		document.points[1][0] += 1.0
		var revised: NativeTrack = TrackCompiler.compile(document)
		check(revised != null and revised.content_hash != track.content_hash,theme+" geometry revision changes content hash")
		_drive_and_replay(track,theme)
	print("CREATOR_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


func _check_import_boundary() -> void:
	check(not TrackDocument.validate(null).is_empty(),"null input rejected")
	check(not TrackDocument.validate([]).is_empty(),"array root rejected")
	var base: Dictionary = TrackDocument.create_default()
	for patch: Dictionary in [
		{"schema":"creator-track-v999"}, {"id":"../outside"}, {"id":"con"}, {"id":"C:/outside"},
		{"name":"Bad\nname"}, {"name":""}, {"name":"a".repeat(41)}, {"name":123},
		{"theme":"https://example.test/a.png"}, {"surface":"res://bad.gd"}, {"script":"res://bad.gd"},
		{"width":5.9}, {"width":20.1}, {"width":true}, {"width":INF}, {"points":[]},
		{"points":[[0,0],[40,0],[40,40],[0,NAN]]},
		{"points":[[0,0],[40,0],[40,40],[0,121]]},
		{"points":[[0,0],[40,0],[40,40],[0,{"script":"run"}]]},
		{"points":[[-40,-30],[40,30],[-40,30],[40,-30]]},
		{"points":[[0,0],[2,0],[2,2],[0,2]]},
		{"points":[[-40,-3],[40,-3],[40,3],[-40,3]]}
	]:
		var changed: Dictionary = base.duplicate(true)
		changed.merge(patch,true)
		check(not TrackDocument.validate(changed).is_empty(),"hostile or invalid document rejected: "+str(patch.keys()))
	var oversized: Dictionary = base.duplicate(true)
	oversized.points = []
	for i: int in range(97):
		oversized.points.append([cos(TAU*i/97)*40,sin(TAU*i/97)*40])
	check(not TrackDocument.validate(oversized).is_empty(),"per-document point bound enforced")
	var sharp: Dictionary = base.duplicate(true)
	sharp.points = [[-40,-30],[40,-30],[40,30],[32,32],[30,-15],[-30,30]]
	check(TrackDocument.validate(sharp).is_empty(),"owner-approved tight bend is no longer blocked by minimum-radius policy")
	check(TrackCompiler.compile(sharp) != null,"tight bend compiles for human test driving")
	var overlap: Dictionary = base.duplicate(true)
	overlap.points = [[-45,-25],[20,-25],[35,-8],[20,8],[-25,8],[-35,-2],[15,-2],[30,28],[-40,28]]
	check(not TrackDocument.validate(overlap).is_empty(),"changed node count without matching property arrays rejected")
	for width: float in [6.0,20.0]:
		var wide: Dictionary = base.duplicate(true)
		wide.width = width
		wide.widths.fill(width)
		check(TrackDocument.validate(wide).is_empty(),"legal boundary width %.0f metres accepted" % width)


func _check_storage() -> void:
	var folder: String = "user://creator_tests_"+TrackLibrary.unique_id()
	var library := TrackLibrary.new(folder)
	var document: Dictionary = TrackDocument.create_default()
	check(library.save_document(document) == OK,"initial atomic save succeeds")
	check(library.load_document(document.id) == document,"saved route round trips")
	var older: Dictionary = document.duplicate(true)
	document.name = "Revised circuit"
	check(library.save_document(document) == OK,"replacement atomic save succeeds")
	var path: String = folder.path_join(document.id+".json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{ interrupted")
	file.close()
	check(library.load_document(document.id) == older,"corrupt primary recovers previous valid backup")
	check(library.save_document(document) == OK and library.load_document(document.id) == document,"can save again after corrupt-primary recovery")
	DirAccess.remove_absolute(path)
	check(library.load_document(document.id) == older,"missing primary recovers backup after interrupted rename")
	check(library.save_document(document) == OK,"commit after missing-primary recovery succeeds")
	var another: Dictionary = document.duplicate(true)
	another.id = "another_track"
	check(library.save_document(another) == OK and library.list_documents().size() == 2,"multiple local documents have independent identities")
	check(library.load_document("../outside").is_empty(),"load rejects path traversal")
	var export_path: String = folder.path_join("exchange.json")
	check(library.export_document(document,export_path) == OK,"plain file export succeeds")
	check(library.import_document(export_path) == document,"free file import round trips")
	file = FileAccess.open(export_path,FileAccess.WRITE)
	file.store_string(" ".repeat(TrackDocument.MAX_BYTES+1))
	file.close()
	check(library.import_document(export_path).is_empty() and "too large" in library.last_error,"oversized input refused before parsing")
	file = FileAccess.open(export_path,FileAccess.WRITE)
	file.store_string("{\"schema\":\"creator-track-v1\",\"script\":\"res://malicious.gd\"}")
	file.close()
	check(library.import_document(export_path).is_empty(),"script-like JSON import rejected without ResourceLoader")
	var temporary_document: Dictionary = older.duplicate(true)
	temporary_document.id = "interrupted_first_save"
	var first_path: String = folder.path_join(temporary_document.id+".json.tmp")
	file = FileAccess.open(first_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(temporary_document))
	file.close()
	check(library.load_document(temporary_document.id) == temporary_document,"interrupted first save can recover verified temporary JSON")
	check(library.list_documents().size() == 3,"library discovers recoverable backups and first-save temporaries once")
	# Clean only files inside this uniquely named test directory.
	var directory := DirAccess.open(folder)
	for filename: String in directory.get_files():
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)


func _drive_and_replay(track: NativeTrack, label: String) -> void:
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var simulation := VehicleSimulation.new(config)
	simulation.reset(track.spawn,track.spawn_heading)
	simulation.state.route_index = track.nearest_route(track.spawn)
	check(track.collision_normal(track.spawn,config.collision_radius,false) == Vector2.ZERO,label+" spawn has body clearance")
	var session := TrackSession.new(120, 3)
	var driver := RouteDriver.new()
	var frames: Array[Array] = []
	for tick: int in range(120*240):
		var from: Vector2 = simulation.state.position
		var input: DriveFrame = driver.sample(simulation.state,track,config)
		frames.append(input.packed())
		simulation.step(input,track)
		session.advance(track,from,simulation.state.position,simulation.state.route_index)
		if session.finished:
			break
	print("CREATOR_RACE ",label," laps=",session.completed_laps," times=",session.lap_times," contacts=",simulation.state.collision_count)
	check(session.finished and session.completed_laps == 3,label+" diagnostic AI completes exactly three ordered laps")
	check(simulation.state.collision_count == 0,label+" diagnostic AI avoids barriers")
	var replay := VehicleSimulation.new(config)
	replay.reset(track.spawn,track.spawn_heading)
	replay.state.route_index = track.nearest_route(track.spawn)
	var replay_session := TrackSession.new(120, 3)
	var parsed_frames: Array = JSON.parse_string(JSON.stringify(frames))
	for batch: int in range(0,parsed_frames.size(),8):
		for index: int in range(batch,mini(batch+8,parsed_frames.size())):
			var input := DriveFrame.new()
			input.steer = int(parsed_frames[index][0])
			input.throttle = int(parsed_frames[index][1])
			input.brake = int(parsed_frames[index][2])
			var from: Vector2 = replay.state.position
			replay.step(input,track)
			replay_session.advance(track,from,replay.state.position,replay.state.route_index)
	check(replay.state.snapshot() == simulation.state.snapshot() and replay_session.lap_times == session.lap_times,label+" complete three-lap JSON replay is exact in 8-tick batches")

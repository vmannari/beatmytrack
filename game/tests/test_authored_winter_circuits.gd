extends SceneTree
## Content acceptance for two original editable Winter tracks. No network/player writes.

const IDS: Array[String] = ["frostline", "lantern_village"]
const SOURCE := "res://resources/creator_tracks/"
const OUTPUT := "res://../docs/evidence/winter-circuits-2026-10-22/"
var failures: int = 0
var checks: int = 0
var rows: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for id: String in IDS:
		var path: String = SOURCE+id+".json"
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var linked: Dictionary = RoadPieces.route_from_pieces(doc)
		check(linked.ok,"connected editable road loop: "+id+str(linked.errors))
		if not linked.ok: continue
		if "--prepare" in OS.get_cmdline_user_args():
			doc = JSON.parse_string(JSON.stringify(linked.document))
			var target := FileAccess.open(path,FileAccess.WRITE)
			target.store_string(JSON.stringify(doc,"\t",true)+"\n"); target.close()
		check(TrackDocument.validate(doc).is_empty(),"bounded current creator schema: "+id+str(TrackDocument.validate(doc)))
		check(doc.theme == "winter" and not doc.automatic_scenery,"Winter with explicitly composed scenery: "+id)
		check(doc.objects.size() <= 96 and FileAccess.get_file_as_bytes(path).size() <= TrackDocument.MAX_BYTES,"existing content limits: "+id)
		var catalog_ok: bool = true
		for object: Dictionary in doc.objects:
			catalog_ok = catalog_ok and CreatorCatalog.available(object.kind,"winter")
		check(catalog_ok,"every prop uses the curated Winter collection: "+id)
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track != null,"native compiler accepts "+id)
		if track == null: continue
		check(track.route_length > 400.0 and track.route_length < 750.0,"complete lap length: "+id)
		check(TrackCompiler.compile(JSON.parse_string(JSON.stringify(doc))).content_hash == track.content_hash,"JSON roundtrip retains the exact content identity: "+id)
		var library := TrackLibrary.new(ProjectSettings.globalize_path("res://../build/winter-circuits-library/"+str(OS.get_process_id())))
		check(library.save_document(doc) == OK and library.load_document(id) == doc,"real draft save and reload: "+id)
		# Independently probe all three lanes for ground/solid contacts, including joins.
		var blocked: int = 0
		var offroad: int = 0
		var config: HandlingConfig = VehicleCatalog.config("compact")
		for i: int in range(track.route.size()):
			var tangent: Vector2 = (track.route[(i+1)%track.route.size()]-track.route[posmod(i-1,track.route.size())]).normalized()
			for offset: float in [-3.0,0.0,3.0]:
				var point: Vector2 = track.route[i]+tangent.orthogonal()*offset
				if track.collision_normal(point,config.collision_radius,false) != Vector2.ZERO: blocked += 1
				if track.cell_at(point,false) != 0: offroad += 1
		check(blocked == 0,"three usable lanes have no prop/solid obstruction: "+id+" "+str(blocked))
		check(offroad == 0,"three usable lanes stay on the continuous ice road: "+id+" "+str(offroad))
		for reverse: bool in [false,true]:
			var variant: Dictionary = doc.duplicate(true)
			if reverse: variant.start_line.heading = fposmod(float(variant.start_line.heading)+180.0,360.0)
			var circuit: NativeTrack = TrackCompiler.compile(variant)
			check(circuit.collision_normal(circuit.spawn,config.collision_radius,false) == Vector2.ZERO,"standing start clears supports: "+id+str(reverse))
			if DisplayServer.get_name() == "headless": simulate(circuit,reverse)
		if DisplayServer.get_name() != "headless": await capture(track)
	var report := FileAccess.open(OUTPUT+"report-"+DisplayServer.get_name()+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":rows},"\t",true)); report.close()
	print("AUTHORED_WINTER_CIRCUITS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func simulate(track: NativeTrack, reverse: bool) -> void:
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var sim := VehicleSimulation.new(config); sim.reset(track.spawn,track.spawn_heading)
	var driver := RouteDriver.new(); var session := TrackSession.new(120,5)
	var warned: bool = false
	var frames: Array = []
	for tick: int in range(90000):
		var input: DriveFrame = driver.sample(sim.state,track,config); frames.append(input.packed())
		var before: Vector2 = sim.state.position
		sim.step(input,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated)
		warned = warned or session.missed_checkpoint >= 0
		if session.finished: break
	var label: String = track.identity+" reverse="+str(reverse)
	check(session.finished and session.completed_laps == 5,"physical Compact completes five laps: "+label)
	check(not warned,"no missed checkpoints on the driven line: "+label)
	check(sim.state.collision_count == 0,"clean physical driving: "+label)
	var replay := VehicleSimulation.new(config); replay.reset(track.spawn,track.spawn_heading)
	var scored := TrackSession.new(120,5)
	for values: Array in JSON.parse_string(JSON.stringify(frames)):
		var input := DriveFrame.new(); input.steer = int(values[0]); input.throttle = int(values[1]); input.brake = int(values[2])
		var before: Vector2 = replay.state.position; replay.step(input,track)
		scored.advance(track,before,replay.state.position,replay.state.route_index,replay.state.track_elevated)
	check(replay.state.snapshot() == sim.state.snapshot() and scored.lap_times == session.lap_times,"complete recording replays exactly: "+label)
	var row: Dictionary = {"id":track.identity,"reverse":reverse,"length_m":track.route_length,"props":track.hazard_objects.size(),"ticks":sim.state.tick,"laps":session.completed_laps,"lap_times":session.lap_times,"collisions":sim.state.collision_count,"missed_checkpoint":warned,"hash":track.content_hash}
	rows.append(row); print("WINTER_DRIVE: ",JSON.stringify(row))

func frames(count: int = 8) -> void:
	for i: int in range(count): await process_frame
	await RenderingServer.frame_post_draw

func capture(track: NativeTrack) -> void:
	root.size = Vector2i(1600,1000); root.content_scale_size = root.size
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track); game.set("production_mode",true); game.set("vehicle_id","compact")
	root.add_child(game); game.set_physics_process(false); game.set("paused",true)
	game.call("_process",0.0); game.set_process(false)
	game.get("hud").hide(); game.get("race_cues").hide()
	var camera: Camera3D = game.get("camera")
	var folder: String = ProjectSettings.globalize_path(OUTPUT+RenderingServer.get_current_rendering_method()+"/")
	DirAccess.make_dir_recursive_absolute(folder)
	var original: String = track.content_hash
	camera.size = 206.0
	camera.far = 600
	camera.look_at_from_position(Vector3(0,220,95),Vector3(0,0,0))
	await frames(15)
	check(root.get_texture().get_image().save_png(folder+track.identity+"-overview.png") == OK,"native overview saved: "+track.identity)
	for fraction: float in [0.0,0.34,0.61,0.83]:
		var i: int = int(track.route.size()*fraction)
		var point: Vector2 = track.route[i]
		var forward: Vector2 = (track.route[(i+3)%track.route.size()]-point).normalized()
		game.get("sim").reset(point,atan2(forward.x,forward.y))
		game.call("_process",0.0)
		camera.size = 46.0
		camera.look_at_from_position(Vector3(point.x,36,-point.y+26),Vector3(point.x,0,-point.y))
		await frames()
		check(root.get_texture().get_image().save_png(folder+track.identity+"-sector-%02d.png" % roundi(fraction*100)) == OK,"native track sector saved")
	check(track.content_hash == original,"capture preserves canonical identity")
	game.queue_free(); await frames(3)

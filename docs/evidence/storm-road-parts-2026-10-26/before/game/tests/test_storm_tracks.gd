extends SceneTree
## Exercise authored content through the actual compiler, collision and lap rules.
const IDS: Array[String] = ["storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"]
const OUTPUT: String = "res://../docs/evidence/storm-five-tracks-2026-10-25"
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	for id: String in IDS:
		var source: String = "res://resources/storm_tracks/"+id+".json"
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
		var errors: Array[String] = TrackDocument.validate(document)
		check(errors.is_empty(),id+" current creator document: "+str(errors))
		if not errors.is_empty(): continue
		var track: NativeTrack = TrackCompiler.compile(document)
		check(track != null,id+" compiles")
		if track == null: continue
		check(document.theme == "storm" and track.metadata.theme == "storm",id+" actual wet biome")
		check(track.metadata.scenery_objects.is_empty() and not document.automatic_scenery,id+" every object explicitly authored")
		var overlaps: Array = []
		var invalid_kit: Array = []
		for i: int in range(document.objects.size()):
			var object: Dictionary = document.objects[i]
			if not CreatorCatalog.family(object.kind).is_empty() and not CreatorCatalog.available(object.kind,"storm"): invalid_kit.append(i)
			if object.kind in ["water","puddle","gantry"] or object.kind in CreatorCatalog.DECORATIVE: continue
			for j: int in range(i):
				var other: Dictionary = document.objects[j]
				if other.kind in ["water","puddle","gantry"] or other.kind in CreatorCatalog.DECORATIVE: continue
				if not Geometry2D.intersect_polygons(CreatorObjects.outline(object),CreatorObjects.outline(other)).is_empty(): overlaps.append([i,j])
		check(overlaps.is_empty(),id+" separate prop footprints do not overlap: "+str(overlaps))
		check(invalid_kit.is_empty(),id+" all placed models belong to the Storm kit")
		var blocked: Array = []
		var shoulder_blocks: Array = []
		var corners: int = 0
		var tight: int = 0
		for i: int in range(track.route.size()):
			var p: Vector2 = track.route[i]
			var tangent: Vector2 = (track.route[(i+1)%track.route.size()]-track.route[posmod(i-1,track.route.size())]).normalized()
			var side := Vector2(-tangent.y,tangent.x)
			for offset: float in [-2.8,0.0,2.8]:
				if track.collision_normal(p+side*offset,0.85,false) != Vector2.ZERO: blocked.append([i,offset])
			for offset: float in [-float(track.route_widths[i])*.5+.6,float(track.route_widths[i])*.5-.6]:
				if track.collision_normal(p+side*offset,.25,false) != Vector2.ZERO: shoulder_blocks.append([i,offset])
			var a: Vector2 = (p-track.route[posmod(i-4,track.route.size())]).normalized()
			var b: Vector2 = (track.route[(i+4)%track.route.size()]-p).normalized()
			var bend: float = absf(a.angle_to(b))
			if bend>.15: corners += 1
			if bend>.35: tight += 1
		check(blocked.is_empty(),id+" continuous 7.3m swept driving corridor: "+str(blocked.slice(0,12)))
		check(shoulder_blocks.is_empty(),id+" props clear usable road width: "+str(shoulder_blocks.slice(0,12)))
		if not blocked.is_empty():
			var point: Vector2 = track.route[blocked[0][0]]
			print("STORM_CLEARANCE_DETAIL ",id," ",point)
			for object: Dictionary in document.objects:
				if point.distance_to(Vector2(object.position[0],object.position[1]))<15: print(object)
		check(corners>75 and tight>12,id+" sustained cornering and multiple tight braking zones")
		check(track.collision_normal(track.spawn,2.0,false)==Vector2.ZERO,id+" largest-car spawn clearance")
		var row: Dictionary = {"id":id,"name":document.name,"route_m":TrackDocument.route_length(track.route),"objects":document.objects.size(),"corner_samples":corners,"tight_samples":tight,"blocked":blocked,"shoulder_blocks":shoulder_blocks,"cars":[]}
		var cars: Array[String] = VehicleCatalog.IDS.duplicate()
		if "--compact-only" in OS.get_cmdline_user_args(): cars = ["compact"]
		if "--geometry-only" in OS.get_cmdline_user_args(): cars = []
		for car: String in cars:
			var config: HandlingConfig = VehicleCatalog.config(car)
			var sim := VehicleSimulation.new(config)
			sim.reset(track.spawn,track.spawn_heading)
			sim.state.route_index = track.nearest_route(track.spawn)
			var driver := RouteDriver.new()
			var session := TrackSession.new(120,5)
			var frames: Array[Array] = []
			var braking: int = 0
			var coasting: int = 0
			for tick: int in range(72000):
				var frame: DriveFrame = driver.sample(sim.state,track,config)
				if car == "compact": frames.append(frame.packed())
				if frame.brake>0: braking += 1
				if frame.throttle==0: coasting += 1
				var before: Vector2 = sim.state.position
				sim.step(frame,track)
				session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated)
				if session.finished: break
			var result: Dictionary = {"car":car,"finished":session.finished,"laps":session.lap_times,"ticks":sim.state.tick,"contacts":sim.state.collision_count,"braking_ticks":braking,"lift_ticks":coasting}
			row.cars.append(result)
			print("STORM_TRACK_DRIVE ",id," ",result)
			check(session.finished,id+" "+car+" completes all five ordered laps")
			check(sim.state.collision_count==0,id+" "+car+" collision-free conservative line")
			check(coasting>300,id+" "+car+" needs speed management")
			if car == "compact":
				check(braking>100,id+" actual braking demanded by the layout")
				var replay := VehicleSimulation.new(config)
				replay.reset(track.spawn,track.spawn_heading)
				replay.state.route_index = track.nearest_route(track.spawn)
				var replay_session := TrackSession.new(120,5)
				var decoded: Array = JSON.parse_string(JSON.stringify(frames))
				for batch: int in range(0,decoded.size(),8):
					for j: int in range(batch,mini(batch+8,decoded.size())):
						var frame := DriveFrame.new()
						frame.steer = int(decoded[j][0]); frame.throttle = int(decoded[j][1]); frame.brake = int(decoded[j][2])
						var before: Vector2 = replay.state.position
						replay.step(frame,track)
						replay_session.advance(track,before,replay.state.position,replay.state.route_index,replay.state.track_elevated)
				check(replay.state.snapshot()==sim.state.snapshot() and replay_session.lap_times==session.lap_times,id+" exact full five-lap JSON replay")
		if "--bake" in OS.get_cmdline_user_args():
			var data: Dictionary = track.metadata.duplicate(true)
			data.identity = id
			data.creator = document.creator
			data.provenance = {"source":"Original authored Storm collection","source_sha256":FileAccess.get_sha256(source),"use":"local built-in circuit and editable creator export"}
			var file := FileAccess.open("res://resources/tracks/"+id+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify(data,"\t")); file.close()
		rows.append(row)
		var suffix: String = "-geometry" if "--geometry-only" in OS.get_cmdline_user_args() else ("-compact" if "--compact-only" in OS.get_cmdline_user_args() else "")
		var report := FileAccess.open(OUTPUT+"/runtime"+suffix+".json",FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks":checks,"failures":failures,"tracks":rows},"\t")); report.close()
	print("STORM_TRACK_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

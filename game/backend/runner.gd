extends SceneTree
## Data-only process boundary around unchanged game simulation and compiler.
const MAX_FRAMES: int = 216000
const REPLAY_SCHEMA: String = "bmt-replay-v1"
var output_path: String = ""

func _initialize() -> void:
	call_deferred("run")

func respond(result: Dictionary, error: String = "") -> void:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	file.store_string(JSON.stringify({"ok":error.is_empty(),"result":result} if error.is_empty() else {"ok":false,"error":error}))
	file.close()
	quit(0 if error.is_empty() else 2)

func manifest() -> Dictionary:
	var vehicles: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		var values: Dictionary = {}
		for property: Dictionary in config.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				values[str(property.name)] = config.get(property.name)
		vehicles[id] = {"handling_version":config.version,"config_hash":JSON.stringify(values,"",true).sha256_text()}
	var engine: Dictionary = Engine.get_version_info()
	var engine_version: String = "%s.%s.%s.%s.%s.%s" % [engine.major,engine.minor,engine.patch,engine.status,engine.build,str(engine.hash).left(9)]
	return {"engine_version":engine_version,"rules_key":RaceRules.KEY,
		"physics_version":VehicleSimulation.PHYSICS_VERSION,"compiler_version":TrackCompiler.VERSION,
		"track_schema":TrackDocument.SCHEMA,"replay_schema":REPLAY_SCHEMA,"tick_rate":VehicleSimulation.TICK_RATE,
		"laps":RaceRules.LAPS,"max_frames":MAX_FRAMES,"vehicles":vehicles,"verifier_version":"canonical-verifier-1"}

func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1])

func route_shape(value: Variant) -> bool:
	if not value is Dictionary or not value.get("points") is Array or not value.get("widths") is Array or not value.get("corners") is Array: return false
	if value.points.size() < 4 or value.points.size() > 96 or value.widths.size() != value.points.size() or value.corners.size() != value.points.size(): return false
	for point: Variant in value.points:
		if not pair(point): return false
	for width: Variant in value.widths:
		if not number(width): return false
	for corner: Variant in value.corners:
		if not corner is String: return false
	return value.get("surface") is String

func safe_shape(doc: Variant) -> bool:
	# Guard unsafe conversions in the original trusted/local editor validator.
	if not doc is Dictionary or not route_shape(doc): return false
	for key: String in ["schema","id","name","theme","base_track"]:
		if not doc.get(key) is String: return false
	if doc.has("creator") and not doc.creator is String: return false
	if not number(doc.get("width")) or not doc.get("route_override") is bool: return false
	if not doc.get("layout") is Dictionary or (not doc.layout.is_empty() and not route_shape(doc.layout)): return false
	for key: String in ["pieces","paint","objects"]:
		if not doc.get(key) is Array: return false
	if doc.pieces.size() > 96 or doc.objects.size() > 96 or doc.paint.size() > 256: return false
	for piece: Variant in doc.pieces:
		if not piece is Dictionary or not piece.get("kind") is String or not pair(piece.get("position")) or not piece.get("flip") is bool: return false
		for key: String in ["heading","length","radius","width"]:
			if not number(piece.get(key)): return false
		for key: String in ["angle","height","curvature","narrow_width"]:
			if piece.has(key) and not number(piece[key]): return false
	for object: Variant in doc.objects:
		if not object is Dictionary or not object.get("kind") is String or not pair(object.get("position")) or not number(object.get("rotation")): return false
		if object.has("scale") and not number(object.scale): return false
	for stroke: Variant in doc.paint:
		if not stroke is Dictionary or not number(stroke.get("surface")) or not number(stroke.get("width")) or not stroke.get("shape") is String or not stroke.get("points") is Array: return false
		for point: Variant in stroke.points:
			if not pair(point): return false
	for key: String in ["start_line","practice_start"]:
		if doc.has(key) and (not doc[key] is Dictionary or not pair(doc[key].get("position")) or not number(doc[key].get("heading"))): return false
	return true

func compile_track(doc: Dictionary) -> Dictionary:
	if not safe_shape(doc): return {"error":"Malformed creator document structure"}
	if JSON.stringify(doc).to_utf8_buffer().size() > TrackDocument.MAX_BYTES: return {"error":"Creator document exceeds 512 KiB"}
	var errors: Array[String] = TrackDocument.validate(doc)
	if not errors.is_empty(): return {"error":errors[0]}
	if doc.base_track != "" or not doc.has("start_line"): return {"error":"Published tracks need original connected road pieces and a placed start line"}
	var generated: Dictionary = RoadPieces.route_from_pieces(doc)
	if not generated.ok: return {"error":str(generated.errors[0])}
	# A route cannot be shortened independently from the physical road.
	var automatic: Dictionary = generated.document
	# Route widths are generated and consumed as float32. JSON round-tripping
	# widens them to float64 with decimal rounding; compare canonical precision,
	# not those incidental low bits. Compile the unchanged submitted document.
	if doc.points.size() != automatic.points.size() or doc.corners != automatic.corners or PackedFloat32Array(doc.widths) != PackedFloat32Array(automatic.widths):
		return {"error":"Regenerate the automatic route from connected road pieces"}
	for i: int in range(doc.points.size()):
		if Vector2(doc.points[i][0],doc.points[i][1]).distance_to(Vector2(automatic.points[i][0],automatic.points[i][1])) > 0.002:
			return {"error":"Lap route does not match connected road pieces"}
	var start := Vector2(doc.start_line.position[0],doc.start_line.position[1])
	var placed: Dictionary = CreatorStartLine.place(automatic,start,null)
	if placed.is_empty() or start.distance_to(Vector2(placed.position[0],placed.position[1])) > 0.05:
		return {"error":"Start line must be placed on the road centreline"}
	# Validate against automatically generated roads, then compile the exact frozen
	# submitted document, as the game does. Replacing saved points with regenerated
	# trig results changes JSON identity across operating systems (even tiny zeros).
	var track: NativeTrack = TrackCompiler.compile(doc)
	if track == null: return {"error":"Track compilation failed"}
	var info: Dictionary = manifest()
	info.track_content_hash = track.content_hash
	info.route_length = track.route_length
	return {"track":track,"manifest":info}

func replay_error(replay: Variant) -> String:
	if not replay is Dictionary or not replay.get("frames") is Array:
		return "Unsupported replay envelope"
	if not ((replay.size() == 2 and replay.get("schema") == REPLAY_SCHEMA) or (replay.size() == 3 and replay.get("schema") == "bmt-replay-v2" and replay.get("rewinds") is Array)): return "Unsupported replay envelope"
	if replay.frames.is_empty() or replay.frames.size() > MAX_FRAMES: return "Replay frame count outside bounds"
	for frame_index: int in range(replay.frames.size()):
		var frame: Variant = replay.frames[frame_index]
		if not frame is Array or frame.size() not in [3, 4, 5]: return "Malformed quantized frame"
		for value: Variant in frame:
			if not number(value) or float(value) != floorf(float(value)): return "Replay inputs must be quantized integers"
		if frame.size() == 5 and (frame_index != 0 or int(frame[4]) not in [1, 2]): return "Invalid launch marker"
		if frame[0] < -127 or frame[0] > 127 or frame[1] < 0 or frame[1] > 255 or frame[2] < 0 or frame[2] > 255 or (frame.size() >= 4 and (frame[3] < 0 or frame[3] > 255)):
			return "Replay input outside quantized range"
	var offset: int = 0
	var tick: int = 0
	var receipts: Array = []
	var events: Array = replay.get("rewinds",[])
	if events.size() > 3 or (replay.schema == "bmt-replay-v2" and events.is_empty()): return "One to three rewinds required"
	for event: Variant in events:
		if not event is Dictionary or event.size() != 4: return "Malformed rewind"
		if not event.get("receipt_id") is String or event.receipt_id.length() != 36 or event.receipt_id in receipts: return "Invalid resume receipt"
		receipts.append(event.receipt_id)
		for key: String in ["input_offset","from_tick","to_tick"]:
			if not number(event.get(key)) or float(event[key]) != floorf(float(event[key])): return "Invalid rewind tick"
		if event.input_offset <= offset or event.input_offset >= replay.frames.size(): return "Invalid rewind input offset"
		if event.from_tick != tick+int(event.input_offset)-offset: return "Invalid rewind timeline"
		if event.to_tick < 0 or event.from_tick-event.to_tick < 1 or event.from_tick-event.to_tick > RewindHistory.WINDOW_TICKS: return "Rewind exceeds 10 seconds"
		offset = int(event.input_offset)
		tick = int(event.to_tick)
	return ""

func initial_simulation(track: NativeTrack, vehicle: String) -> VehicleSimulation:
	var sim := VehicleSimulation.new(VehicleCatalog.config(vehicle))
	sim.reset(track.spawn,track.spawn_heading)
	# Match the standing production race start, not the untimed editor spawn.
	var distance: float = (sim.state.position-track.finish_center).dot(track.finish_forward)
	sim.state.position -= track.finish_forward*maxf(0.0,distance+3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	sim.state.track_elevated = track.elevated_at(sim.state.position,sim.state.route_index)
	if CreatorBridges.at_any(track.creator_bridges,sim.state.position):
		sim.state.track_elevated = CreatorBridges.initial_layer(track.creator_bridges,sim.state.position,sim.state.heading)
	return sim

func verify(track: NativeTrack, replay: Dictionary, vehicle: String, info: Dictionary, creator_test: bool = false, document: Dictionary = {}) -> void:
	if creator_test and not replay.get("rewinds",[]).is_empty():
		respond({},"Creator practice cannot contain rewinds"); return
	var sim: VehicleSimulation = initial_simulation(track,vehicle)
	var target_laps: int = 1 if creator_test else RaceRules.LAPS
	if creator_test:
		sim.reset(Vector2(document.start_line.position[0],document.start_line.position[1]),PI*0.5-deg_to_rad(float(document.start_line.heading)))
		sim.state.route_index = track.nearest_route(sim.state.position)
		sim.state.track_elevated = track.elevated_at(sim.state.position,sim.state.route_index)
		if CreatorBridges.at_any(track.creator_bridges,sim.state.position):
			sim.state.track_elevated = CreatorBridges.initial_layer(track.creator_bridges,sim.state.position,sim.state.heading)
	var session := TrackSession.new(VehicleSimulation.TICK_RATE,target_laps)
	if not creator_test: session._configure(track)
	var ghost := PersonalGhostRun.new()
	var bridge := BridgeElevation.new(track)
	ghost.capture(sim.state,session,track,bridge,sim.config,true)
	var lap_ticks: Array[int] = []
	var last_lap_tick: int = 0
	var events: Array = replay.get("rewinds",[])
	var targets: Array[int] = []
	for event: Dictionary in events: targets.append(int(event.to_tick))
	var saved: Dictionary = {}
	var next_event: int = 0
	var offset: int = 0
	for values: Array in replay.frames:
		if offset == 0 and values.size() == 5: LaunchStart.initialize(sim.state,int(values[4]))
		if sim.state.tick in targets:
			saved[sim.state.tick] = {"state":RewindHistory.properties(sim.state),"session":RewindHistory.properties(session,true),"laps":lap_ticks.duplicate(),"last_lap":last_lap_tick}
		if next_event < events.size() and int(events[next_event].input_offset) == offset:
			var event: Dictionary = events[next_event]
			if session.finished or sim.state.tick != int(event.from_tick) or not saved.has(int(event.to_tick)):
				respond({},"Cannot rewind this race state"); return
			var checkpoint: Dictionary = saved[int(event.to_tick)]
			RewindHistory.restore(sim.state,checkpoint.state)
			RewindHistory.restore(session,checkpoint.session)
			ghost.branch(sim.state.tick)
			lap_ticks.assign(checkpoint.laps)
			last_lap_tick = int(checkpoint.last_lap)
			for key: int in saved.keys():
				if key > sim.state.tick: saved.erase(key)
			next_event += 1
		offset += 1
		if session.finished:
			respond({},"Replay contains frames after the race finished")
			return
		var frame := DriveFrame.new()
		frame.steer = int(values[0]); frame.throttle = int(values[1]); frame.brake = int(values[2])
		frame.handbrake = int(values[3]) if values.size() >= 4 else 0
		frame.launch_start = int(values[4]) if values.size() == 5 else 0
		var before: Vector2 = sim.state.position
		var previous_layer: int = int(sim.state.track_elevated)
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated,previous_layer)
		ghost.capture(sim.state,session,track,bridge,sim.config,session.finished)
		if session.completed_laps > lap_ticks.size():
			lap_ticks.append(session.elapsed_ticks-last_lap_tick)
			last_lap_tick = session.elapsed_ticks
	if not session.finished or session.completed_laps != target_laps or lap_ticks.size() != target_laps:
		respond({},"Replay does not complete the required laps and ordered road gates")
		return
	respond({"time_ticks":session.elapsed_ticks,"time_ms":roundi(session.race_time_seconds()*1000.0),"lap_ticks":lap_ticks,"manifest":info,"ghost":ghost.recording("race") if not creator_test else {}})

func run() -> void:
	var input_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input_path = arg.trim_prefix("--input=")
		elif arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	if input_path.is_empty() or output_path.is_empty(): quit(3); return
	var file := FileAccess.open(input_path,FileAccess.READ)
	if file == null or file.get_length() > 8388608: respond({},"Invalid request file"); return
	var request: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not request is Dictionary: respond({},"Invalid request envelope"); return
	if request.get("operation") == "manifest": respond(manifest()); return
	if request.get("operation") == "prepare_track" and request.get("document") is Dictionary:
		var source: Dictionary = request.document
		if not safe_shape(source): respond({},"Malformed creator document structure"); return
		var automatic: Dictionary = RoadPieces.route_from_pieces(source)
		if not automatic.ok: respond({},str(automatic.errors[0])); return
		var prepared: Dictionary = compile_track(automatic.document)
		if prepared.has("error"): respond({},prepared.error); return
		respond({"document":automatic.document,"manifest":prepared.manifest}); return
	if request.get("operation") not in ["track","run","creator_test"] or not request.get("document") is Dictionary:
		respond({},"Unsupported verification operation"); return
	if request.operation in ["run","creator_test"]:
		var error: String = replay_error(request.get("replay"))
		if not error.is_empty(): respond({},error); return
		if not request.get("vehicle_id") is String or request.vehicle_id not in VehicleCatalog.IDS:
			respond({},"Unsupported vehicle"); return
	var compiled: Dictionary = compile_track(request.document)
	if compiled.has("error"): respond({},compiled.error); return
	if request.operation == "track": respond(compiled.manifest); return
	verify(compiled.track,request.replay,request.vehicle_id,compiled.manifest,request.operation == "creator_test",request.document)

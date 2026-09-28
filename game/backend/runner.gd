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
	if doc.points.size() != automatic.points.size() or doc.corners != automatic.corners or doc.widths != automatic.widths:
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
	if not replay is Dictionary or replay.size() != 2 or replay.get("schema") != REPLAY_SCHEMA or not replay.get("frames") is Array:
		return "Unsupported replay envelope"
	if replay.frames.is_empty() or replay.frames.size() > MAX_FRAMES: return "Replay frame count outside bounds"
	for frame: Variant in replay.frames:
		if not frame is Array or frame.size() != 3: return "Malformed quantized frame"
		for value: Variant in frame:
			if not number(value) or float(value) != floorf(float(value)): return "Replay inputs must be quantized integers"
		if frame[0] < -127 or frame[0] > 127 or frame[1] < 0 or frame[1] > 255 or frame[2] < 0 or frame[2] > 255:
			return "Replay input outside quantized range"
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

func verify(track: NativeTrack, replay: Dictionary, vehicle: String, info: Dictionary) -> void:
	var sim: VehicleSimulation = initial_simulation(track,vehicle)
	var session := TrackSession.new(VehicleSimulation.TICK_RATE,RaceRules.LAPS)
	var lap_ticks: Array[int] = []
	var last_lap_tick: int = 0
	for values: Array in replay.frames:
		if session.finished:
			respond({},"Replay contains frames after the race finished")
			return
		var frame := DriveFrame.new()
		frame.steer = int(values[0]); frame.throttle = int(values[1]); frame.brake = int(values[2])
		var before: Vector2 = sim.state.position
		sim.step(frame,track)
		session.advance(track,before,sim.state.position,sim.state.route_index)
		if session.completed_laps > lap_ticks.size():
			lap_ticks.append(session.elapsed_ticks-last_lap_tick)
			last_lap_tick = session.elapsed_ticks
	if not session.finished or session.completed_laps != 5 or lap_ticks.size() != 5:
		respond({},"Replay does not complete all five laps and ordered road gates")
		return
	respond({"time_ticks":session.elapsed_ticks,"time_ms":roundi(session.race_time_seconds()*1000.0),"lap_ticks":lap_ticks,"manifest":info})

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
	if request.get("operation") not in ["track","run"] or not request.get("document") is Dictionary:
		respond({},"Unsupported verification operation"); return
	if request.operation == "run":
		var error: String = replay_error(request.get("replay"))
		if not error.is_empty(): respond({},error); return
		if not request.get("vehicle_id") is String or request.vehicle_id not in VehicleCatalog.IDS:
			respond({},"Unsupported vehicle"); return
	var compiled: Dictionary = compile_track(request.document)
	if compiled.has("error"): respond({},compiled.error); return
	if request.operation == "track": respond(compiled.manifest); return
	verify(compiled.track,request.replay,request.vehicle_id,compiled.manifest)

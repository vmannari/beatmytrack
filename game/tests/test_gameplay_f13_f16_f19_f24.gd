extends SceneTree
const BUDGET = preload("res://race/attempt_evidence.gd")
const DISK = preload("res://track/road_mesh_disk_cache.gd")
const ROADS = preload("res://editor/road_preparation.gd")
const BAKES = preload("res://track/road_cache_bakes.gd")
const BEFORE = "res://tests/fixtures/gameplay_f13_f16_f19_f24_before/"
var checks: int = 0
var failures: int = 0
var metrics: Array = []

class CountingCloud extends Node:
	var enqueues: int = 0
	func enqueue_completed(_ticket: Dictionary, _frames: Variant, _version: String, _rewinds: Array) -> bool:
		enqueues += 1
		return true

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func original(name: String, declaration: String = "") -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(BEFORE+name+".gd.txt").replace("\r\n","\n")
	if not declaration.is_empty(): script.source_code = script.source_code.replace("class_name "+declaration+"\n","")
	check(script.reload() == OK,"frozen baseline compiles "+name)
	return script
func same(a: VehicleState, b: VehicleState, label: String) -> void:
	check(var_to_bytes(a.snapshot()) == var_to_bytes(b.snapshot()),label)

func hazards() -> void:
	var old_track_script := GDScript.new()
	var baseline: String = FileAccess.get_file_as_string(BEFORE+"native_track.gd.txt").replace("\r\n","\n")
	var begin: int = baseline.find("func _creator_query()")
	var end: int = baseline.find("\nfunc ramp_height",begin)
	old_track_script.source_code = "extends NativeTrack\n"+baseline.substr(begin,end-begin)
	check(old_track_script.reload()==OK,"frozen original cache validation")
	var old_sim: GDScript = original("vehicle_simulation","VehicleSimulation")
	var old_bumps: GDScript = original("speed_bumps","SpeedBumps")
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
	var reference: RefCounted = old_track_script.new()
	for property: Dictionary in track.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE: reference.set(property.name,track.get(property.name))
	var objects: Array = []
	for index: int in range(4096):
		objects.append({"kind":["oil","puddle","jump","speed_bump"][index%4],"position":[float(index%64)*8.0-256.0,float(index/64)*8.0-256.0],"rotation":float(index%7)*29.0,"scale":0.5+float(index%4)*0.5})
	# Deliberately overlapping ramps have different heights and headings. First wins.
	objects.push_front({"kind":"jump","position":[0.0,0.0],"rotation":0.0,"scale":1.0})
	objects.push_front({"kind":"jump","position":[0.0,0.0],"rotation":180.0,"scale":2.0})
	track.hazard_objects = objects
	track.speed_bump_objects = objects.filter(func(item: Dictionary) -> bool: return item.kind == "speed_bump")
	reference.hazard_objects = objects; reference.speed_bump_objects = track.speed_bump_objects
	check(track.ramp_height(Vector2.ZERO) == 1.0,"overlapping ramps retain original first-match order")
	for index: int in range(600):
		var point := Vector2(float((index*31)%103)-51.0,float((index*19)%97)-48.0)*0.53
		check(track.ramp_height(point) == TrackHazards.ramp_height(point,objects),"ordered ramp height")
		check(track.ramp_pitch(point,Vector2.RIGHT) == TrackHazards.ramp_pitch(point,Vector2.RIGHT,objects),"ordered ramp pitch")
		var state := VehicleState.new(); state.position = point; state.velocity = Vector2(12.0,-3.0)
		check(track.tire_fluids(state) == reference.tire_fluids(state),"fluid candidates")
		check(track.surface_factors(state) == reference.surface_factors(state),"surface candidates")
		var before := VehicleState.new(); before.position = point+Vector2(40.0,-20.0); before.velocity = Vector2(30.0,0.0)
		var after := VehicleState.new(); RewindHistory.restore(after,RewindHistory.properties(before))
		TrackHazards.launch(before,point-Vector2(40.0,-20.0),objects)
		track.launch_jump(after,point-Vector2(40.0,-20.0))
		same(before,after,"swept launch candidates")
	# Empty nearby list must NOT take the no-bumps spring early return.
	for mode: int in range(6):
		var a := VehicleState.new(); a.position = Vector2(1000.0,1000.0); a.velocity = Vector2(10.0,1.0)
		a.bump_transfer = Vector2(0.2,-0.1); a.kerb_offset = Vector3(0.03,0.02,-0.01); a.kerb_velocity = Vector3(0.01,0.02,0.03)
		a.track_elevated = mode == 1; a.jump_height = 1.0 if mode == 2 else 0.0; a.roll_ticks = 2 if mode == 3 else 0
		var b := VehicleState.new(); RewindHistory.restore(b,RewindHistory.properties(a))
		var config: HandlingConfig = VehicleCatalog.config("compact")
		var bumps: Array = [] if mode == 4 else track.speed_bump_objects
		track.speed_bump_objects = bumps
		old_bumps.advance(a,a.position-Vector2(0.1,0.2),0.2,Vector2(9.0,1.0),config,bumps,VehicleSimulation.STEP)
		track.step_speed_bumps(b,b.position-Vector2(0.1,0.2),0.2,Vector2(9.0,1.0),config,VehicleSimulation.STEP)
		same(a,b,"distant/absent/air/elevated/roll spring semantics "+str(mode))
	track.speed_bump_objects = reference.speed_bump_objects
	var full_reference: NativeTrack = preload("res://tests/test_creator_capacity.gd").ReferenceTrack.new()
	for property: Dictionary in track.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE: full_reference.set(property.name,track.get(property.name))
	for car: String in VehicleCatalog.IDS:
		var a: RefCounted = old_sim.new(VehicleCatalog.config(car)); var b := VehicleSimulation.new(VehicleCatalog.config(car))
		a.reset(Vector2(-16,-16),0.0); b.reset(Vector2(-16,-16),0.0)
		for tick: int in range(240):
			var frame := DriveFrame.new(); frame.throttle = 255; frame.steer = 55 if tick%100 < 50 else -55; frame.brake = 120 if tick%60 > 50 else 0
			a.step(frame,full_reference); b.step(frame,track)
			same(a.state,b.state,"full exact driving "+car+"/"+str(tick))
			if failures: return
		check(track._creator_query().scope_depth == 0,"scope leaves every simulation step")
		for mode: int in range(3):
			var edge := VehicleSimulation.new(VehicleCatalog.config(car))
			edge.state.roll_ticks = 1 if mode == 0 else 0
			edge.state.jump_height = 1.0 if mode == 1 else 0.0
			edge.state.track_elevated = mode == 2
			edge.step(DriveFrame.new(),track)
			check(track._creator_query().scope_depth == 0,"early physics exit releases query scope")
	var work: RefCounted = track._creator_query(); var validations: int = work.validations
	track.begin_creator_queries()
	for index: int in range(10): track.ramp_height(Vector2.ZERO); track.ramp_pitch(Vector2.ZERO,Vector2.RIGHT)
	track.end_creator_queries()
	check(work.validations == validations+1,"one value validation per atomic scope")
	objects[0].position = [1000.0,1000.0]
	check(track.ramp_height(Vector2.ZERO) == TrackHazards.ramp_height(Vector2.ZERO,objects),"in-place edits invalidate between scopes")
	var times: Array = []
	for version: int in range(2):
		var elapsed: Array = []
		for repeat: int in range(5):
			var start: int = Time.get_ticks_usec()
			for tick: int in range(120):
				if version == 1: track.begin_creator_queries()
				for index: int in range(8):
					if version == 0: reference.ramp_height(Vector2.ZERO)
					else: track.ramp_height(Vector2.ZERO)
				if version == 1: track.end_creator_queries()
			elapsed.append((Time.get_ticks_usec()-start)/120.0)
		elapsed.sort(); times.append(elapsed[2])
	metrics.append({"hazard_queries_per_tick":8,"objects":objects.size(),"before_us":times[0],"after_us":times[1]})

func evidence_limits() -> void:
	var budget: RefCounted = BUDGET.new(); var frames: Array = []; var frame := DriveFrame.new()
	var proof: RefCounted = preload("res://backend/race_proof.gd").new()
	for index: int in range(BUDGET.MAX_INPUTS): budget.append_input(frames,frame)
	check(not budget.can_resume(frames,proof),"full recording cannot spend a credit for unusable future inputs")
	check(frames.size() == BUDGET.MAX_INPUTS and budget.eligible(proof),"exact input limit remains eligible")
	budget.append_input(frames,frame)
	check(frames.size() == BUDGET.MAX_INPUTS and not budget.eligible(proof),"overflow is explicit and bounded")
	var session := TrackSession.new(); var state := VehicleState.new()
	# Rewinds reduce scored ticks, never the append-only input offset budget.
	var rewound_budget: RefCounted = BUDGET.new(); var rewound_frames: Variant = []
	var offsets: Array = []
	for branch: int in range(3):
		for tick: int in range(20): rewound_budget.append_input(rewound_frames,frame)
		offsets.append(rewound_frames.size()); state.tick = 1
	check(offsets == [20,40,60] and rewound_budget.can_resume(rewound_frames,proof),"three rewind offsets remain monotonic despite scored tick rollback")
	for tick: int in range(proof.MAX_SAMPLES+1):
		state.tick = tick; proof.capture(state,session,true)
	check(proof.samples.size() == proof.MAX_SAMPLES and proof.overflow,"forced proof capture bounded")
	session.finished = true
	check(proof.recording(session).is_empty(),"truncated proof never exports")
	proof.branch(1,session)
	check(not budget.eligible(proof),"rewind cannot repair missing evidence")
	var ghost := PersonalGhostRun.new(); ghost.overflow = true; ghost.branch(1)
	check(ghost.overflow and ghost.recording("race").is_empty(),"ghost overflow is sticky across rewind")
	var telemetry := LapTelemetry.new(); telemetry.begin(Vector2.ZERO)
	for index: int in range(telemetry.MAX_EVENTS+1): telemetry._add_event("off_track",session,Vector2.ZERO)
	check(telemetry.events.size() == telemetry.MAX_EVENTS and telemetry.events_truncated,"incidents are bounded and marked")
	var history := RewindHistory.new(); state.tick = 12; history.capture(state,session,true,telemetry)
	telemetry.events_truncated = false
	RewindHistory.restore(telemetry,history.entries[0].telemetry)
	check(telemetry.events_truncated,"rewind retains incident completeness")
	check(BUDGET.new().eligible(preload("res://backend/race_proof.gd").new()),"restart owns fresh evidence eligibility")
	var game: Node = load("res://core/game.tscn").instantiate()
	game.attempt_evidence = budget; game.race_proof = proof
	game.rewind_panel = preload("res://ui/rewind_panel.gd").new()
	# Boundary guard is exercised through the actual confirmation entry point.
	game.resume_credits = preload("res://platform/resume_credits.gd").new()
	game.add_child(game.resume_credits)
	game.rewind_choices.append({"tick":1}); game.rewind_selected = 0
	root.add_child(game.rewind_panel)
	await game.confirm_rewind()
	check(game.rewind_panel.status.text.contains("recording limit") and not game.resume_credits.busy,"overflow guard precedes credit consumption")
	var app: Node = load("res://core/app.tscn").instantiate()
	var cloud := CountingCloud.new(); app.cloud = cloud
	app._save_result_upload(game,{},frames,"",[])
	check(cloud.enqueues == 0,"actual result entry rejects truncated evidence before accessing backend")
	app.cloud = null; cloud.free(); app.free()
	game.rewind_panel.free(); game.free()

func compact_monitor() -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.hitch_diagnostics_enabled = false
	game.preference_records = LocalRecords.new("user://f19-records-"+TrackLibrary.unique_id()+".json")
	root.add_child(game)
	game.set_physics_process(false); game.set_process(false)
	game.production_mode = true; game.paused = false; game.countdown_ticks = 0
	game.online_frames.resize(BUDGET.MAX_INPUTS)
	game.online_frames.fill(preload("res://race/input_record.gd").pack(DriveFrame.new()))
	var tick_before: int = game.sim.state.tick
	game._physics_process(VehicleSimulation.STEP)
	check(game.sim.state.tick == tick_before+1 and game.attempt_evidence.overflow,"actual physics keeps driving past recording capacity")
	check(game.online_frames.size() == BUDGET.MAX_INPUTS and game.race_proof.overflow and game.ghost_run.overflow,"actual capture stops all unusable evidence together")
	game.restart()
	check(game.online_frames.is_empty() and game.attempt_evidence.eligible(game.race_proof) and not game.ghost_run.overflow,"actual restart resets all evidence ownership")
	var monitor: Node = preload("res://diagnostics/race_hitch_monitor.gd").new()
	monitor.game = game; monitor.detailed = false; monitor.persist_enabled = false; monitor.console_enabled = false
	game.add_child(monitor); monitor.set_process(false)
	check(not game.profile_enabled and monitor._render_items.is_empty(),"compact observer does not enable stage instrumentation or render scans")
	for index: int in range(80): monitor._process(0.0)
	check(monitor._compact_count == monitor.HISTORY_FRAMES and monitor.events.is_empty(),"ordinary compact frames stay in packed fixed ring")
	monitor._last_usec = Time.get_ticks_usec()-150000; monitor._process(0.0)
	for index: int in range(20): monitor._process(0.0)
	check(monitor.events.size() == 1 and monitor.events[0].before.size() == 64 and monitor.events[0].after.size() == 16,"compact hitch retains before and after windows")
	check(not monitor.latest.has("stages_ms") and monitor.snapshot().header.detail == "compact","minimal diagnostics remain inspectable")
	monitor._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	monitor._last_usec = Time.get_ticks_usec()-1000000; monitor._process(0.0)
	check(monitor.events.size() == 1,"background time excluded")
	monitor._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var start: int = Time.get_ticks_usec()
	for index: int in range(1000): monitor._process(0.0)
	var compact_us: float = (Time.get_ticks_usec()-start)/1000.0
	monitor.detailed = true; game.profile_enabled = true
	start = Time.get_ticks_usec()
	for index: int in range(1000): monitor._process(0.0)
	metrics.append({"compact_observer_us":compact_us,"full_observer_us":(Time.get_ticks_usec()-start)/1000.0,"note":"observer body only; excludes nested Game timers and draw callbacks"})
	game.free()

func road_cache() -> void:
	DISK.directory = "user://f24-numeric-"+TrackLibrary.unique_id()
	for theme: String in ["pine","winter","desert","night_city","storm"]:
		var doc: Dictionary = TrackDocument.create_default(); doc.theme = theme
		doc.pieces = [RoadPieces.create("curve",Vector2.ZERO),RoadPieces.create("straight",Vector2(12,-12))]
		var track: NativeTrack = TrackCompiler.compile(doc)
		var key: Array = ROADS.disk_key_for(track)
		var packet: Dictionary = ROADS.prepare(track,true)
		var expected: PackedByteArray = var_to_bytes(packet)
		var receipt: Dictionary = DISK.stage_arrays(key,packet,Callable())
		check(not receipt.is_empty() and DISK.publish_arrays(receipt),theme+" numeric cache commits")
		var loaded: Dictionary = DISK.read_arrays(key,str(packet.key))
		check(var_to_bytes(loaded) == expected,theme+" exact numeric cache round trip")
		NativeTrackVisual._road_mesh_cache.clear(); ROADS.entries.clear()
		var job: RefCounted = preload("res://editor/road_preparation_job.gd").start(track,self)
		var frames: int = 0
		while not job.done: frames += 1; await process_frame
		check(not job.result.get("parts",[]).is_empty(),theme+" worker reads prepared disk geometry")
		check(var_to_bytes(job.result.parts) == var_to_bytes(packet.parts),theme+" worker geometry is exact")
		DISK.discard_arrays(job.result.get("receipt",{}))
		var path: String = DISK.directory.path_join(DISK.identity(key)+".arrays")
		var file := FileAccess.open(path,FileAccess.WRITE); file.store_string("corrupt"); file.close()
		check(DISK.read_arrays(key,str(packet.key)).is_empty(),theme+" corruption fails closed")
		var cancelled: Dictionary = DISK.stage_arrays(key,packet,func() -> bool: return true)
		check(cancelled.is_empty(),theme+" cancelled stage has no receipt")
		BAKES.start(track,self)
		while BAKES.job != null: await process_frame
		check(not DISK.read_arrays(key,str(packet.key)).is_empty(),theme+" production save rebuilds without GPU readback")
		var cancelled_job: RefCounted = preload("res://editor/road_preparation_job.gd").start(track,self)
		preload("res://race/selected_track_preparation.gd").cancel(cancelled_job,self)
		while not cancelled_job.done: await process_frame
		preload("res://race/selected_track_preparation.gd").reap_discarded()
		check(cancelled_job.result == null,theme+" abandoned worker releases its packet and pending receipt")
		metrics.append({"theme":theme,"worker_wait_frames":frames,"parts":packet.parts.size()})
	for filename: String in DirAccess.get_files_at(DISK.directory): check(not filename.contains("pending-"),"no orphaned cache stage")

func run() -> void:
	hazards()
	await evidence_limits()
	await compact_monitor()
	await road_cache()
	print("GAMEPLAY_F13_F16_F19_F24 ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	quit(1 if failures else 0)

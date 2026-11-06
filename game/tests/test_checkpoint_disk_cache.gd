extends SceneTree
const CACHE = preload("res://race/checkpoint_layout_cache.gd")
const DISK = preload("res://race/checkpoint_layout_disk_cache.gd")
const ARTIFACT = preload("res://race/checkpoint_layout_artifact.gd")
var checks: int = 0
var failures: int = 0
var rows: Array = []
var versions: Array = [RaceRules.KEY,TrackSession.NOTICE_LAYOUT_VERSION,RaceRules.CHECKPOINT_LAYOUT_VERSION]

class ObservedSession extends TrackSession:
	var builds: int = 0
	func _prepare_notice_route(track: NativeTrack) -> void:
		builds += 1
		super._prepare_notice_route(track)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	var mode: String = "write"
	var selected_fixture: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
		if argument.begins_with("--fixture="): selected_fixture = argument.trim_prefix("--fixture=")
	DISK.directory = "user://test-checkpoint-artifacts"
	check(CACHE.count() == 0,"process begins without RAM layouts")
	for fixture: String in ["star_spline_lap","silmukka","dust_cloud","over_and_under","knot"]:
		if not selected_fixture.is_empty() and fixture != selected_fixture: continue
		for reverse: bool in [false,true]:
			var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture+".json"))
			if reverse and not document.has("start_line"): continue
			if reverse: document.start_line.heading = fposmod(float(document.start_line.heading)+180.0,360.0)
			var track: NativeTrack = TrackCompiler.compile(document)
			var key: String = CACHE.key_for(track,versions)
			var id: String = DISK.identity(key,versions)
			check(id.length() == 64,"valid build manifest produces cache identity")
			var expected_path: String = "user://expected-"+fixture+str(reverse)+".bin"
			CACHE.trim_to()
			var session := ObservedSession.new()
			var began: int = Time.get_ticks_usec()
			session.prepare_cached(track,func() -> bool: return false)
			var elapsed: int = Time.get_ticks_usec()-began
			check(session.initialized,fixture+" session initializes")
			var bytes: PackedByteArray = var_to_bytes(track._race_gates)
			if mode == "write":
				check(session.builds == 1,"empty profile uses unchanged builder")
				_write_bytes(expected_path,bytes)
			else:
				check(session.builds == 0,"new process uses disk without entering builder")
				check(bytes == FileAccess.get_file_as_bytes(expected_path),"restart prepared fields and order remain byte-exact")
			check(FileAccess.file_exists(DISK.directory.path_join(id+".gates")),"worker persists layout")
			check(ARTIFACT.validate(track._race_gates,track,versions),"full numeric schema validates")

			var payload: PackedByteArray = ARTIFACT.encode(track._race_gates,track,versions)
			check(not payload.is_empty(),"fixed numeric payload encodes")
			var decoded: Dictionary = ARTIFACT.new().decode(payload,track,versions)

			check(var_to_bytes(decoded) == bytes,"codec preserves all fields and typed containers exactly")
			check(var_to_bytes(DISK.read_entry(key,track,versions)) == bytes,"disk receipt round-trips exact layout")
			check(DISK.read_entry(key,track,["different",versions[1],versions[2]]).is_empty(),"rules identity fences disk reuse")
			var cached := ObservedSession.new()
			cached.prepare_cached(track,func() -> bool: return false)
			check(cached.builds == 0 and var_to_bytes(track._race_gates) == bytes,"same-track preparation is exact without another build")
			rows.append({"fixture":fixture,"reverse":reverse,"mode":mode,"elapsed_us":elapsed,"serialized_bytes":bytes.size(),"artifact_bytes":payload.size()+DISK.HEADER_BYTES,"builds":session.builds})
			print("CHECKPOINT_DISK_ROW ",JSON.stringify(rows[-1]))
			if mode == "contracts" and fixture == "over_and_under" and not reverse: await contracts(track,key,payload)
			await process_frame
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("CHECKPOINT_DISK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func contracts(track: NativeTrack, key: String, payload: PackedByteArray) -> void:
	var expected: PackedByteArray = var_to_bytes(track._race_gates)
	var id: String = DISK.identity(key,versions)
	var path: String = DISK.directory.path_join(id+".gates")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for length: int in [0,1,8,72,104,105,original.size()-1]:
		_write_bytes(path,original.slice(0,length))
		check(DISK.read_entry(key,track,versions).is_empty(),"truncated artifact falls back")
	for offset: int in [0,8,72,104,original.size()-1]:
		var damaged: PackedByteArray = original.duplicate(); damaged[offset] ^= 1
		_write_bytes(path,damaged)
		check(DISK.read_entry(key,track,versions).is_empty(),"header/key/checksum/payload corruption falls back")
	_write_bytes(path,original)
	for length: int in [0,1,42,45,payload.size()-1]:
		check(ARTIFACT.new().decode(payload.slice(0,length),track,versions).is_empty(),"truncated numeric payload rejects")
	var damaged: PackedByteArray = payload.duplicate(); damaged.append(0)
	check(ARTIFACT.new().decode(damaged,track,versions).is_empty(),"trailing payload rejects")
	damaged = payload.duplicate(); damaged.encode_u32(42,0x7fffffff)
	check(ARTIFACT.new().decode(damaged,track,versions).is_empty(),"oversized gate count rejects before allocation")
	damaged = payload.duplicate(); damaged.encode_double(0,NAN)
	check(ARTIFACT.new().decode(damaged,track,versions).is_empty(),"nonfinite scalar rejects")
	damaged = payload.duplicate(); damaged[8] = 2
	check(ARTIFACT.new().decode(damaged,track,versions).is_empty(),"invalid boolean rejects")
	damaged = payload.duplicate(); damaged.encode_u32(118,track.route.size())
	check(ARTIFACT.new().decode(damaged,track,versions).is_empty(),"out-of-route hint rejects")
	for field: String in ["_centers","_directions","_progress","_widths","_road_widths","_notice_reach","_route_hints","_layers","_notice_route_bins","_notice_approaches","_notice_route_layers","_notice_layer_offsets"]:
		var malformed: Dictionary = track._race_gates.duplicate(true); malformed[field] = "wrong"
		check(not ARTIFACT.validate(malformed,track,versions),"wrong type rejects "+field)
	var malformed: Dictionary = track._race_gates.duplicate(true); malformed._notice_layer_offsets[0] = malformed._notice_route_layers.size()
	check(not ARTIFACT.validate(malformed,track,versions),"invalid layer offset rejects")
	malformed = track._race_gates.duplicate(true); malformed._notice_route_layers[0] = 2
	check(not ARTIFACT.validate(malformed,track,versions),"invalid layer value rejects")
	malformed = track._race_gates.duplicate(true); malformed._notice_route_bins[Vector2i.ZERO] = PackedInt32Array([0,0])
	check(not ARTIFACT.validate(malformed,track,versions),"duplicate/unsorted route indices reject")
	var saved_key: String = key
	track.finish_center += Vector2(0.25,0)
	check(CACHE.key_for(track,versions) != saved_key,"actual geometry invalidates unchanged declared content hash")
	track.finish_center -= Vector2(0.25,0)
	check(not DISK.write_entry(key,track._race_gates,track,versions,func() -> bool: return true),"cancelled worker does not write")
	check(FileAccess.get_file_as_bytes(path) == original,"cancelled publication preserves existing complete artifact")
	CACHE.trim_to()
	var ticket: Dictionary = CACHE.read(key)
	CACHE.trim_to()
	CACHE.store(key,track._race_gates,ticket.generation)
	check(CACHE.count() == 0 and not CACHE.current(ticket.generation),"pressure rejects stale generation")
	var abandoned := ObservedSession.new()
	track._race_gates = {}
	abandoned.prepare_cached(track,func() -> bool: return true)
	check(not abandoned.initialized and track._race_gates.is_empty(),"cancel before read never installs")
	var cancelled_read := ObservedSession.new()
	var cancelled_calls: Array[int] = [0]
	cancelled_read.prepare_cached(track,func() -> bool:
		cancelled_calls[0] += 1
		return cancelled_calls[0] >= 2)
	check(not cancelled_read.initialized and track._race_gates.is_empty() and CACHE.count() == 0,"cancel after disk read cannot install or retain")
	var pressured := ObservedSession.new()
	var calls: Array[int] = [0]
	pressured.prepare_cached(track,func() -> bool:
		calls[0] += 1
		if calls[0] == 2: CACHE.trim_to()
		return false)
	check(pressured.initialized and pressured.builds == 1 and CACHE.count() == 0,"pressure during disk read cannot admit stale RAM layout")
	check(var_to_bytes(track._race_gates) == expected,"pressure fallback preserves all prepared fields")
	var isolated: String = DISK.directory
	DISK.directory = "user://test-checkpoint-cancelled-write"
	var write_calls: Array[int] = [0]
	check(not DISK.write_entry(key,track._race_gates,track,versions,func() -> bool:
		write_calls[0] += 1
		return write_calls[0] >= 4),"cancellation after staging prevents rename")
	check(DirAccess.get_files_at(DISK.directory).is_empty(),"cancelled staged write removes its temporary file")
	DISK.directory = "user://test-checkpoint-eviction"
	for i: int in range(DISK.MAX_FILES+3):
		var other_key: String = str(i).sha256_text()
		check(DISK.write_entry(other_key,track._race_gates,track,versions,func() -> bool: return false),"atomic retention write")
	var files: PackedStringArray = DirAccess.get_files_at(DISK.directory)
	check(files.size() == DISK.MAX_FILES,"disk retention limits complete artifacts")
	check(not DISK._owned_filename("owner-save.json") and not DISK._owned_filename("../"+id+".gates"),"pruning owns only bounded cache filenames")
	DISK.directory = isolated
	var after_cancel: String = DISK.directory
	DISK.directory = "user://test-checkpoint-cancelled-build"
	track._race_gates = {}; CACHE.trim_to()
	var cancelled_build := ObservedSession.new()
	cancelled_calls[0] = 0
	cancelled_build.prepare_cached(track,func() -> bool:
		cancelled_calls[0] += 1
		return cancelled_calls[0] >= 3)
	check(cancelled_build.builds == 1 and CACHE.count() == 0 and not DirAccess.dir_exists_absolute(DISK.directory),"cancellation during construction retains neither RAM nor disk artifact")
	DISK.directory = after_cancel
	_write_bytes(path,original.slice(0,105))
	track._race_gates = {}; CACHE.trim_to()
	var rebuilt := ObservedSession.new()
	rebuilt.prepare_cached(track,func() -> bool: return false)
	check(rebuilt.builds == 1 and var_to_bytes(track._race_gates) == expected,"corrupt file falls back to unchanged builder")
	check(var_to_bytes(DISK.read_entry(key,track,versions)) == expected,"fallback atomically repairs corrupt artifact")
	track._race_gates._notice_route_bins[Vector2i(-999,-999)] = PackedInt32Array([0])
	check(var_to_bytes(CACHE.read(key).layout) == expected,"installed track cannot mutate RAM receipt")
	track._race_gates = {}; CACHE.trim_to()
	var worker: RefCounted = preload("res://editor/work_job.gd").start(func(cancelled: Callable) -> Dictionary:
		var loaded := ObservedSession.new()
		loaded.prepare_cached(track,cancelled)
		return {"builds":loaded.builds,"layout":var_to_bytes(track._race_gates)},self)
	while not worker.done: await process_frame
	check(worker.result.builds == 0 and worker.result.layout == expected,"actual worker installs exact persistent layout")

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes); file.flush(); file.close()

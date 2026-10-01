extends SceneTree

var checks: int = 0
var failures: int = 0
var folder: String
var track: NativeTrack
var handling: HandlingConfig


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+description)


func run() -> void:
	folder = "user://records_tests_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	track = TrackCompiler.compile(TrackDocument.create_default())
	handling = load("res://resources/balanced.tres")
	_check_records()
	_check_recovery()
	_check_migration()
	_check_failures()
	var directory := DirAccess.open(folder)
	for filename: String in directory.get_files():
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	print("RECORD_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


func _check_records() -> void:
	var store := LocalRecords.new(folder.path_join("records.json"))
	check(store.best_for(track,handling) == 0.0,"new partition has no personal best")
	var laps: Array[float] = [10.0004,21.2346,23.004,30.0,30.0]
	check(store.record(track,handling,114.239,laps) == OK,"complete race persists")
	check(store.settings.get("raced_tracks",[]) == [track.identity],"completed race records track history")
	var key: String = store.key_for(track,handling)
	check(store.records[key].race_ms is int and store.records[key].race_ms == 114239,"race persisted in rounded integer milliseconds")
	check(store.records[key].flying_ms is int and store.records[key].flying_ms == 21235,"first standing lap excluded from flying PB")
	check(is_equal_approx(store.best_for(track,handling),114.239),"best_for exposes seconds API from milliseconds")
	var serialized: String = FileAccess.get_file_as_string(store.path)
	check('"race_ms":114239' in serialized and '"flying_ms":21235' in serialized and '"schema":2' in serialized,"JSON uses integer millisecond fields and schema 2")
	laps = [20.5,19.5,20.0,30.0,30.0]
	check(store.record(track,handling,120.0,laps) == OK,"slower race can still improve flying lap")
	check(store.records[key].race_ms == 114239 and store.records[key].flying_ms == 19500,"whole-race and flying PB improve independently")
	var revised: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	revised.content_hash += "_revision"
	check(store.key_for(revised,handling) != key and store.best_for(revised,handling) == 0.0,"track-content revisions have separate PBs")
	var tuning: HandlingConfig = handling.duplicate()
	tuning.lateral_grip -= 1.0
	check(store.key_for(track,tuning) != key,"actual tuning changes partition records")
	tuning = handling.duplicate()
	tuning.version += "_revision"
	check(store.key_for(track,tuning) != key,"handling-version changes partition records")
	store.settings = {"touch_scale":1.4,"left_handed":true}
	check(store.save_records() == OK,"allowlisted control settings save with records")
	var reloaded := LocalRecords.new(store.path)
	reloaded.load_records()
	check(reloaded.records == store.records and reloaded.settings == store.settings,"new instance restores both PBs and settings")
	check(reloaded.records[key].race_ms is int,"JSON float parsing normalized back to integer milliseconds")
	var before: Dictionary = store.records.duplicate(true)
	for invalid: Array in [[1.0,2.0],[1.0,2.0,3.0],[0.0,2.0,3.0,4.0,5.0],[1.0,NAN,3.0,4.0,5.0],[1.0,INF,3.0,4.0,5.0]]:
		var invalid_laps: Array[float] = []
		invalid_laps.assign(invalid)
		check(store.record(track,handling,6.0,invalid_laps) == ERR_INVALID_DATA and store.records == before,"invalid or incomplete lap result cannot alter PB")
	laps = [1.0,2.0,3.0,4.0,5.0]
	check(store.record(track,handling,5.0,laps) == ERR_INVALID_DATA,"race total must agree with its five laps")
	check(store.record(track,handling,NAN,laps) == ERR_INVALID_DATA,"nonfinite race total rejected")
	var old_key: String = (track.content_hash+VehicleSimulation.PHYSICS_VERSION+JSON.stringify(handling.snapshot(),"",true)+"standing-3-local-v1").sha256_text()
	var old_store := LocalRecords.new(folder.path_join("old_laps.json"))
	old_store.records[old_key] = {"race_ms":50000,"flying_ms":15000}
	old_store.settings.favorites = [track.identity]
	check(old_store.save_records() == OK,"old record partitions and favorites can be preserved together")
	old_store.load_records()
	check(old_store.best_for(track,handling) == 0.0 and old_store.records.has(old_key),"three-lap PBs are retained but never compared with five-lap races")
	laps = [30.0,29.0,28.0,27.0,18.0]
	check(old_store.record(track,handling,132.0,laps) == OK and old_store.records[key].flying_ms == 18000,"fifth lap participates in the flying-lap best")
	check(track.identity in old_store.settings.favorites,"record updates preserve favorites")


func _check_recovery() -> void:
	var store := LocalRecords.new(folder.path_join("recover.json"))
	var laps: Array[float] = [10.0,21.0,23.0,30.0,30.0]
	store.record(track,handling,114.0,laps)
	laps = [10.0,20.0,22.0,30.0,30.0]
	store.record(track,handling,112.0,laps)
	var key: String = store.key_for(track,handling)
	for corrupt: Variant in [[], {"schema":2,"records":{},"settings":[]},
		{"schema":true,"records":{},"settings":{}},
		{"schema":99,"records":{},"settings":{}},
		{"schema":2,"records":{"../bad":{"race_ms":50000,"flying_ms":20000}},"settings":{}},
		{"schema":2,"records":{key:{"race_ms":"1","flying_ms":1}},"settings":{}},
		{"schema":2,"records":{key:{"race_ms":true,"flying_ms":1}},"settings":{}},
		{"schema":2,"records":{key:{"race_ms":52000.5,"flying_ms":20000}},"settings":{}},
		{"schema":2,"records":{key:{"race_ms":-1,"flying_ms":1}},"settings":{}},
		{"schema":2,"records":{},"settings":{"left_handed":"yes"}},
		{"schema":2,"records":{},"settings":{"touch_scale":99}},
		{"schema":2,"records":{},"settings":{},"unexpected":"ignored?"}]:
		_write(store.path,JSON.stringify(corrupt))
		store.load_records()
		check(store.best_for(track,handling) == 114.0,"wrong-shaped primary recovers strict valid backup")
	var preserved_backup: String = FileAccess.get_file_as_string(store.path+".bak")
	laps = [10.0,19.0,21.0,30.0,30.0]
	check(store.record(track,handling,110.0,laps) == OK,"new record commits after corrupt-primary recovery")
	check(FileAccess.get_file_as_string(store.path+".bak") == preserved_backup,"corrupt primary cannot replace known-good backup")
	_write(store.path,"not JSON")
	store.load_records()
	check(store.best_for(track,handling) == 114.0,"backup remains recoverable after a subsequent primary corruption")
	DirAccess.remove_absolute(store.path)
	store.load_records()
	check(store.best_for(track,handling) == 114.0,"missing primary recovers interrupted commit backup")
	_write(store.path+".bak","[]")
	store.load_records()
	check(store.records.is_empty() and store.settings.is_empty(),"two invalid files clear stale in-memory data")


func _check_migration() -> void:
	var store := LocalRecords.new(folder.path_join("legacy.json"))
	var key: String = store.key_for(track,handling)
	_write(store.path,JSON.stringify({"schema":1,"records":{key:{"race":54.1234,"flying":20.4567}},"settings":{}}))
	store.load_records()
	check(store.records[key].race_ms == 54123 and store.records[key].flying_ms == 20457,"legacy seconds safely migrate to integer milliseconds")
	DirAccess.make_dir_absolute(store.path+".tmp")
	check(store.save_records() != OK,"interrupted migration write reports failure")
	check('"schema":1' in FileAccess.get_file_as_string(store.path) and store.records[key].race_ms == 54123,"failed migration preserves legacy disk state and recovered in-memory PB")
	DirAccess.remove_absolute(store.path+".tmp")
	check(store.save_records() == OK and '"schema":2' in FileAccess.get_file_as_string(store.path),"next save upgrades legacy storage schema")


func _check_failures() -> void:
	var store := LocalRecords.new(folder.path_join("failure.json"))
	var laps: Array[float] = [10.0,21.0,23.0,30.0,30.0]
	store.record(track,handling,114.0,laps)
	var before: Dictionary = store.records.duplicate(true)
	var committed_path: String = store.path
	# A regular file as parent makes write failure deterministic with any
	# privilege level. No permission mutation or owner files are involved.
	var blocker: String = folder.path_join("not_a_directory")
	_write(blocker,"blocker")
	store.path = blocker.path_join("cannot_save.json")
	laps = [10.0,19.0,21.0,30.0,30.0]
	check(store.record(track,handling,110.0,laps) != OK,"unwritable destination reports failure")
	check(store.records == before and store.best_for(track,handling) == 114.0,"failed improved PB rolls back memory")
	store.settings = {"touch_scale":1.2,"left_handed":true}
	check(store.save_records() != OK and store.settings == {"raced_tracks":[track.identity]},"failed settings save restores last committed preferences")
	var empty := LocalRecords.new(store.path)
	check(empty.record(track,handling,110.0,laps) != OK and empty.best_for(track,handling) == 0.0,"failed first record never appears as a phantom PB")
	var reload := LocalRecords.new(committed_path)
	reload.load_records()
	check(reload.records == before,"failed write cannot change original committed file")
	store.path = committed_path
	store.records[store.key_for(track,handling)] = {"race_ms":1,"flying_ms":-1}
	check(store.save_records() == ERR_INVALID_DATA and store.records == before,"invalid in-memory schema cannot overwrite a good save")
	# A valid temporary alone is not a successful commit and must not load.
	var uncommitted := LocalRecords.new(folder.path_join("uncommitted.json"))
	_write(uncommitted.path+".tmp",FileAccess.get_file_as_string(committed_path))
	uncommitted.load_records()
	check(uncommitted.records.is_empty(),"uncommitted first-save temporary cannot fabricate a saved PB")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()

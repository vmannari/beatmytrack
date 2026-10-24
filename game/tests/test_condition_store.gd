extends SceneTree
var checks: int = 0
var failures: int = 0
var folder: String
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)
func condition(dirt: float) -> Dictionary:
	var value: Dictionary = VehicleWeathering.new().snapshot()
	value.dirt = dirt
	return value
func run() -> void:
	folder = "user://condition_store_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	for index: int in range(10000): records.records[str(index).sha256_text()] = {"race_ms":100000,"flying_ms":20000}
	records.settings.vehicle_conditions = {"compact":condition(0.2)}
	check(records.save_records() == OK,"seed legacy embedded cosmetics and large PB store")
	var primary_hash: String = FileAccess.get_sha256(records.path)
	var prior_records: Dictionary = records.records.duplicate(true)
	var signals: Array[int] = [0]
	records.achievement_progress_committed.connect(func() -> void: signals[0] += 1)
	check(VehicleCondition.read(records,"compact") == condition(0.2),"legacy cosmetic data loads unchanged")
	var queue_started: int = Time.get_ticks_usec()
	check(VehicleCondition.save(records,"compact",condition(0.4),true) == OK,"periodic save enqueues immutable cosmetic packet")
	var queue_us: int = Time.get_ticks_usec()-queue_started
	check(records._condition_store._thread != null,"background save starts owned writer")
	for value: float in [0.5,0.6,0.7,0.8,0.9]:
		check(VehicleCondition.save(records,"compact",condition(value),true) == OK,"newer pending revision coalesces")
	var shared := LocalRecords.new(records.path)
	shared.load_records()
	check(shared._condition_store == records._condition_store,"one writer for the same profile path")
	check(VehicleCondition.read(shared,"compact").dirt == 0.9,"shared reader observes latest live revision")
	check(shared._committed_settings.vehicle_conditions == shared._condition_store.committed,"new profile owner mirrors confirmed cosmetics separately from queued revisions")
	check(VehicleCondition.save(records,"compact",condition(0.9)) == OK,"lifecycle barrier flushes newest queued revision")
	check(FileAccess.get_sha256(records.path) == primary_hash,"cosmetic commit never rewrites full PB/settings file")
	check(records.records == prior_records and signals[0] == 0,"cosmetics cannot commit PBs or achievement signals")
	var store: Node = records._condition_store
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	check(document.conditions.compact == JSON.parse_string(JSON.stringify(condition(0.9),"",true)),"worker commits exact last JSON mask and condition")
	check(FileAccess.get_file_as_bytes(store.path).size() < 20000,"single-car packet remains small despite 10k PBs")
	var committed: Dictionary = store.committed.duplicate(true)
	check(DirAccess.make_dir_absolute(store.path+".tmp") == OK,"create isolated blocked temporary path")
	check(VehicleCondition.save(records,"compact",condition(0.95)) != OK,"failed sidecar write is reported")
	check(store.committed == committed,"failure retains confirmed cosmetic revision")
	check(records.records == prior_records and FileAccess.get_sha256(records.path) == primary_hash,"failure never rolls back or rewrites unrelated records")
	check(DirAccess.remove_absolute(store.path+".tmp") == OK,"remove only the disposable blocked temporary directory")
	check(VehicleCondition.save(records,"compact",condition(0.95)) == OK,"unchanged queued value retries and commits after storage recovers")
	var invalid: Dictionary = condition(1.0); invalid.dirt = INF
	check(VehicleCondition.save(records,"compact",invalid) == ERR_INVALID_DATA,"invalid cosmetics do not enter writer")
	check(VehicleCondition.read(records,"compact").dirt == 0.95,"invalid write retains last live condition")
	check(VehicleCondition.save(records,"classic",condition(0.3),true) == OK,"other cars share ordered profile writer")
	var weak_store: WeakRef = weakref(store)
	records = null; shared = null
	for index: int in range(6): await process_frame
	check(weak_store.get_ref() == null,"last profile owner releases and joins writer without retained nodes")
	var reopened := LocalRecords.new(folder.path_join("records.json")); reopened.load_records()
	check(reopened.records == prior_records,"restart retains every PB")
	check(VehicleCondition.read(reopened,"compact").dirt == 0.95 and VehicleCondition.read(reopened,"classic").dirt == 0.3,"owner release flushes final per-car conditions")
	var sidecar: String = reopened._condition_store.path
	reopened = null
	for index: int in range(4): await process_frame
	FileAccess.open(sidecar,FileAccess.WRITE).store_string("corrupt")
	var recovered := LocalRecords.new(folder.path_join("records.json")); recovered.load_records()
	check(VehicleCondition.read(recovered,"compact").dirt == 0.95,"corrupt primary falls back to last committed sidecar backup")
	check(not recovered.records.is_empty(),"cosmetic corruption does not damage PB recovery")
	print("CONDITION_STORE checks=%d failures=%d queue_10k_us=%d" % [checks,failures,queue_us])
	quit(1 if failures else 0)

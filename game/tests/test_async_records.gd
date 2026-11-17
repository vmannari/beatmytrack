extends SceneTree
## Ordered durable saves retain later edits and keep the scene loop advancing.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func save(owner: LocalRecords, receipt: Dictionary) -> void:
	receipt.error = await owner.save_records_async()
	receipt.done = true

func run() -> void:
	var folder: String = "user://async_records_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var owner := LocalRecords.new(folder.path_join("records.json"))
	for index: int in range(10000): owner.records[str(index).sha256_text()] = {"race_ms":50000,"flying_ms":10000}
	owner.settings.music_volume = 0.4
	var receipt: Dictionary = {"done":false}
	var started: int = Time.get_ticks_usec()
	save(owner,receipt)
	var dispatch_us: int = Time.get_ticks_usec()-started
	owner.settings.music_volume = 0.8
	var frames: int = 0
	while not receipt.done:
		frames += 1
		await process_frame
	check(receipt.error == OK and frames > 1,"large save commits while the scene loop advances")
	check(owner.settings.music_volume == 0.8,"an edit during saving remains staged")
	var saved: Dictionary = LocalRecords._read_document(owner.path)
	check(saved.records.size() == 10000 and saved.settings.music_volume == 0.4,"disk contains the exact dispatched snapshot")
	check(await owner.save_records_async() == OK,"later preference commits asynchronously")
	check(LocalRecords._read_document(owner.path).settings.music_volume == 0.8,"later preference survives reload")
	receipt = {"done":false}
	owner.settings.music_volume = 0.6
	save(owner,receipt)
	owner.settings.music_volume = 0.9
	check(owner.save_records() == OK,"synchronous caller joins the active writer")
	while not receipt.done: await process_frame
	check(LocalRecords._read_document(owner.path).settings.music_volume == 0.9,"ordered writers preserve the newer synchronous edit")
	var original: String = FileAccess.get_sha256(owner.path)
	DirAccess.make_dir_absolute(owner.path+".tmp")
	owner.settings.music_volume = 0.2
	check(await owner.save_records_async() != OK,"asynchronous storage failure is returned")
	check(FileAccess.get_sha256(owner.path) == original and owner.settings.music_volume == 0.9,"failed save restores committed preferences and preserves file bytes")
	DirAccess.remove_absolute(owner.path+".tmp")
	check(await owner.save_records_async() == OK,"failed save can be retried")
	receipt = {"done":false}
	owner.settings.music_volume = 0.7
	save(owner,receipt)
	var reloaded := LocalRecords.new(owner.path)
	reloaded.load_records()
	check(reloaded.settings.music_volume == 0.7,"another reader joins the writer for the same destination")
	while not receipt.done: await process_frame
	owner.records[str(0).sha256_text()].race_ms = true
	check(owner.save_records() == ERR_INVALID_DATA,"cached PB encoding cannot hide an invalid changed record")
	var upgraded: Dictionary = LocalRecords._normalize({"schema":2,"records":{},"settings":{"simple_car_models":true,"reduced_car_models":false,"music_volume":0.3}})
	check(upgraded.settings == {"music_volume":0.3},"obsolete toggles retire at the input boundary")
	check(LocalRecords._normalize({"schema":2,"records":{},"settings":{"simple_car_models":"invalid"}}).is_empty(),"malformed retired settings remain rejected")
	print("ASYNC_RECORDS: %d checks, %d failures; dispatch_us=%d; frames=%d" % [checks,failures,dispatch_us,frames])
	quit(1 if failures else 0)

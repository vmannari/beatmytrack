extends SceneTree
const SESSION = preload("res://race/track_session.gd")
const WORK = preload("res://editor/work_job.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cold: bool = not ResourceLoader.has_cached("res://race/checkpoint_layout_disk_cache.gd")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	var worker: RefCounted = WORK.start(func(cancelled: Callable) -> bool:
		var session: RefCounted = SESSION.new()
		session.prepare_cached(track,cancelled)
		return session.initialized,self)
	while not worker.done: await process_frame
	var result: Dictionary = {"helper_cold":cold,"initialized":worker.result,"helper_loaded":ResourceLoader.has_cached("res://race/checkpoint_layout_disk_cache.gd")}
	print("CHECKPOINT_COLD_WORKER ",JSON.stringify(result))
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	worker = null
	track = null
	for _i: int in range(24): await process_frame
	quit(0 if result.helper_cold and result.initialized and result.helper_loaded else 1)

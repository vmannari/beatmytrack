extends SceneTree
const ROADS = preload("res://editor/road_preparation.gd")
const DISK = preload("res://track/road_mesh_disk_cache.gd")
const SELECTED = preload("res://race/selected_track_preparation.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	var folder: String = ProjectSettings.globalize_path("res://../build/device-track-loading/spill-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder); DISK.directory = folder.path_join("roads")
	ROADS.entries.clear(); ROADS.bytes = 0; ROADS.account_gpu([])
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json")); doc.theme = "desert"
	var track: NativeTrack = TrackCompiler.compile(doc)
	var job: RefCounted = SELECTED.start(track,{}, {},self)
	while not job.done: await process_frame
	var result: Dictionary = job.result
	check(result.get("track") == track and not result.get("receipt",{}).is_empty(),"large selected track completes its CPU preparation")
	check(ROADS.entries.is_empty() and ROADS.bytes+ROADS.gpu_bytes <= ROADS.BUDGET,"oversized selected roads are not retained in the idle CPU LRU")
	check(DISK.publish_arrays(result.receipt),"large selected geometry publishes to bounded device storage")
	job.result = null
	var expected: Dictionary = DISK.read_arrays(ROADS.disk_key_for(track),ROADS.key_for(track))
	check(not expected.is_empty(),"large prepared geometry reads from local storage")
	var estimate: int = 0
	for part: Dictionary in expected.get("parts",[]):
		estimate += part.arrays[Mesh.ARRAY_VERTEX].size()*96
		if part.arrays[Mesh.ARRAY_INDEX] != null: estimate += part.arrays[Mesh.ARRAY_INDEX].size()*4
	check(estimate > ROADS.BUDGET and estimate <= DISK.MAX_RESIDENT_BYTES,"fixture exceeds idle memory budget and respects active-artifact bounds")
	# A transient diagnostic copy makes hidden regeneration observable without
	# adding a test hook to the shipping preparation API.
	var code: String = FileAccess.get_file_as_string("res://editor/road_preparation.gd").replace("\r\n","\n")
	code += "\nstatic var probe_generated: bool = false\n"
	code = code.replace("\tvar builder := NativeTrackVisual.new()","\tprobe_generated = true\n\tvar builder := NativeTrackVisual.new()")
	var guarded := GDScript.new(); guarded.source_code = code
	check(guarded.reload() == OK,"guarded production loader compiles")
	var began: int = Time.get_ticks_usec()
	var actual: Dictionary = guarded.call("prepare",track)
	var read_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(not guarded.get("probe_generated"),"production loader restores oversized geometry without regenerating it")
	check(actual == expected,"restored final mesh arrays and metadata are exact")
	var path: String = DISK.directory.path_join(DISK.identity(ROADS.disk_key_for(track))+".arrays")
	var file := FileAccess.open(path,FileAccess.READ); var bytes: int = file.get_length(); file.close()
	check(bytes <= DISK.MAX_FILE_BYTES,"compressed selected geometry respects the existing per-file limit")
	file = FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"resident_estimate_bytes":estimate,"artifact_bytes":bytes,"verified_read_ms":read_ms},"\t")); file.close()
	print("DEVICE_ROAD_SPILL: ",checks," checks, ",failures," failures; read_ms=",read_ms," report=",folder.path_join("report.json"))
	quit(1 if failures else 0)

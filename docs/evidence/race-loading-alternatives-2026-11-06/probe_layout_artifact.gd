extends SceneTree
const CACHE = preload("res://race/checkpoint_layout_cache.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rows: Array = []
	for fixture: String in ["star_spline_lap","over_and_under","knot"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture+".json"))
		var track: NativeTrack = TrackCompiler.compile(doc)
		CACHE.trim_to()
		var started: int = Time.get_ticks_usec()
		TrackSession.new()._configure(track)
		var build_us: int = Time.get_ticks_usec()-started
		var bytes: PackedByteArray = var_to_bytes(track._race_gates)
		var path: String = "user://alternative-layout-"+fixture+".bin"
		started = Time.get_ticks_usec()
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_buffer(bytes); file.close()
		var write_us: int = Time.get_ticks_usec()-started
		var versions: Array = [RaceRules.KEY,TrackSession.NOTICE_LAYOUT_VERSION,RaceRules.CHECKPOINT_LAYOUT_VERSION]
		var expected_key: String = CACHE.key_for(track,versions)
		var samples: Array = []
		for trial: int in range(5):
			track._race_gates = {}; CACHE.trim_to()
			started = Time.get_ticks_usec()
			var key: String = CACHE.key_for(track,versions)
			var key_us: int = Time.get_ticks_usec()-started
			check(key == expected_key,"geometry/version key stable")
			started = Time.get_ticks_usec()
			var decoded: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path))
			var read_us: int = Time.get_ticks_usec()-started
			check(decoded is Dictionary and var_to_bytes(decoded) == bytes,"disk numeric layout byte exact")
			# Evidence-only injection: production requires an envelope/schema validator.
			track._race_gates = decoded
			started = Time.get_ticks_usec()
			var session := TrackSession.new(); session._configure(track)
			var install_us: int = Time.get_ticks_usec()-started
			check(session.initialized and session.checkpoint_count() > 0,"restored layout installs")
			samples.append({"key_us":key_us,"read_decode_us":read_us,"install_us":install_us,"total_us":key_us+read_us+install_us})
		rows.append({"fixture":fixture,"build_us":build_us,"payload_bytes":bytes.size(),"write_us":write_us,"samples":samples})
		print("ARTIFACT_ROW ",JSON.stringify(rows[-1]))
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("LAYOUT_ARTIFACT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

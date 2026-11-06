extends SceneTree
## Diagnostic component timings, independent of rendering and network.
var rows: Array = []
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for theme: String in ["pine","winter","desert","storm","night_city"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
		document.theme = theme
		var began: int = Time.get_ticks_usec()
		var track: NativeTrack = TrackCompiler.compile(document)
		var compile_us: int = Time.get_ticks_usec()-began
		if track == null:
			push_error("Track compilation failed"); quit(1); return
		for cycle: int in range(2):
			var row := {"theme":theme,"cycle":cycle,"compile_us":compile_us}
			began = Time.get_ticks_usec()
			track._creator_query()
			row.query_us = Time.get_ticks_usec()-began
			began = Time.get_ticks_usec()
			var bridge := BridgePresentation.new(track)
			row.bridge_us = Time.get_ticks_usec()-began
			began = Time.get_ticks_usec()
			var session := TrackSession.new()
			session._configure(track)
			row.gates_us = Time.get_ticks_usec()-began
			row.gates = session._centers.size()
			checks += 1
			if not session.initialized or session.target_laps != 5 or track._race_gates.get("checkpoint_layout_version",0) != RaceRules.CHECKPOINT_LAYOUT_VERSION:
				failures += 1
			row.bridge_present = bridge != null
			rows.append(row)
			print("REVIEW_CPU ",JSON.stringify(row))
			await process_frame
	var output := OS.get_environment("BMT_LOADING_OUTPUT")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify({"rows":rows,"checks":checks,"failures":failures,"engine":Engine.get_version_info().string},"  "))
	file.close()
	quit(1 if failures else 0)

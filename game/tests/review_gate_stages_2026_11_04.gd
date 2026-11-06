extends SceneTree
## Timestamp-only in-memory copies; compare every resulting gate-layout byte.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var corridor_source := FileAccess.get_file_as_string("res://race/spline_gate_corridor.gd").replace("\r\n","\n").replace("class_name SplineGateCorridor\n","")
	var hooks := [
		["\tvar crossings: Array[PackedFloat64Array] = []","start"],
		["\tvar paved_crossings: Array[PackedFloat64Array] = []","edge_lanes_done"],
		["\tvar counts := PackedInt32Array()","recovery_lanes_done"],
		["\tvar selected := PackedInt32Array()","selection_done"],
		["\tvar projections: Dictionary = {}","notices_begin"],
		["\treturn selected\n","notices_end"],
	]
	for hook: Array in hooks:
		if corridor_source.count(hook[0]) != 1: push_error("Gate stage anchor changed"); quit(1); return
		corridor_source = corridor_source.replace(hook[0],"\tsession.set_meta(\"review_"+str(hook[1])+"\",Time.get_ticks_usec())\n"+str(hook[0]))
	var corridor := GDScript.new()
	corridor.source_code = corridor_source
	if corridor.reload() != OK: quit(1); return
	var session_source := FileAccess.get_file_as_string("res://race/track_session.gd").replace("\r\n","\n").replace("class_name TrackSession\n","")
	var needle := "SplineGateCorridor.select(self,track)"
	if session_source.count(needle) != 1: push_error("Gate select anchor changed"); quit(1); return
	session_source = session_source.replace(needle,"_review_corridor.select(self,track)")+"\nvar _review_corridor: GDScript\n"
	var session_script := GDScript.new()
	session_script.source_code = session_source
	if session_script.reload() != OK: quit(1); return
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json")))
	var session: RefCounted = session_script.new()
	session._review_corridor = corridor
	var began := Time.get_ticks_usec()
	session._configure(track)
	var total: int = Time.get_ticks_usec()-began
	var marks: Dictionary = {}
	for hook: Array in hooks: marks[hook[1]] = session.get_meta("review_"+str(hook[1]))
	var instrumented: PackedByteArray = var_to_bytes(track._race_gates)
	track._race_gates = {}
	var original := TrackSession.new()
	began = Time.get_ticks_usec()
	original._configure(track)
	var original_us: int = Time.get_ticks_usec()-began
	var exact: bool = instrumented == var_to_bytes(track._race_gates)
	var output := {"total_us":total,"original_us":original_us,"marks":marks,"layout_bytes":instrumented.size(),"layout_exact":exact,"gates":original._centers.size(),"checks":1,"failures":0 if exact else 1}
	print("GATE_STAGES ",JSON.stringify(output))
	var file := FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify(output,"  ")); file.close()
	quit(0 if exact else 1)

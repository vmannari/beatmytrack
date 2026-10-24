extends SceneTree
const OUTPUT: String = "res://../docs/evidence/gameplay-f05-f10-2026-10-23/rewind-profile.json"
func _initialize() -> void: run.call_deferred()
func measure(script: GDScript) -> Dictionary:
	var state := VehicleState.new(); var session := TrackSession.new(); var telemetry := LapTelemetry.new()
	for index: int in range(576): state.loose_tyres.append([index*0.5,0.0,index*0.713,0.0,0.0])
	for index: int in range(400): telemetry.samples.append(LapTelemetry._point(0,index/20.0,index/20.0,Vector2(index,0),index/1000.0,12.0,true))
	var history: RefCounted = script.new()
	var before: int = OS.get_static_memory_usage(); var times: Array[float] = []
	for index: int in range(101):
		state.tick = index*12
		for offset: int in range(2): telemetry.samples.append(LapTelemetry._point(0,state.tick/120.0,state.tick/120.0,Vector2(index,0),index/1000.0,12.0,true))
		var start: int = Time.get_ticks_usec(); history.capture(state,session,false,telemetry); times.append((Time.get_ticks_usec()-start)/1000.0)
	var allocated: int = OS.get_static_memory_usage()-before
	times.sort()
	var retained: WeakRef = weakref(history); history = null
	assert(retained.get_ref()==null)
	return {"history_entries":101,"capture_median_ms":times[50],"capture_p95_ms":times[95],"tracked_allocation_bytes":allocated,"released":retained.get_ref()==null}
func run() -> void:
	var original := GDScript.new(); original.source_code = FileAccess.get_file_as_string("res://tests/fixtures/gameplay_f05_f10_before/rewind_history.gd.txt").replace("class_name RewindHistory",""); assert(original.reload()==OK)
	measure(original); measure(load("res://race/rewind_history.gd"))
	var rows: Array = []
	for pair: int in range(7):
		for variant: int in ([0,1] if pair%2==0 else [1,0]):
			var row: Dictionary = measure(original if variant==0 else load("res://race/rewind_history.gd")); row.pair = pair; row.variant = "before" if variant==0 else "after"; rows.append(row)
	var file := FileAccess.open(OUTPUT,FileAccess.WRITE); file.store_string(JSON.stringify({"rows":rows,"scope":"Pinned desktop headless; 576 tyres, 400 initial + 202 appended telemetry samples, 101 checkpoints. Godot tracked allocation delta includes the appended samples; not process RSS/PSS or Android data."},"\t",true)+"\n"); file.close()
	print("COMPACT_REWIND_PROFILE ",JSON.stringify(rows)); quit()

extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	var state := VehicleState.new(); var session := TrackSession.new(); var telemetry := LapTelemetry.new()
	var expected_state: Array[String] = []; var expected_session: Array[String] = []
	for item: Dictionary in state.get_property_list():
		if int(item.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE: expected_state.append(item.name)
	for item: Dictionary in session.get_property_list():
		if int(item.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and not str(item.name).begins_with("_"): expected_session.append(item.name)
	check(expected_state==RewindHistory.STATE_FIELDS,"explicit state schema covers every original mutable field in order")
	check(expected_session==RewindHistory.SESSION_FIELDS,"explicit session schema covers all timing/checkpoint fields")
	for index: int in range(576): state.loose_tyres.append([index*0.5,-0.0,sin(index)*19,0.0,index*0.713])
	state.light_props = [[1.1,2,3.0,4,0.5,6,7.0,8,9,10,11,12,13,14]]
	state.prop_destruction = [[false,3,0.1234567890123456]]; state.prop_fragments = [{"position":Vector3(1,2,3),"life":17}]
	var history := RewindHistory.new(); var reference: Array[Dictionary] = []
	for index: int in range(161):
		state.tick = index*12; state.heading += 0.000123456789; state.position = Vector2(index,2)
		state.loose_tyres[0][4] += 0.001234567890123
		session.elapsed_ticks = state.tick; session.lap_times = [12.123456789012345]
		telemetry.samples.append({"tick":state.tick,"speed":index*1.234567890123})
		if index%3==0: telemetry.events.append({"tick":state.tick,"kind":"collision"})
		if index==70: telemetry.completed.append({"index":0,"samples":telemetry.samples}); telemetry.samples = []; telemetry.events = []
		if index==90:
			var decimated: Array[Dictionary] = []
			for item: int in range(0,telemetry.samples.size(),2): decimated.append(telemetry.samples[item])
			telemetry.samples = decimated; telemetry.stride *= 2
		history.capture(state,session,false,telemetry)
		reference.append({"state":RewindHistory.properties(state),"session":RewindHistory.properties(session,true),"telemetry":RewindHistory.properties(telemetry)})
		var restored := VehicleState.new(); var restored_session := TrackSession.new(); var restored_telemetry := LapTelemetry.new()
		RewindHistory.restore(restored,history.entries[-1].state); RewindHistory.restore(restored_session,history.entries[-1].session); RewindHistory.restore(restored_telemetry,history.entries[-1].telemetry)
		check(var_to_bytes(RewindHistory.properties(restored))==var_to_bytes(reference[-1].state),"packed arrays preserve exact values and Variant types")
		check(var_to_bytes(RewindHistory.properties(restored_session,true))==var_to_bytes(reference[-1].session),"session scalar/list restoration exact")
		check(var_to_bytes(RewindHistory.properties(restored_telemetry))==var_to_bytes(reference[-1].telemetry),"shared telemetry handles append, lap reset and decimation")
	check(history.entries.size()<=101,"history window remains bounded")
	for entry: Dictionary in history.entries:
		var index: int = int(entry.tick)/12
		var restored := LapTelemetry.new(); RewindHistory.restore(restored,entry.telemetry)
		check(RewindHistory.properties(restored)==reference[index].telemetry,"future appends do not change retained prefixes")
	var target: Dictionary = history.entries[30]
	RewindHistory.restore(state,target.state); RewindHistory.restore(telemetry,target.telemetry); history.branch(target.tick)
	state.tick += 12; telemetry.samples.append({"tick":state.tick,"speed":-0.0}); history.capture(state,session,false,telemetry)
	check(history.entries[-1].telemetry.samples==telemetry.samples,"a resumed branch owns an exact new telemetry prefix")
	check(history.entries[-2].telemetry.samples==reference[int(target.tick)/12].telemetry.samples,"a resumed branch cannot modify the selected prefix")
	var old := VehicleState.new(); RewindHistory.restore(old,reference[0].state)
	check(RewindHistory.properties(old)==reference[0].state,"original dictionary snapshots remain supported")
	var journal_ref: WeakRef = weakref(history.entries[-1].telemetry._journals[1])
	var snapshot_ref: WeakRef = weakref(history.entries[-1].telemetry)
	target.clear(); history = null
	check(journal_ref.get_ref()==null and snapshot_ref.get_ref()==null,"race history release retires snapshot objects and their shared journals")
	print("COMPACT_REWIND: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)

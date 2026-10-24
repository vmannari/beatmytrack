extends SceneTree
var checks: int = 0
var failures: int = 0
class ObservedAudio extends VehicleAudio:
	var rows: Array[Dictionary] = []
	func _emit_collision_trace(trace: Dictionary) -> void:
		rows.append(trace)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var audio := ObservedAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	state.tick = 7
	state.velocity = Vector2(20,0)
	state.collision_impulse = Vector2(-20,0)
	audio.begin_physics_feedback()
	audio.resolved_contact(state,null,state.velocity)
	await process_frame
	check(audio.rows.is_empty(),"ordinary play has no diagnostic trace")
	audio.reset()
	audio.collision_trace_enabled = true
	audio.begin_physics_feedback()
	var snapshot: Array = state.snapshot()
	audio.resolved_contact(state,null,state.velocity)
	check(audio.impact_count==1 and audio.events[0].playing,"trace-enabled direct collision still starts immediately")
	check(state.snapshot()==snapshot,"diagnostic cannot change canonical state")
	await process_frame
	await process_frame
	check(audio.rows.size()==1,"one deferred trace for the actual collision")
	if audio.rows.size()==1:
		var row: Dictionary = audio.rows[0]
		check(row.tick==7 and row.source=="canonical","trace identifies actual physical trigger and tick")
		check(row.played and row.route=="godot","trace identifies the headless fallback actually used")
		check(row.unix_us>0 and row.outline_points==0,"time/context recorded only for the diagnostic")
		check(not row.has("player") and not row.has("session") and not row.has("token"),"no account or session data in trace")
	audio.resolved_contact(state,null,state.velocity)
	await process_frame
	await process_frame
	check(audio.rows.size()==2 and not audio.rows[1].played and audio.rows[1].route=="suppressed","cooldown rejection is visible without creating another sound")
	audio.free()
	await create_timer(.15).timeout
	print("COLLISION_TRACE_TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)

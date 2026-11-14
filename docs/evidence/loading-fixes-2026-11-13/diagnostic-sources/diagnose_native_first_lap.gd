extends "res://tests/test_shared_graphics_first_laps.gd"
var diagnostic_last_ms: int = 0
var diagnostic_game: int = 0

func observe() -> void:
	super.observe()
	if not is_instance_valid(app) or not is_instance_valid(app.game): return
	var game: Node = app.game
	if not game.preparation_complete or game.sim == null: return
	var now: int = Time.get_ticks_msec()
	if game.get_instance_id() == diagnostic_game and now-diagnostic_last_ms < 1000: return
	diagnostic_game = game.get_instance_id(); diagnostic_last_ms = now
	var row: Dictionary = {"wall_ms":now,"game":diagnostic_game,"tick":game.sim.state.tick,"countdown":game.countdown_ticks,"laps":game.track_session.completed_laps,"checkpoint":game.track_session.next_checkpoint,"missed_checkpoint":game.track_session.missed_checkpoint,"position":[game.sim.state.position.x,game.sim.state.position.y],"speed":game.sim.state.velocity.length(),"route_index":game.sim.state.route_index,"paused":game.paused,"tree_paused":paused,"process_mode":game.process_mode,"can_process":game.can_process(),"physics_processing":game.is_physics_processing(),"ai":game.ai_enabled,"physics_frames":Engine.get_physics_frames(),"backgrounded":game._preparation_backgrounded}
	print("FIRST_LAP_NATIVE_STATE ",JSON.stringify(row))
	if not cases.is_empty():
		if not cases[-1].has("native_diagnostic"): cases[-1].native_diagnostic = []
		cases[-1].native_diagnostic.append(row)

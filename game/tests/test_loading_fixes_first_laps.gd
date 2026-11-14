extends "res://tests/test_shared_graphics_first_laps.gd"
## Strict inherited native lap/emission/cancellation checks. The optional resume
## models a user pressing Resume after another test window takes desktop focus.

func observe() -> void:
	super.observe()
	if not "--resume-backgrounded-ai" in OS.get_cmdline_user_args(): return
	if mode != "complete" or not is_instance_valid(app) or not is_instance_valid(app.game): return
	var game: Node = app.game
	if not game.ai_enabled or not game.paused or not game._preparation_backgrounded: return
	if not game.preparation_complete or not game.can_process() or not game.is_physics_processing(): return
	if game.finish_sim != null or game.track_session.finished or is_instance_valid(game.rewind_panel) or game.rewind_return.remaining > 0: return
	var event: Dictionary = {"tick":game.sim.state.tick,"countdown":game.countdown_ticks,"wall_ms":Time.get_ticks_msec(),"reason":"backgrounded AI test resumed through Game.toggle_pause"}
	print("LOADING_TEST_FOCUS_RESUME ",JSON.stringify(event))
	if not cases.is_empty():
		if not cases[-1].has("focus_resumes"): cases[-1].focus_resumes = []
		cases[-1].focus_resumes.append(event)
	game.toggle_pause(false)

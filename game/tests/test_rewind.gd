extends SceneTree
var checks: int = 0
var failures: int = 0
var capture_path: String = ""

class AwardedCredits extends Node:
	var busy: bool = false
	var pending: Dictionary = {}
	var used: int = 0
	func refresh() -> Dictionary:
		return {"ok":true,"data":{"free":0,"balance":9-used}}
	func consume(_from: int, _to: int, _offset: int) -> Dictionary:
		used += 1
		return {"ok":true,"data":{"receipt_id":"00000000-0000-0000-0000-%012d" % used,"wallet":{"free":0,"balance":9-used}}}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	_check_return_pacing()
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-rewind="): capture_path = argument.trim_prefix("--capture-rewind=")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../backend/tests/fixtures/verified_oval.json")))
	var track: NativeTrack = TrackCompiler.compile(fixture.document)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.resume_credits.guest_path = "user://rewind-test-"+str(Time.get_ticks_usec())+".json"
	var guest_path: String = game.resume_credits.guest_path
	# Replay actual race input across at least one lap boundary.
	for i: int in range(4000):
		game.driver.clear()
		# Use a deterministic autopilot in the scene; replay parity is tested below independently.
		game.ai_enabled = true
		game.call("_physics_process",1.0/120.0)
	check(game.sim.state.tick == 4000,"scene advances 4000 ticks")
	check(game.rewind_history.entries.size() <= 101,"history remains bounded at 101 checkpoints")
	var original: Array = game.sim.state.snapshot()
	var original_session: Dictionary = RewindHistory.properties(game.track_session,true)
	await game.open_rewind()
	check(game.paused and not game.hud.touch.enabled,"rewind freezes simulation and releases controls")
	check(game.rewind_choices[0].tick >= 2800,"timeline never goes beyond ten seconds")
	check(game.sim.state.snapshot() == original,"rewind opens at the exact current position")
	if not capture_path.is_empty():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_path.get_basename()+"-current.png") == OK,"current-position opening screenshot saved")
	game.preview_rewind(0)
	check(game.sim.state.tick < 4000,"scrubbing previews the historical vehicle")
	game.call("_physics_process",1.0/120.0)
	check(game.sim.state.tick == game.rewind_choices[0].tick,"preview never advances physics")
	check(not FileAccess.file_exists(guest_path),"opening and scrubbing do not spend a resume")
	check(game.rewind_ghosts.ghosts.size() == 4 and game.rewind_ghosts.labels.size() > 0,"preview shares a bounded pool of actual history cars")
	game.preview_rewind(game.rewind_choices.size())
	check(game.sim.state.snapshot() == original and game.rewind_panel.confirm.disabled,"LIVE endpoint previews original state and cannot spend")
	await game.confirm_rewind()
	check(game.online_rewinds.is_empty(),"programmatic confirmation at LIVE also cannot spend")
	game.preview_rewind(0)
	game.preview_rewind(game.rewind_choices.size()/2)
	var has_before: bool = false
	var has_after: bool = false
	var recorded_only: bool = true
	for marker: Dictionary in game.rewind_ghosts.labels:
		has_before = has_before or int(marker.tick) < game.sim.state.tick
		has_after = has_after or int(marker.tick) > game.sim.state.tick
		recorded_only = recorded_only and int(marker.tick) <= 4000
	check(has_before and has_after and recorded_only,"ghosts show recorded positions on both sides without future extrapolation")
	game.rewind_panel.show_balance({"free":0,"balance":3,"ad_preview_available":true},1)
	check(game.rewind_panel.resume_action.count == 3 and not game.rewind_panel.resume_action.use_ad,"banked button shows ticket icon and actual banked count")
	game.rewind_panel.show_balance({"free":0,"balance":0,"ad_preview_available":true},1)
	check(game.rewind_panel.resume_action.use_ad and not game.rewind_panel.resume_action.disabled,"empty wallet shows usable temporary ad action")
	game.rewind_panel.show_balance({"free":0,"balance":0,"ad_preview_available":true},3)
	check(game.rewind_panel.resume_action.disabled and game.rewind_panel.confirm.disabled,"both resume actions enforce the race cap")
	game.rewind_panel.status.text = ""
	game.rewind_panel.show_balance({"free":0,"balance":0,"ad_preview_available":true},0)
	if not capture_path.is_empty():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_path) == OK,"rewind screenshot saved")
		game.rewind_panel.show_balance({"free":0,"balance":3,"ad_preview_available":true},1)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_path.get_basename()+"-banked.png") == OK,"banked resume button screenshot saved")
		root.size = Vector2i(960,540)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_visible_rect().encloses(game.rewind_panel.confirm.get_global_rect()),"compact viewport keeps resume action on screen in canvas coordinates")
		check(root.get_texture().get_image().save_png(capture_path.get_basename()+"-compact.png") == OK,"compact rewind screenshot saved")
		root.size = Vector2i(1280,720)
	game.cancel_rewind()
	check(game.sim.state.snapshot() == original,"cancel restores exact canonical state")
	check(RewindHistory.properties(game.track_session,true) == original_session,"cancel restores exact timing and ordered gates")
	check(not game.paused and game.online_rewinds.is_empty(),"cancel costs no race resume")
	check(game.rewind_ghosts == null,"cancel removes ghost scene")
	await game.open_rewind()
	game.preview_rewind(0)
	var target: Dictionary = game.rewind_choices[0].duplicate(true)
	check(int(target.tick) >= 2800,"resume remains within the ten-second window")
	game.rewind_panel.resume_action.pressed.emit()
	check(game.online_rewinds.size() == 1 and game.resume_credits.used == 1,"confirm spends exactly one resume")
	check(game.sim.state.tick == target.tick and not game.paused,"resume continues from selected tick")
	check(RewindHistory.properties(game.track_session,true) == target.session,"resume restores laps, gates and race clock")
	check(game.lap_telemetry.samples == target.telemetry.samples and game.lap_telemetry.completed == target.telemetry.completed,"resume restores telemetry including abandoned lap data")
	check(game.online_frames.size() == 4000,"discarded input stays in audit replay")
	check(not game.attempt_practice,"resume does not disqualify leaderboard eligibility")
	check(game.rewind_history.entries[-1].tick <= target.tick,"discarded future checkpoints are removed")
	await game.open_rewind()
	check(game.rewind_panel == null,"cannot reopen to interrupt the brief resume ramp")
	var before_return: int = game.sim.state.tick
	var before_inputs: int = game.online_frames.size()
	for i: int in range(36): game.call("_physics_process",1.0/120.0)
	var returned_ticks: int = game.sim.state.tick-before_return
	check(returned_ticks > 0 and returned_ticks < 36,"resume briefly reduces cadence of complete simulation steps")
	check(game.online_frames.size()-before_inputs == returned_ticks,"slow return records exactly one input per canonical tick")
	var refreshed: Dictionary = await game.resume_credits.refresh()
	check(refreshed.data.free == 0,"guest daily allowance persists")
	game.resume_credits.begin()
	refreshed = await game.resume_credits.refresh()
	check(refreshed.data.free == 0,"restarting does not replenish today's free resume")
	var denied: Dictionary = await game.resume_credits.consume(120,0,120)
	check(denied.ok and denied.data.wallet.free == 0 and denied.data.wallet.balance == 0,"temporary ad resume works without replenishing daily or saved credits")
	DirAccess.remove_absolute(guest_path)
	# A funded adapter exercises the scene's independent three-resume limit.
	game.resume_credits.queue_free()
	var awarded := AwardedCredits.new()
	game.resume_credits = awarded
	game.add_child(awarded)
	for index: int in range(2):
		for i: int in range(48): game.call("_physics_process",1.0/120.0)
		await game.open_rewind()
		check(game.rewind_panel != null,"funded player can choose another resume")
		game.preview_rewind(0)
		await game.confirm_rewind()
	check(game.online_rewinds.size() == 3,"daily and awarded resumes share the three-resume race limit")
	await game.open_rewind()
	check(game.rewind_panel == null and awarded.used == 2,"fourth resume cannot open or consume credits")
	game.queue_free()
	await process_frame
	_check_exact_restore(track,fixture.replay.frames)
	print("Rewind: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _check_return_pacing() -> void:
	var pacing := RewindReturn.new()
	pacing.resume()
	var ticks: int = 0
	for i: int in range(36):
		if pacing.step_due(): ticks += 1
	check(ticks == 23 and pacing.remaining == 0,"resume ramp lasts 300 ms and executes 23 full ticks")
	check(pacing.step_due() and pacing.speed == 1.0,"resume returns to full cadence")
	for fps: int in [30,60,120]:
		pacing.cancel()
		for i: int in range(fps):
			pacing.visual_delta(1.0/fps)
		check(pacing.cancel_remaining == 0.0,"cancel easing expires independently of render frequency")
	var full_speed: bool = true
	for i: int in range(120):
		pacing.cancel()
		full_speed = full_speed and pacing.step_due() and pacing.speed == 1.0
	check(full_speed,"repeated Cancel never slows simulation or input sampling")

func _check_exact_restore(track: NativeTrack, frames: Array) -> void:
	var sim := VehicleSimulation.new(VehicleCatalog.config("compact"))
	sim.reset(track.spawn,track.spawn_heading)
	var distance: float = (sim.state.position-track.finish_center).dot(track.finish_forward)
	sim.state.position -= track.finish_forward*maxf(0.0,distance+3.0)
	sim.state.route_index = track.nearest_route(sim.state.position)
	sim.state.track_elevated = track.elevated_at(sim.state.position,sim.state.route_index)
	var session := TrackSession.new()
	session._configure(track)
	var history := RewindHistory.new()
	var final_state: Array = []
	var captured: Dictionary = {}
	for pass_index: int in range(2):
		for i: int in range(0 if pass_index == 0 else 1200,3600):
			var values: Array = frames[i]
			var frame := DriveFrame.new()
			frame.steer = int(values[0]); frame.throttle = int(values[1]); frame.brake = int(values[2])
			var before: Vector2 = sim.state.position
			sim.step(frame,track)
			session.advance(track,before,sim.state.position,sim.state.route_index)
			if pass_index == 0:
				history.capture(sim.state,session)
				if sim.state.tick == 1200: captured = history.entries[-1].duplicate(true)
		if pass_index == 0:
			final_state = sim.state.snapshot()
			RewindHistory.restore(sim.state,captured.state)
			RewindHistory.restore(session,captured.session)
	check(sim.state.snapshot() == final_state,"restored complete physics state reproduces exact canonical trajectory")

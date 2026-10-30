extends SceneTree
## Actual finished App results must remain escapable when evidence is ineligible.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func run() -> void:
	print("AUDIT_PID ",OS.get_process_id())
	var audit_config := ConfigFile.new()
	audit_config.set_value("backend","url","")
	assert(audit_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var folder: String = "user://recording-limit-"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json")); app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records.settings.music_enabled = false; app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	track.metadata.cloud_version = "owned-record-limit-fixture"
	for mode: String in ["limit","practice"]:
		app._show_screen("tracks"); app.selected_track = track
		await app._start_race(track,false,true)
		var game: Node = app.game
		game.set_physics_process(false); game.paused = true
		game.attempt_evidence.overflow = mode=="limit"
		game.attempt_practice = mode=="practice"
		game.track_session.finished = true; game.track_session.completed_laps = 5; game.track_session.elapsed_ticks = 1200
		game.track_session.lap_times.assign([2.0,2.0,2.0,2.0,2.0])
		app.cloud_ticket = {"ticket_id":"ineligible-"+mode}
		app.challenge_racing = true
		app.challenges.result_ticket = str(app.cloud_ticket.ticket_id)
		app.challenges.result_state = "verified"
		app.challenges.outcome = {"fixture":"previous result must not appear"}
		app._results()
		var panel: RaceResults = app.root_ui.find_child("RaceResults",true,false)
		check(panel!=null and not panel.verification_notice.is_empty(),mode+" result explains local-only eligibility")
		check(app.cloud_ticket.is_empty() and app.challenges.result_ticket.is_empty() and app.cloud.result_saves.jobs.is_empty(),mode+" never submits or polls an impossible recording")
		check(app.challenges.outcome.is_empty() and app.challenges.result_state.is_empty() and not app.challenges.error.is_empty(),mode+" cannot show a previous race as this result")
		check(panel.find_child("RaceVerificationNotice",true,false)!=null,mode+" notice is actually mounted")
		app._results()
		check(app.root_ui.find_child("RaceResults",true,false)==panel,mode+" duplicate completion cannot replace the result")
		if DisplayServer.get_name()!="headless":
			for _frame: int in range(30): await process_frame
			await RenderingServer.frame_post_draw
			var out: String = ProjectSettings.globalize_path("res://../build/re-audit-2026-10-27/outputs/test_result_recording_limit/recording-limit")
			DirAccess.make_dir_recursive_absolute(out)
			root.get_texture().get_image().save_png(out.path_join(mode+".png"))
		app._results_continue(panel,panel.get_parent())
		for _frame: int in range(4): await process_frame
		check(app.game==null and app.screen=="challenges",mode+" Challenge Continue releases Game and remains usable")
	app.queue_free()
	for _frame: int in range(8): await process_frame
	print("RESULT_RECORDING_LIMIT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

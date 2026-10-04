extends SceneTree
## PB partition/recovery, fractional finish timing, rewind branches and actual race integration.
var checks: int = 0
var failures: int = 0
var folder: String

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func fixture(ends: Array[float]) -> PersonalGhostRun:
	var run := PersonalGhostRun.new()
	run.lap_ends = ends
	for tick: int in range(0, ceili(ends[-1]) + 1):
		if tick % PersonalGhostRun.STRIDE == 0 or tick == ceili(ends[-1]):
			run.poses.append([tick, float(tick), 2.0, 3.0, deg_to_rad(179.0 if tick < 6 else -179.0), 0.1, 0.2])
	return run

func best_for(run: PersonalGhostRun) -> Dictionary:
	return {"race_ms": roundi(float(run.recording("race").ticks) * 1000.0 / 120.0), "flying_ms": roundi(float(run.recording("lap").ticks) * 1000.0 / 120.0)}

func run() -> void:
	folder = "user://personal_ghost_tests_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	var handling: HandlingConfig = VehicleCatalog.config("compact",HandlingSelection.ORIGINAL_PLUS_INDEX)
	var key: String = records.key_for(track,handling)
	var store := LocalGhosts.new(records.path)
	var recording: PersonalGhostRun = fixture([120.4,240.8,350.2,490.5,620.9])
	var best: Dictionary = best_for(recording)
	check(is_equal_approx(recording.recording("lap").ticks,109.4),"fastest flying lap excludes standing first and retains fractional ticks")
	check(store.save_run(key,best,recording) == OK,"PB ghosts atomically saved")
	var loaded: Dictionary = LocalGhosts.new(records.path).load_best(key,best)
	check(loaded.size() == 2,"both PB modes survive reload")
	check(is_equal_approx(loaded.lap.poses[0][1],240.8) and is_equal_approx(loaded.lap.poses[-1][1],350.2),"exact crossing endpoints interpolated from recorded poses")
	check(absf(absf(PersonalGhostRun.sample(loaded.race,3.0)[4]) - PI) < 0.001,"heading interpolation takes shortest wrap")
	check(is_equal_approx(PersonalGhostRun.sample(loaded.lap,50.0)[1],290.8),"lap playback uses relative clock")
	check(PersonalGhostRun.sample(loaded.lap,110.0).is_empty(),"completed ghost hides without extrapolation")
	check(store.load_best(records.key_for(track,VehicleCatalog.config("kart",HandlingSelection.ORIGINAL_PLUS_INDEX)),best).is_empty(),"car handling partitions isolated")
	var modified: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	modified.content_hash += "changed"
	check(store.load_best(records.key_for(modified,handling),best).is_empty(),"track revisions isolated")
	check(LocalGhosts.new(folder.path_join("another_profile.json")).load_best(key,best).is_empty(),"profiles isolated")
	var improved: PersonalGhostRun = fixture([120.4,240.8,330.2,490.5,650.9])
	var next_best: Dictionary = best.duplicate()
	next_best.flying_ms = best_for(improved).flying_ms
	check(store.save_run(key,next_best,improved) == OK,"slower complete race can improve lap ghost")
	loaded = store.load_best(key,next_best)
	check(is_equal_approx(loaded.race.ticks,620.9) and is_equal_approx(loaded.lap.ticks,89.4),"race and lap best recordings update independently")
	var missing_best: Dictionary = next_best.duplicate()
	missing_best.race_ms -= 100
	check(not store.load_best(key,missing_best).has("race"),"older faster PB never gets an inaccurately labelled slower ghost")
	check(store.save_run(key,next_best,recording) == OK and is_equal_approx(store.load_best(key,next_best).lap.ticks,89.4),"slower run retains best")
	var file := FileAccess.open(store.folder.path_join(key + ".json"),FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(store.load_best(key,best).size() == 2,"corrupt primary recovers committed backup")
	check(store.save_run(key,next_best,improved) == OK,"corrupt primary replaced without deleting good backup")
	var abandoned: PersonalGhostRun = fixture([120.4,240.8,350.2,490.5,620.9])
	abandoned.branch(250)
	check(abandoned.lap_ends.size() == 2 and abandoned.poses[-1][0] <= 250 and abandoned.recording("race").is_empty(),"rewind removes future poses and completed laps")
	abandoned.overflow = true
	check(abandoned.recording("lap").is_empty(),"overlong recordings cannot replace PBs")
	check(store.save_run(key,best,abandoned) == ERR_OUT_OF_MEMORY,"recording cap reports missing ghost without changing saved PB")
	var invalid: Dictionary = {"schema":1,"key":key,"race":{"ticks":2,"poses":[[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]]}}
	check(not LocalGhosts._valid(invalid,key),"duplicate ticks rejected")
	invalid.race.poses[1][0] = 2
	invalid.race.poses[1][1] = NAN
	check(not LocalGhosts._valid(invalid,key),"nonfinite poses rejected")
	check(LocalGhosts.new(folder.path_join("missing/records.json")).save_run(key,best,recording) == OK,"new profile directory created")
	var blocked := LocalGhosts.new(records.path)
	blocked.folder = records.path
	records.settings.ghost_mode = "race"
	check(records.save_records() == OK,"ghost mode saves with preferences")
	check(blocked.save_run(key,best,recording) != OK,"save failure reported without changing PB times")
	var reloaded := LocalRecords.new(records.path)
	reloaded.load_records()
	check(reloaded.settings.ghost_mode == "race","selected mode survives restart")
	check(not records._normalize({"schema":2,"records":{},"settings":{"ghost_mode":"other"}}).size(),"unknown preference mode rejected")
	await _game(records,track)
	_cleanup(folder)
	print("PERSONAL_GHOST_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _game(records: LocalRecords, track: NativeTrack) -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	game.preference_records = records
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_ticks = 0
	game.ai_enabled = true
	check(game.personal_ghost != null and game.ghost_run.poses[0][0] == 0,"ordinary race creates ghost and records tick-zero spawn")
	var source: String = (game.personal_ghost.material_override as ShaderMaterial).shader.code
	check("vec3(0.78,0.80,0.82)" in source and game.personal_ghost.get_child_count() == 0,"neutral grey silhouette has no collision nodes")
	while not game.track_session.finished and game.sim.state.tick < 30000: game._physics_process(1.0 / 120.0)
	check(game.track_session.finished,"real five-lap AI race completes")
	var session: TrackSession = game.track_session
	check(records.record(track,game.handling,session.race_time_seconds(),session.lap_times) == OK,"actual fractional lap and race times committed")
	check(game.save_personal_ghost() == OK,"actual completed race saves both matching ghosts")
	game.restart()
	game.set_physics_process(false)
	game.set_process(false)
	check(game.ghost_bests.size() == 2,"restart loads actual lap and race ghosts")
	game.countdown_ticks = 0
	game.track_session.elapsed_ticks = 30
	game.set_ghost_mode("race")
	var state_before: Array = game.sim.state.snapshot()
	game._present_personal_ghost(0.5)
	check(game.personal_ghost.visible and game.sim.state.snapshot() == state_before,"playback leaves canonical state unchanged")
	var expected: Array = PersonalGhostRun.sample(game.ghost_bests.race,29.5)
	check(game.personal_ghost.position.distance_to(Vector3(expected[1],expected[3]+0.05,-expected[2])) < 0.00001,"race ghost shares interpolated race clock")
	game.set_ghost_mode("lap")
	game.track_session.lap_start_time = 30.0/120.0
	game._present_personal_ghost(1.0)
	check(is_equal_approx(game.personal_ghost.position.x,game.ghost_bests.lap.poses[0][1]),"lap ghost resets at player's lap boundary")
	game.track_session.lap_start_time = 10.0/120.0
	game._present_personal_ghost(1.0)
	check(is_equal_approx(game.personal_ghost.position.x,PersonalGhostRun.sample(game.ghost_bests.lap,20.0)[1]),"restored lap start resynchronizes after rewind")
	game.countdown_ticks = 1
	game._present_personal_ghost(1.0)
	check(not game.personal_ghost.visible,"countdown hides ghost")
	game.countdown_ticks = 0
	game.set_ghost_mode("off")
	game._present_personal_ghost(1.0)
	check(not game.personal_ghost.visible,"Off hides ghost")
	game.queue_free()
	await process_frame

func _cleanup(path: String) -> void:
	for child: String in DirAccess.get_directories_at(path): _cleanup(path.path_join(child))
	for file: String in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)

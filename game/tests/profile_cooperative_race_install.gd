extends SceneTree
const WORLDS = preload("res://track/prepared_world_cache.gd")
const ROADS = preload("res://editor/road_preparation.gd")
const OUTPUT: String = "res://../docs/evidence/gameplay-f04-f05-2026-10-23/loading-profile.json"
func _initialize() -> void: run.call_deferred()
func sample(track: NativeTrack, packet: Dictionary, sliced: bool, records: LocalRecords) -> Dictionary:
	WORLDS.entries.clear(); NativeTrackVisual._road_mesh_cache.clear()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.production_mode = true; game.initial_track = track; game.prepared_road_packet = packet
	game.cooperative_preparation = sliced; game.preference_records = records
	game.profile_enabled = true
	game.process_mode = Node.PROCESS_MODE_DISABLED; game.hitch_diagnostics_enabled = false
	var began: int = Time.get_ticks_usec()
	root.add_child(game)
	var attach_us: int = Time.get_ticks_usec()-began
	var intervals: Array = []; var previous: int = began
	while not game.preparation_complete:
		await process_frame
		var now: int = Time.get_ticks_usec(); intervals.append(now-previous); previous = now
	var total_us: int = Time.get_ticks_usec()-began
	if intervals.is_empty(): intervals.append(attach_us)
	var ordered: Array = intervals.duplicate(); ordered.sort()
	assert(game.sim.state.tick == 0 and game.countdown_ticks == 360 and game.track_ground.world_built)
	var result: Dictionary = {"cooperative":sliced,"total_us":total_us,"initial_add_child_us":attach_us,"observed_frame_intervals_us":intervals,"max_observed_interval_us":ordered.back(),"p95_observed_interval_us":ordered[mini(ordered.size()-1,ceili(ordered.size()*0.95)-1)],"install_yields":game.track_ground.install_yields,"peak_install_vertices":game.track_ground.install_peak_vertices,"draw_nodes":game.track_ground.get_child_count()}
	result.stage_costs = game.preparation_costs; result.world_costs = game.track_ground.build_costs
	game.free(); await process_frame
	return result
func run() -> void:
	var output: Dictionary = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"kind":"paired desktop construction responsiveness; frame intervals include engine scheduling, not isolated CPU/GPU times","samples":[]}
	var folder: String = "user://load_profile_"+TrackLibrary.unique_id(); DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	NativeTrackVisual.ROAD_DISK_CACHE.directory = ""
	for theme: String in (["winter"] if "quick=1" in OS.get_cmdline_user_args() else ["pine","winter","desert"]):
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json")); doc.theme = theme
		var track: NativeTrack = TrackCompiler.compile(doc)
		var packet: Dictionary = ROADS.with_winter_cover(ROADS.prepare(track,true),track,func() -> bool: return false)
		# Warm shared resource/code caches equally; every timed sample still
		# rebuilds its world and road GPU cache from the same prepared CPU packet.
		await sample(track,packet,false,records); await sample(track,packet,true,records)
		for repeat: int in range(1 if "quick=1" in OS.get_cmdline_user_args() else 3):
			for sliced: bool in ([false,true] if repeat%2 == 0 else [true,false]):
				var row: Dictionary = await sample(track,packet,sliced,records)
				row.theme = theme; row.repeat = repeat; output.samples.append(row)
				var brief: Dictionary = row.duplicate(); brief.erase("observed_frame_intervals_us")
				print("LOAD_INSTALL_PROFILE ",JSON.stringify(brief))
	WORLDS.entries.clear()
	NativeTrackVisual._road_mesh_cache.clear()
	# Let the renderer retire transient texture handles before engine shutdown.
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var path: String = OUTPUT.replace(".json","-compatibility-quick.json") if "quick=1" in OS.get_cmdline_user_args() else OUTPUT
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(output,"\t",true)+"\n"); file.close()
	# Release the run's last track/packet locals before shutting down rendering.
	finish.call_deferred()
func finish() -> void:
	await process_frame
	quit()

extends SceneTree
var app: Node
var rows: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var live: bool = OS.get_environment("BMT_BLIND_LIVE") == "1"
	OS.set_environment("BMT_API_URL",OS.get_environment("BMT_PROFILE_URL") if live else "")
	OS.set_environment("BMT_RACE_LOAD_PROFILE","1")
	var folder: String = ProjectSettings.globalize_path("res://../build/blind-spot-timeout-20261011/client-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	if live:
		var login: Dictionary = await app.online.client.development_login(OS.get_environment("BMT_PROFILE_SUBJECT"),OS.get_environment("BMT_PROFILE_NAME"),OS.get_environment("BMT_DEV_AUTH_KEY"))
		if not login.get("ok",false): print("BLIND_SPOT_LOGIN status=",login.get("status",0));quit(1);return
	app._show_screen("tracks")
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/blind-spot-timeout-20261011/metadata.json"))
	if live:
		metadata = JSON.parse_string(FileAccess.get_file_as_string("res://../build/blind-spot-timeout-20261011/public-track-contracts.json")).tracks[0].metadata
	var entry: Dictionary = app.cloud.entry_from_metadata(metadata)
	var body: String = FileAccess.get_file_as_string("res://../build/blind-spot-timeout-20261011/blind-spot.json")
	DirAccess.make_dir_recursive_absolute(str(entry.cache_path).get_base_dir())
	var file := FileAccess.open(entry.cache_path,FileAccess.WRITE);file.store_string(body);file.close()
	for attempt: int in range(2):
		var track: NativeTrack = app.cloud.presentation_track(entry.duplicate(true))
		app.selected_track = track
		var start: int = Time.get_ticks_usec()
		await app._start_race(track,false,not live)
		var value: Dictionary = {"signed_in":app.online.client.signed_in(),"error":app.cloud.last_error,"attempt":attempt,"ms":(Time.get_ticks_usec()-start)/1000.0,"started":is_instance_valid(app.game),"overlay_closed":app.race_loading == null}
		if is_instance_valid(app.game):
			app.game.set_physics_process(false)
			value.laps = app.game.track_session.target_laps
			app._leave_race()
		rows.append(value);print("BLIND_SPOT_START ",JSON.stringify(value))
		if not value.started: break
	var output := FileAccess.open("res://../build/blind-spot-timeout-20261011/"+("live-start.json" if live else "local-start.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(rows,"\t"));output.close()
	app.queue_free();await process_frame
	quit(0 if rows.all(func(row: Dictionary) -> bool: return row.started and row.overlay_closed and row.laps == 5) else 1)

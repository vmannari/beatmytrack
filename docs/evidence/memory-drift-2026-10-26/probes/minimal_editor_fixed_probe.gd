extends SceneTree
var app: Node
var heap: RefCounted
var output: FileAccess
var directory: String
var tag: String = "editor-fixed-headless"
var cycles: int = 24
var practice: bool = false
func _initialize() -> void: run.call_deferred()
func frames(count: int = 8) -> void:
	for _index: int in range(count): await process_frame
func sample(cycle: int) -> void:
	var bytes: int = OS.get_static_memory_usage()
	var queue: Dictionary = heap.queue_info(self)
	var row := {"cycle":cycle,"bytes":bytes,"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"accessibility":queue}
	output.store_line(JSON.stringify(row)); output.flush()
	print("MINIMAL ",JSON.stringify(row))
	if cycle in [2,8,10,12,18,23]: heap.dump(directory.path_join(tag+"-"+str(cycle)+".tsv"),str(cycle))
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag=arg.trim_prefix("--tag=")
		if arg.begins_with("--cycles="): cycles=int(arg.trim_prefix("--cycles="))
		if arg=="--practice": practice=true
	directory=ProjectSettings.globalize_path("res://../build/memory-drift-2026-10-26").simplify_path()
	assert(GDExtensionManager.load_extension(directory.path_join("heap_probe_v4.gdextension"))==GDExtensionManager.LOAD_STATUS_OK)
	heap=ClassDB.instantiate("BmtHeapProbe")
	output=FileAccess.open(directory.path_join(tag+".jsonl"),FileAccess.WRITE)
	var config := ConfigFile.new(); config.set_value("backend","url",""); assert(config.save("user://backend.cfg")==OK)
	root.size=Vector2i(1280,720)
	var folder: String="user://minimal-memory-"+TrackLibrary.unique_id()
	app=load("res://core/app.tscn").instantiate()
	app.records=LocalRecords.new(folder.path_join("records.json")); app.records.settings.music_enabled=false
	app.library=TrackLibrary.new(folder.path_join("tracks")); app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	assert(app.online.client.base_url().is_empty()); print("BACKEND_DISABLED true")
	print("ACCESSIBILITY ",DisplayServer.get_name()," ",DisplayServer.has_feature(DisplayServer.FEATURE_ACCESSIBILITY_SCREEN_READER))
	app.document=JSON.parse_string(FileAccess.get_file_as_string("res://resources/storm_tracks/storm_freight.json"))
	app.document.theme="pine"; app.document.objects=[]; app.document.creator=app.library.owner_name
	for cycle: int in range(cycles):
		app._show_screen("create")
		var deadline: int=Time.get_ticks_msec()+60000
		while not (is_instance_valid(app.canvas) and app.editor_preview_thread==null and not app.canvas.preparing and not app.editor_world._building and not app.editor_commits.unsettled()):
			if Time.get_ticks_msec()>=deadline:
				print("MINIMAL_FAILURE editor preparation deadline ",cycle); quit(1); return
			await process_frame
		if practice:
			await app._test_document(); assert(is_instance_valid(app.game) and app.game.editor_test); app._leave_race()
		app._show_screen("settings"); await frames()
		if cycle==2: print("HEAP_HOOKS ",heap.start(64))
		sample(cycle)
	app.queue_free(); app=null; await frames(16); sample(cycles)
	output.close(); print("MINIMAL_RESULT: ",cycles," cycles complete"); quit()

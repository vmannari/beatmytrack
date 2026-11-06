extends SceneTree
## Feature coroutines/workers release with App, including cancellation mid-entry.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FEATURE_LIFETIME_FAIL ",message)
func frames(count: int = 8) -> void:
	for _i: int in range(count): await process_frame
func make_app(label: String) -> Node:
	var app: Node = load("res://core/app.tscn").instantiate()
	var folder: String = "user://feature-lifetime/"+label
	DirAccess.make_dir_recursive_absolute(folder)
	app.records = load("res://persistence/local_records.gd").new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	check(app.records.save_records() == OK,"private records "+label)
	app.library = load("res://persistence/track_library.gd").new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._publishing_slots_foreground = false
	return app
func run() -> void:
	create_timer(90,true,false,true).timeout.connect(func() -> void: printerr("FEATURE_LIFETIME_TIMEOUT"); quit(1))
	var app: Node = await make_app("race")
	var track: RefCounted = load("res://track/native_track.gd").read("res://resources/tracks/ellipse.json")
	track.metadata.cloud_version = "private-lifetime-fixture"
	app.selected_track = track
	app._start_race(track,false,true)
	check(is_instance_valid(app.race_loading) and app.game == null,"race cancellation occurs at the real first yield")
	var controller: WeakRef = weakref(app._feature_resources["res://core/features/race.gd"])
	check(controller.get_ref().get_parent() == app,"race controller has App lifetime")
	var previous: WeakRef = weakref(app)
	app.queue_free()
	app = null
	await frames()
	check(previous.get_ref() == null and controller.get_ref() == null,"pending race controller and App release together")
	app = await make_app("editor")
	app.document = load("res://editor/track_document.gd").create_default()
	app._queue_editor_preview()
	check(app.editor_preview_thread != null,"real editor worker started")
	controller = weakref(app._feature_resources["res://core/features/editor.gd"])
	check(controller.get_ref().get_parent() == app,"editor controller has App lifetime")
	previous = weakref(app)
	app.queue_free()
	app = null
	await frames()
	check(previous.get_ref() == null and controller.get_ref() == null,"editor worker retires before its owner releases")
	app = await make_app("write")
	check(app._feature_resources.is_empty(),"unused authoring feature starts cold")
	var document: Dictionary = load("res://editor/track_document.gd").create_default()
	check(app.editor_writes.enqueue(app.library,document) == OK,"private authoring write queued")
	app._flush_editor_writes()
	check(FileAccess.file_exists(app.library.directory.path_join("wip/"+str(document.id)+".json")),"pending write flushes even before an editor page opens")
	check(app.editor_writes.pending.is_empty() and app.editor_writes.thread == null and app.editor_writes.completed.is_empty(),"write queue drains completely")
	app.queue_free()
	app = null
	await frames()
	print("FEATURE_LIFETIME ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

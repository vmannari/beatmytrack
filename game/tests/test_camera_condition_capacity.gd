extends SceneTree
## Pause-camera Apply with every current and retained car's real condition masks.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func run() -> void:
	var directory: String = "user://camera_condition_capacity_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	var conditions: Dictionary = {}
	for index: int in range(VehicleCatalog.ALL_IDS.size()):
		var condition: Dictionary = VehicleWeathering.new().snapshot()
		condition.dirt = float(index + 1) / 10.0
		conditions[VehicleCatalog.ALL_IDS[index]] = condition
	check(VehicleCondition.valid_collection(conditions), "real snapshots for all retained and current cars are valid")
	records.records["capacity".sha256_text()] = {"race_ms":100000,"flying_ms":20000}
	records.settings = {"favorites":["ellipse"],"camera_mode":"overhead"}
	check(records.save_records() == OK, "seed unrelated PB and preferences")
	var expected_records: Dictionary = records.records.duplicate(true)
	# A race adds another car to an older profile before pause Settings flushes it.
	check(records.save_vehicle_conditions(conditions, true) == OK, "queue all-car condition packet")
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	game.production_mode = true
	game.preference_records = records
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.toggle_pause(false)
	game.hud.pause_menu._settings()
	var page: SettingsPage = game.hud.pause_menu.settings_overlay.page
	page._show_section("camera")
	(page.find_child("Camera_follow_car", true, false) as Button).pressed.emit()
	check(page._apply(), "pause camera Apply succeeds with full condition collection")
	check(game.camera.mode == "follow_car" and game.paused and not game.hud.touch.enabled, "camera changes while race remains paused")
	check(records._condition_store.committed == conditions, "pending masks commit without dropping a car or changing masks")
	var sidecar: String = records._condition_store.path
	check(FileAccess.get_file_as_bytes(sidecar).size() > 131072, "fixture exercises the former 128 KiB limit")
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sidecar)) if FileAccess.file_exists(sidecar) else {}
	check(packet.get("conditions") == JSON.parse_string(JSON.stringify(conditions)), "sidecar retains every exact serialized condition")
	var reloaded := LocalRecords.new(records.path)
	reloaded.load_records()
	check(reloaded.settings.get("camera_mode") == "follow_car", "camera persists after reloading records")
	check(reloaded.records == expected_records and reloaded.settings.get("favorites") == ["ellipse"], "PB and unrelated preferences survive Apply")
	for frame: int in range(6): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/camera-save-fix-2026-11-09/pause-camera.png")) == OK, "capture applied pause camera")
	var state: Array = game.sim.state.snapshot()
	game.restart()
	check(game.camera.mode == "follow_car" and game.sim.state.snapshot() == state, "retry retains camera and canonical starting state")
	game.queue_free()
	records = null
	reloaded = null
	for frame: int in range(6): await process_frame
	var reopened := LocalRecords.new(directory.path_join("records.json"))
	reopened.load_records()
	check(reopened._condition_store.current == packet.get("conditions"), "fresh sidecar reader accepts complete all-car packet")
	check(reopened.settings.get("camera_mode") == "follow_car", "fresh reader retains camera preference")
	var oversized: String = directory.path_join("oversized.json")
	var file := FileAccess.open(oversized, FileAccess.WRITE)
	file.store_string(" ".repeat(preload("res://persistence/condition_store.gd").MAX_BYTES + 1))
	file.close()
	check(preload("res://persistence/condition_store.gd")._read(oversized).is_empty(), "oversized condition files remain rejected")
	print("CAMERA_CONDITION_CAPACITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

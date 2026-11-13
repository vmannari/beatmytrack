extends SceneTree
## Restoring an account must not read/compile an unrelated Guest creation first.
var checks: int = 0
var failures: int = 0

class CountingLibrary extends TrackLibrary:
	var reads: int = 0
	func load_document(id: String, summary: bool = false) -> Dictionary:
		reads += 1
		return super.load_document(id,summary)

class RestoredApp extends "res://core/app.gd":
	func _show_screen(next: String) -> void:
		super._show_screen(next)
		if next != "restoring" or startup_complete: return
		online.client._access_token = "loading-owner-fixture"
		online.client.player = {"id":"loading-owner-fixture","needs_username":true}
		_account_changed()

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SELECTED_OWNER_FAIL ",label)

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "user://selected-owner"
	var guest := LocalRecords.new(folder.path_join("records.json"))
	var guest_library := CountingLibrary.new(folder.path_join("tracks"))
	var guest_document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	check(guest_library.save_document(guest_document) == OK,"private Guest Star saved")
	guest_library.reads = 0
	guest.settings = {"music_enabled":false,"last_track":"creator_"+str(guest_document.id)}
	check(guest.save_records() == OK,"Guest preference saved")
	var directory: String = folder.path_join("players").path_join("/loading-owner-fixture".sha256_text())
	DirAccess.make_dir_recursive_absolute(directory)
	var owner := LocalRecords.new(directory.path_join("records.json"))
	var owner_library := TrackLibrary.new(directory.path_join("tracks"))
	var owner_document: Dictionary = TrackDocument.create_default()
	owner_document.id = "track_11111111111111111111111111111111"
	owner_document.name = "Owner selection"
	check(owner_library.save_document(owner_document) == OK,"private owner track saved")
	owner.settings = {"music_enabled":false,"last_track":"creator_"+str(owner_document.id)}
	check(owner.save_records() == OK,"owner preference saved")
	var guest_hash: String = FileAccess.get_sha256(guest_library.directory.path_join(str(guest_document.id)+".json"))
	var app := RestoredApp.new()
	app.records = guest
	app.library = guest_library
	app.cloud_root_override = folder.path_join("cloud")
	var began: int = Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._publishing_slots_foreground = false
	app._garage_preloader.set_process(false)
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var ready_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var guest_reads: int = guest_library.reads
	check(not app.online.configured,"fixture remains offline")
	check(guest_reads == 0,"restored startup never reads discarded Guest selection")
	check(app.records.path == owner.path and app.selected_track.identity == owner.settings.last_track,"restored owner retains exact last track")
	check(app.selected_track.content_hash != "" and not app.selected_track.metadata.get("metadata_only",false),"owner selection fully compiled before ready")
	# Switching back later still restores the Guest's real track through shipping code.
	app.online.client._access_token = ""
	app.online.client.player = {}
	app._account_changed()
	check(app.records == guest and guest_library.reads == 1,"sign-out reads Guest once")
	check(app.selected_track.identity == guest.settings.last_track and not app.selected_track.content_hash.is_empty(),"sign-out restores fully compiled Guest Star")
	check(FileAccess.get_sha256(guest_library.directory.path_join(str(guest_document.id)+".json")) == guest_hash,"Guest file remains byte exact")
	app.queue_free()
	for _i: int in range(8): await process_frame
	# An ordinary Guest launch still restores its selection before APP_READY.
	guest_library.reads = 0
	var ordinary: Node = load("res://core/app.gd").new()
	ordinary.records = guest
	ordinary.library = guest_library
	ordinary.cloud_root_override = folder.path_join("guest-cloud")
	root.add_child(ordinary)
	while not ordinary.startup_complete: await process_frame
	ordinary._publishing_slots_foreground = false
	ordinary._garage_preloader.set_process(false)
	check(guest_library.reads == 1 and ordinary.selected_track.identity == guest.settings.last_track,"Guest-only startup restores exact selection once")
	ordinary.queue_free()
	for _i: int in range(8): await process_frame
	var result: Dictionary = {"checks":checks,"failures":failures,"restored_ready_ms":ready_ms,"guest_reads_before_ready":guest_reads}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("SELECTED_OWNER ",JSON.stringify(result))
	quit(1 if failures else 0)

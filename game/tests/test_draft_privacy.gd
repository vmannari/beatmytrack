extends SceneTree

class FixtureApp extends "res://core/app.gd":
	func _ready() -> void: pass

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func choose(app: Node, id: String) -> void:
	app.online.client.player = {} if id.is_empty() else {"id":id,"display_name":id}
	app.online.client._access_token = "" if id.is_empty() else "fixture"
	app._select_player_storage()

func browser_for(app: Node, title: String) -> void:
	var shell := VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shell)
	shell.add_child(MenuStyle.label(title,32))
	var browser := preload("res://ui/draft_browser.gd").new()
	browser.library = app.library
	shell.add_child(browser)
	check(browser.entries.size() == 1 and browser.entries[0].document.creator == title,"draft browser shows only "+title+" work")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output: String = ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir().path_join("docs/evidence/draft-privacy-2026-10-06")
		DirAccess.make_dir_recursive_absolute(output)
		check(root.get_texture().get_image().save_png(output.path_join(title.to_lower()+".png")) == OK,"capture "+title)
	shell.queue_free()
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "user://draft_privacy_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder.path_join("tracks"))
	var app := FixtureApp.new()
	app.profile_root = folder
	app.guest_library = TrackLibrary.new(folder.path_join("tracks"))
	app.library = app.guest_library
	app.guest_records = LocalRecords.new(folder.path_join("records.json"))
	app.records = app.guest_records
	app.online = preload("res://backend/account_controller.gd").new()
	app.online.client._base_url = "http://privacy.invalid"
	root.add_child(app)
	var guest: Dictionary = TrackDocument.create_default()
	guest.id = "guest_private"
	guest["creator"] = "Guest"
	check(app.library.save_document(guest) == OK,"save Guest original: "+app.library.last_error)
	choose(app,"Alice")
	var alice: Dictionary = TrackDocument.create_default()
	alice.id = "alice_private"
	check(app.library.save_document(alice) == OK,"save Alice original")
	alice.name = "Alice autosave"
	check(app.library.save_wip(alice) == OK,"save Alice WIP")
	var alice_library: TrackLibrary = app.library
	app.document = alice.duplicate(true)
	choose(app,"Bob")
	check(app.document.is_empty() and app.library.editable_entries().is_empty(),"Bob inherits neither Alice editor nor Guest originals")
	check(app.library.load_document(alice.id).is_empty() and app.library.load_wip(alice.id).is_empty(),"Bob cannot load Alice original or WIP")
	check(app._legacy_track_directories() == [app.library.directory],"normal sync recovery stays in the active profile")
	var bob: Dictionary = TrackDocument.create_default()
	bob.id = "bob_private"
	check(app.library.save_document(bob) == OK,"save Bob original")
	# A stale selection must not resolve a private Guest document.
	app.records.settings.last_track = "creator_"+guest.id
	check(app.records.save_records() == OK,"save stale Guest selection")
	choose(app,"Alice")
	choose(app,"Bob")
	check(app.selected_track.content_hash == NativeTrack.read("res://resources/tracks/"+app.BUILTIN_IDS[0]+".json").content_hash,"selection restoration keeps the safe default instead of loading a Guest draft")
	await browser_for(app,"Bob")
	# Local publication snapshots are the only cross-profile local catalog source.
	var published: Dictionary = alice.duplicate(true)
	published.id = "alice_public"
	check(TrackLibrary.new(alice_library.directory.path_join(".published")).save_document(published) == OK,"seed local published snapshot")
	app._ensure_track_catalog()
	check(app.guest_library.directory not in app.track_catalog.shared_directories,"catalog never shares raw Guest storage")
	app.track_catalog.add_shared_tracks()
	check(app.track_catalog.entries.size() == 1 and app.track_catalog.entries[0].local_id == published.id,"Bob sees Alice publication, without Alice or Guest drafts")
	check(app.track_catalog.resolve(app.track_catalog.entries[0]) != null,"other profile publication remains playable")
	choose(app,"Alice")
	check(app.library.load_wip(alice.id).name == "Alice autosave","Alice recovers her own autosave")
	await browser_for(app,"Alice")
	choose(app,"")
	check(app.library == app.guest_library and not app.library.load_document(guest.id).is_empty(),"Guest retains original work after account switches")
	await browser_for(app,"Guest")
	app.online.client.free()
	app.online.free()
	app.free()
	print("DRAFT_PRIVACY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

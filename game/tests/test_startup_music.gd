extends SceneTree
## First decoder must use the selected profile's record, including restored accounts.
const Library = preload("res://soundtrack/record_library.gd")
var checks: int = 0
var failures: int = 0

class StartupApp extends "res://core/app.gd":
	var restoring_silent: bool = false
	var profile_silent: bool = false
	func _show_screen(next: String) -> void:
		super._show_screen(next)
		if next != "restoring" or startup_complete: return
		var music: GameSoundtrack = GameSoundtrack.instance()
		restoring_silent = not music.menu_player.has_stream_playback() and music.menu_target == 0.0
		# Select a fictional restored account through the shipping storage path.
		# No request/session file or owner profile is used.
		online.client._access_token = "startup-music-fixture"
		online.client.player = {"id":"startup-music-fixture","needs_username":true}
		_select_player_storage()
		profile_silent = not music.menu_player.has_stream_playback() and music.menu_target == 0.0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func reset_music(music: GameSoundtrack) -> void:
	music.menu_player.stop()
	music.menu_player.stream = Library.stream(Library.selected({}))
	music.menu_record = Library.DEFAULT_ID
	music._pending_record = null
	music._record_fade = 1.0
	music.mode = "silent"
	music.menu_gain = 0.0
	music.menu_target = 0.0
	music.bind_records(null)
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	create_timer(150).timeout.connect(func() -> void: printerr("FAIL: startup music deadline"); quit(1))
	var music: GameSoundtrack = GameSoundtrack.instance()
	for entry: Dictionary in Library.CATALOG:
		reset_music(music)
		music.apply_settings({"music_record":entry.id})
		music.show_menu()
		check(music.menu_player.stream.resource_path == entry.asset,"first stream is selected record: "+entry.id)
		check(music._pending_record == null,"startup does not queue a later replacement: "+entry.id)
		if music.output_enabled:
			check(music.menu_player.has_stream_playback(),"selected record starts immediately: "+entry.id)
			await create_timer(0.04).timeout
			check(music.menu_player.stream.resource_path == entry.asset,"first decoded frames retain selection: "+entry.id)
	reset_music(music)
	music.apply_settings({"music_record":Library.CATALOG[5].id,"music_enabled":false})
	music.show_menu()
	check(not music.menu_player.has_stream_playback() and music.menu_target == 0.0,"disabled startup creates no playback")
	reset_music(music)
	music.apply_settings({"music_record":"retired-record"})
	music.show_menu()
	check(music.menu_record == Library.DEFAULT_ID and music._pending_record == null,"invalid saved selection starts fallback directly")
	if music.output_enabled:
		await create_timer(0.3).timeout
		music.menu_player.seek(2.0)
		var cursor: float = music.menu_player.get_playback_position()
		music.show_menu()
		music.apply_settings({})
		check(music.menu_player.get_playback_position() >= cursor-0.05,"repeated menu/settings calls preserve playback cursor")
		music.apply_settings({"music_record":Library.CATALOG[2].id})
		check(music._pending_record != null,"changing an already playing record retains fade transition")
		music._process(0.2)
		check(music.menu_player.stream.resource_path == Library.CATALOG[2].asset,"manual transition installs requested record")
	reset_music(music)
	var folder: String = "user://startup_music_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var guest := LocalRecords.new(folder.path_join("records.json"))
	guest.settings = {"music_record":Library.CATALOG[1].id,"music_enabled":true}
	check(guest.save_records() == OK,"isolated guest fixture saves")
	var profile: String = folder.path_join("players").path_join("/startup-music-fixture".sha256_text())
	DirAccess.make_dir_recursive_absolute(profile)
	var account := LocalRecords.new(profile.path_join("records.json"))
	account.settings = {"music_record":Library.CATALOG[8].id,"music_enabled":true}
	check(account.save_records() == OK,"isolated account fixture saves")
	var app := StartupApp.new()
	app.records = guest
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(app.restoring_silent,"Guest record never starts on startup restoration screen")
	check(app.profile_silent,"restored account preferences are applied before playback")
	check(app.records.path == account.path,"shipping profile selection uses restored account fixture")
	check(music.menu_record == Library.CATALOG[8].id and music.menu_player.stream.resource_path == Library.CATALOG[8].asset,"first startup menu plays restored account record")
	check(music._pending_record == null,"startup menu has no delayed record replacement")
	if music.output_enabled: check(music.menu_player.has_stream_playback(),"startup menu plays music after restoration")
	# Let deferred menu/button and picture work settle before freeing the App.
	await create_timer(0.5).timeout
	app.queue_free()
	await process_frame
	music.menu_player.stop()
	if music.output_enabled: await create_timer(0.3).timeout
	print("STARTUP_MUSIC: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

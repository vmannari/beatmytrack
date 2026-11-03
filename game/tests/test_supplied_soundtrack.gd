extends SceneTree
const Library = preload("res://soundtrack/record_library.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var music: GameSoundtrack = GameSoundtrack.instance()
	var settings := {"music_record":"exploration", "music_volume":0.42, "music_enabled":true}
	check(Library.selected(settings).id == Library.DEFAULT_ID, "legacy selection falls back")
	var old := {"schema":2,"records":{},"settings":settings}
	var upgraded: Dictionary = preload("res://persistence/save_upgrades.gd").prepare(old)
	check(not upgraded.is_empty() and upgraded.settings.music_record == Library.DEFAULT_ID and upgraded.settings.music_volume == 0.42, "old saved selection migrates without changing volume")
	check(Library.CATALOG.size() == 14, "all fourteen supplied tracks")
	var covers: Array[PackedByteArray] = []
	var contact := Image.create_empty(7 * 256, 2 * 256, false, Image.FORMAT_RGBA8)
	var cover_index := 0
	for entry: Dictionary in Library.CATALOG:
		var stream: AudioStream = Library.stream(entry)
		check(stream is AudioStreamMP3 and stream.get_length() > 1.0 and not stream.loop, "playable complete MP3: " + entry.id)
		var picture: Image = Library.cover(entry.id).get_image()
		check(picture.get_size() == Vector2i(256,256) and picture.has_mipmaps() and not covers.has(picture.get_data()), "distinct cover: " + entry.id)
		covers.append(picture.get_data())
		picture.convert(Image.FORMAT_RGBA8)
		contact.blit_rect(picture, Rect2i(0,0,256,256), Vector2i((cover_index % 7) * 256, (cover_index / 7) * 256))
		cover_index += 1
	contact.save_png("res://../build/soundtrack-2026-test/covers.png")
	settings = upgraded.settings
	music.apply_settings(settings)
	music.show_menu()
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	music._menu_finished()
	check(music.menu_record == Library.CATALOG[1].id and settings.music_record == music.menu_record, "end advances current selection")
	music.menu_record = Library.CATALOG[-1].id
	music._menu_finished()
	check(music.menu_record == Library.DEFAULT_ID, "last recording wraps to first")
	music.music_enabled = false
	music._menu_finished()
	check(music.menu_record == Library.DEFAULT_ID, "paused player does not advance")
	music.apply_settings({"music_record":Library.CATALOG[4].id,"music_enabled":true})
	music._process(1.0)
	check(music.menu_record == Library.CATALOG[4].id and music.menu_player.stream.resource_path == Library.CATALOG[4].asset, "manual track selection switches stream")
	music.mode = "race"
	music._menu_finished()
	check(music.menu_record == Library.CATALOG[4].id, "race cannot advance menu playlist")
	var records := LocalRecords.new("user://soundtrack-test/records.json")
	DirAccess.make_dir_recursive_absolute("user://soundtrack-test")
	records.settings = {"music_record":Library.DEFAULT_ID,"music_enabled":true,"music_volume":0.6}
	music.bind_records(records)
	music.apply_settings(records.settings)
	music.show_menu()
	music._process(1.0)
	var menu = preload("res://ui/garage_records_menu.gd").new()
	menu.records = records
	root.add_child(menu)
	await process_frame
	menu._skip_record(1)
	music._process(1.0)
	check(records.settings.music_record == Library.CATALOG[1].id and music.menu_record == Library.CATALOG[1].id, "player skip selects and saves next recording")
	menu._select_record(5)
	music._process(1.0)
	check(records.settings.music_record == Library.CATALOG[5].id and music.menu_record == Library.CATALOG[5].id, "browsed sleeve plays selected recording")
	check(records.save_records() == OK, "unrelated save succeeds before automatic advance")
	music._menu_finished()
	check(records.settings.music_record == Library.CATALOG[6].id, "automatic advance updates current settings after unrelated save")
	check(menu.now_title.text == Library.CATALOG[6].title, "player reflects automatic advance")
	if music.output_enabled:
		music.menu_player.seek(maxf(0.0,music.menu_player.stream.get_length()-0.2))
		await create_timer(0.8).timeout
		check(music.menu_record == Library.CATALOG[7].id, "native end-of-track signal advances playlist")
		var recorder := AudioEffectRecord.new()
		var bus := AudioServer.get_bus_index("Music")
		var slot := AudioServer.get_bus_effect_count(bus)
		AudioServer.add_bus_effect(bus,recorder)
		recorder.set_recording_active(true)
		await create_timer(0.8).timeout
		recorder.set_recording_active(false)
		var sample := recorder.get_recording()
		var peak := 0
		for i: int in range(0,sample.data.size()-1,2): peak = maxi(peak,absi(sample.data.decode_s16(i)))
		AudioServer.remove_bus_effect(bus,slot)
		sample = null
		recorder = null
		check(peak > 0, "native music bus receives decoded soundtrack audio")
	menu.queue_free()
	await process_frame
	music.menu_player.stop()
	if music.output_enabled: await create_timer(0.3).timeout
	print("SOUNDTRACK: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

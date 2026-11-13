extends SceneTree
## Cold autoload and intermediate account selections must not load unused MP3s.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("AUDIO_LOADING_FAIL ",label)
func run() -> void:
	var music: Node = root.get_node("AudioWorld")
	var library: Script = load("res://soundtrack/record_library.gd")
	var original: Dictionary = library.entry(library.DEFAULT_ID)
	var guest: Dictionary = library.CATALOG[1]
	var owner: Dictionary = library.CATALOG[8]
	check(music.menu_player.stream == null,"silent autoload has no music stream")
	check(not ResourceLoader.has_cached(original.asset),"unused default MP3 remains unloaded")
	music.apply_settings({"music_record":guest.id,"music_enabled":true})
	check(music.menu_record == guest.id and music.menu_player.stream == null,"guest preference staged without opening a stream")
	music.apply_settings({"music_record":owner.id,"music_enabled":false})
	music.show_menu()
	check(not music.menu_player.has_stream_playback() and music.menu_player.stream == null,"disabled restored owner loads no music")
	check(not ResourceLoader.has_cached(guest.asset) and not ResourceLoader.has_cached(owner.asset),"intermediate and disabled recordings stay unloaded")
	music.apply_settings({"music_record":owner.id,"music_enabled":true})
	# Headless has no decoder; explicit menu presentation still resolves its resource.
	music.show_menu()
	check(music.menu_player.stream != null and music.menu_player.stream.resource_path == owner.asset,"enabled owner starts the exact saved recording")
	check(not ResourceLoader.has_cached(original.asset) and not ResourceLoader.has_cached(guest.asset),"starting owner never opens the previous default or guest recording")
	if DisplayServer.get_name() != "headless":
		check(music.menu_player.has_stream_playback(),"native owner decoder starts")
		await create_timer(0.05).timeout
	music.menu_player.stop()
	print("STARTUP_AUDIO_LOADING ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

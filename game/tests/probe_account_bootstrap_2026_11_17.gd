extends SceneTree
## Architecture sizing only: real existing account UI/controller, no App handoff.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var began: int = Time.get_ticks_usec()
	var records: RefCounted = load("res://persistence/local_records.gd").new("user://bootstrap-review/records.json")
	records.load_records()
	records.settings.music_enabled = false
	load("res://localization/language.gd").instance().configure("user://bootstrap-review/language.json")
	var music: Node = load("res://soundtrack/audio_world.gd").instance()
	music.bind_records(records); music.apply_settings(records.settings)
	var account: Node = load("res://backend/account_controller.gd").new()
	account.client.session_path = "user://bootstrap-review/account_session.cfg"
	root.add_child(account)
	assert(not account.configured)
	await account.start_session()
	var style: Script = load("res://ui/menu_style.gd")
	var surface := Control.new()
	style.fill(surface); surface.theme = style.theme(); root.add_child(surface)
	var background: Control = load("res://ui/account_backdrop.gd").new()
	style.fill(background); surface.add_child(background)
	var margin := MarginContainer.new()
	style.fill(margin)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,32 if side in ["left","right"] else 16)
	surface.add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	var panel: Control = load("res://ui/account_panel.gd").new()
	panel.account = account
	center.add_child(panel)
	music.show_menu()
	await process_frame
	await RenderingServer.frame_post_draw
	var drawn: int = Time.get_ticks_usec()
	var result: Dictionary = {"engine_to_first_draw_ms":drawn/1000.0,"bootstrap_ms":(drawn-began)/1000.0,
		"real_account_controller":account.get_script().resource_path,"real_panel":panel.get_script().resource_path,
		"network_disabled":not account.configured,"app_loaded":ResourceLoader.has_cached("res://core/app.gd"),
		"scope":"Account-only architecture sizing; navigation/account handoff and whole journey are not implemented or qualified"}
	assert(not result.app_loaded)
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("BOOTSTRAP_SIZING ",JSON.stringify(result))
	surface.queue_free(); account.queue_free(); music.queue_free()
	for frame: int in range(16): await process_frame
	quit()

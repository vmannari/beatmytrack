extends "res://tests/test_editor_t01_t04.gd"
## Reuse the real editor lifecycle and its original assertions, with fresh output.
var previous_frame: int = 0
var intervals: Array[float] = []

func observe() -> void:
	var now: int = Time.get_ticks_usec()
	if previous_frame > 0: intervals.append((now-previous_frame)/1000.0)
	previous_frame = now
	if is_instance_valid(app):
		app._publishing_slots_foreground = true
		if is_instance_valid(app._garage_preloader): app._garage_preloader.foreground = true
		if is_instance_valid(app.game) and app.game.paused: app.game.toggle_pause()

func show(doc: Dictionary) -> void:
	var began: int = Time.get_ticks_usec()
	intervals.clear(); previous_frame = began
	app.canvas = null; app.document = doc; app.editor_pending_tools.clear(); app.editor_view.clear(); app.history.clear(); app.redo_history.clear()
	await app._show_screen("create")
	await settle()
	record("editor_open",{"pieces":doc.pieces.size(),"objects":doc.objects.size(),"theme":doc.theme,"ready_ms":(Time.get_ticks_usec()-began)/1000.0,"frame":stats(intervals) if not intervals.is_empty() else {}})

func run() -> void:
	root.size = Vector2i(1280,720)
	out = OS.get_environment("BMT_GRAPHICS_OUTPUT")
	process_frame.connect(observe)
	await app_loop()
	record("complete",{"checks":checks,"failures":failures,"static_bytes":OS.get_static_memory_usage(),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()})
	quit(1 if failures else 0)

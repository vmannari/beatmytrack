extends "res://tests/test_editor_t01_t04.gd"
## Current production App path and original assertions; no frozen comparison build.
func run() -> void:
	root.size = Vector2i(1280,720)
	out = ProjectSettings.globalize_path("res://../docs/evidence/track-editor-review-2026-10-28/performance/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(out)
	await app_loop()
	record("complete",{"checks":checks,"failures":failures,"static_bytes":OS.get_static_memory_usage()})
	await create_timer(0.3).timeout
	print("TRACK_EDITOR_PROFILE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

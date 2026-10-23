extends "res://tests/test_editor_incremental_objects.gd"
## Keep the existing exact triangle/normal and native pixel assertions, focused
## on all-biome object assembly without unrelated changing application menus.
func run() -> void:
	root.size = Vector2i(1280,720)
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/track-object-optimization-2026-10-16/editor-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(evidence)
	for biome: String in TrackTheme.IDS: await compare_props(biome)
	print("PROP_OPTIMIZATION_EDITOR: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

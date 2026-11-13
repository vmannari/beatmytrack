extends "res://tests/test_scenery_mesh_lods.gd"
func run()->void:
	folder=ProjectSettings.globalize_path("res://../docs/evidence/asset-optimisation-2026-11-08/existing-scenery-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(folder)
	await structural()
	print("EXISTING_SCENERY ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

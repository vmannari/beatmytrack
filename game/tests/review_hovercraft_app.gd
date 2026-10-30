extends "res://tests/test_hovercraft.gd"
## Reuse the original actual-App selection/race assertions without dated physics goldens.
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	graphical = DisplayServer.get_name() != "headless"
	output = "res://../docs/evidence/hovercraft-model-rebuild-2026-10-28/app-"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _app(VehicleCatalog.config("hovercraft"))
	var file := FileAccess.open(output.path_join("native.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"garage_template_hits":preload("res://ui/garage_car_cache.gd").hits},"\t"))
	file.close()
	print("HOVERCRAFT_MODEL_APP: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

extends "res://tests/test_hovercraft.gd"
## Original real-App selection and race checks with a task-specific destination.
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	graphical = DisplayServer.get_name() != "headless"
	output = "res://../docs/evidence/hovercraft-sport-redesign-2026-10-29/app-"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _app(VehicleCatalog.config("hovercraft"))
	var file := FileAccess.open(output.path_join("native.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"garage_template_hits":preload("res://ui/garage_car_cache.gd").hits},"\t"))
	file.close()
	print("HOVERCRAFT_SPORT_APP: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

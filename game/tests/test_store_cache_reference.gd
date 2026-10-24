extends "res://tests/test_menu_medium_priority.gd"
## Run the existing Store cache/account-fence checks independently of Garage washing.
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	await test_store()
	print("STORE_CACHE_REFERENCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

extends "res://tests/test_store_first_entry.gd"
func _initialize() -> void:
	for pair: Array in [["res://backend/store_access_cache.gd","backend/store_access_cache.gd"],["res://ui/store_page.gd","ui/store_page.gd"]]:
		var original: GDScript = load(pair[0])
		original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/store-first-entry-2026-10-28/before/game/"+pair[1])
		assert(original.reload() == OK)
	run.call_deferred()

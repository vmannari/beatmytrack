extends "res://tests/test_dust_depth.gd"
## Re-run unchanged depth assertions with the exact task-start dust in memory.
func run() -> void:
	var source: GDScript = load("res://vehicle/sand_dust.gd")
	source.source_code = FileAccess.get_file_as_string("res://../docs/evidence/desert-rally-dust-2026-10-25/before/sand_dust.gd.txt")
	assert(source.reload() == OK)
	await super.run()

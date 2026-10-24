extends "res://tests/test_challenge_discovery.gd"

func run() -> void:
	# Replace only the resource in this isolated process. No workspace source is
	# swapped, and the original challenge fixture/assertions run unchanged.
	var adapter: GDScript = load("res://backend/discovery_windows.gd")
	var baseline: String = FileAccess.get_file_as_string("res://../docs/evidence/discovery-hardening-2026-10-23/before/game__backend__discovery_windows.gd")
	if baseline.is_empty(): quit(2); return
	adapter.source_code = baseline
	if adapter.reload() != OK: quit(3); return
	print("TASK_ORIGINAL_DISCOVERY_ADAPTER "+baseline.sha256_text())
	await super.run()

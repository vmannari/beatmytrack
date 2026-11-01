extends "res://tests/bake_racing_car_models.gd"
## The generic baker must retain, never silently regenerate, Forklift shadows.

func _initialize() -> void:
	var path: String = RacingCarModels.ASSET_ROOT.path_join("manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var checks: int = 0
	var failures: int = 0
	var original: Array = checked_forklift(manifest)
	checks += 1
	if original.size() != 5: failures += 1; print("FAIL: valid Forklift entry and resources")
	var absent: Dictionary = manifest.duplicate(true)
	absent.cars.erase("forklift")
	checks += 1
	if not checked_forklift(absent).is_empty(): failures += 1; print("FAIL: missing entry rejected")
	var incomplete: Dictionary = manifest.duplicate(true)
	incomplete.cars.forklift.pop_back()
	checks += 1
	if not checked_forklift(incomplete).is_empty(): failures += 1; print("FAIL: incomplete entry rejected")
	var inconsistent: Dictionary = manifest.duplicate(true)
	inconsistent.cars.forklift[0].triangles = int(inconsistent.cars.forklift[0].triangles)+1
	checks += 1
	if not checked_forklift(inconsistent).is_empty(): failures += 1; print("FAIL: incorrect mesh count rejected")
	var unordered: Dictionary = manifest.duplicate(true)
	unordered.cars.forklift[3].frame = 2
	checks += 1
	if not checked_forklift(unordered).is_empty(): failures += 1; print("FAIL: wrong articulation frame rejected")
	checks += 1
	if checked_forklift(manifest) != original: failures += 1; print("FAIL: control entry unchanged")
	checks += 1
	if needs_forklift_guard(true,false): failures += 1; print("FAIL: Compact-only bake must not require Forklift")
	checks += 1
	if not needs_forklift_guard(false,false): failures += 1; print("FAIL: full bake must protect Forklift")
	checks += 1
	if not needs_forklift_guard(true,true): failures += 1; print("FAIL: explicit verification must protect Forklift")
	print("FORKLIFT_BAKE_GUARD ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

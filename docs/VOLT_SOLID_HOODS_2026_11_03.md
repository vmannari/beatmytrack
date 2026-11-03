# Solid Volt hood alternatives — 2026-11-03

VSH01 removes all four optional hood vent treatments at the owner's request. Shoulder sculpt replaces Side vents; Triple contour replaces Triple vents; Touring sculpt replaces Track vents. Race channels keeps its name and loses its slots. All four use a continuous body-coloured skin with shallow formed contours. There are no vent floors, louvres or inset openings. The intentional Carbon centre insert is unchanged.

VSH02 preserves every saved/owned ID, category order, option count, factory hood, paint binding and handling. The IDs `volt_vent`, `volt_triple`, `volt_track` and `volt_race` remain valid. All four Electric category ID lists match the unchanged backend catalogue exactly. Display names and descriptions reflect the solid shapes; they retain the existing English fallback behavior.

[View the four replacements in blue and silver](evidence/volt-solid-hoods-2026-11-03/solid-hoods.jpg). Each desktop renderer has thirty native Garage images: Original plus four changed options, two colours and three angles. These are desktop Compatibility and Forward Mobile runs; no physical-device test was performed.

Runtime changes are limited to `game/vehicle/electric_kits.gd` and the Electric hood copy in `game/vehicle/vehicle_customisation.gd`. Removing vent generation and pocket displacement also removes the old dark materials from these choices. A new hood revision invalidates previous module/photo caches through the existing shared revision bindings. Four Volt base scenes, 120 full/simple modules and the Volt Garage rest scene are rebuilt to keep their shared-source provenance current.

Verification uses isolated repository test profiles, empty `BMT_API_URL`, the pinned Godot 4.7.2 console executable and `python scripts/run_no_crash_dialog.py --` for every engine launch:

- `res://tests/test_volt_solid_hoods.gd`: 84 checks, zero failures. Covers absent vent geometry, solid painted replacement surfaces, wording and byte-exact skin arrays for all eleven unchanged optional hoods in both model qualities.
- `res://tests/test_volt_hood_quality.gd`: 250 checks, zero failures. Retains paint coverage and colour changes, smooth normals, factory edge fit and the existing −20/+30 mm shape bounds.
- `res://tests/test_volt_kits.gd`: 610 checks, zero failures. All categories, distinct geometry, independent replacement and Original restoration remain covered. Its expected replacement skin name advances to V5; no requirement is relaxed.
- Prepared solid-hood admission checks: 84/0. Prepared paint/material checks: 160/0. Every optional full/simple hood is admitted through the actual module loader; all colour-binding checks pass. Logs are `test_volt_solid_hoods-prepared.log` and `test_volt_hood_quality-prepared.log` in the evidence directory.
- `capture_volt_hood_quality.gd` completes thirty native views and exits successfully on each desktop renderer. Its new optional `--options=` filter limits the review to these choices without changing the default all-option capture.

Commands use `--path game --audio-driver Dummy`. The three procedural checks add `--headless --script res://tests/<test>.gd`; prepared checks add `-- --prepared`. Asset preparation runs `bake_modular_car_bases.gd`, `bake_modular_car_kits.gd` and `bake_garage_cars.gd` with `--headless` and `-- --vehicle=electric`. Native captures use `--rendering-method gl_compatibility` or `mobile`, `--script res://tests/capture_volt_hood_quality.gd` and `-- --options=stock,volt_vent,volt_triple,volt_track,volt_race --output=res://../docs/evidence/volt-solid-hoods-2026-11-03/<renderer>`.

Windows emitted its existing certificate-store read error at startup; the retained logs distinguish it from the completed checks and process exit statuses. The evidence directory contains task-start sources/assets, source fingerprints, command logs, native images, catalogue comparison and the byte-checked task-only patch. Concurrent work and generated build identity remain preserved; the main Git index is untouched.

Reload and owner appearance acceptance remain. No device query/test, APK, real purchase, owner-save/process change, live/backend mutation or deployment was performed.

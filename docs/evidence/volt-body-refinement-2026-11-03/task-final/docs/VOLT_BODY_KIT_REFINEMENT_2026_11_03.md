# Volt body kit refinement — 3 November 2026

The fifteen optional body kits now cover the whole lower bumper, including its corners, and the sills between the wheel openings. The short open splitter, side strips and partial rear panel are replaced by formed shells with fitted backings and physical edge returns. Painted road packages and graphite competition packages use rounded, chamfered, split and swept sill sections, full-width front blades, rear valances, enclosed diffuser beds and two/four/six closed strakes.

[Before and after](evidence/volt-body-refinement-2026-11-03/before-after.jpg) · [All fifteen packages](evidence/volt-body-refinement-2026-11-03/all-body-kits.jpg) · [Full local review](evidence/volt-body-refinement-2026-11-03/review.html)

VBR01 covers complete bumper/sill/corner coverage and closed construction. VBR02 covers fitted transitions, finish and silhouette refinement. VBR03 refreshes prepared assets and photo/module identities. VBR04 preserves factory construction, all saved and owned IDs, independent kit selection and handling. Appearance remains subject to owner review; these desktop checks do not establish an objective “AAA” rating.

Runtime changes are `game/vehicle/electric_body_kits.gd` (new original procedural geometry), the body delegate in `game/vehicle/electric_kits.gd`, the Electric body revision in `game/vehicle/modular_car_kits.gd`, and the Electric photo revision in `game/ui/garage_preview_cache.gd`. Four Volt bases, 120 full/simple kit modules, the Volt Garage rest scene and the existing hood-bank source manifest are refreshed. All 62 hood mesh files are byte exact. The hood/aero source prefix, wheel builder, entire customisation catalogue and generated build identity are exact against task start; see `preservation.json` in the evidence directory. No source for the factory body, cabin, wheels, physics or other vehicles was edited.

Actual verification uses Godot 4.7.2, isolated repository APPDATA/LOCALAPPDATA, empty BMT_API_URL and `scripts/run_no_crash_dialog.py` for each automated engine launch. The reproducible wrapper is `python scripts/run_volt_body_refinement.py <log-name> res://tests/<script>.gd <engine flags> -- <script flags>`. Each log begins with its complete command and records its exit status. The wrapper rejects engine/script errors even when Godot exits with zero; the existing Windows root-certificate-store startup error is recorded separately.

| Check | Actual outcome |
| --- | --- |
| `test_volt_body_construction.gd --headless` | 8,162 checks, zero failures, both model qualities. Triangle rays cover both complete bumpers, both sills and all four corner returns. All 566 individual shells have paired geometric edges. Normals, triangle degeneracy and body budgets pass. |
| Same coverage test against archived original builder | 4,478 checks, 2,264 failures, demonstrating the old coverage/assembly defects. This expected failing control is retained. |
| `test_volt_kits.gd --headless` | 610 checks, zero failures; all category options, distinct geometry, replacement, simultaneous parts and Original restoration. |
| `test_volt_body_kit_wheel_fit.gd --headless` | 180 checks, zero failures, including steering, suspension and kerb poses. |
| `test_electric_wheel_clearance.gd --headless` | 79 checks, zero failures. |
| `test_volt_solid_hoods.gd --headless` | 84 checks, zero failures; previous solid-hood requirement remains. |
| `test_modular_car_assets.gd --headless -- --vehicle=electric --all-kits` | 1,788 checks, zero failures, including actual admission and source/prepared correspondence for all 120 modules, stock bases and race/ghost representations. |
| `test_volt_kits_garage.gd` | 54 checks, zero failures on each desktop renderer, including preview, fixture equip/save/reload, purchase cancellation, actual race and personal ghost construction. |
| `capture_volt_body_refinement.gd` | 105 final native images per desktop renderer: Original and all fifteen alternatives in silver, five representative finishes in blue, five angles. 55 task-start control images and intermediate captures are retained separately. |
| `scripts/volt_body_review.ps1` | 75 silver option/view comparisons all exceed the retained 1,500-pixel visibility gate; minimum 18,937 pixels with an RGB-channel change greater than 12. This measures visibility, not aesthetic quality. |

Prepared all-kit comparison is recorded in `prepared-all-kits.log`.

Asset preparation commands use the same wrapper with `--headless`: `bake_volt_hood_meshes.gd`; `bake_modular_car_bases.gd -- --vehicle=electric`; `bake_modular_car_kits.gd -- --vehicle=electric`; `bake_garage_cars.gd -- --vehicle=electric`. Native commands use `--rendering-method gl_compatibility` or `mobile`, and capture commands add `-- --output=res://../docs/evidence/volt-body-refinement-2026-11-03/<renderer>`. The review sheet uses the built-in Windows drawing library; initial missing Pillow diagnostics led to this dependency-free implementation, without installing a package.

Initial shell generation exposed zero-area end caps; the first construction fixture also had a typed-array assignment error. Later checks caught mismatched simplified edge samples and four float-collapsed inset-tip triangles. These were corrected in the geometry/fixture without reducing coverage or relaxing a gate. Intermediate seam, overlapping trailing-shoe and blunt sill-end views remain in `first`, `second` and `third`; the final trailing relief is formed into the sill itself. Earlier module bakes taken while geometry was changing were superseded by the complete final bake and its subsequent prepared comparison. An attempted read of task process command lines was denied by the sandbox; the bounded test runners finished normally, without modifying owner processes.

Closed construction adds geometry: original body kits had 4,000–5,584 full-detail triangles and 1,008–1,448 simple triangles. Revised body assemblies have 27,046–28,902 triangles in full detail and 8,052–8,660 in simple detail, within the explicit 30,000/9,000 body limits. These are geometry checks, not phone FPS or memory measurements. Conservative checkout source guards can make unrelated old prepared templates fall back to their existing procedural builders; their files and packaged revisions were preserved.

The evidence directory contains task-start sources/assets, final native views, actual commands, preservation measurements and a task-only binary-inclusive checkpoint. The main Git index is untouched. No device query/test, APK, real purchase, owner save/process change, live/backend mutation or deployment was performed. Reload the client to load the revised modules and invalidate old kit pictures. Owner appearance and device performance acceptance remain.

# Rally window proportions, 8 November 2026

RW01 lowers the shared door/quarter-window sill from 1.080 to 1.035 model metres. The visible glass starts at about 1.047 instead of 1.091 metres, occupying more of the flat cabin side. Both sides retain aligned lower and upper rails, separate pillars, trim, reflections and rounded corners.

RW02 gives the windshield a slightly wider, taller trapezoid, a lower cowl edge, tighter corner radii and an 8 mm cross-car crown instead of 18 mm. Its vertical generators remain straight. The rear hatch glazing keeps its prior shape. Body dimensions, paint, materials, physics and cameras are unchanged by the task's production source edits.

Production sources are `game/vehicle/compact_coachwork.gd` and `game/vehicle/compact_glazing.gd`. Four front glass/seal meshes in `compact_coachwork_v3` and `racing_simple_v1/compact` are rebuilt with `game/tests/bake_rally_glazing.gd`. `test_compact_joints.gd` now checks the exact authored front/rear crowns rather than a range tied to the old windshield. The standalone review checks the same straight-generator invariant, clearances, finite normals, aligned side apertures and unchanged rear shape.

Final native images: [front quarter](evidence/rally-windows-2026-11-08/accepted-mobile/simple-front-quarter.png), [side](evidence/rally-windows-2026-11-08/accepted-mobile/simple-side.png), [Compatibility front](evidence/rally-windows-2026-11-08/accepted-gl/standard-front.png). Before views and rejected intermediate captures are retained in the same evidence directory.

Actual checks:

- Accepted geometry: 47 checks, 0 failures headless; 55 checks, 0 failures in each of desktop Compatibility and Mobile, with eight captures per renderer across both model qualities.
- Driving contract: 72 checks, 0 failures. Pinned `scripts/dev.ps1 CheckScript` succeeds after its initial execution-policy/locked-asset attempts. The fallback runner uses the exact pinned Godot 4.7.2 build, private profiles, empty backend URL and Dummy audio.
- The initial broader Rally module suite reports 1269 checks, 1 failure: the existing fourth-module attachment counter. All reported shape/material comparisons pass. Its isolated rollback repeat reports 18 checks, 1 failure. The assertion is retained. Shared module source changed during this task, so no pre-existing-failure attribution is claimed.
- Initial global prepared preflight reports 468 resources / 1925 checks / 248 failures in Volt keys/sources. A subsequent Rally-only check first reports 35, then 167 stale-source failures as shared rebuilds overwrite outputs. Diagnostic output identifies changes to `modular_car_kits.gd` and the vehicle input-tree digest. These reports remain; no guard is bypassed.
- First five-picture bake rejects changing sources. The repeat renders all five pictures successfully, but its later provenance check detects a concurrently changed geometry revision. A coherent whole-project export is not established by those earlier runs.
- Final scoped rebuild/preflight passes all 84 Rally resources / 342 checks. Final five-picture bake and its provenance check pass: five exact native images and 155 current source hashes. The final global preflight still reports 249 failures in Volt keys/sources, so it is not a clean whole-project export qualification.
- Final exhaustive Rally module repeat remains 1269 checks / 1 attachment-counter failure, with no reported shape/material mismatch. This broader suite is not reported as passed.

The first wider windshield candidate passed the renderer/clearance checks but failed the newly added exact-crown check (47/1). The final width fits inside the cabin's flat front face and passes 47/0. A mistaken initial driving-script filename also failed before running any test; the actual `test_driving.gd` run passes 72/0. The platform's certificate-store diagnostic remains in logs.

Commands and exact outcomes are retained as `.log` and `.json` receipts under `docs/evidence/rally-windows-2026-11-08`. Entry points:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CheckScript -ScriptPath res://tests/review_rally_windows.gd
python docs/evidence/rally-windows-2026-11-08/run_check.py bake-glass-final res://tests/bake_rally_glazing.gd
python docs/evidence/rally-windows-2026-11-08/run_check.py shape-accepted res://tests/review_rally_windows.gd --phase=shape-accepted --prepared --validate
python docs/evidence/rally-windows-2026-11-08/run_check.py accepted-gl res://tests/review_rally_windows.gd --native --phase=accepted-gl --prepared --validate
python docs/evidence/rally-windows-2026-11-08/run_check.py accepted-mobile res://tests/review_rally_windows.gd --native --renderer mobile --phase=accepted-mobile --prepared --validate
python docs/evidence/rally-windows-2026-11-08/run_check.py driving-final res://tests/test_driving.gd
python docs/evidence/rally-windows-2026-11-08/refresh_prepared.py final
```

The refresh helper rebuilds only Rally's four bases, 78 fitted modules, Garage reference and header template. These derived files share the workspace with another active car-quality task. Source changes and the four front meshes are independently reviewable in the task checkpoint; generated identity and unrelated/concurrent changes are excluded. The main Git index is not written.

The task-only [patch](evidence/rally-windows-2026-11-08/task.patch) and [checkpoint receipt](evidence/rally-windows-2026-11-08/checkpoint.json) retain source hashes and a private Git round-trip check. Derived assemblies and shared picture provenance are excluded from that patch to avoid including the other task's model-policy changes.

Restart/reload and owner appearance acceptance remain. No device query or device test, APK/export/install, owner-save change, owner-process restart, live/backend operation or deployment was performed. Desktop Mobile rendering is not an Android device test.

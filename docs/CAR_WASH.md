# Persistent local car dirt and Garage washing

Owner request, 2026-10-11. Requirements: CW13 (persistent per-car dirt), CW14 (melting snow smears existing dirt), CW15 (manual Garage washing), CW16 (local storage only), plus V06/G01/R01/Q01 presentation, race and validation boundaries. This supersedes the former race-owned clean-on-retry/biome-change lifecycle in `VEHICLE_WEATHERING.md`.

Dirt now survives completed races, abandoned races, retry, track/biome changes, Garage paint resets, and application restarts. Each of the five cars has its own condition. Dirt colours blend as new material accumulates rather than replacing the previous coat; Winter snow is a separate overlay. Snow melts over up to eight seconds during the finish coast, in Garage, and while driving a non-Winter track. Melted snow smears existing dirt without adding dirt to a clean car. These are cosmetic presentation seconds; no wall clock or backend is involved.

Garage has a **Wash** action beside its existing view controls. Holding/dragging on the actual visible mesh progressively cleans a small patch, with a blue brush indicator. A quick swipe leaves dirt; modest repeated passes clean it. Older grime grows resistance over active dirty driving, capped at 40% more work after roughly fifteen minutes. Fully cleaned patches start soft again, while untouched dirt retains its age. One finger washes; two fingers rotate and pinch. A right mouse drag rotates, and existing wheel/buttons still zoom. **Done** returns to ordinary orbit. The player reaches other sides by rotating the car. Clicking empty background does not clean it; pressing Wash alone does not clean anything. Later driving gradually coats cleaned patches again. Washing is free and optional for racing and score eligibility.

## Local persistence and cost

`vehicle_conditions` is an additive, validated settings field in the existing atomic local-records schema 2. Entries use cosmetic version 1 and contain bounded dirt/snow/wetness/mud/smudge values, a colour and an exact 4,096-byte wash volume encoded in Base64. CW17–CW19 adds bounded slow dirt/snow, a second 4,096-byte wash volume and a small pending re-coating remainder. CW20–CW22 adds a 4,096-byte per-patch grime-age map and bounded ageing remainder; earlier eight/eleven/twelve-field entries remain valid and retain their exact wash masks, with zero new age. Final entries have fourteen fields. Five cars now use roughly 84 KB plus small scalar metadata. Existing saves lacking this optional field start clean; no player file is removed. Condition stays within the local guest/player profile. No new telemetry, request, backend endpoint, race-proof field, upload, ghost condition, reward, handling or score rule is introduced. See [rims and twenty-times-slower coating](RIM_SLOW_WEATHERING.md) and [gentle scrubbing](GENTLE_SCRUBBING.md) for exact rates, commands and captures.

The finish uses the existing opaque material and actual car geometry. The primary and slow 16-cubed wash volumes are each packed into a shared 256x16 R8 texture, with two interpolated slice reads each; there is no additional mesh/draw pass, screen read or runtime asset. Brush work visits only nearby voxels. Garage lazily caches model triangles for closest-hit ray picking, now including the rims. Local saves occur when a wash stroke ends, Done is pressed, snow finishes melting, Garage exits, a race finishes/retries/exits, or the app loses focus; active race checkpointing is every five seconds, active washing/melting every two seconds. Unchanged entries skip saves. Cached/outgoing Garage pages cannot overwrite newer race wear. Save failures retain unsaved presentation for retry and use the existing storage-error path.

Changed runtime files: `game/vehicle/vehicle_condition.gd` (+UID), `vehicle_weathering.gd`, `vehicle_weathering.gdshader`, `game/ui/car_showroom.gd`, `garage_page.gd`, `game/core/game.gd`, `app.gd` (generalized existing Garage save-error wording), and `game/persistence/local_records.gd`. Updated `game/tests/test_vehicle_weathering.gd` changes only the superseded clean-on-retry/biome assertions; explicit diagnostic resets, contacts, tick/FPS and canonical checks remain. Added `game/tests/test_car_wash.gd` (+UID). Documentation: this file, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and the weathering lifecycle follow-up.

## Actual commands and outcomes

All Godot commands use `scripts/dev.ps1` and the pinned `4.7.2.stable.official.ed1daf0bf`, not the old PATH alias:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_livery.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_view_controls.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRecords
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python build/checkpoint_car_wash.py
```

Final Compatibility and Mobile/Vulkan wash runs each pass **1,402 checks / zero failures**, covering all five independent saves, exact wash-mask/palette persistence, float recovery within 1e-9, local patch/opposite-side isolation, later re-coating, clean/dirty snow melting, actual Game retry/finish/exit and unchanged scored snapshots, mesh-hit mouse/touch washing, cancellation, original-paint revelation, cached-page fencing, paint-reset separation, and actual app action/input ownership at 960/1280/1600 widths. The original blue door pixel's blue channel rises from 0.0784 to 0.3373 on Compatibility and 0.1294 to 0.3451 on Mobile, with the brush hidden for that comparison.

Other actual passes: weathering **600**, Garage livery **115**, view controls **59**, records **54**, app **99**, all zero failures. The headless weathering test reports an ObjectDB shutdown warning (68 instances on the final run); it is recorded, not represented as a warning-free run. Initial direct PowerShell launch was blocked by execution policy; the process-scoped Bypass launcher resolves it. Restricted Godot import failed to read the Windows root certificate store; normal Windows tool access resolves it. Initial wash fixtures exposed ordinary JSON floating-point rounding (exact mask/palette assertions retained; scalar tolerance 1e-9), a missing Desert fixture theme, and a wrong red-channel expectation for washing the blue car. Corrected fixtures retain actual dirty-to-clean pixel and canonical assertions. No failed invariant was bypassed.

Inspected actual renders: [dirty car](evidence/car-wash-2026-10-11/garage-dirty.png), [partly washed](evidence/car-wash-2026-10-11/garage-partly-washed.png), [actual app at 960](evidence/car-wash-2026-10-11/garage-app-960.png), [1280](evidence/car-wash-2026-10-11/garage-app-1280.png), [1600](evidence/car-wash-2026-10-11/garage-app-1600.png), and equivalent Mobile/Vulkan captures under `evidence/car-wash-2026-10-11/mobile/`. Test saves and app captures use isolated local directories; no owner save or competitive result is written.

## Review and remaining acceptance

A task-only two-commit Git checkpoint lives in `build/car_wash/checkpoint-repo`, with `task-only.patch`, SHA256 ledger and actual logs in `docs/evidence/car-wash-2026-10-11/`. It preserves the main repository branch/index and unrelated pre-existing work.

Restart the local client to load the new behavior. Manual acceptance: finish/abandon on dirt, retry/change biome/car/restart the app, confirm each car's retained dirt; drive Winter after mud, confirm snow melts into smears; hold/drag to wash a patch, rotate with two fingers/right mouse, wash other sides, release/leave/reopen, then drive through dirt again. Confirm narrow-phone touch precision, the eight-second melt and brush size/speed are comfortable, and prolonged driving/washing remains smooth. The current implementation approximates smears and deposition cosmetically; it does not simulate fluid flow. A forced crash may lose at most the last periodic checkpoint interval. Phone performance and human visual/input acceptance remain open.

No physical-device test or phone-attachment check, Android export/install, full Validate, physics regression/merge, backend operation, production deployment or new asset generation was performed. Desktop Mobile/Vulkan is not a device-performance claim.

# Forklift racing shadows and wheel test — 31 October 2026

The simplified stock Forklift now uses five prepared shadow meshes: one for the sprung body and one for each rolling wheel. Its previous fallback rendered the ordinary simplified geometry into the shadow map. In the desktop fixture this changes **42 casters / 50,744 shadow triangles to 5 / 8,892**, while the visible geometry remains 50,744 triangles. This is a work-count comparison, not a measured FPS improvement.

The body proxy keeps 3,736 original triangles for the fork tines, overhead guard, mast and backrest, and combines them with a simplified remainder in one shadow mesh. The final body has 8,198 triangles; the four wheel proxies have 120, 132, 118 and 324. Each wheel proxy remains under its own rolling/steering frame. Editable Forklifts retain their ordinary casters while changing parts; a race car that starts with fitted parts also retains ordinary casters, so a stock proxy cannot omit a fitted silhouette. Vehicle physics, steering and visible model geometry are not changed.

The racing-model regression now checks four rolling wheels and two **rear** steering pivots for the Forklift. It also checks stock proxies, a fitted race car and an editable stock → fitted → stock sequence, including that the fitted hood casts a shadow and the original wheel pivots remain.

## Visual and repeatability evidence

The [Compatibility visual report](evidence/forklift-shadow-fix-2026-10-31/visual-report.json) compares the approved candidate against the procedural caster at 1280 × 720, with visible spot and directional lighting, shadow-disabled controls and repeated procedural captures. A thresholded comparison covers **98.39%, 99.16%, 97.28% and 99.12%** of the original shadow pixels in high, medium, low and steered views respectively. The low-angle silhouette retains small differences; the fork and guard remain visible. The report's exact threshold and precision are recorded with the measurements. These are desktop Compatibility observations, not phone performance or universal pixel equivalence.

Inspect the [medium procedural shadow](evidence/forklift-shadow-fix-2026-10-31/medium-shadow-procedural.png) and [medium proxy shadow](evidence/forklift-shadow-fix-2026-10-31/medium-shadow-proxy.png), or the [low procedural shadow](evidence/forklift-shadow-fix-2026-10-31/low-shadow-procedural.png) and [low proxy shadow](evidence/forklift-shadow-fix-2026-10-31/low-shadow-proxy.png). The promoted body mesh's complete arrays and bounding box matched the approved scratch candidate. The final baker was run twice; the five resources and manifest were byte-identical between successful runs. Removing only the new Forklift manifest entry reconstructs the pre-task manifest SHA-256 `2C5EF8B9E8D660254951A73FF8983EF42ADDE25AEF63CCFB1BFD813A8A8E1D38` exactly, preserving the concurrent Electric entry.

A desktop Mobile/Vulkan capture attempt stalled during startup and was stopped; it is inconclusive. No Android device test or phone performance measurement was performed. Owner appearance acceptance remains.

## Commands and checks

Use the pinned Godot build, an isolated offline profile and the process-scoped crash-dialog wrapper for each noninteractive command. From the repository root, for example:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/forklift-shadow-offline-user'
$env:BMT_API_URL = ''
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/bake_forklift_racing_shadows.gd
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/test_forklift_bake_guard.gd
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --audio-driver Dummy --script res://tests/bake_racing_car_models.gd -- --verify-forklift-only
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/capture_forklift_shadow_proxy.gd -- --output=res://../build/forklift-shadow-offline-capture
```

The dedicated baker writes only the five Forklift shadow resources and its manifest entry. Its `--candidate=<res-path>` option instead writes a scratch body candidate without updating the manifest. After model or shadow changes, regenerate the shared build identity and modular car assets using the documented modular-asset workflow; their source revision intentionally includes these resources. The generic racing-model baker preserves the Forklift resources and manifest entry during a full bake, rejects missing or inconsistent Forklift data, and directs regeneration to the dedicated baker. Compact-front-only mode does not require Forklift data. The read-only generic guard and malformed-entry regression passed, the latter **9 checks / 0 failures**.

Final integrated checks passed: racing-model **101/0**, the Forklift modular regression including all kit choices **538/0**, Forklift kits **96/0**, and the generic-baker guard **9/0**. A prior personal-ghost run passed **38/0**. The rebuilt modular assets' source revisions matched before and after the final bake for all eight IDs. Offline Windows Godot runs emitted the root-certificate-store diagnostic. One earlier bake saw a transient concurrent translation-file parse error; a repeated bake completed without it. The initial over-simplified candidate and early fixture attempts remain in `build/forklift-shadow-review/`; they are not treated as the approved final shadow.

The isolated Android Debug export-pack audit found all 20 prepared car bases, 242 kit scenes and five Forklift shadow meshes, each byte-identical to the workspace. It does not establish Android runtime or performance behavior.

Concurrent Electric asset generation initially invalidated the conservative shared modular revision. The build-identity routing now treats the verified Electric-only fender and shadow resources as Electric inputs and excludes the shadow manifest from modular revisions because it is offline provenance. Unknown assets and model scripts remain shared. `scripts/test_modular_car_identity.ps1` exercises the routing and the complete build identity in an isolated fixture.

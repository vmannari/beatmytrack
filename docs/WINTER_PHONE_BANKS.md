# Winter phone bank artifacts — 2026-10-13

Requirements WPB01/V04/V05/G01/R01/Q01: investigate owner-reported strange snowbanks and clipped terrain on Android.

Found an actual missing material binding: smooth winter banks call `winter_wear_width`
and `shoulder_fringe`, which sample `surface_factors`, but their material only bound
snow and ice artwork. Both winter bank constructors also bypassed the earlier biome
sampler specialization. Bind the existing shared texture set and specialize both bank
materials; retain snow/ice flags so active artwork is never aliased away. Bank geometry,
mask/discard rules, camera, canonical driving/scoring and local cosmetics are unchanged.

Changed files: `game/track/native_track_visual.gd` and
`game/tests/test_terrain_sampler_budget.gd`. The fixture now explicitly checks actual
bank bindings and specialization. Cache invalidation was bumped 177→178; another
concurrent workspace task subsequently bumped it to 179, retained without rollback.

Actual commands, through pinned `scripts/dev.ps1` with PowerShell execution-policy bypass:

- `TestScript -ScriptPath res://tests/test_terrain_sampler_budget.gd -Graphical`: 60 checks, zero failures, all five biome shaders rendered.
- `TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical`: 99 checks, zero failures.
- Same with correctly passed PowerShell array `-TestArgument @('--capture','--fresh-roads','--bank-detail','--output-dir=res://../docs/evidence/phone-terrain-2026-10-13/desktop')`: 100 checks, zero failures; actual fresh-road close-up/gameplay captures inspected.
- `TestRoadCache`: 70 checks, zero failures, exact disk-loaded meshes/materials/masks.
- `ExportAndroid -QuickValidation -CommandTimeoutSeconds 600`: import/APP_READY/driving72/catalog21/menus48 pass; fresh APK exported.
- `InstallAndroid -DeviceSerial PRQKU4U4PREQNRWG`: streamed install Success, existing app data preserved.
- `LaunchAndroid -DeviceSerial PRQKU4U4PREQNRWG`: COLD Status ok, TotalTime895ms, actual phone APP_READY.
- `git diff --check` passed (CRLF notice only). Scoped patch reverse-check passed with `--ignore-space-change` after accounting for concurrent kit179. Original reverse checks recorded failures due to line endings/concurrent version change.

Initial capture argument invocation did not enable captures; a later `-File` invocation
with a leading `--capture` value failed argument parsing. The explicit `-Command` array
invocation above produced the actual captures. Planned captures are not counted as evidence.

Actual OnePlus DN2103/Mali-G77 MC9/OpenGL ES3.2 device check: initial result screen
captured; subsequent early screenshots were black. Following installation, entered
Guest→Free Race→Slippery without signing in or backend race writes. Captured the start
view and a second view after a two-second gas press on the bridge. Both show textured
snowbanks/terrain; no terrain holes are visible in these two views, and Godot logs show
APP_READY/PLAYGROUND_READY with no shader errors. Paused the unfinished local attempt.
This is a short physical rendering check, **not** a full lap/all-track clipping or device
performance acceptance. The separately reported clipping cause remains unconfirmed;
owner location/reproduction review remains necessary. No claim that all artifacts are fixed.

Installed APK SHA256 (read directly after install):
`0f8bad6339bfb0c384b9a1c20712035e22c92392dcd343193074ad828649d176`.
Shared APK path is `build/android/circuit01-debug.apk`; concurrent builds may replace it.

Evidence: `docs/evidence/phone-terrain-2026-10-13/` contains phone before/start/moved
captures, actual startup log, desktop close-ups and scoped task.patch. Isolated reviewable
Git checkpoint `build/phone-terrain-2026-10-13/checkpoint-repo`, commit
`22a86e231ce54ccc2e3a4e4111845549e2f41300`; main index/HEAD and unrelated edits preserved.
No full physics regression/production deployment/backend changes performed.

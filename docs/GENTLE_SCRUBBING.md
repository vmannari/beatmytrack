# Modest scrubbing and gently ageing grime

Owner request, 2026-10-11. CW20 requires several modest passes rather than a one-swipe clean. CW21 adds a little more work for long-unwashed dirt, without becoming annoying. CW22 preserves local per-car dirt/washing persistence and the existing body/rim/slow-coat behavior, with G01/R01/V06/Q01 boundaries.

The base brush rate falls from 3.0 to **0.85 normalized clean units per second** at its centre. Its existing 0.48-metre soft radial falloff is retained. A 0.2-second quick pass can remove at most about 17% of the dirt at a directly covered voxel, less toward the edge. Repeated passes or a short hold progressively finish a patch. Existing one-finger/left-mouse washing, two-finger/right-mouse orbit, zoom and Done controls remain.

Old grime adds **at most 40% more work** at the same brush location. Each existing wash-volume voxel has a bounded age byte; visible/potential dirt ages while driving with dirt, reaching its cap after about fifteen minutes of active use. Pause/countdown and time with the app closed do not age it. This deliberately keeps returning players from facing an offline-time penalty. Age persists across races and app restarts. Once both dirt layers are fully cleaned at a voxel, its age resets to zero; cleaning one patch does not soften untouched old dirt elsewhere. Values are local tuning defaults awaiting owner feel acceptance.

The previous code rounded every small brush sample upward, so fast interpolated swipes could accumulate excessive cleaning. Fractional byte progress is now retained separately for the primary and slow masks, then committed only when a full byte is earned. One pass split into 100 small samples gives the same visual mask as the unsplit pass in the all-car fixture. The unsaved fractional remainder is less than one byte; exact visible R8 wash progress remains persisted.

## Files, persistence and cost

- `game/vehicle/vehicle_weathering.gd`: modest rate, bounded per-patch resistance/age, fractional scrub progress and age reset on full cleaning. Main dirt/slow dirt/rim/snow deposition, twenty-times-slower exposure and melting rules are retained.
- `game/vehicle/vehicle_condition.gd`: two optional version-1 fields, `grime_age` (exact 4,096-byte Base64 map) and `grime_elapsed` (bounded age-step remainder). Eight/eleven/twelve-field entries remain valid; fourteen-field entries are validated. Existing masks/palette remain exact and old entries start gently with no invented age. Local-records schema stays 2; no deletion or network write.
- `game/tests/test_gentle_scrubbing.gd` / `.uid`: actual all-car first-pass work, sample splitting, fresh/aged effort cap, comfortable completion, patch-specific reset, atomic reboot persistence, legacy upgrade and pause/age bounds; native actual-model views.
- `game/tests/test_rim_slow_weathering.gd`: its legacy fixture removes the two new optional fields along with previous optional slow fields to continue testing the original eight-field format; all prior assertions remain.
- Status/plan, `docs/CAR_WASH.md` and this document record actual results. No shader, geometry, camera, UI labels/actions, handling, scoring or backend change.

Age visits the bounded 4,096-cell map approximately every 3.53 seconds of active dirty driving. It stays CPU-side: no new texture or fragment lookup. Per-active-car working memory adds a 4 KB age map and two 16 KB fractional buffers; persisted data adds about 28 KB across all five cars (roughly 84 KB total condition payload including previous masks and small metadata). Existing body/wheel wash coordinates and mask dimensions are retained. Save cadence/error handling stays unchanged.

## Actual verification

All engine commands use pinned `4.7.2.stable.official.ed1daf0bf` via the launcher, isolated test records and disabled backend access:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_gentle_scrubbing.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_gentle_scrubbing.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_gentle_scrubbing.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rim_slow_weathering.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRecords
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python build/checkpoint_gentle_scrubbing.py
```

Final native Compatibility and Mobile/Vulkan focused runs pass **223 checks / 0 failures** each. Existing wash regression passes 1,383 headless checks; rims/slow coat 195; records 54; app 99. Exact byte-mask/palette/age persistence and previous legacy/gesture/score boundaries remain. Initial focused run found the 900-second ageing boundary one byte short because of floating-point accumulation; a tiny interval-comparison tolerance fixes the implementation, retaining the exact cap assertion. The first existing-wash launch encountered a concurrently added Winter texture missing its import cache; Import resolved it. No failing assertion was removed or weakened.

Actual views: [fresh dirt after one pass](evidence/gentle-scrubbing-2026-10-11/fresh-one-pass.png), [fresh after five passes](evidence/gentle-scrubbing-2026-10-11/fresh-five-passes.png), [aged after five passes](evidence/gentle-scrubbing-2026-10-11/aged-five-passes.png), [aged patch finished](evidence/gentle-scrubbing-2026-10-11/aged-finished.png), and desktop Mobile/Vulkan equivalents. They use the actual Garage picker/model and repeated controlled 0.2-second brush doses, not a completed race or physical-device recording. Adjacent dirt remains intact after washing the central patch.

## Remaining acceptance and checkpoint

The task-only checkpoint under `build/gentle_scrubbing/checkpoint-repo` preserves the main index/branch and unrelated work. Patch/hashes/logs are beside the evidence. **No phone test or attachment check, Android export/install, full Validate, physics regression/merge, backend operation, deployment or asset generation.** Owner acceptance of the base rate and 40% cap, touch precision, whole-car cleaning comfort and phone performance remain. Manual acceptance: make a quick swipe, repeat a few passes on the same patch, compare old grime with fresh dirt, clean a patch fully and re-dirty it, then restart and verify retained ageing/progress. Washing remains optional and free, with no race/score gate.

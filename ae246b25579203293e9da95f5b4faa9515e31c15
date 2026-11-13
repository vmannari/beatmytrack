# Volt Night glass correction — 2026-11-06

The owner supplied a screenshot showing the pale roof after the preceding investigation. This task implements the correction. The Volt's panoramic roof, windshield and rear glass now use a dark blue-grey analytic reflection in Night. Daylight and studio defaults remain in the shader; the Night branch does not reflect the bright daytime sky/cloud palette.

## Implementation

- **VNF01 — correct the material in actual races.** `game/vehicle/electric_glass.gdshader` adds a default-off Night context. `game/race/electric_glass_lighting.gd` creates private material copies for the Volt, preserving material sharing within that car and leaving shared source materials untouched. `game/core/game.gd` applies the context after model preparation and when the biome changes. Studio mode takes precedence. The shared Hovercraft shader retains its existing default.
- **VNF02 — preserve ownership and transitions.** Daytime does not allocate copies. Repeated Night configuration reuses bindings. Returning to daytime restores exact original overrides, including null per-surface overrides. Weak mesh references tolerate teardown; reset does not overwrite a material replaced by another owner. The canonical simulation, physics, paint and lighting are not changed.
- **VNF03 — refresh and verify production assets.** Rebuild the affected Volt/Hover bases, kit modules and Garage templates using the existing bakers and dependency guards; refresh native thumbnail provenance and run the complete asset preflight. No dependency check is bypassed.
- **VNF04 — native acceptance evidence.** The focused fixture checks procedural/prepared and full/simple Volt construction, material ownership, separate cars, repeat calls, restoration, replacement and teardown. Native runs use production Game scenes with blue paint, capture ordinary race framing and four close-view headings, and compare current glass with the archived original shader on the same car. Roof-only black/white controls isolate the visible pixels. Day and studio old/new frames must remain exact; track and simulation state must remain exact.

## Validation

The final Compatibility run passes **290 checks, 0 failures**. The final desktop Mobile run records **290 checks, 1 retained full-frame restoration-control failure**. All eight Night roof views per renderer, exact roof restoration, car/material ownership, prepared hits, daytime/studio source comparisons, and track/simulation checks pass. The full-frame mismatch is not counted as a pass or removed from the fixture.

In Compatibility, the isolated roof mean falls from **60.29–60.91 to 13.32–13.33** on a 0–255 RGB-channel scale across full/simple models and four headings: roughly 78% darker. There are 58 native captures per final renderer, including diagnostic preparation controls, for 116 total. The same blue body paint is used for before and after.

- [Before, matching the supplied pale-roof appearance](evidence/volt-night-roof-fix-2026-11-06/accepted-compatibility/full-heading-270-before.png)
- [Corrected dark glass](evidence/volt-night-roof-fix-2026-11-06/accepted-compatibility/full-heading-270-after.png)
- [Corrected ordinary race framing](evidence/volt-night-roof-fix-2026-11-06/accepted-compatibility/full-race-after.png)
- [Desktop Mobile corrected glass](evidence/volt-night-roof-fix-2026-11-06/final-mobile-limited/full-heading-270-after.png)

The existing bakers regenerate eight full/simple editable/fixed bases, 120 Volt and 80 Hover kit modules, and two Garage templates. Independent preflight passes **468 resources / 1,925 checks / 0 failures**, and all five active native preview pictures/provenance pass. All five active pictures remain byte-exact to the task-start images; three dormant archived pictures are also unchanged. The 211 changed asset files are 210 prepared scenes and the provenance manifest. No other car's geometry scenes were rebuilt.

The [summary](evidence/volt-night-roof-fix-2026-11-06/summary.json), individual process receipts and pixel reports retain actual outcomes. The [task-only source/binary patch](evidence/volt-night-roof-fix-2026-11-06/task.patch) is verified forward/reverse with byte-exact content in private Git repositories; the [checkpoint receipt](evidence/volt-night-roof-fix-2026-11-06/checkpoint.json) lists its files. The three runtime changes are the shader, the new race material helper and three narrow Game insertions. Tests, evidence helpers and project summaries accompany them.

## Commands and artifacts

```powershell
python docs/evidence/volt-night-roof-fix-2026-11-06/run_check.py initial-parse res://tests/test_volt_night_glass.gd --dev
python docs/evidence/volt-night-roof-fix-2026-11-06/run_check.py before-bakes res://tests/test_volt_night_glass.gd
python docs/evidence/volt-night-roof-fix-2026-11-06/prepare_assets.py
python docs/evidence/volt-night-roof-fix-2026-11-06/prepare_assets.py --resume
python docs/evidence/volt-night-roof-fix-2026-11-06/run_check.py accepted-compatibility res://tests/test_volt_night_glass.gd --native
python docs/evidence/volt-night-roof-fix-2026-11-06/run_check.py final-mobile-limited res://tests/test_volt_night_glass.gd --native --renderer mobile
python docs/evidence/volt-night-roof-fix-2026-11-06/run_check.py original-mobile-control-v2 res://tests/test_volt_night_glass.gd --native --renderer mobile --original-glass
python docs/evidence/volt-night-roof-fix-2026-11-06/update_trackers.py
python docs/evidence/volt-night-roof-fix-2026-11-06/checkpoint.py
```

The first command uses the pinned `scripts/dev.ps1` entry point, which refreshes generated client identity. Later checks use the same pinned engine through the project's crash-dialog wrapper, private APPDATA/LOCALAPPDATA, Dummy audio and empty backend URL. Each completed run retains its command, exit code, script errors and source hashes. The asset helper archives all replaced files before writing and scopes geometry baking to the shader's two existing consumers.

Initial findings are retained: the sandboxed `dev.ps1` launch returned Access denied after starting Godot. The direct Dummy-audio run completed 116 checks with two expected failures because prepared Volt bases still held the old shader dependency; the remaining material/lifecycle checks passed. No assertion was weakened to accept stale assets.

The first Volt kit runner reached its 300-second bound while its builder continued. The exact task-owned wrapper/child command was identified; a first identity check rejected a Windows path-separator mismatch without acting on any process. The corrected wait observed completion, and the log contains all 120 module receipts and its final count. An exit code could not be recovered from the attached wrapper handle, so the original timeout receipt remains failed. Completed outputs were accepted only after the independent full asset preflight; the resumed helper did not rewrite them or repeat the long build. Future bake stages use a 900-second bound, and timeout cleanup results are now recorded.

The initial Compatibility image fixture passed all eight Night roof tests but failed its two full-detail day/studio whole-frame equality checks. Both were the same one-pixel glass/body boundary, black versus blue, caused by comparing different shader/material identities. Repeating the source comparison on a single shader RID with stable material bindings retained the exact-pixel requirement and passed all 218 checks. The original source, images and diagnostic remain archived.

Two initial Mobile runs passed the roof, daytime and studio checks but each retained one full-frame restoration failure at the first full-detail heading. The diagnostic found 845 changed world pixels, maximum 7/255 and mean 0.001122/255. The fixture added the existing project's exact-image pipeline-settling procedure (`test_editor_preparation.gd`): draw both frames per round and require four quiet rounds of specialization/surface/draw counters within 30 rounds. Separately pre-rendering mask controls was also tested. Neither step removed the mismatch, so the final failure remains reported; no numerical threshold or equality assertion was relaxed.

An explicit original-shader control uses the archived shader code only inside its test process. It records **290 checks / 9 failures**: the eight expected pale-roof rejections plus the same whole-frame restoration assertion. The **final** candidate and original control each change exactly three non-roof pixels at `(493,456)`, `(686,504)` and `(649,549)`, with identical before/after colours. Maximum channel difference is 7/255 and whole-frame mean is 0.000006149/255. The larger 845-pixel discrepancy belongs to earlier fixture runs. The final pixel diagnostics establish a matched original-control limitation, without proving its engine-level cause; the equality assertion still reports failure. All sampled roof pixels restore exactly in both versions. The first control invocation had a GDScript constant-assignment parse error; an ordinary local Shader reference corrected the fixture, and that failed launch is retained.

Initial native logs also retain intermittent two-object/one-resource shutdown warnings; no blanket clean-log claim is made. The environment's certificate-store error is retained separately from script/shader failures. A first Python pixel-inspection attempt found Pillow unavailable, so the checked-in Godot image diagnostic performs the measurements without adding a dependency.

## Delivery limits

The fix is local and requires a newly loaded game instance. No running owner game was restarted. No device query/test, APK, owner-save change, live/backend request or deployment was performed. Desktop rendering is not physical-device acceptance; the owner still needs to review the corrected appearance on their device.

Concurrent source changes and generated build metadata are excluded from the task-only checkpoint. Historical investigation evidence remains intact.

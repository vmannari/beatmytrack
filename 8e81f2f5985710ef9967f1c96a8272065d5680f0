# Garage paint sweep — 2026-10-26

Garage colour changes, pattern previews, direct pattern selection and Reset now reveal the new paint from the physical rear (+Z) toward the nose (-Z). The 0.72-second sine easing blends a soft edge with a restrained moving highlight. It stays attached to the body while orbiting. Equipped comparison and authoritative appearance restoration stay immediate.

[Watch the captured Garage transition](evidence/garage-paint-transition-2026-10-26/paint-sweep.png), [review native frames](evidence/garage-paint-transition-2026-10-26/review.html), or [inspect the commands, hashes and results](evidence/garage-paint-transition-2026-10-26/report.json).

| Requirement | Result |
| --- | --- |
| GPT01 | Rear-to-front transition for colour and pattern changes, including unsaved/unowned previews. |
| GPT02 | Opaque original-surface rendering, existing model/world/camera, native finishes, stickers, local dirt/wash masks and live reflections. |
| GPT03 | Existing ownership, explicit Buy & Equip, local save, account, selection, navigation and compare fences. |
| R01 | Independent native pixel direction and endpoint checks on all seven cars, weathered/sticker case, lifecycle and existing configurator/paint-list regressions. |
| Q01 | Native progress frames and animated review, actual commands, scoped checkpoint and explicit device limits. |

Runtime changes are limited to `game/ui/garage_paint_transition.gd`, `game/ui/car_showroom.gd` and `game/ui/garage_page.gd`. The helper temporarily duplicates only paint finishes. It reuses the existing livery/sticker projection and blends pigments before the existing dirt shader, with the current car-body transforms. It preserves disabled toon specular, ink passes and material priority. No new model, viewport or transparent overlay is created. Completion restores the exact target materials and retained rendering; hide, detach, car/part replacement and wash entry clear the temporary effect.

Browsing another pattern retains the currently shown target instead of flashing equipped paint between previews. Equipping an already previewed pattern keeps that appearance. Rapid changes finish the preceding visual target and start the newest sweep, with no deferred appearance write or unbounded transition history. Continuous colour-picker dragging therefore may advance through intermediate visual targets; final owner motion acceptance remains open.

The new test is `game/tests/test_garage_paint_transition.gd`. It checks logical preview/save boundaries, rapid selection, exact momentary comparison, navigation cancellation, natural completion, active car/reflection redraw, return to idle, hide/free cleanup and bounded shader variants. Native comparisons require changed paint at both physical ends, at least 90% correct old/new classification away from the feather, and at most 12 endpoint pixels beyond the unchanged 0.04 RGB-distance tolerance. All seven cars achieve 100% classification in the retained end regions. A separate wet, lightly dirty, stickered Compact checks the decorated and weathering shader paths and exact condition data.

Actual final results:

- Focused transition: **72 headless**, **156 Compatibility**, **156 desktop Mobile/Vulkan**, zero failures.
- Existing configurator: **647 Compatibility**, zero failures, including native App behavior.
- Existing paint list: **151 headless**, **192 Compatibility**, zero failures, including account/compare/purchase fences and actual App captures at 960×540, 1280×720 and 1720×900.
- Full script parser: **1259 scripts**, zero failures. Pinned import result and exact command outcomes are recorded in the report.

The first native implementation produced **116 checks / 5 failures**, retained under `initial/first-native`. Plain toon finishes needed their disabled specular mode and ink next pass; body transforms cached before pedestal reparenting also produced incorrect longitudinal mapping. These production defects were fixed without weakening the direction or endpoint assertions. Later tests add completion, reflections, idle and weather/sticker coverage. The initial restricted headless run stalled at a Windows certificate-store read; its log is retained under `initial/restricted-headless`. Only this task's exact test process was stopped. Final checks use isolated repository-owned APPDATA and normal Windows runtime access.

Commands run through the pinned `scripts/dev.ps1` entry point via the task's isolated runner:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-transition-2026-10-26/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-transition-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-transition-2026-10-26/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-transition-2026-10-26/run.ps1 -Test test_customisation_carousel -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-transition-2026-10-26/run.ps1 -Test test_garage_paint_list
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-transition-2026-10-26/run.ps1 -Test test_garage_paint_list -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-transition-2026-10-26/run.ps1 -Test test_script_parse
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-transition-2026-10-26/run.ps1 -Import
python docs/evidence/garage-paint-transition-2026-10-26/record.py
```

The animation replays actual native progress captures with the effect's sine timing and endpoint holds. All-car side views are isolated renderer diagnostics; actual App views are retained by the existing paint-list suite. `task-only.patch` is checked in reverse against current sources; the original two modified runtime files are retained under `before/`. Concurrent changes remain preserved outside the scoped patch.

Reload the project/application to see the change. Owner appearance, rapid colour-picker interaction, touch feel and sustained device performance remain acceptance checks. Physical-device attachment was not checked and no device test was performed. No APK/AAB, real authentication/purchase, live service mutation, deployment, staging, commit, merge or owner-process restart was performed.

# Customisation purchase perspective — 2026-10-27

The owner reports an unnatural-looking car perspective in the new purchase window. CPP01 replaces the flattened projection; CPP02 lowers the parked-car viewing angle; CPP03 preserves complete framing while rotating/resizing. R01 preserves the existing car/materials, dialog and transaction behavior. Q01 covers native rendering and regression checks.

The task-start preview uses orthographic projection at a 19.29-degree downward angle. Nearby and distant details consequently have equal projected scale. The corrected preview uses a fixed 38-degree perspective lens and a 12-degree view toward the car's bounds center. Its nearer end now appears larger and its rear recedes, with less roof dominating the image. This is a menu-only camera correction; it does not change the gameplay camera contract.

Camera distance is fitted from the cached visible-mesh corners, including each corner's depth, the viewport aspect and 12% projection padding. The lens remains fixed during drag rotation and resizing. This avoids substituting a wide-angle lens or changing model proportions to fit the sheet. Callouts continue to use the same camera's projection.

Runtime scope is only `game/ui/cosmetic_purchase_preview.gd`. The existing `game/tests/test_customisation_purchase_layout.gd` gains independent projection/depth-response, moderate-lens, lower-angle and all-corner-clearance assertions. It retains all prior layout, native mouse/touch, source reuse, camera isolation, idle rendering, account/purchase, duplicate/stale confirmation, modal cleanup, rear-aero and overflow assertions. No previous assertion is weakened.

Actual results:

| Run | Outcome |
|---|---|
| Task-start camera with expanded checks, Compatibility | 622 checks, 84 expected new perspective/angle/depth failures |
| Corrected camera, native Compatibility | 622 checks, 0 failures |
| Corrected camera, desktop Mobile/Vulkan | 622 checks, 0 failures |
| Existing script parser | 1,320 scripts, 0 failures |

Both native suites include the existing six production-stretched window sizes, raw short-landscape/portrait resizing, front/rear views and seven locale/font configurations. New assertions check that equal-size features shrink with distance and every cached visible-mesh corner keeps 2.5% viewport clearance. The original orthographic camera fails the new projection, lens, elevation and depth tests in all 21 inspections; existing framing and behavior assertions continue to run.

The dialog, Garage page, shared popup helper, ordinary showroom, original backdrop, CarVisual and Compact kit/aero source hashes match task start. Their hashes are retained in `before/retained-hashes.json` and the report. No art generation, geometry, finish, lighting, economy or save change is included. Generated build identity and unrelated concurrent work are excluded from the review patch.

Actual commands use the pinned Godot 4.7.2 engine through the existing entry point, with `APPDATA` set to task-owned `test-data`, `mobile-data` or `parser-data` directories under the evidence folder:

```powershell
# The same native command was first run with the original camera and --evidence=.../baseline.
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod gl_compatibility -TestArgument "--evidence=res://../docs/evidence/customisation-purchase-perspective-2026-10-27/gl_compatibility" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument "--evidence=res://../docs/evidence/customisation-purchase-perspective-2026-10-27/mobile" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
git apply --reverse --check docs/evidence/customisation-purchase-perspective-2026-10-27/checkpoint.patch
```

The baseline failures, native before/after/front/rear/rotated screenshots, logs, original source, hashes and task-only checkpoint are in `docs/evidence/customisation-purchase-perspective-2026-10-27`.

Reload/rebuild and owner visual acceptance remain. The underlying native model and renderer-specific material appearance are retained; this is not a whole-model redesign or exact photographic calibration. No device attachment check or physical-device test was performed. No APK, real authentication/purchase, owner-save/live mutation, deployment, staging, commit, merge or owner-process restart was performed.

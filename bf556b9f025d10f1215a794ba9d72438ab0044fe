# Garage Body kits camera — 2026-10-25

GBK01–GBK02/R01/Q01 address the owner's report that Body kits inherits a top view which hides the fitted kit.

Body kits used the same `body` focus as Patterns and Colours. That focus deliberately preserves the previous Garage viewing direction, including an elevated view. Body kits now has a separate `body_kit` preset: a low front three-quarter angle which shows the bumper, wheel arches and side skirts. The camera still fits the actual model bounds, including the selected kit, into the main Garage view. Category selection, option selection and a layout resize all use that preset.

The change is confined to `game/ui/garage_customisation_camera.gd` and its three kit-focus call sites in `game/ui/garage_page.gd`. The shared body fit, pattern/colour framing, right-side option list, preview/equip behavior and exact return-camera state remain. Driving cameras, car geometry and canonical simulation are untouched.

The expanded native customisation regression enters Parts from a 62-degree Garage view and visits Hood before Body kits. It checks all ten kits at 960 × 540, 1280 × 720 and 1720 × 900 for a low camera angle, a front/side viewing direction, fully visible model bounds, the retained car/viewport and unchanged saved cosmetics. Entry and resize checks verify that selecting an option is not required for the low preset. The existing tests still cover all seven vehicles, free previews, account/save/purchase guards, gestures and returning to the exact preceding view.

The original runtime reproduces the top view at 62 degrees in every option, with 634 checks / 92 failures against the expanded regression. The corrected suite passes **646 Compatibility / 646 desktop Mobile**, with zero failures. The final full parser passes **1204 scripts**. The preset is approximately 10.76 degrees above level. Existing framing, preview and return-camera assertions remain; the Body kits focus identity changes from the shared `body` to `body_kit`.

The exact task-start runtime sources and native rejection captures are retained under `docs/evidence/garage-body-kit-camera-2026-10-25/before/`. [Recorded commands, actual results, source hashes and the reverse-checked task-only patch](evidence/garage-body-kit-camera-2026-10-25/report.json) document the local checkpoint. The runner uses the pinned Godot via `scripts/dev.ps1`, isolated APPDATA and local fixture records:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-body-kit-camera-2026-10-25/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-body-kit-camera-2026-10-25/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-body-kit-camera-2026-10-25/run.ps1 -Test test_script_parse -Mode headless
```

[Review the actual Body kits before/after](evidence/garage-body-kit-camera-2026-10-25/review.html).

Reload and owner appearance/touch acceptance remain. Mobile here means Windows Vulkan. No device attachment check or physical-device test, APK, real purchase, live mutation, deployment or owner-process restart was performed. Concurrent work is preserved; no staging or commit is implied.

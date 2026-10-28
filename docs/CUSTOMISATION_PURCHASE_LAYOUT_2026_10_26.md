# Customisation purchase layout — 2026-10-26

The owner supplied a purchase confirmation in which the permanent-unlock text overlaps Buy/Cancel. CPL01 fixes the text/action separation; CPL02 keeps the message accessible during resizing and overflow; CPL03 preserves the existing purchase/sign-in callbacks and availability rules. R01 covers other shared popups; Q01 covers native renderer checks.

The shared message-only popup had a fixed 820×380 minimum and body padding that left insufficient space after the application's multilingual font fallbacks increased line height. With the real font configuration, the original builder fails 10 of 182 checks. The ordinary message reaches y=317 while the buttons start at y=298.

`game/ui/popup_style.gd` now measures the wrapped heading and body, fits the height to the parent viewport, and puts the native actions beneath the text column. A vertical scroll container clips overflowing copy above the actions. Compact typography and a smaller icon arrangement accommodate narrow windows; short windows omit the decorative icon. Parent resizing and message changes recalculate the layout. Form/file dialogs retain their existing body arrangement.

The ordinary purchase is now 820×421: message y=126–315, buttons y=339–397, with a 24-unit gap. The insufficient-balance message expands the panel to 453 units. Native Buy, Cancel, Close and account/purchase callbacks remain in their existing code. The original `garage_page.gd` is byte-identical to the task-start snapshot; no economy code changes.

Changed files are the shared popup helper, `game/tests/test_customisation_purchase_layout.gd`, this document, and the evidence folder. The test uses the real `GaragePage._require_owned` method with an in-memory economy and a lightweight page host. It invokes no live account, purchase or save operation. Existing concurrent changes, including the profile-icon branch in the shared helper, are retained.

Actual validation:

| Check | Result |
|---|---|
| Original purchase layout, configured app fonts | 182 checks, 10 failures; retained in `baseline.log` |
| Final native Compatibility | 337 checks, 0 failures |
| Final desktop Mobile/Vulkan | 337 checks, 0 failures |
| Existing shared popup suite, native Compatibility | 157 checks, 0 failures |
| Existing script parser | 1,287 scripts, 0 failures |

The focused suite covers six production-stretched window sizes (1138×535, 960×540, 1280×720, 1720×960, 540×960, 640×360), seven locale/font configurations, affordable/unaffordable/busy/pending/guest/paint states, native confirmation/sign-in/cancel semantics, a long heading/body, scrolling to the last line, and live resizing between raw 640×360 and 540×960 logical viewports. The existing translations retain some English fallback copy; this task does not supply translations. These are desktop rendering checks, not physical-device results.

The first extended run passed 317 checks but visual review showed a nearly empty message area with the extreme title in the short window. The final run adds a minimum 64-unit visible-message assertion and adjusts short-window heading typography; no original assertion is removed or relaxed. Early setup runs encountered Windows execution policy, an invalid test color constant, and sandbox certificate access; corrected commands and isolated data allowed the engine checks to complete.

Commands actually run use the pinned engine through the repository entry point. For each check, `APPDATA` points to a task-owned subdirectory of `docs/evidence/customisation-purchase-layout-2026-10-26`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod gl_compatibility -TestArgument "--evidence=res://../docs/evidence/customisation-purchase-layout-2026-10-26/final-gl_compatibility" -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument "--evidence=res://../docs/evidence/customisation-purchase-layout-2026-10-26/final-mobile" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_popup_style.gd -Graphical -RenderingMethod gl_compatibility -TestArgument "--evidence=res://../docs/evidence/customisation-purchase-layout-2026-10-26/shared" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
git apply --reverse --check docs/evidence/customisation-purchase-layout-2026-10-26/checkpoint.patch
```

Native before/after screenshots, logs, task-start source, task-only checkpoint patch and hashes are in `docs/evidence/customisation-purchase-layout-2026-10-26`. The build entry point refreshes generated build identity as usual; generated identity and unrelated concurrent work are excluded from the checkpoint.

Reload/rebuild the game to use the code. Owner appearance/touch acceptance and a physical-device check remain. No device attachment check or device test was performed. No APK, real authentication/purchase, live mutation, deployment, staging, commit, merge or owner-process restart was performed.

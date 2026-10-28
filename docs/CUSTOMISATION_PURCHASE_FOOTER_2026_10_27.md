# Customisation purchase footer spacing — 2026-10-27

P01 gives the owner's “Not now” action comfortable bottom padding matching the side insets. R01 retains the car-free purchase sheet, ordinary no-money layout, complete purchase translations, native confirmation/cancellation and existing transaction fences. Q01 verifies the actual native window and painted panel, including focused buttons.

The original `ConfirmationDialog` resized its direct `Control` child to ten units shorter than the window, even with native actions hidden. Footer coordinates used the window height, so the nominal 14-unit bottom inset became only four units against the visible panel. The purchase surface now belongs to a full-window `CanvasLayer`. Bottom padding is 32 logical units on wide panels and 24 on narrow panels, matching the sides. The action gap increases from four to eight units. Content-based sizing includes those insets and keeps the ordinary no-money states free of scrolling.

Changed files are `game/ui/cosmetic_purchase_dialog.gd`, the existing `game/tests/test_customisation_purchase_layout.gd`, and this document. The focused suite now checks the actual painted surface bounds, equal bottom/side insets and action separation alongside its existing language, state, scrolling, touch-target, cancellation and purchase-guard assertions. No assertions were removed or weakened.

Actual validation uses pinned Godot 4.7.2 and task-owned `APPDATA` directories:

- Task-start runtime against the strengthened native suite: 5,389 checks, 282 expected failures. All three new spacing assertions failed in each of the 94 inspected views; the measured visible bottom inset was four units.
- Final desktop Compatibility: 5,389 checks, zero failures. Wide-panel bottom inset is 32 units; raw narrow portrait and tiny-viewport fallback use 24 units. The Swedish zero-balance capture was visually reviewed.
- Final desktop Mobile/Vulkan: 5,389 checks, zero failures, including the same measured insets and native input guards.

Commands (each native run uses a separate task-owned fixture-data directory):

```powershell
$env:APPDATA = Join-Path (Get-Location) 'docs/evidence/customisation-purchase-footer-2026-10-27/test-data'
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence=res://../docs/evidence/customisation-purchase-footer-2026-10-27/gl_compatibility' -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence=res://../docs/evidence/customisation-purchase-footer-2026-10-27/mobile' -CommandTimeoutSeconds 180
git apply --reverse --check docs/evidence/customisation-purchase-footer-2026-10-27/checkpoint.patch
```

The suite covers 12 languages and seven account/balance/availability/item states, six production-stretched sizes, raw portrait, real overflow, live language changes, touch bounds, Close/Escape/Not now, stale contexts, sign-in and duplicate confirmation. Transactions use an in-memory economy; no real account is authenticated and no real purchase is performed. Native test sources, baseline failures, screenshots, actual logs, hashes and a task-only review patch are in `docs/evidence/customisation-purchase-footer-2026-10-27`.

Reload/rebuild and owner appearance/touch acceptance remain. No device attachment check or physical-device test was performed. Desktop Mobile/Vulkan is not an Android device test. No APK, owner-save/live mutation, deployment, staging, commit, merge or owner-process restart was performed. Concurrent work and generated build identity are excluded from the scoped patch.

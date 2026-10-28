# Customisation purchase reference — 2026-10-26

The owner requests the supplied car-led purchase composition. CPR01 presents the actual selected car and cosmetic on the left with an interactive rotation preview and a selected-part callout. CPR02 uses a category eyebrow, large item title, permanent-unlock scope, gold coin price, current/after-purchase balances, a prominent Unlock action and quiet Not now/Close controls. CPR03 preserves account/economy/purchase fences. R01 covers isolation and cleanup; Q01 covers desktop native rendering and responsive layout.

The purchase screen now owns a dedicated `ConfirmationDialog` presentation. Its landscape sheet is 1180×610 logical units when space permits, with a 55% car area and a dark details panel. Narrow portrait windows stack the car above the scrollable details. Short landscape windows retain two columns; details scroll above the fixed actions. The Unlock button has a 76-unit height; Not now and Close retain at least 48/52-unit heights. Price and both balances are bound to the existing economy values. Insufficient balance shows no invented negative post-purchase balance; guest sign-in and busy/pending availability retain the native confirmation state.

The new preview shares every visible Garage `MeshInstance3D` mesh and its materials when the shown appearance matches the requested item. It has one temporary transparent viewport, a separate camera and no idle render loop. Mouse/touch rotation changes only that camera; the Garage view and cosmetics remain exact. Direct requests that are not already displayed use a cooperative native car build for the requested paint/parts. Rear aero opens from behind and its callout uses the selected native aero profile's center; wheel/body callouts follow the viewed side. Initial native draws complete before the preview settles. Hiding/freeing the dialog releases its viewport and modal scrim. No alternate photographic vehicle replaces the game's fictional model.

`garage_page.gd` only changes the purchase-builder function: it supplies item/car/appearance data and uses the custom sheet. Existing account request, `economy.purchase`, asynchronous result/apply fences, modal ownership and queue-free callbacks remain. An additional pre-confirmation context check rejects stale navigation/account/preview state, and the custom action issues confirmation once. Close, Not now and Escape cancel through the native cancellation action. The shared `popup_style.gd` remains byte-identical to task start, including the earlier overlap fix and concurrent profile-icon branch.

The original winter turnout background is a built-in imagegen edit of the existing original mountain illustration. The image contains scenery only; the car, callout, prices and all controls remain native. It is imported losslessly with mipmaps and a 1024-pixel cap. Exact prompt and source provenance are recorded in `game/assets/menu/customisation_winter_turnout_v1.json`; the addition is recorded in `licenses/ASSETS.md`.

Runtime changes:

- `game/ui/garage_page.gd`
- `game/ui/cosmetic_purchase_dialog.gd`
- `game/ui/cosmetic_purchase_preview.gd`
- `game/ui/cosmetic_purchase_background.gdshader`
- `game/assets/menu/customisation_winter_turnout_v1.png` and import/provenance

Validation/support files are the updated `test_customisation_purchase_layout.gd`, the diagnostic original-builder economy control, this document, license entry and the evidence folder.

Actual checks:

| Check | Outcome |
|---|---|
| Initial native composition | 457 checks, 19 failures: reserved Close area and short-window body spacing; retained |
| Refined native layout | 457 checks, 0 failures |
| Interaction extension | 491 checks, 0 failures |
| Compatibility/Mobile before rear-aero extension | 491 checks each, 0 failures |
| Final Compatibility, including rear-aero fallback | 517 checks, 0 failures |
| Final desktop Mobile/Vulkan, including rear-aero fallback | 517 checks, 0 failures |
| Existing economy/real Garage suite, first attempt | Engine stopped on missing `kart_refined_v1/13a67020771bb20ea41540be.res`; retained |
| Same assertions with task-start purchase builder restored in memory | 56 checks, 0 failures |
| Existing economy/real Garage suite, current-builder retry | 56 checks, 0 failures |
| Existing script parser | 1,306 scripts, 0 failures |
| Pinned imports | Both import runs passed |

No assertion was weakened to resolve the initial spacing failures. The initial composition, typography/callout review captures and all subsequent runs remain in evidence. The economy control copies the unchanged assertions and replaces only the Garage purchase builder in memory; it does not edit the runtime source or skip assertions. The missing kart resource belongs to other workspace model work; no kart file was repaired or replaced by this task.

The focused test calls the real purchase builder with an in-memory economy and a native Garage source car. It covers six stretched window sizes, seven locale/font configurations, affordable/unaffordable/busy/pending/guest/paint states, actual mouse/touch input, source mesh reuse, unchanged Garage camera/cosmetics, direct unpreviewed rear-wing construction, no repeated idle render requests, modal cleanup, Close/Escape, stale preview rejection, duplicate confirmation suppression, long text/last-line scrolling and raw landscape-to-portrait resizing. Translated titles can wrap and scroll; several new captions still use existing English fallback. Renderer-specific native material appearance differs; the saved desktop views are visual evidence, not a physical-device appearance or frame-rate claim.

Commands actually run use `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1` and the pinned Godot 4.7.2 build. `APPDATA` is a separate task-owned evidence subdirectory for each fixture:

```powershell
# Earlier native destinations include initial-native, refined-native, interaction-native and final-*/final-*-rear.
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod gl_compatibility -TestArgument "--evidence=res://../docs/evidence/customisation-purchase-reference-2026-10-26/review-gl_compatibility" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_customisation_purchase_layout.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument "--evidence=res://../docs/evidence/customisation-purchase-reference-2026-10-26/review-mobile" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_earned_coins.gd -TestArgument "--evidence-root=res://../docs/evidence/customisation-purchase-reference-2026-10-26/economy-final" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/probe_customisation_purchase_economy_control.gd -TestArgument "--evidence-root=res://../docs/evidence/customisation-purchase-reference-2026-10-26/economy-control" -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
git apply --reverse --check docs/evidence/customisation-purchase-reference-2026-10-26/checkpoint.patch
```

Evidence, task-start sources, hashes and a task-only binary-capable review patch live in `docs/evidence/customisation-purchase-reference-2026-10-26`. Its Garage comparison restores only the task-start `_require_owned` function against the current surrounding source, preserving/excluding concurrent progressive-entry work. The license comparison similarly reconstructs only the added marked block against the current surrounding text. Generated build identity and concurrent App/header/car-model/handling work are excluded.

This reference supersedes the earlier generic purchase-window presentation only. Reload/rebuild and owner appearance/touch/translation/frame-pacing acceptance remain. No device attachment check or physical-device test was performed. No APK, real authentication/purchase, owner-save/live mutation, deployment, staging, commit, merge or owner-process restart was performed.

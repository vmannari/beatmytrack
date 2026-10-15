# Garage vertical swipe scrolling — 2026-10-14

GSW01–GSW04 / LV01–LV06 / CKT01–CKT06 / GMM01–GMM04 / V06 / G01 / R01 / Q01: the owner requests vertical scrolling by swiping in the livery and tuning menus.

Patterns, Colours, both sticker galleries and all four Compact tuning categories now share a vertical gesture owner. A swipe can begin on a selectable card or empty list space, continue beyond the list and reach either bounded end. Movement suppresses selection and saving; a tap still selects once. Emulated mouse events cannot activate a card during a touch swipe. Canceled touches, a second finger, hidden tabs and outgoing input-disabled panels cannot complete a stale selection. Mouse dragging, the wheel, the native scrollbar and keyboard focus remain available. Custom colour popups and the dedicated sticker-position editor retain their native input.

The sticker browser also had a zero-height list at 960×540. Its Hood/Roof, Emblems/Sponsors, gallery and placement actions now occupy one scrolling content area beneath the fixed Patterns/Colours/Stickers tabs. The list has 200 usable logical pixels at that size, with all choices and actions reachable. The actual car, camera, local condition, retained controls, saved paint/kit IDs, offline photographs and sixteen-kit-photo bound remain intact.

Actual native captures: [patterns at the bottom](evidence/garage-swipe-scroll-2026-10-14/compatibility/patterns-960-bottom.png), [tuning at the bottom](evidence/garage-swipe-scroll-2026-10-14/compatibility/tuning-960-bottom.png), [sticker actions reached by scrolling](evidence/garage-swipe-scroll-2026-10-14/compatibility/stickers-roof-sponsors-bottom.png). Matching Mobile/Vulkan captures are in the `mobile` evidence directory.

Pinned Godot `4.7.2.stable.official.ed1daf0bf` results:

| Check | Actual result |
|---|---|
| Before-fix full-app input fixture | 18 checks, 4 failures: upward and end-reaching swipes failed in Patterns and Tuning. |
| Final full-app `test_garage_swipe_scroll.gd`, Compatibility / Mobile Vulkan | **109 + 109 checks, zero failures**: both directions, card starts, bounds, no drag saves, touch/emulated mouse, cancellation, multiple fingers, tab hiding, native popup/scrollbar/wheel, sticker placement, keyboard reveal, local persistence and retained car/camera/condition. |
| Existing `test_garage_tuning_layout.gd`, Compatibility / Mobile Vulkan | **61 + 61 checks, zero failures**: matching Painting/Tuning pane rectangles, retained actual car/viewport/camera, footer fit, all category focus reveals, three display sizes and bounded photos. |
| Final project script parse | **753 scripts, zero failures**. |

The first expanded check exposed the collapsed sticker list; those failures remain in `initial-sticker-failure.log`. A later desktop fixture omitted the wheel's release event, retaining GUI mouse focus and blocking the subsequent scrollbar check. Completing that real input sequence resolved the fixture failure without weakening its assertion. The intermediate diagnostic is retained in `incomplete-wheel-fixture.log`. The initial sandbox run could not open Godot's normal local log directory; subsequent approved local runs use isolated records under `build/garage-swipe-scroll/` and disable backend access.

Actual commands, from the workspace PowerShell shell:

```powershell
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_swipe_scroll.gd -Graphical -TestArgument @('--baseline','--evidence-root=res://../docs/evidence/garage-swipe-scroll-2026-10-14/baseline')
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_swipe_scroll.gd -Graphical -TestArgument @('--evidence-root=res://../docs/evidence/garage-swipe-scroll-2026-10-14/compatibility')
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_swipe_scroll.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/garage-swipe-scroll-2026-10-14/mobile')
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_tuning_layout.gd -Graphical -TestArgument @('--evidence-root=res://../docs/evidence/garage-swipe-scroll-2026-10-14/layout-compatibility')
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_tuning_layout.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--evidence-root=res://../docs/evidence/garage-swipe-scroll-2026-10-14/layout-mobile')
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

Runtime changes are `game/ui/vertical_swipe_scroll.gd`, `garage_livery_menu.gd` and the tuning scroll's construction in `garage_page.gd`. The new export-excluded fixture is `game/tests/test_garage_swipe_scroll.gd`; both new scripts include engine-generated UIDs. Source patches, checksums, logs and the isolated review checkpoint receipt are retained with the evidence. The review repository is `build/garage-swipe-scroll/checkpoint-repo`, with its hashes in `delivery.json`. The shared branch/index and concurrent thumbnail-refresh change are preserved.

Physical-phone interaction and appearance acceptance remain untested. No device commands, APK export/install, backend operation or deployment were performed. These desktop renderer checks make no phone performance claim.

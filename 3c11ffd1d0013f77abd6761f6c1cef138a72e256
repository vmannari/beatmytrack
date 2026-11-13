# Object properties redesign — 28 October 2026

The editor now exposes a visible **Properties** action. A shared inspector replaces the sparse placement popup and the selected object's scattered size/rotation controls. It names the object, explains its behavior, and groups the relevant settings on consistent dark surfaces with cyan selection and keyboard focus states.

| Requirement | Delivered behavior |
| --- | --- |
| OP01 — Discovery and hierarchy | Visible Properties entry in the object palette and on a selected object; named heading, labeled sections, Close and Done. |
| OP02 — Size | Three visible presets with current multiplier and actual footprint dimensions; selected objects also accept numeric scale. Speed bumps retain independent width and Fit road width. |
| OP03 — Orientation | Top-view direction preview, exact degree entry, ±22.5° steps and four cardinal shortcuts. Typed angles commit with Done, including without Enter. |
| OP04 — Fence placement | Illustrated Single, Straight line, Curve and Road edge cards, selected state and specific instructions. Runs explain automatic orientation and hide irrelevant manual controls. |
| OP05 — State and history | Opening/reopening preserves size, variant, angle and placement. Selected-object edits use ordinary undo/redo; one whole fence run remains one action. Stale inspectors cannot edit another selection. |
| OP06 — Responsive/localized presentation | Theme margins are measured; only the fields scroll on short screens, with Done outside the scroll area. Twenty-three authored messages cover eleven additional languages. |
| Q01 — Evidence | Actual-App pointer interactions, native screenshots, saved-document round trips, retained suites, exact commands and source hashes. |

Native previews: [size and orientation](evidence/object-properties-2026-10-28/Windows-mobile/02-size-orientation.png), [fence curve](evidence/object-properties-2026-10-28/Windows-mobile/03-fence-curve.png), [road edge](evidence/object-properties-2026-10-28/Windows-mobile/04-fence-road-edge.png), [selected object](evidence/object-properties-2026-10-28/Windows-mobile/08-selected-object.png), [short landscape](evidence/object-properties-2026-10-28/Windows-mobile/09-fence-960x540.png), [German](evidence/object-properties-2026-10-28/Windows-mobile/10-localized-de.png).

## Files and boundaries

- `game/editor/object_properties.gd`: new shared native inspector and original vector placement/orientation illustrations. It has no processing loop, generated imagery or extra 3D preview world.
- `game/editor/object_browser.gd`: explicit entry, shared inspector wiring and preservation of choices.
- `game/core/app.gd`: selected-object integration, rotation signal and preservation of defaults within an asset family.
- `game/editor/object_thumbnail.gd`: tooltip points to Properties.
- `scripts/translations/object_properties.tsv` and localized catalogues: 23 directly authored messages, exact interpolation placeholders, current source/English inventory.
- `game/tests/test_object_properties.gd`: new regression and native capture helper. Existing tests were not edited by this task.

Concurrent editor selection/snapping/guidance, separate jump assets, catalogue/art, Garage, vehicle, backend and generated build-identity work is retained. The initial source copies predate some of those changes and are evidence, not a replacement tree. The source checkpoint reconstructs only this task's prior behavior on the final surrounding code; it does not claim a clean original-worktree baseline. Generated source/English catalogues and evidence images remain separate derivatives.

## Actual verification

The exact pinned engine is `4.7.2.stable.official.ed1daf0bf`.

| Check | Result |
| --- | --- |
| Actual-App inspector, Compatibility | **94 checks, 0 failures**, 14 native captures |
| Actual-App inspector, desktop Vulkan Mobile | **94 checks, 0 failures**, 14 native captures |
| Earlier headless actual-App run | 79 checks, 0 failures; subsequently strengthened with the final visible-instructions check |
| Existing object rotation suite | **60 checks, 0 failures** |
| Existing editor workflow suite | **254 checks, 0 failures** |
| Authored localization scope | **253 nonempty translation/placeholder checks**, zero failures |
| Scoped whitespace and source checkpoint | See `checkpoint.json` and `report.json` |

The final UI checks cover real pointer delivery through embedded windows, size/angle placement, reopening, actual fence construction and whole-run undo, the 16/24 m cliff contract, width-only speed bumps, contextual paint, selected-object undo/redo, stale selection fencing and save/reload. Views include 1280×720, 960×540, 1920×1080 and 720×1000, plus Finnish and German. Both native runs retain source-before/source-after hashes; the accepted final sources are stable within each run.

Reproduce the final UI checks from the repository root:

```powershell
python docs/evidence/object-properties-2026-10-28/run_check.py res://tests/test_object_properties.gd gl_compatibility verified-compatibility
python docs/evidence/object-properties-2026-10-28/run_check.py res://tests/test_object_properties.gd mobile verified-mobile
python docs/evidence/object-properties-2026-10-28/run_check.py res://tests/test_object_rotation.gd headless retained-rotation
python docs/evidence/object-properties-2026-10-28/run_check.py res://tests/test_editor_workflow.gd headless retained-workflow
```

The runner creates disposable offline profiles and evidence-local track/record/cloud directories. Its execution JSON contains the exact engine command, exit, elapsed time and source hashes. It does not use owner storage.

## Retained failures and corrections

The preferred `scripts/dev.ps1 -Action CheckScript -ScriptPath res://editor/object_properties.gd` completed. Its later `TestScript` invocation was stopped by the wrapper on this sandbox's root-certificate-store diagnostic. Direct pinned-engine runs retain that diagnostic while completing their actual assertions. This is not a certificate/configuration fix.

Initial input injections targeted the child Window instead of routing through the root viewport. They failed 13 interaction assertions in both headless and native runs; those receipts remain. Actual root-routed pointer events pass. The initial close-button expansion and an undercount of PopupPanel theme margins were corrected after native inspection. A focused geometry probe confirmed the margin discrepancy; final native assertions ensure the entire run instruction is visible.

The original broad object-browser fixture reports five placement/direct-selection failures, then dereferences its removed `ObjectSize` OptionButton and times out. It uses two-frame preparation waits and the former menu structure. It remains unchanged; the new fixture waits for actual preparation and independently exercises placement, run construction, cliff dimensions and persistence. No claim is made that the old fixture passes.

The full parser checked 1,403 scripts and reported one failure in the untouched historical `tests/fixtures/parking_hall_before/garage_page.gd`, which calls missing `_build_wash_requirement()`, plus its dependent fixture App error. Production inspector/App loading and the native tests succeed. The broad localization gate reports 1,254 missing/untranslated/obsolete inventory entries across the current workspace. This task's 23 authored messages pass all 253 scoped checks; no full-project localization-pass claim is made.

## Remaining acceptance

Reload the client to use the redesign. Owner review of the final look and interaction remains, particularly finger reach, physical text size, keyboard behavior and scrolling on Android. No physical-device test or device attachment query was performed. Desktop Vulkan Mobile uses an RTX 3090 and is not an Android performance result. AAA remains the quality target, not a certification established by automated checks.

No APK, real authentication/purchase, owner-save mutation, deployment, owner-process restart or main-index staging/commit/merge was performed.

# Garage workshop buttons, 28 October 2026

The workshop now has one vertical stack on the right: Appearance, Parts and Wash. The duplicate wash-required panel and its Wash car button on the left are removed. These buttons share the dark rounded tile surfaces, borders and interaction states used by the wash tools, with consistent icon spacing and gold selection. Captions remain visible at narrow widths.

| Requirement | Result |
| --- | --- |
| GWB01 | Remove the left wash-required panel and duplicate action. |
| GWB02 | Arrange the right actions vertically with equal widths and the existing wash-tool tile style. |
| GWB03 | When the current exterior requires cleaning, disable Appearance and Parts and highlight the enabled Wash action. Wash opens manual washing. The original cleanliness check enables both editing buttons during washing as soon as the exterior qualifies. |

The only runtime file changed is `game/ui/garage_page.gd`. Two existing regressions, `game/tests/test_garage_clean_customisation.gd` and `game/tests/test_garage_sidebar.gd`, follow the new action and check button availability, pointer/touch activation and layout. The standalone fixture also waits for layout before sending pointer events and prepares the existing lazy native picking before inspecting the exterior. The original cleanliness thresholds, washing, local persistence, appearance mutation guards, vehicle models and handling remain unchanged.

Commands, logs, screenshots, original-source controls, hashes and the task-only source patch are in [the evidence folder](evidence/garage-workshop-buttons-2026-10-28/). Commands use the pinned `scripts/dev.ps1` entry point, isolated workspace test profiles and a disabled backend. The initial sandbox certificate-store failure and intermediate fixture/class-alias findings are retained.

The source parser passed. The actual-app Compatibility check passed 4,495 assertions before the final icon-padding refinement. The final actual-app desktop Mobile run passed 4,507 assertions, including Compact/Forklift touch entry and captures. The final standalone native Compatibility suite completed 416 assertions with one failure: `forklift heavy slow film still blocks`. Its exact original-source control, with the same lazy-picking and layout setup, also fails that assertion (309 assertions, one failure). All new navigation and button-availability assertions pass; the broader Forklift invariant remains unchanged and failing. Full results are recorded in `report.json`.

Review the final actual-app `app-dirty-compact-overlay.png`, `app-wash-compact.png` and matching Forklift captures for the new stack and wash view. The standalone native captures additionally show the immediate clean/unlocked state and 960-, 1280- and 1600-pixel layouts.

Reload the game to see the change. Owner appearance/input acceptance and Android verification remain. No physical-device query or test, APK export/install, backend operation, owner-save change, owner-process restart, deployment or main-index staging/commit was performed. Existing unrelated workspace changes are excluded from the source patch.

The source-only patch passes forward and reverse application checks and `git diff --check`. A newer concurrent build identity was present at cleanup, so the conditional metadata cleanup preserved it; the receipt is `metadata-restoration.json`.

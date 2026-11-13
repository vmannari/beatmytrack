# Garage live Parts configurator — 2026-10-26

GLF01–GLF05/R01/Q01 implement the owner's numbered-list reference and live 3D comparison workflow.

Parts now uses a full-width vertical list, with numbered rows, a title and description, aligned prices, a thin yellow selection outline and a green equipped check. A large category heading and actual selection count sit above the retained Hood / Rear aero / Rims / Body kits tabs. All 43 existing options remain; counts use the actual category length, such as `02 / 10`. Prices, balances and ownership still come from the existing economy. Owned previews use Equip without another purchase.

The selected-part summary, separate detail image, repeated option photos and Cancel preview action are removed from Parts. The main Garage car is its only visual preview. The fixed yellow Buy & Equip action includes the current price and retains the existing explicit confirmation, authentication, affordability, receipt, delayed-response, account and save fences. Browsing remains free and never equips or saves by itself. Selecting the equipped row or leaving the workbench restores equipped cosmetics.

Hold to compare is a momentary control in the Garage view. It shows the saved equipped part while held, then restores the selected preview on release, including release outside the button. Mouse, touch and Space are supported. Touch cancellation, focus loss, a new selection, account changes and navigation clear the held state; old releases cannot restore stale previews. Comparing preserves the camera, list selection, purchase count and saved cosmetics. Drag, wheel, trackpad and pinch remain; the former Top view/zoom/reset controls remain absent.

The main preview uses a small projected callout, with no tint over the actual part finish. Hood framing pulls back enough to show more of the car, and Garage key/fill lighting is balanced for readable vents and lower bodywork while retaining native shadows. The accepted low Body kits camera remains. Flat native controls replace the old header gradient; no reference bitmap or new car art ships.

Runtime changes are `garage_page.gd`, `garage_customisation_camera.gd`, `garage_environment.gd` and descriptive metadata in `vehicle_customisation.gd`, plus four focused UI scripts: `garage_parts_list.gd`, `garage_part_option.gd`, `garage_compare_button.gd` and `garage_part_indicator.gd`. Geometry, canonical physics, saved cosmetic IDs and economy rules are unchanged. Patterns/Colours/Stickers retain their existing tools. New strings use GameText with English fallback; translated descriptive-copy review remains.

The expanded existing customisation suite retains purchase, guest, ownership, account, save, gesture, all-seven-model fit and exact return-camera assertions. Obsolete shipping Parts-photo/carousel/cancel assertions are replaced with text-row, no-photo-world, actual-car paint and momentary-compare checks. Final focused checks pass **599 headless / 646 Compatibility / 646 desktop Mobile**; the retained prepared-photo/geometry/cache regression passes **1446**, Workshop/Wash navigation **549**, view gestures **65**, review fixture **18 per renderer**, and the final parser **1219 scripts**. The pinned import passes and creates all five script UIDs. Initial logs retain a checkmark mistaken for a thumbnail in the new no-photo assertion, a detached-row layout callback error, and clipped selected rows. The final implementation guards detached layout and reveals rows after scroll bounds update, without relaxing visibility or transaction assertions.

[Review the finished native UI and comparison states](evidence/garage-live-configurator-2026-10-26/review.html). The red paint and 3000-coin review wallet are isolated local fixtures inside the actual App; no live account or balance is used. Review captures include 960 × 540, 1280 × 720 and 1720 × 900, mouse/touch comparison, owned/unowned choices and Body kits. Exact commands, outcomes, source/capture hashes and the reverse-checked task-only patch are in [report.json](evidence/garage-live-configurator-2026-10-26/report.json).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-live-configurator-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-live-configurator-2026-10-26/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-live-configurator-2026-10-26/run.ps1 -Test capture_garage_configurator -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-live-configurator-2026-10-26/run.ps1 -Import
```

Reload, owner appearance/touch acceptance, descriptive-copy localisation and physical-device review remain. Mobile here is Windows Vulkan. No device attachment check or phone/tablet test, APK, real authentication/purchase, live mutation, deployment or owner-process restart was performed. Concurrent work is preserved; no staging or commit is implied.

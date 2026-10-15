# Tuning workbench layout — 2026-10-14

The owner requests Tuning to resemble Painting. Tuning now uses the same retained side-by-side container: the large live car pane on the left and the 344-unit workbench on the right. Its header, reset icon, category styling, spacing and two-column native-photo gallery follow the painting workbench. Four kit categories occupy two rows; choices scroll vertically. Back to cars stays in the footer, and the same Top view / zoom / Reset view controls remain available beside the car.

Actual full-app captures: [Tuning at 1280](evidence/garage-tuning-layout-2026-10-14/compatibility/tuning-1280.png), [Painting at 1280](evidence/garage-tuning-layout-2026-10-14/compatibility/painting-1280.png), [Tuning at 960](evidence/garage-tuning-layout-2026-10-14/compatibility/tuning-960.png). Matching Mobile captures are in the `mobile` evidence directory. Capture sizes and logical viewport sizes are both 960×540, 1280×720 and 1600×720.

The viewport, actual car, room, camera/zoom and condition remain attached and retained. Care, Trophy wall and car selection restore their existing layouts. Saved part IDs, kit geometry, the sixteen-photo cache and independent part replacement are unchanged. Focused cards are revealed through a deferred instance-ID callback that ignores stale/outgoing cards; saved selections still reveal automatically.

Final checks using pinned Godot 4.7.2:

| Check | Result |
|---|---|
| Full-app `test_compact_kits.gd`, Compatibility / Mobile | **547 + 547**, zero failures: all 43 touch selections/saves, reset/rollback, actual pane equality with Painting, header reset, three sizes, last-card focus scrolling, retained car/camera, washing and race/ghost/awards integration. |
| Production-themed direct Garage `test_garage_tuning_layout.gd`, Compatibility / Mobile | **61 + 61**, zero failures: every category’s last card, matching pane rectangles, retained objects/camera, footer fit, view controls, bounded photos and Care restoration. |
| `test_garage_menu_motion.gd`, Compatibility / Mobile | **228 + 228**, zero failures: attached live viewport, interruption, navigation and exact first resized reflection/car draws. |
| Final script parse | **733 scripts**, zero failures. |

Initial focus checks exposed an offscreen focused card; the explicit reveal callback corrected it. An unrelated in-progress road API change temporarily prevented full-app startup. That change settled without edits from this task, and the final full-app checks above pass. Diagnostics and successful command receipts are retained in the evidence directory.

Implementation is limited to `garage_page.gd`, the existing kit workflow fixture and the new direct layout fixture. This is a menu layout change; no vehicle asset, canonical handling/scoring, backend, APK or deployment change is included. Physical-phone visual/touch acceptance remains untested.

The isolated review checkpoint is `build/garage-tuning-layout/checkpoint-repo`. Its baseline/task hashes, source/capture hashes and task-only patch are recorded in `docs/evidence/garage-tuning-layout-2026-10-14/delivery.json`. The shared Git branch and index remain untouched by this task.

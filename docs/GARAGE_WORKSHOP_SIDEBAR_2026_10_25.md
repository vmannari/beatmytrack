# Garage Workshop side navigation — 2026-10-25

GWS01 moves Appearance, Parts and Wash from the row above the car into a compact vertical submenu beside the primary left rail. It appears while Workshop is active and disappears for car selection, record player, trophies and News. The car and workbench share their top edge again.

GWS02 preserves the five primary destinations and remembered Workshop section. The current workbench styling, absent customisation footer, retained car/camera, media views, local washing rules, free previews and explicit equip/ownership rules remain. The AGENTS.md override records the owner's new side-navigation requirement, superseding the previous horizontal placement.

Changed runtime: `game/ui/garage_page.gd` uses a vertical container in the left layout, with a WORKSHOP heading and three 132×52 logical-unit action targets. Existing sidebar and carousel tests now assert that the submenu stays left of the car and no task navigation row displaces the car's top edge. All existing interaction, viewport/car retention, window, photo, cancellation and ownership assertions remain.

Native Compatibility and desktop Mobile navigation each pass 484 checks across 960×540, 1280×720 and 1600×720. Existing headless carousel passes 304 checks, including small and large workbench layouts. Per-run exact commands, exit codes and console logs are under [report evidence](evidence/garage-workshop-sidebar-2026-10-25/report.json).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-workshop-sidebar-2026-10-25/run.ps1 -Test test_garage_sidebar -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-workshop-sidebar-2026-10-25/run.ps1 -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-workshop-sidebar-2026-10-25/run.ps1 -Test test_garage_sidebar -Mode mobile
git diff --check -- AGENTS.md game/ui/garage_page.gd game/tests/test_garage_sidebar.gd game/tests/test_customisation_carousel.gd
git apply --stat docs/evidence/garage-workshop-sidebar-2026-10-25/task-only.patch
```

Tests use pinned Godot 4.7.2 through scripts/dev.ps1, disposable workspace APPDATA and offline test records. Host access is used for the Windows certificate store. The [task-only patch](evidence/garage-workshop-sidebar-2026-10-25/task-only.patch) is based on exact task-start copies, preserving earlier unrelated work; no staging or commit is implied.

Review [Appearance at 960×540](evidence/garage-workshop-sidebar-2026-10-25/test_garage_sidebar-gl_compatibility/customise-960.png), [Parts](evidence/garage-workshop-sidebar-2026-10-25/test_garage_sidebar-gl_compatibility/tuning-1280.png), [Wash](evidence/garage-workshop-sidebar-2026-10-25/test_garage_sidebar-gl_compatibility/care-1280.png) and the unchanged separate [record player](evidence/garage-workshop-sidebar-2026-10-25/test_garage_sidebar-gl_compatibility/records-1280.png) and [News](evidence/garage-workshop-sidebar-2026-10-25/test_garage_sidebar-gl_compatibility/news-1280.png) destinations.

Reload the client to review. Owner appearance/touch acceptance remains. No phone/tablet attachment check or physical-device test was performed. No APK, deployment, live mutation, actual purchase or owner-process restart.

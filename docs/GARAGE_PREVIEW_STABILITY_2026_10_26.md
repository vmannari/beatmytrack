# Stable Garage option previews — 2026-10-26

GPS01–GPS03/R01/Q01 fix the reported rear-aero and body-kit camera jumps and selection resets.

Each option used to restart the category focus, recomputing its direction from the rotated car and discarding the player's current angle/zoom. Focus is now retained within the same showroom/category. Real viewport resizing refits distance while preserving viewing direction and user orbit values. A new category still gets its existing smooth entry animation, and leaving editing restores the preceding Garage camera.

The cleanliness guard was also inspecting temporary preview geometry. A mask that cleaned the equipped exterior could fail on different preview surfaces; the next selection then rebuilt the workbench and cleared the choice. Browsing now restores the equipped model before checking cleanliness. Other gated operations inspect the equipped exterior and restore the preview without changing its selection or saved wash data. All cleanliness thresholds remain unchanged. Genuine newer dirt still cancels the preview and locks editing. Re-clicking the active category or active Parts/Workshop navigation preserves selection and camera; other navigation and internal refresh behavior remain.

Runtime scope is only `game/ui/garage_page.gd` and `game/ui/garage_customisation_camera.gd`. Geometry, economy, physics, cleanliness sampling/thresholds and persistence formats are unchanged.

The focused native regression uses actual pointer input after rotation and zoom, every non-stock rear-aero/body option, rapid choices, incoming camera animation, active navigation, resizing and a real newer dirty state. Fixtures include a clean car, actual exterior washing with untouched interior cells, and a diagnostic trilinear mask that cleans the equipped exterior precisely. Original runtime: 402 native checks / 218 failures; expanded headless regression: 593 / 343. The latter records four actual selection resets and up to 2.655 world units of camera-origin displacement. The final 63 sampled option transitions have no selection resets or reported origin displacement in either desktop renderer.

Final stability checks pass **646 headless / 658 Compatibility / 658 desktop Mobile**. The retained configurator suite passes **647 per desktop renderer**, including purchase/save/account fences, comparison, all seven model fits and exact return-camera behavior. Its actual-App fixture now explicitly waits for covered Garage preparation and asserts readiness; the initial stale synchronous-entry errors are retained. The pinned import and full parser (**1234 scripts**) pass. Complete commands/hashes are recorded in [report.json](evidence/garage-preview-stability-2026-10-26/report.json).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-preview-stability-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-preview-stability-2026-10-26/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-preview-stability-2026-10-26/run.ps1 -Test test_customisation_carousel -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-preview-stability-2026-10-26/run.ps1 -Test test_script_parse -Mode headless
```

[Review native before/after transitions](evidence/garage-preview-stability-2026-10-26/review.html). Exact original sources, failed baseline logs, diagnostic rows and the reverse-checked task-only patch remain in the evidence directory. Tests use isolated APPDATA, local records and the existing offline Shop fixture.

Reload and owner appearance/input acceptance remain. Mobile means Windows Vulkan. No device attachment check or phone/tablet test, APK, real purchase, live mutation, deployment, merge or owner-process restart was performed. Concurrent work is preserved; no staging or commit is implied.

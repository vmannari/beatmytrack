# Header car dropdown (2026-10-26)

HCD01: Clicking the header car opens a dropdown containing all seven cars, with the active car checked. HCD02: Selecting an entry updates and saves the active car without opening Profile. HCD03: Clicking the adjacent player name opens Profile. R01/Q01: Retain native screenshots, actual input/save results and a task-only checkpoint.

`game/ui/header_car_picker.gd` adds a native MenuButton over the car half of the existing header. Its popup uses the shared menu styling, existing localized car classes and radio selection. The current larger, centered car preview and wide name area remain. No dropdown arrow is added. The name half keeps the original profile action.

`game/core/app.gd` connects selection to the existing preference-saving flow, refreshes the retained Garage, updates the visible daily-car selector and refreshes Free Race comparisons for the new car. `game/ui/track_of_day_page.gd` synchronizes its selector when a retained daily page becomes active. Shared vehicle rendering, models, handling, online contracts and purchase rules are unchanged.

`game/tests/capture_profile_car.gd` now supports a separate evidence destination and the new split interaction. It records actual touch on the header car, all seven menu entries, the checked active car, arrow-key/Enter selection, mouse selection, saved preference reload, Escape dismissal and an actual touch on the name. The previous assertion that the entire car/name button opens Profile is superseded by this request. Existing all-car, saved appearance, unchanged-render, long-name and window-fit measurements remain.

Commands use the pinned Godot 4.7.2 runner, with process-local `APPDATA` and `LOCALAPPDATA` redirected to `build/header-car-dropdown-appdata`. Captures set `BMT_PROFILE_CAR_OUTPUT=res://../docs/evidence/header-car-dropdown-2026-10-26`. Native execution uses reviewed Windows certificate-store access.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_profile_car.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_profile_car.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/probe_header_car_baseline.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_track_of_day.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
```

Final native Compatibility and desktop Mobile reviews pass every recorded dropdown, mouse/keyboard selection, persistence, Escape, name navigation and retained appearance/window measurement. The broader App suite reports **141 checks, two failures** in Garage retention before and after an ordinary race. Reloading the exact task-start App and daily-page sources only in isolated process memory reproduces the same two failures at the same 141 checks; these remain outside this task. The separate daily HTTP integration stops at three checks/one failure because its required `BMT_TOTD_API_URL` fixture is not configured; no integration pass is claimed. Import completes with the environment's nonfatal missing Android build-tools notice.

Final results and source hashes are recorded in `evidence/header-car-dropdown-2026-10-26/report.json`, with native measurements in each renderer's `capture-report.json`. The initial attempt referenced an unavailable forklift news photograph; the final dropdown uses consistent native text/radio rows. Initial keyboard diagnostics pushed events into the popup viewport and then assumed End selected the last item. Corrected diagnostics route full key press/release events through the root window and use ordinary Down arrows followed by Enter. The initial failed measurements and runner logs are retained; no interaction/save requirement was relaxed.

Review the [dropdown](evidence/header-car-dropdown-2026-10-26/gl_compatibility/car-dropdown.png), [mouse-selected forklift](evidence/header-car-dropdown-2026-10-26/gl_compatibility/dropdown-selected-forklift.png) and [Profile opened from the name](evidence/header-car-dropdown-2026-10-26/gl_compatibility/profile-opened-from-name.png). The task-only source patch is checked in reverse against current files and forward against exact task-start sources. Concurrent work and generated build identity updates are excluded.

Reload and owner/device appearance/input acceptance remain. No device attachment check or physical-device test, APK, live mutation, purchase, deployment or owner-process restart was performed.

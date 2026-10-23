# Race graphics settings, 22 October 2026

Settings → Graphics now offers saved race shadow quality, 3D resolution and anti-aliasing alongside the existing simpler-car option. Apply commits the draft; Reset graphics stages automatic defaults and detailed cars. The next race consumes a private snapshot of the choices. Existing profiles retain their previous rendering through Auto.

| Requirement | Delivered behavior |
| --- | --- |
| GFX01 | Shadow quality: Auto, Off, Low, Medium, High. Low/Medium/High use 512/1024/2048 directional shadow maps. Off disables the race's directional shadows; inexpensive contact and cloud shading remain. |
| GFX02 | 3D resolution: Auto, 50%, 67%, 75%, 100%. The existing mobile 1.5-million-pixel limit and 55% Night limit still cap the selected scale. Native Canvas menus, HUD and camera projection remain independent. |
| GFX03 | Anti-aliasing: Auto, Off, FXAA, MSAA 2x, MSAA 4x. Affected Adreno Compatibility devices offer Auto/Off/FXAA and map previously saved MSAA to safe FXAA, retaining the original depth workaround. |
| GFX04 | Strict allowlisted local preferences, atomic save/rollback, retained drafts across categories and failed saves, staged section reset, unrelated settings preserved. No schema bump is required for optional settings. |
| R01 | Original five laps, canonical state, geometry, weather, car detail option, Garage resources and mobile budgets remain. Race teardown restores entry MSAA/render scale and the configured directional atlas before subsequent menu rendering. |
| Q01 | Native menu layouts/popups at 960×540, 1280×720 and 1600×720, mouse and keyboard selection, actual race profiles, rendered shadow-map changes and exact shadow restoration, plus existing regressions. |

Changed runtime files are `game/presentation/graphics_preferences.gd`, `game/ui/settings_page.gd`, `game/persistence/local_records.gd` and `game/core/game.gd`. The focused regression is `game/tests/test_graphics_settings.gd`; `scripts/test_graphics_settings.ps1` runs it through the pinned `scripts/dev.ps1`, with APPDATA redirected into `build/` and backend configuration disabled. Both new GDScript files retain their generated Godot UIDs. Project/build identity files may be refreshed by the standard runner; the task-only checkpoint excludes those generated changes and unrelated work.

The directional atlas setter is global rather than per viewport, so race setup captures its configured platform size/format and teardown restores them. The original project is the sole production owner of this setting outside the race override. No per-frame tree traversal, extra lighting, renderer switch, runtime image readback, network operation or simulation work was added. See the [Godot RenderingServer API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-directional-shadow-atlas-set-size).

## Actual verification

Engine: `4.7.2.stable.official.ed1daf0bf`. Native renderers ran on Windows/NVIDIA RTX 3090; “Mobile” below means the desktop Vulkan Mobile renderer, not an Android device.

| Executed check | Result |
| --- | --- |
| Focused graphics, headless | 146 checks, 0 failures |
| Focused graphics, native Compatibility | 155 checks, 0 failures |
| Focused graphics, desktop Mobile | 155 checks, 0 failures |
| `test_records.gd` | 54 checks, 0 failures |
| `test_app.gd` | 141 checks, 0 failures |
| `test_racing_car_models.gd`, headless | 75 checks, 0 failures |
| `test_tablet_render_budget.gd` | 481 checks, 0 failures |
| Final `test_script_parse.gd` | 930 scripts, 0 failures |
| Scoped `git diff --check` | Passed |

The fixed shadow fixture changes 2,791 pixels between Low and High on Compatibility and 6,713 on Mobile (more than one color level). After leaving High, zero pixels differ from the original atlas rendering on either renderer at that tolerance. This fixture uses its own environment, a bounded shadow atlas and a 50m camera far plane. The race checks instantiate all five quality combinations, retain identical initial canonical snapshots and verify five laps, selected scale/AA, biome-refresh shadow preferences and viewport restoration.

Actual commands used the temporary `build/run_graphics_settings.ps1` wrapper initially and the equivalent saved runner for final runs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_graphics_settings.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_graphics_settings.ps1 -Renderer gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_graphics_settings.ps1 -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_graphics_settings.ps1 -Script res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_graphics_settings.ps1 -Script res://tests/test_records.gd
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_graphics_settings.ps1 -Script res://tests/test_app.gd
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_graphics_settings.ps1 -Script res://tests/test_tablet_render_budget.gd
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_graphics_settings.ps1 -Script res://tests/test_racing_car_models.gd
git diff --check -- game/core/game.gd game/persistence/local_records.gd game/ui/settings_page.gd game/presentation/graphics_preferences.gd game/tests/test_graphics_settings.gd scripts/test_graphics_settings.ps1
```

Initial attempts are not counted as final passes. The direct PowerShell invocation encountered the host execution policy; the runner uses the established process-scoped Bypass invocation. The sandboxed engine reported certificate-store access errors; successful engine runs used approved execution outside the sandbox with isolated workspace APPDATA. The initial focused run passed 139 headless checks. Native fixture development then exposed one scaled mouse-coordinate failure, three unsupported End-key/navigation failures, a focus-dependent first popup failure, one environment-coupled shadow-restoration failure, and one fixture without a usable Compatibility shadow atlas. Fixes establish local coordinates, native popup focus and Up/Enter navigation, give the independent fixture an explicit environment/atlas/far plane, and retain both strict shadow assertions. One intermediate fixture enum typo was corrected after a parser error. Assertions and runtime invariants were not removed or relaxed. Final logs are retained under the evidence directory; earlier intermediate build logs may be reused by concurrent runner processes.

## Evidence and acceptance

Evidence: [`evidence/graphics-settings-2026-10-22/`](evidence/graphics-settings-2026-10-22/). `Windows-gl_compatibility/` and `Windows-mobile/` contain inspected native settings, popup and five race-profile views plus original/Low/High/restored shadow fixtures. `before/` preserves source baselines; `task.patch` is the reviewable task-only checkpoint, and `fingerprints.json` records its source inputs. Existing unrelated work was preserved and no Git commit was made in the shared dirty checkout.

Owner appearance/quality preference, physical-phone touch/Adreno execution, memory, thermal and frame-rate acceptance remain. No phone attachment check or physical-device test was performed. No APK/export/install, live account or progression write, backend modification or deployment was performed. No device performance improvement is claimed. Reload the local client to see the added controls.

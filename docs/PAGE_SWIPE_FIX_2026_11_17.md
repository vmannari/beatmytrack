# Page swipes restored — 2026-11-17

PSF01 restores horizontal menu navigation. The persistent achievement overlay at layer 30 was treated as a modal even with its banner hidden. App now marks that decorative layer with the existing `menu_input_passthrough` metadata. Native tooltip windows also reached the modal check; the check now respects `Window.FLAG_MOUSE_PASSTHROUGH`.

PSF02 preserves real modal blocking. The existing recursive search still discovers dialogs inside a passthrough layer and ordinary modal canvas layers. No gesture distances, carousel ownership, navigation order or layout changed.

Changed sources: `game/core/app.gd` (two added lines), `game/ui/menu_page_swipe.gd` (tooltip check and comment), and `game/tests/test_page_swipe_notifications.gd`. Earlier changes in App remain outside this task's patch.

## Verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. All new test runs used separate task-local APPDATA/LOCALAPPDATA directories and isolated records/cloud roots, with the API URL empty.

| Check | Result |
| --- | --- |
| Initial focused reproduction, before either fix | 16 checks / 11 failures |
| Achievement-only intermediate | 16 / 6; tooltip window remained a blocker |
| Final focused headless | 17 / 0 |
| Final focused desktop Compatibility | 21 / 0 |
| Final focused desktop Mobile/Vulkan | 21 / 0 |
| Exportable production parser | 583 scripts / 0 failures |
| Scoped whitespace check | Passed |
| Existing race-mode input suite | Stopped after 183 seconds; only `APP_READY`, no assertion summary |

The final focused test dispatches viewport touches at 1280×720 and 960×540. It checks left/right Race/Create navigation, a visible award, an input-transparent tooltip, a dialog nested beneath the passthrough overlay, an ordinary modal layer, and navigation after closing modals. Four screenshots per renderer are retained under [evidence](evidence/page-swipe-fix-2026-11-17/).

Initial attempts remain recorded: the legacy `test_menu_page_swipe.gd` reported four failed assertions and a nil-tween `pause` error during reproduction. Its expectation of three warmed neighbors also conflicts with the existing cold-Garage exclusion. It is not claimed as passing. An explicit synthetic tooltip held open across swipes intercepted popup input; the final fixture tests its modal classification before hiding it. The first Mobile run passed navigation but failed four screenshot writes because the output URI was not globalized; the fixture now resolves it to a filesystem path and the repeat passes.

## Commands

Initial repository entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_menu_page_swipe.gd -CommandTimeoutSeconds 240
```

Subsequent runs used the same verified pinned executable directly, with separate task-local `APPDATA` and `LOCALAPPDATA` directories:

```powershell
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_page_swipe_notifications.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --script res://tests/test_page_swipe_notifications.gd -- --output=docs/evidence/page-swipe-fix-2026-11-17/gl_compatibility
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method mobile --script res://tests/test_page_swipe_notifications.gd -- --output=res://../docs/evidence/page-swipe-fix-2026-11-17/mobile
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_editor_shipping_parse.gd
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_race_mode_input.gd
git diff --check -- game/core/app.gd game/ui/menu_page_swipe.gd
python build/page-swipe-fix-2026-11-17/finalize.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The Compatibility output initially resolved beneath `game/`; its four task-owned screenshots were moved to the documented evidence directory. The final fixture globalizes resource paths.

## Limits and checkpoint

Reload/restart is needed to load the updated scripts. Physical-device input was not tested; desktop Mobile is a renderer test, not an Android-device claim. No export, deployment, live service mutation or owner-process/save action was performed. The unrelated race-mode run and task checkpoint receipt are recorded with the evidence. Concurrent work and the shared Git index are preserved. Standard build retention applies.

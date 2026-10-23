# Editor starting background, 2026-10-18

EBG01: Apply the document's biome before the editor's first rendered view. EBG02: Reuse the established palette and lighting for the initial sheet and completed preview. G01/Q01: Preserve editing and document behavior; record actual desktop verification.

`game/core/app.gd` supplies `document.theme` before adding `EditorWorld` to the tree. `game/editor/editor_world.gd` initializes its ground, environment and lighting from that theme immediately, using the same helper when detailed geometry becomes visible. Previously the ground always started with `TrackTheme.PINE[1]` and only changed after asynchronous preview construction. New tracks, loaded drafts and rebuilt editors use this shared entry point.

`game/tests/capture_editor_start_background.gd` captures the actual app with preview compilation held back, so every image shows the pending initial view. Its persistence uses disposable storage. All five captures completed successfully with `preview_pending=true`; ground/background pigments match the existing palette:

| Biome | Ground/background pigment | Desktop capture |
|---|---|---|
| Grass | `#606b36` | [View](evidence/editor-start-background-2026-10-18/gl_compatibility/pine-start.png) |
| Desert | `#c5a16b` | [View](evidence/editor-start-background-2026-10-18/gl_compatibility/desert-start.png) |
| Night | `#555965` | [View](evidence/editor-start-background-2026-10-18/gl_compatibility/night_city-start.png) |
| Winter | `#b5c2cd` | [View](evidence/editor-start-background-2026-10-18/gl_compatibility/winter-start.png) |
| Storm | `#566549` | [View](evidence/editor-start-background-2026-10-18/gl_compatibility/storm-start.png) |

Rendered colors include the existing biome lighting. All five screenshots were visually inspected. Observations and logs are under `docs/evidence/editor-start-background-2026-10-18/`.

Commands executed from the repository root, using pinned Godot 4.7.2 through `scripts/dev.ps1`. Each successful invocation set `APPDATA` and `LOCALAPPDATA` to its own `build/editor-start-background-2026-10-18/{app,capture,parse}-userdata` directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_app.gd -CommandTimeoutSeconds 180
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_editor_start_background.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://editor/editor_world.gd
```

Results: existing App regression **140 checks, zero failures**; five successful native desktop Compatibility captures; editor-world parser exits zero. The existing regression covers editor save/close/return and practice round trips.

Initial attempts are retained: direct PowerShell invocation hit execution policy; concurrently starting two entry-point commands contended on generated build identity; sandboxed Godot hit user-log access and then Windows certificate-store access. Final commands ran sequentially with disposable data under approved execution outside the sandbox. The first capture helper skipped retained Garage preparation, causing recursive profile-menu rebuilding; restoring normal preparation corrected the helper. Runtime invariants were unchanged to address these fixture failures.

The task-only source checkpoint is commit `4f236cf`, exported as `evidence/editor-start-background-2026-10-18/task-only.patch` from a separate Git repository under `build/editor-start-background-2026-10-18/checkpoint`. Its parent contains the two affected runtime files as captured before this task, preserving the workspace's pre-existing edits. The checkpoint contains only this task's runtime changes and capture helper. This report and the new entries in `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md` record completion.

Remaining acceptance: owner visual review and physical-device startup appearance. No phone attachment check or device test, APK/export/install, backend action or deployment was performed. Desktop Mobile/Vulkan was not tested for this small initialization change.

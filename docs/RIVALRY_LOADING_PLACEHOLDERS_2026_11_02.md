# Rivalry loading placeholders (2026-11-02)

The owner requested a blurred, very slightly pulsing abstract car and a fitting loading animation for the standings table during Rivalry car changes.

| Requirement | Implementation |
| --- | --- |
| RLP01 | Three anonymous blue-grey car silhouettes replace the empty podium blocks. Soft analytic edges, a slow approximately 3.6-second pulse and small phase offsets keep motion restrained. |
| RLP02 | Empty standings rows show rank, name, points and gap shapes with a broad diagonal shimmer and faint travelling opacity pulse. No fake names, scores or ranks are displayed. |
| RLP03 | Retained 2D drawing commands and a small canvas shader add no 3D worlds, off-screen render targets, per-frame CPU callbacks or asset downloads. Pending notifications retain the same visuals; failure/retry and final-board handoff dispose and recreate them through the existing presentation lifecycle. The existing fresh-membership entry gate and same-car background refresh behavior remain. |

Runtime sources are `game/ui/weekly_rivalry_page.gd`, `game/ui/rivalry_loading_visual.gd` and `game/ui/rivalry_loading_visual.gdshader`. The silhouette is original mathematical 2D artwork, with no new external image or model asset. Existing localization strings are reused. The focused regression is `game/tests/test_rivalry_loading_visuals.gd`.

| Actual verification | Outcome |
| --- | --- |
| Initial headless fixture | 54 checks, zero failures. |
| Final native Compatibility/OpenGL, 1280x720, 960x540, 1600x720 | 66 checks, zero failures; six captures. |
| Final native desktop Mobile/Vulkan, same sizes | 66 checks, zero failures; six captures. |
| Native motion samples, 0.65 seconds apart | Both car and table regions change pixels on both renderers at all three sizes, within the unchanged low-contrast assertions. |
| Source whitespace and task-only checkpoint | See the recorded check outcomes in `report.json`. |

The initial two Compatibility attempts retained one failed small-window motion assertion each. The fixture resized the physical window without resizing its logical canvas, so the sampled standings region was outside the rendered table. The final fixture sets both sizes explicitly; no assertion was relaxed. A faint row pulse was also added between shimmer passes. Original logs remain recorded in [report.json](evidence/rivalry-loading-placeholders-2026-11-02/report.json).

Example final native views: [Compatibility, 1280x720](evidence/rivalry-loading-placeholders-2026-11-02/gl_compatibility/loading-1280x720.png), [Compatibility, 960x540](evidence/rivalry-loading-placeholders-2026-11-02/gl_compatibility/loading-960x540.png), [Mobile, 1280x720](evidence/rivalry-loading-placeholders-2026-11-02/mobile/loading-1280x720.png). Each renderer has a second motion sample at every size.

All engine commands used the pinned `4.7.2.stable.official.ed1daf0bf` build through `scripts/dev.ps1` and the process-tree crash-dialog wrapper, with `APPDATA=build/rivalry-loading-visuals/profile` and an empty `BMT_API_URL`. The synthetic page fixture opens no service connection and uses no owner save. Native windows were placed off-screen.

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-loading-visuals/profile'
$env:BMT_API_URL = ''
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_loading_visuals.gd -CommandTimeoutSeconds 90
# For native captures, append either renderer combination:
# -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3
# -Graphical -RenderingMethod mobile -RenderingDriver vulkan
```

Normal local execution was used because the earlier analysis probe established that sandboxed Godot startup cannot access the Windows certificate store. No device query/test, Android export, owner-process restart, owner-save mutation, live/backend mutation, deployment or main-index write was performed. Owner appearance acceptance and device behavior remain unmeasured. The change adds loading feedback; it does not claim to reduce network or model construction time. Concurrent changes and generated build identities are preserved.

The task-start page, source hashes, command logs, captures and source-only patch are indexed in [report.json](evidence/rivalry-loading-placeholders-2026-11-02/report.json).

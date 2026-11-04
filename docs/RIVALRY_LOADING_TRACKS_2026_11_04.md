# Rivalry weekly-track loading presentation (2026-11-04)

Owner correction: keep the loading and ready layouts identical. The final implementation now shares the track-card header, summary slot, column headings and spacing. Placeholder rows use the same minimum height and thumbnail dimensions as populated rows, including their text-driven minimum height. The rank and time placeholders align with their actual columns. Summary text occupies a stable single-line slot with its complete text available on hover; finale wrapping is retained. Below 600 logical viewport units, shared spacing compacts so all five rows fit, including after resizing while pending.

| Follow-up requirement / verification | Actual result |
| --- | --- |
| RLT04: stable loading-to-ready layout | Track panel, all five rows and all five thumbnails have exactly equal before/after rectangles at 960×540, 1280×720 and 1600×720. Podium bounds remain equal too. |
| New regression against the preceding implementation | 240 checks, 16 failures, reproducing the first row's 25-pixel shift and the small-window panel expansion. |
| Final Compatibility and desktop Mobile | 260 checks, zero failures each, including viewport fit, exact handoff rectangles, resize, animation and retained lifecycle checks. |
| Existing Rivalry presentation regression, native Compatibility | 381 checks, zero failures, including score refresh and track/header interactions. |
| Ready-view preservation | Compatibility's ready track panel is pixel-exact against the preceding ready view at both 1280×720 and 1600×720. The complete 1600 image is exact; the complete 1280 image differs at two car pixels outside the track panel. |
| Follow-up captures | 28 final focused native PNGs plus the existing presentation regression's captures. Loading/ready pairs are available for each size and renderer. |

Follow-up evidence and incremental source-only checkpoint: [layout-stability/report.json](evidence/rivalry-loading-tracks-2026-11-04/layout-stability/report.json). The preceding source files, failing shift regression, initial shared-header initialization failure, intermediate runs and thumbnail-height failures are retained there. A manually sized resize fixture was corrected to reapply its shell bounds after the old minimum settled; final assertions also check the actual viewport. No invariant or motion bound was relaxed. An optional Pillow comparison could not run because Pillow was unavailable; a standard-library PNG decode established the pixel comparisons above without installing anything.

Final comparison: [loading](evidence/rivalry-loading-tracks-2026-11-04/layout-stability/final/gl_compatibility/loading-1280x720.png), [ready](evidence/rivalry-loading-tracks-2026-11-04/layout-stability/final/gl_compatibility/ready-1280x720.png), [small ready view](evidence/rivalry-loading-tracks-2026-11-04/layout-stability/final/mobile/ready-960x540.png).

Follow-up commands use the same isolated profile and empty API URL as below, with `BMT_RIVALRY_LOADING_EVIDENCE=res://../docs/evidence/rivalry-loading-tracks-2026-11-04/layout-stability/before-views`, `.../initial-fixed` or `.../final`. The two renderer command forms below were repeated. The retained check used the same Compatibility command with `-ScriptPath res://tests/test_rivalry_view_polish.gd` and `BMT_RIVALRY_POLISH_EVIDENCE_DIR=res://../docs/evidence/rivalry-loading-tracks-2026-11-04/layout-stability/retained`. Source checks and patch application receipts are in the follow-up JSON. Device testing was not performed; owner visual/device acceptance remains.

The following records the initial delivery, superseded by RLT04 above.

The owner requested better visualisation of “This week's tracks” while Rivalry content loads. Five blank blocks now become numbered thumbnail rows with neutral circuit schematics, name/biome/result placeholders and the existing gentle loading shimmer. The existing translated “Loading tracks…” message explains the wait.

| Requirement | Delivered |
| --- | --- |
| RLT01 | Five stable 01–05 slots follow the populated track list's thumbnail, text and result hierarchy. The repeated schematic is loading artwork; actual routes, names and results still come from the membership snapshot. |
| RLT02 | Existing shader animation drives retained 2D draw commands. No new textures, 3D worlds, viewports, CPU animation callbacks or external dependencies. |
| RLT03 | Rows fit the available panel, ignore input and retain their controls on repeated pending notifications. Failure removes them, retry restores them and the authoritative board replaces them with selectable tracks. Existing car selection, podium colors, entry gate and usable background-refresh behavior remain covered. |

Changed files:

- `game/ui/weekly_rivalry_page.gd`: loading-track rows and translated status.
- `game/ui/rivalry_loading_visual.gd`: retained track schematic and skeleton drawing.
- `game/tests/test_rivalry_loading_visuals.gd`: panel fit, five slots, input/lifecycle, rendered animation and configurable evidence destination.
- This report and its evidence directory.

| Actual verification | Result |
| --- | --- |
| Before change, native Compatibility | 135 checks, zero failures. |
| Final native Compatibility/OpenGL | 216 checks, zero failures. |
| Final native desktop Mobile/Vulkan | 216 checks, zero failures. |
| Window sizes in each run | 960×540, 1280×720 and 1600×720. |
| Captures | 11 before and 22 final native PNGs, including motion samples and retained selected-model coverage. |
| Track-panel mean pixel change, RGB /255 | Compatibility: 1.451144, 1.988574, 0.203901; Mobile: 0.117421, 0.141224, 0.094240, in 1280/960/1600 order. All satisfy the unchanged gentle-motion bound used for standings. |
| Source checks | Scoped `git diff --check`; source-only task patch with forward/reverse and byte comparison receipts in `report.json`. |

Native views: [before, 960×540](evidence/rivalry-loading-tracks-2026-11-04/before-views/gl_compatibility/loading-960x540.png), [final Compatibility, 960×540](evidence/rivalry-loading-tracks-2026-11-04/final/gl_compatibility/loading-960x540.png), [final Compatibility, 1280×720](evidence/rivalry-loading-tracks-2026-11-04/final/gl_compatibility/loading-1280x720.png), [final Mobile, 960×540](evidence/rivalry-loading-tracks-2026-11-04/final/mobile/loading-960x540.png).

Commands actually run, with `APPDATA` resolved to `build/rivalry-loading-tracks/profile`, an empty `BMT_API_URL`, and `BMT_RIVALRY_LOADING_EVIDENCE` set to `res://../docs/evidence/rivalry-loading-tracks-2026-11-04/before-views` for the baseline or `.../final` for the final runs:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_loading_visuals.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 120
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_loading_visuals.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 120
git diff --check -- game/ui/weekly_rivalry_page.gd game/ui/rivalry_loading_visual.gd game/tests/test_rivalry_loading_visuals.gd
```

Pinned Godot: `4.7.2.stable.official.ed1daf0bf`. The first sandboxed baseline failed on the known Windows certificate-store restriction and the test runner's subsequent cleanup reported access denied. It is retained as a failed environment attempt. Normal local Windows access allowed all three subsequent native runs to finish successfully. An outer PowerShell profile policy warning appeared on the baseline retry; the engine test itself passed. No invariant was removed or weakened.

The isolated profile and synthetic snapshots avoid owner account/save changes. No device query/test, APK/export, live/backend access, deployment, owner-process change or main-index write occurred. Concurrent workspace edits and generated build identities are excluded from the task patch and preserved. Reload and owner appearance/device acceptance remain; no loading-time or phone-performance improvement is claimed.

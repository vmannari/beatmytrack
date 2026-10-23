# Winter spline snow banks — 2026-10-18

WSB01 corrects the owner's corrupted Winter spline snow banks. WSB02 fences stale prepared visuals. R01 retains canonical driving and authored track data; Q01 requires reproduced failure, rendered evidence and regressions.

The Star spline reproduced a broad dark border in the actual Compatibility renderer. Most bank ribbon triangles faced down while their supplied smooth normals faced up. The double-sided bank shader consequently showed the underside. Removing shadows did not remove the dark strip; an unlit diagnostic exposed intact geometry in the same location.

`NativeTrackVisual._winter_bank_section()` now checks each triangle's projected winding and exchanges its last two vertices when needed. Each vertex retains its original position, normal, UVs and colour. Profile shapes, deposits, materials, lighting, road meshes and canonical bank contacts are retained. The shared visual kit advances from 211 to 212 so existing road, section, selected-track and finished-world caches rebuild through their original bounded paths. No native-library rebuild is needed.

The complete Star scene retains 92,163 bank vertices. Downward-facing triangles fall from 123,046 to 316; the latter belong to the original decorative fragments, rather than the bank ribbon. Independent ribbon checks find zero downward triangles on all three Star pieces, both contour directions around an enclosed spline island, and original/mirrored straight, taper, curve, S-bend, hairpin and variable-width spline sections. Complete Star, enclosed-island and bridge worlds retain exact canonical metadata, cells, route and contact triangles.

## Actual validation

| Check | Result |
| --- | --- |
| Initial Star ribbon regression on original source | 6 checks, 3 reproduced failures |
| Final focused headless | 27 checks, zero failures |
| Final focused Compatibility | 27 checks, zero failures |
| Final focused desktop Mobile | 27 checks, zero failures |
| Native road kernels / scalar parity | 115 checks, zero failures |
| Road cache | 70 checks, zero failures |
| Shoulders / joins / internal contours | union area 30, zero failures; 71 + 18 checks pass |
| Prepared race worlds | 85 checks, zero failures |
| Driving, including exact replay | 72 checks, zero failures |
| Complete script parser | 890 scripts, zero failures |

Tests ran with Godot 4.7.2 through `scripts/dev.ps1`, disposable workspace APPDATA and local road-cache isolation. Desktop Compatibility and Mobile captures show the corrected Star, close bank detail, enclosed island and bridge. Mobile means the desktop renderer, not a physical phone result. Kernel timings ran alongside other checks and are not performance measurements for this fix.

Commands executed (PowerShell process execution policy set to Bypass):

```powershell
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_spline_banks.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--before','--diagnose') -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_spline_banks.gd -TestArgument @('--before') -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_spline_banks.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_spline_banks.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_spline_banks.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_native_road_geometry.gd -CommandTimeoutSeconds 240
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_cache.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_shoulders.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestDriving -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

Initial attempts are retained: the first invocation met the default PowerShell script restriction; the first sandboxed engine invocation could not read the Windows certificate store and failed to terminate its child cleanly. Running the same local test with ordinary host access succeeded. The expanded island fixture initially inspected an inset boundary that no longer carried a hole winding. The fixture now explicitly exercises the real unoffset inner contour while ordinary cases retain the actual inset boundary; the zero-downward-triangle assertion remains. No canonical or shared contour code was changed to satisfy that fixture.

## Evidence and checkpoint

Evidence: `docs/evidence/winter-spline-banks-2026-10-18/`, including original-source snapshots, the dark/no-shadow/unlit diagnosis, final renderer captures, command receipts and `task.patch`. Some successive TestScript commands share a log filename; `commands.json` retains their observed stdout summaries as well as copied raw logs where available.

Runtime change: `game/track/native_track_visual.gd` (version plus `_winter_bank_section` only). Regression: `game/tests/test_winter_spline_banks.gd` and UID. This document and short project-status entries complete the slice. The source-only patch isolates those changes against the current workspace; concurrent editor upload-budget changes in the same runtime file remain context and are excluded. Root Git metadata is untouched.

Owner appearance acceptance and physical-device review remain. No phone attachment check or device test was performed, and no APK/export/install, backend change or deployment was performed.

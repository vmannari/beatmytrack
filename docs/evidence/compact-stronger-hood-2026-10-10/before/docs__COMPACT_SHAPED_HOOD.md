# Compact shaped hood - 2026-10-10

Requirements: CG12 (owner asks for visible hood shape in the supplied overhead view), CG01-CG11/GL01-GL06/V06/R01/Q01. This updates the real shared fictional Compact model in Garage and driving.

The hood gains a broad raised centre and two tapered pressed shoulders. At its middle section, the centre rises65mm above the side-edge height, compared with the former28mm crown. A softly rolled central field and narrow shoulder contours converge toward the nose. Their relief fades with zero slope at the perimeter, preserving every existing front/fender boundary coordinate and the rear cowl. The shape is authored geometry using the existing satin paint finish and showroom lighting.

The accent paint now uses56interior columns from the steel's88-column grid, with the same24longitudinal samples. Corresponding triangles follow the shaped steel with a1.5mm paint-layer offset; this avoids intersections that an independently sampled overlay could introduce. Accent edges snap to those matching stations, and their adjacent seams follow the sculpted surface. Body/accent editing and UV atlas mapping remain supported.

Changed files: `game/vehicle/compact_coachwork.gd`; v3 `crowned_hood.res`, `hood_accent.res`, manifest and provenance; new `game/tests/test_compact_hood.gd` and UID; this documentation and scoped status/plan/license entries. **Only two of50 native resources change; the other48 hashes remain exact.** Final original v3 geometry totals735928bytes. Fictional identity, windows/doors/markers/mirrors, front bumper/rear joints/roof/windshield, wheel transforms, canonical collision/handling and camera controls are retained. No external model, texture, generated bitmap, source-reference pixels or runtime service is added. [Task-only binary/text Git checkpoint](evidence/compact-shaped-hood-2026-10-10/scoped-change.patch) preserves prior and unrelated workspace changes.

Actual engine commands use pinned Godot **4.7.2.stable.official.ed1daf0bf** through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with normal engine log/certificate access. Actual-app fixtures disable API requests and use isolated records/library/cloud paths.

| Actual command | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd` | **50meshes/735928bytes**, exit0 |
| `-Action TestScript -ScriptPath res://tests/test_compact_hood.gd -Graphical` | **3745checks, zero failures**: actual baked crown, symmetry, finite unit normals and every accent vertex's matching steel position; five native actual-app views |
| `-Action TestScript -ScriptPath res://tests/test_compact_front_join.gd -Graphical` | **115checks, zero failures**: hood/front/corner rim and hood/fender joins retain their original0.2mm tolerance; earlier lighting/tangent and37old-v2 array comparisons pass |
| `-Action TestScript -ScriptPath res://tests/test_garage_studio.gd -Graphical` | **75checks, zero failures**: all50source/bake arrays exact, finite UV geometry, paints, studio/driving glass isolation, wheels and batching |
| `-Action TestVehicleBatch` | **35checks, zero failures**, all five cars preserve exact source/batched geometry and bounds; Compact985parts ->48meshes/98432triangles |
| `-Action TestScript -ScriptPath res://tests/test_garage_livery.gd -Graphical` | **115checks, zero failures**, saved colors, preview/reset/save-failure handling and driving application |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **488scripts, zero failures** in the current shared workspace |
| Python SHA-256 comparison to captured v3 manifest | Only `crowned_hood.res` and `hood_accent.res` changed;48resources exact |
| `C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe devices -l` | OPD2403 OnePlus Pad2/f0ba474a attached; **no phone attached** |
| Scoped whitespace/reverse-apply checkpoint checks | Pass |

Measured baked middle section: centre `(0,1.077,-1.552)`m, side edge `(-0.73,1.012,-1.4275)`m; cross-section crown0.065000057m. All accent vertices match corresponding steel vertices within0.01mm after removing the1.5mm layer offset. Front-rim discrepancy remains0.000000377m and hood/fender discrepancy0.000000119m; neither original join tolerance was weakened.

Native evidence inspected: [hood overhead](evidence/compact-shaped-hood-2026-10-10/hood-top-1280.png), [left angle](evidence/compact-shaped-hood-2026-10-10/hood-front-left-1280.png), [right angle](evidence/compact-shaped-hood-2026-10-10/hood-front-right-1280.png), [low angle](evidence/compact-shaped-hood-2026-10-10/hood-low-1280.png), [high Garage view](evidence/compact-shaped-hood-2026-10-10/garage-high-1280.png). Inspection fixture targets do not alter the shipping camera.

Final Compact:98432triangles/48batched meshes/69248UVvertices. One desktop studio construction observation328.988ms; RTX3090 Compatibility SubViewport CPUmedian0.729ms/GPUmedian0.166ms during concurrent graphical checks. These are individual desktop observations, not phone/whole-app performance or AAA acceptance. No physical-device test, Android export/install, full Validate, physics regression, backend deployment or production action was performed. Remaining acceptance: owner hood-shape review and tablet/phone presentation/performance. Restart/rebuild the client to load the two changed native resources.

# Flat sand apron and independent berm clods

2026-09-24; V02/V04/V05/Q01; kit 65. Owner rejected repeated raised-strip refinements and requested a different approach to match the supplied reference.

## Approach

The continuous raised creator shoulder ribbon is removed. Its replacement is a flat apron of original illustrated sand, pebbles and mineral grit. Independent irregular low sand clods form broken deposits at inside bends, with sparse smaller deposits on straights. Curve-run taper affects clod size near the ends. Gaps and different sizes replace the previous continuous lip. Clods are opaque geometry in the existing shoulder batch, not alpha cards or new colliders. Authored road widths, canonical kerb contacts, camera, daylight, approved directional road artwork/UV mapping and dust behavior are retained.

The apron extends approximately 2.7-3.3 m outside the inset road outline, within a 3.7 m ground skirt. Its inner contact band is darker; its outer region breaks into the dune material. The 1024 mipmapped artwork adds one new texture asset. Reference images are not copied into the project. [Exact built-in imagegen prompt and provenance](DESERT_APRON_PROMPT.md); saved asset `game/assets/textures/desert_apron_v1.png`.

Each clod has 18 triangles. Saved desert track builds 809 clods (14,562 triangles), with a maximum 1,800 per track. Removing the raised cross-section reduces shoulder-strip vertices to six per section. All remain in the existing shoulder render batch. No added runtime AI or dependency. This is a different geometry/material approach, not proof of equal performance. No claim that dense reference scenery is fully reproduced.

## Evidence and validation

[Start/straight](evidence/desert-apron/start-straight.png), [road and bends](evidence/desert-apron/route-35.png), [another bend/bridge](evidence/desert-apron/route-70.png). All final desktop captures inspected; the bridge view includes an existing bridge unrelated to this change. Historical dune comparison images are preserved.

Pinned Godot 4.7.2 commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action Import`: new texture imported, 1024 limit and mipmaps enabled.
- `-Action CaptureDesert -Track track_3e26605a8a90165e`: 53 checks pass including five-car exact replay, dust, canonical surfaces and three route captures. Logs report actual clod count.
- `-Action TestSurfaces`: 50 checks pass.
- `-Action TestSurfaceProfile`: initial run caught missing packed_wear in the historical shader adapter (despite the test assertion summary); command correctly failed. Added the missing compatibility functions/sampler. Rerun: 928 checks pass with no shader errors.
- `-Action ExportAndroid -QuickValidation`: import/startup, 74 driving, 18 catalog and 22 menu checks pass; APK exported. Existing build-tools 35.0.1 fallback and driving-test ObjectDB shutdown warnings remain.

## Phone

`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -DesertProfile -Baseline -Seconds 30 -ReportName desert-apron-phone-2026-09-24` installs the final build on DN2103 and runs the real production materials, dust, lighting, HUD and touch-stress probe for 30 measured seconds after warmup. Unscored driving does not save race records. The run completed: median 20.868 ms, p95 47.709 ms, p99 82.301 ms; 1,113 frames, 107.2 m driven. It is not a steady 60 fps result. Battery temperature rose from 27.6 to 28.5 C. Screenshot and raw report are in `docs/evidence/desert-apron-phone-2026-09-24/`. The screenshot shows heavy existing dust covering much of the view.

This is a current-build smoke measurement, not an old/new comparison or thermal acceptance. The runner removes diagnostic markers and relaunches normal play in its finally block.

A follow-up `-DesertCostProfile -SkipInstall -Seconds 15 -ReportName desert-apron-cost-2026-09-24` compares production / particles disabled / production, with five-second warmups. This diagnostic toggles particles only; it does not alter shipping dust behavior. Completed results:

| Stage | Median ms | p95 ms |
|---|---:|---:|
| Production 1 | 17.344 | 29.629 |
| Particles disabled | 16.851 | 20.153 |
| Production 2 | 17.347 | 28.838 |

The repeat is more stable than the initial 30-second run. Particles contribute to long frames, but this does not isolate the cost of the apron/clods versus the prior build. No steady 60 fps or performance-regression acceptance is claimed. Both runs cleaned up markers and relaunched normal play; normal dust remains enabled. Raw reports, configurations, APK hash, battery data and phone screenshots are saved in both evidence directories.

## Changes and remaining acceptance

`game/track/native_track_visual.gd`, `creator_road.gdshader`, `surface_detail.gdshaderinc`, new texture/import, `game/tests/test_desert.gd` route capture additions and `game/diagnostics/surface_material_probe.gd` compatibility fix. Status/plan/provenance and this report record actual evidence.

Owner style approval, moving-camera inspection at all joins, representative large-track load cost and sustained phone performance remain. Generated artwork tile continuity is visually reviewed rather than mathematically guaranteed. Clods are decorative; canonical bump/contact behavior is unchanged.

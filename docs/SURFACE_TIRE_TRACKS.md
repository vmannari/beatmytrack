# Surface-aware race-persistent tire tracks

Date: 2026-09-20

Requirements: R01, V02, V04, V05, Q01.

## Delivered behavior

`SkidTrails` retains the existing single-`MultiMesh` rendering boundary. Its fixed ring is now 16,384 marks; at the 0.32 m sample spacing, four-wheel contact marks still cover about 1.31 km of active marking before the oldest group is reused. The allocation is fixed at race start, does not grow with play time, and still renders as one instanced batch. Gaps longer than 1.5 m are rejected so respawns and discontinuities do not draw lines across the circuit.

Each rear wheel samples the actual native surface beneath it. Asphalt rubber, carried dirt on asphalt, flattened grass, compressed dirt/sand, water, kerbs and snowbanks use distinct color, opacity and width. Winter asphalt has a restrained frosty scuff and Storm asphalt a damp, darker mark. The canonical tire-dirt state continues to fade carried soil as the tires clean. Bridges use the elevated surface layer and the existing bridge-aware mark height.

Mark strength is continuous rather than binary. Slip angle, lateral scrub speed, brake pressure at speed, yaw rate, loose/wet-surface rolling, tire contamination and outside-wheel cornering load feed each wheel segment's opacity and width. Mild behavior leaves a faint, narrow trace; braking and a broad slide progressively approach the strongest treatment, and left/right tracks can differ during a turn.

The asphalt reference follow-up moves emission to all four actual wheel contact paths. Rear marks retain full slip/scrub response; front marks are deliberately lighter during oversteer and become clearer under heavy braking. Asphalt width is approximately 22–25 cm depending on strength. A nonlinear opacity curve keeps mild slip below 5% while bounding the strongest clean-rubber mark near 46%. Strength is distance-smoothed over roughly 0.32 m on onset and 0.5 m on release, avoiding hard starts and ends.

The shared shader feathers the outer 28% of asphalt marks and adds several longitudinal charcoal streaks plus deterministic fine grain. Overlapping transparent segments blend naturally, so repeated laps darken and broaden the common racing line without a second unbounded history or extra draw call. This accumulation is visual within the bounded race mark ring; it is not saved between races.

The shared mark mesh now has a low-poly shoulder-and-groove cross-section. The follow-up deepens grass relief to 7.2 cm and dirt/sand relief to 6 cm at maximum intensity, with a broader pressed center and steeper 3D shoulders. Physics strength scales those maxima down for lighter contact. A reference-guided procedural treatment adds tread-block tonal breakup, compacted center bands and chipped granular edges. Sand retains its approved warm soil treatment; grass uses a darker, more opaque brown-green crushed-vegetation tone. Loose marks are approximately full tire width (29–30 cm). The angular planes create explicit cel-shaded light/dark faces, while asphalt remains nearly flat and wet wakes use only slight relief. This geometry and shader remain one shared mesh/material in the existing `MultiMesh`; they do not create nodes or draw calls per mark.

The runtime call passes the current `NativeTrack` only to presentation. Simulation, handling, replay state, collision, camera and track data are unchanged.

## Changed files

- `game/vehicle/skid_trails.gd`: fixed race-scale ring, longer sampling interval, discontinuity guard and per-surface styles.
- `game/core/game.gd`: supplies the current track to trail presentation.
- `game/tests/test_soil.gd`: checks the bounded batch, distinct surface treatments, soft-ground widths and winter/Storm routing.
- `game/diagnostics/mobile_race_probe.gd`: debug-marker-only empty/saturated/empty trail comparison.
- `docs/evidence/soil/dirty-trails.png`: refreshed desktop visual evidence.
- `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`: delivery record.

## Actual verification

- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 TestSoil`: passed 134 checks after the four-wheel asphalt follow-up.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 CaptureSoil`: passed 139 checks and refreshed `docs/evidence/soil/dirty-trails.png`, `docs/evidence/soil/deep-off-track-ruts.png` and `docs/evidence/soil/asphalt-skid-progression.png` on the desktop OpenGL renderer.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 Validate -QuickValidation`: final import and startup passed; driving 74, catalog 18 and menu-presentation 22 checks passed. Godot reported the existing four leaked `ObjectDB` instances after the driving test; the command still completed successfully. The full regression suite was not run.

The first focused run failed one old 1.04 m seam-length assertion because the intentional overlap is now 6 cm. The assertion was corrected to 1.06 m. During concurrent off-track handling work, two later focused runs exposed its temporarily failing full-soil speed assertion; after that work settled, the final headless and graphical runs above passed without weakening the invariant.

## Performance and acceptance limits

The design bounds CPU work to four instance updates per accepted sample and GPU work to one instanced draw. Maximum visible geometry is 16,384 small faceted strips (163,840 triangles), with fixed transform/color/custom-data storage plus engine overhead. Marks normally occupy only a fraction of capacity because clean, non-slipping driving emits none. This is an architectural budget, not a physical-device frame-time measurement.

## Physical-phone performance and deployment — 2026-09-20

Device: DN2103, Android 13, Mali-G77 MC9, Compatibility renderer, game scale 0.667. The final debug APK was exported with pinned Godot 4.7.2, installed successfully with `adb install -r`, and cold-launched. APK SHA-256: `88A7FC94C6D942036A779D635E4698C56CD4602614DF89C045EAD883B96B75C7`.

A controlled 75-second debug probe used identical Starter Circuit AI driving, lighting, shadows, vehicle and render scale. After five-second warm-ups, its three 20-second measurement stages were empty trails / all 16,384 instances visible / empty trails:

| Stage | Median | p95 | p99 | >25 ms | Draw calls | Primitives |
|---|---:|---:|---:|---:|---:|---:|
| Empty A | 16.866 ms | 20.400 ms | 22.000 ms | 1/1189 | 291 | 274,090 |
| Saturated | 16.792 ms | 19.913 ms | 21.631 ms | 4/1188 | 292 | 437,930 |
| Empty B | 16.837 ms | 19.833 ms | 21.942 ms | 1/1188 | 290 | 272,936 |

The saturated batch adds one draw call and 163,840 submitted primitives. Median and percentile frame times did not regress relative to either empty control in this run. Four saturated-stage intervals exceeded 25 ms versus one in each control, but maxima remained below 33.34 ms; the sample is too short to attribute those isolated misses to the trails. The concurrent SurfaceFlinger trace covered 4,343 presentation intervals over 73.42 seconds: median 16.834 ms, p95 16.972 ms, p99 17.072 ms, with ten intervals over 25 ms including stage transitions and a 134.70 ms maximum.

[Internal on/off/on report](evidence/tire-performance/device-probe.json) and [SurfaceFlinger report](evidence/tire-performance/surfaceflinger.json) retain the measurements. These establish bounded worst-case cost on this phone, not thermal acceptance across all tracks/devices. The debug marker and results were removed from app-private storage, absence verified, and the normal installed app was cold-launched afterward. Player files were not deleted.

Remaining acceptance is owner visual judgment during a five-lap drift-heavy race, visibility on every biome/material, bridge layering, and whether the 1.31 km active-mark budget covers the most aggressive driving. On an unusually mark-heavy race exceeding that budget, the oldest marks are reused rather than allocating more memory.

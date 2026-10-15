# Grass slowdown and five-centimetre road height

The height/shoulder implementation below was superseded by the owner's asphalt-only correction. See [Asphalt rise correction](ASPHALT_RISE_CORRECTION_2026_10_14.md); the grass slowdown remains.

Owner request, 2026-10-14: lose speed faster when entering grass, set the road slightly above terrain (about 5 cm), and account for bridge seams.

Requirements: GRH01 stronger grass resistance from the first wheel; GRH02 escape from rest and exact replay; GRH03 shared 5 cm road/terrain datum with sloped shoulders; GRH04 continuous bridge mouths and shared car/ghost/trail support; R01 versioned canonical contracts; Q01 actual regression and renderer evidence.

Grass adds a speed-dependent dissipative resistance using the existing four contacts and each car's existing soil multiplier. The grass pickup value remains 0.5 and sand remains 1.0; neither contamination nor the shared soil torque changes. Coasting resistance fades below 2 m/s. Under throttle, the added resistance fades between 24 and 14 m/s to retain the approved low-speed powered escape, including the kart's more-than-10-metre escape in two seconds. Physics is now `arcade-planar-0.57`; the saved record/ticket keys already include physics versions. The handling profiles, five-lap rules, compiler-27, track documents, and road/sand dynamics stay unchanged.

The road surface stays at its existing 0.012 m datum. The terrain/road skirts use -0.038 m, exactly 0.05 m below it. Existing shoulder geometry slopes between those datums; the decorative fringe follows the shoulder instead of covering it with a flat sheet at road height. Native and explicitly painted asphalt use a single merged-run mesh, with closed exposed edges and the unchanged terrain shader/UVs. This adds at most one native/painted-road draw; ordinary authored roads retain their existing draws. Existing cache budgets are retained and track-kit-195 invalidates old road/world artifacts.

Creator bridge asphalt matches 0.012 m at both mouths and smoothly returns to the existing 0.025 m finish offset over the first/last metre. Native bridge asphalt uses the same road datum. Rails, bridge height/clearance, collision layers and ramp shapes remain unchanged. `BridgeElevation` now owns a pure, spatially indexed ground/shoulder support sampler shared by car presentation, recorded/verified ghosts, contact shadows, dust and tire marks. It owns no scene or GPU resources and does not change canonical vertical physics.

Measured coasting from 24 m/s (86.4 km/h), all four wheels on grass:

| Car | Previous stop time | New stop time | Previous distance | New distance |
| --- | ---: | ---: | ---: | ---: |
| Compact | 4.96 s | 1.64 s | 18.58 m | 10.61 m |
| Pickup | 6.80 s | 2.19 s | 21.88 m | 15.40 m |
| Classic | 5.61 s | 1.54 s | 17.91 m | 9.77 m |
| Formula | 4.18 s | 1.26 s | 15.66 m | 7.62 m |
| Kart | 2.81 s | 0.63 s | 9.39 m | 2.87 m |

These are deterministic desktop simulation measurements, not phone performance measurements. Reverse coasting also passes; all five cars escape grass from rest under both pedals. The spatial one-wheel test confirms greater speed loss before the centre leaves asphalt. Five-car road/sand snapshots are exact against the saved physics-0.56 source.

Changed runtime files: `game/vehicle/vehicle_simulation.gd`; `game/track/road_surface_height.gd`, `bridge_elevation.gd`, `native_track_visual.gd`, `shoulder_mesh.gd`, `creator_bridge_visual.gd`, and `bridge_presentation.gd`. Regression/contract files: `game/tests/test_grass_road_height.gd`, `backend/deploy/stage_verifier.py`, `backend/tests/test_verifier.py`, and `backend/tests/fixtures/verified_oval.json`. Project instructions/status and this report document the change.

Verification uses pinned Godot 4.7.2 through `scripts/dev.ps1`, with isolated workspace APPDATA. Commands actually run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_road_height.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_road_height.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_road_height.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File build/grass-road-height/run-regressions.ps1
.tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q --junitxml=build/grass-road-height/verifier-final.xml
git diff --check -- <changed tracked runtime/contract files>
```

Final focused headless checks: 96 pass. Final Compatibility and Mobile/Vulkan checks: 104 pass each, including actual closed native road edges. All 26 native regression commands pass; they cover driving/handling, launch, five-lap route/bridge gates, bridge contacts, shallow collisions, all-car replays, soil, hazards/speed bumps/props, suspension/kerbs/snow, rewind/ghosts and records. The final parser checks 725 scripts with zero failures. Ruff and scoped `git diff --check` pass. All eight native-world overhead/seam photographs per renderer are under `docs/evidence/grass-road-height-2026-10-14/{gl_compatibility,mobile}/`. They use inspection cameras and simple fixture lighting, not a changed gameplay camera. Pine and Desert close views and Winter transition views were visually inspected on Compatibility; the final Mobile Pine overhead view was inspected as well. Actual outcomes are retained in `regressions.json`, `validation.json` and the individual logs.

Backend verifier: final 70 pass, including unchanged historical .50 replay/lap times and standalone canonical staging. Initial staging failed because concurrent editor work added three pure-script dependencies and a four-argument prepared-cell loader. Staging now includes those dependencies and the new support sampler. The historical test adapts only its loader signature, ignores prepared buffers, and retains original rectangle expansion and physics; assertions and replay bytes are unchanged. The existing Starlette deprecation warning remains.

Initial sandbox runs could not write normal user logs/read Windows certificates; workspace APPDATA and approved certificate-store access resolved these. A transient concurrent compact-kit refactor omitted its old `BODIES` interface, blocking one graphical attempt; that concurrent work restored it and the affected checks passed without modifying kit source in this task.

The first full native regression batch exposed the kart's powered grass escape and soil tradeoff checks. The added drag now follows the existing per-car soil multiplier and fades under low-speed throttle. The original assertions are retained: both kart soil entry comparisons still require at least 15% stronger slowing, and powered escape still requires more than 10 m in two seconds. Final kart handling checks pass; the initial failures are retained under `initial-regressions/`.

No physical-phone driving test, Android export/install, live backend write or deployment was performed. Phone attachment was not checked. Owner acceptance of grass balance, subtle road height/edge appearance and phone motion/performance remains. Matching client/verifier rollout is required before new .57 online attempts; existing .56 records must not be relabelled. The source-only review checkpoint is `docs/evidence/grass-road-height-2026-10-14/change.patch`, with exact final source hashes in `source-receipt.json`; the existing Git index and concurrent edits are retained. Its reverse Git applicability check passes with `--ignore-space-change` for the current Windows line endings. No rollout was published.

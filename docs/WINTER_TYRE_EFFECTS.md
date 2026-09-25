# Winter tyre trails and snow effects

2026-09-24; V02/V04/V05/Q01; presentation version `winter-spray-1`. Owner accepted kit 77 road colour and requested surface-fitting tracks, bank-impact clouds and snow flying from tyres.

Winter maps road cells to subtle blue-grey ice scuffs (8), grass/kerb/snow cells to loose-snow ruts (7), sand/dirt cells to compressed-snow tracks (10), and water/ice-patch cells to slush wakes (11). Canonical surface types, traction and contacts are unchanged. Snow ruts have raised displaced shoulders, a tread pattern and more relief than the nearly flat ice scuffs. Marks still use the existing bounded persistent MultiMesh. At ground-bank contacts their base follows canonical bank height. Concrete retains its ordinary hard-surface treatment.

The existing SandDust presentation component lazily creates winter emitters: four 64-particle ballistic chip emitters, four 28-particle short powder emitters and a pool of two 32-particle bank bursts (432 additional particle capacity). Loose/packed snow emits during ordinary driving and more strongly under scrub; ice has sparse chips only under scrub. Water/slush does not throw dry snow. Winter ground cannot select green grass blades, brown sand dust or rubber smoke. Bank entry above 2.5 m/s triggers a 1.6-second cloud with a 51-tick minimum interval, rather than repeated bursts throughout contact. Airborne/rolling/stopped wheels stop emitting; elevated wheels exclude ground-bank impacts. One-shot reset now calls restart before disabling emission, fixing a test-discovered restart that enabled an emitter again.

No runtime AI or new image asset: powder reuses the project's existing original dust-puff texture; chips use bounded generated mesh geometry. New particles never write simulation state. Road materials and bank meshes remain unchanged.

Changed files: `game/vehicle/skid_trails.gd`, `game/vehicle/sand_dust.gd`, `game/tests/capture_winter.gd`, this report, status/plan and `docs/evidence/winter-effects/`.

## Actual commands and outcomes

All commands use pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action CheckScript -ScriptPath res://vehicle/sand_dust.gd`: passed.
- `-Action CaptureWinter`: final 138 checks, zero failures. Includes all winter surface mappings, canonical snapshot preservation over 105 presentation samples, bank burst/cooldown, bounded emitters, airborne/elevated exclusion, clearing, biome switching, trail colour/relief and captures.
- `-Action TestSoil`: 163 checks, zero failures.
- `-Action TestIce`: 69 checks, zero failures including five-vehicle replay/handling checks.
- `-Action TestDesert`: 53 checks, zero failures.
- `git diff --cached --check`: passed.

Initial capture failed to parse because a snapshot was incorrectly typed Dictionary instead of Array; corrected. Next run caught the one-shot clear issue; corrected and rerun. Neither failure is counted as a pass.

[Bank cloud](evidence/winter-effects/bank-impact.png) and [snow trails](evidence/winter-effects/snow-tracks.png) captured and inspected on desktop. The fixture manually feeds crossing poses to presentation, with physics disabled and a diagnostic camera, so its paused HUD is not live speed/timing evidence. It tests/render-checks effect response, not a complete player-driven race. Particle variation makes captures nondeterministic visually, while snapshots are checked unchanged.

No phone test, Android export/install or GPU/thermal measurement was performed. Remaining acceptance: owner review of cloud density, chip size and trail visibility during real driving; mixed-surface/bridge joins; phone particle cost and sustained frame pacing. Snow marks follow the canonical contact height, which can differ slightly from cosmetic piled-bank crests. Existing ground texture and snowfall can reduce contrast of small white chips in a still image.

## 2026-09-25: drift spray and immediate bank response

V02/V04/V05/Q01; `winter-spray-2`. Ice drifting now uses the same chip and powder emitters and full-drift strength as off-track snow, ramping with slip angle. Straight ice driving stays clear. Bank entry is sampled along a swept elliptical body envelope including bumper overhang, independently of the tyres. Its first bank contact anchors the stationary burst. This is a presentation approximation, not a new collision shape or handling change.

Bank particles spawn together with visible initial alpha, fall under stronger gravity and disappear within 0.42 seconds (previously 1.6). Initial size and intersection fading keep the small puff visible around the bumper. The two-emitter pool and entry cooldown remain bounded. Road appearance and canonical state are unchanged.

Changed files: `game/vehicle/sand_dust.gd`, `game/core/game.gd`, `game/tests/capture_winter.gd`, this report, development status/plan and `docs/evidence/winter-response/`.

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `-Action CaptureWinter` final 153 checks, zero failures; `-Action TestSoil` 163 checks, zero failures; `-Action TestIce` 69 checks, zero failures. Capture coverage includes ice/off-track emission parity, quiet straight driving, initial burst opacity/lifetime, body-perimeter bank origin, unchanged snapshots, cooldown and biome isolation. Earlier successful captures were repeated to refine the puff and capture its early frame; the previous four-frame delay nearly outlasted the short burst on this diagnostic runner.

Desktop [ice drift](evidence/winter-response/ice-drift.png), [initial contact](evidence/winter-response/bank-contact.png), [early puff](evidence/winter-response/bank-impact.png), and [off-track trails](evidence/winter-response/snow-tracks.png) captured; early puff inspected. The synthetic crossing fixture and paused HUD are presentation evidence, not player-driven timing. The small white puff has low contrast against white banks. Owner acceptance during driving and phone performance remain outstanding. No Android export/install or physical-device test performed in this pass.

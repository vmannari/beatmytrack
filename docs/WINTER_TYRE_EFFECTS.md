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

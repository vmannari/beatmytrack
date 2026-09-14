# Tyre pushing ? 2026-09-14

Requirement G01: the owner requests stronger impact slowdown, sustained pushing of a tyre, and piles that can exceed available engine torque. Physics is now `arcade-planar-0.15`; no document/compiler change.

## Implementation

`game/vehicle/loose_tyres.gd` uses 400 kg effective stack mass (previously 260 kg) and inelastic normal contact. Ground resistance remains 24 m/s?. A fixed 16-pass contact solver shares momentum between the car and touching stacks, with a single accumulated friction budget per tyre per tick. This permits static friction to absorb a weak push, while surplus engine force moves a single stack. It replaces the previous impulse-then-friction ordering that erased each small push. Fixed-order spatial buckets bound neighbour searches; contact impulses do not depend on dictionary traversal order. Positional correction prevents the car passing through stalled stacks and limits stack overlap. Existing terrain collision and ground/bridge separation remain.

At the balanced profile's 16,500 N nominal engine force, one stack costs up to 9,600 N of ground resistance; multiple constrained stacks can exceed the available force. Actual resistance depends on contact direction, arrangement and surface traction. Stacks can spread sideways, so a loose pile is not a fixed numerical gate. These are arcade effective masses, not literal individual tyre weights.

`game/vehicle/vehicle_simulation.gd` bumps the replay physics key. `game/tests/test_tyres_and_load.gd` adds force-driven single/pile, exact-repeatability, separation, reverse escape and bridge separation checks, and strengthens the impact expectation. Existing creator tests exercise real vehicle input and JSON replay with a tyre wall.

## Measured checks

- Direct 20 m/s contact: car exits at 14.428 m/s, previously 15.634 m/s.
- Free stack launched at 10 m/s: stops in 2.042 m / 0.417 s.
- Two seconds of balanced nominal engine force minus rolling resistance from rest: single stack moves 9.308 m; six-stack column moves 0.00023 m. This isolated force fixture does not include speed-dependent engine falloff.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestTyresLoad`: initial 18 checks passed; expanded checks included in full validation below.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRefinement`: 29 checks passed before final overlap correction; final version included in full validation below.

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Validate`: passed import, 70 script parses, startup and all 947 domain/UI checks, including 20 tyre/load checks and 29 creator refinement checks. Full driving/native-track/creator replay regressions passed on Godot 4.7.2 Windows.
- `git diff --check`: passed (line-ending normalization warnings only).

## Acceptance limits

No UI or asset changes. No phone/device driving test or Android export performed; engine import reports missing Android build-tools. Manual acceptance remains impact feel, pushing at different angles, pile spreading against scenery, and performance with dense maximum-size tyre arrangements on a phone. The bounded iterative solver approximates planar stacks; it does not simulate individual rings tumbling in 3D or guarantee exact rigid contact for extreme overlapping placements. Replay equivalence is same-engine/platform only.

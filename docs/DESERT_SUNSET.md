# Desert compacted sand and sunset ? 2026-09-22

2026-09-24: [Dune ground update](DESERT_DUNES.md) replaces the loose-ground appearance; sunset, compacted road and dust behavior remain unchanged.

Requirements: G01/G03 (surface handling), R01/R03/R07 (determinism/versioning), V02/V04/V05 (biome materials, dust and lighting), Q01 (validation). Owner request makes desert roads firm sand and deliberately permits lingering visibility obstruction, overriding the older brief/unobstructive dust guideline for this biome.

## Implemented behavior

Desert structural road cells, including bridge decks and asphalt-painted road additions, use compacted sand. The compiler resolves saved dirt/asphalt road selections to the same firm road bed without modifying or deleting the source document. Road grip is 0.94 and rolling resistance is 0.35 m/s?, versus loose sand's 0.80 / 2.0 plus deep-soil wheel drag. Firm roads do not trigger soil trip/roughness penalties. Loose roadside sand retains its existing behavior. Paint and hazard objects can still cover roads deliberately.

The road has its own lighter warm sand palette and finer, lower-contrast baked mineral texture. Shared terrain, placed-road and bridge shaders use the same material behavior. No generated art or new external assets were added. Road paint/kerbs and race markings remain editable.

Grounded wheels emit dust during ordinary movement above 0.8 m/s, including straight driving and reversing, without needing a slide. Desert uses four world-space emitters, each capped at 720 particles, nine-second lifetime, larger early-growing puffs and higher opacity. The cloud continues aging after the car leaves or stops. Airborne/tumbling wheels do not emit ground dust. Other biomes retain the previous restrained profile. Dust is presentation-only and never enters replay state.

Desert sunlight is red-orange (#ff9566), 22 degrees above the ground instead of 58 degrees, with muted mauve ambient fill. This makes cast shadows approximately four times longer geometrically; existing mobile shadow quality/distance settings remain. Switching back to another biome restores the normal light angle. Gameplay camera framing is unchanged.

Contracts: physics arcade-planar-0.39, creator-compiler-19, track-kit-53. Compiler golden identity updated while keeping all geometry, route-area and deterministic round-trip checks. Physics/compiler identities separate existing local records from changed rules/content.

## Changed files

- `game/editor/track_compiler.gd`: resolve desert road beds and version content.
- `game/track/native_track.gd`: compacted-sand traction/resistance.
- `game/vehicle/vehicle_simulation.gd`: physics identity.
- `game/track/track_theme.gd`: road palette, sunset light and reset.
- `game/track/surface_detail.gdshaderinc`, `creator_road.gdshader`, `native_track_visual.gd`, `creator_bridge_visual.gd`, `bridge_presentation.gd`: shared sand rendering.
- `game/vehicle/skid_trails.gd`, `sand_dust.gd`: sand trails and desert particle profile.
- `game/tests/test_desert.gd` (+ Godot UID), `test_creator.gd`, `test_soil.gd`: desert behavior/replay, updated compiler golden, ordinary-asphalt regression fixture separated from desert override.
- `scripts/dev.ps1`: TestDesert/CaptureDesert entry points; include desert in full validation.
- `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this report and `docs/evidence/desert/*.png`.

## Commands and outcomes

All engine commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <action>` and pinned Godot 4.7.2.stable.official.ed1daf0bf.

| Action | Actual result |
|---|---|
| TestDesert | 22 checks pass, including five-car deterministic replay and actual acceleration comparisons |
| CaptureDesert | 25 checks pass; rendered desktop road/dust/persistence evidence |
| TestTracks | 167 checks pass, including legacy three-lap driving/replay/bridge fixtures |
| TestSoil | Initially two old desert-asphalt effect assumptions failed; the generic effect fixture now explicitly uses pine. All 163 checks pass, retaining the assertions |
| TestCreator | Initially old road-kind/hash expectations failed; versioned expectations updated. All 112 checks pass, with three diagnostic laps and replay in each biome |
| TestBiomes | 57 checks pass |
| TestBridgeHUD | 153 checks pass; engine reports two ObjectDB instances leaked at exit |
| Validate | Import, all GDScript parse checks, startup, driving (74), handling (88), checkpoints (122), tracks (167), extra tracks (27), editor retirement (24), placement (24), road approval (19), start line (27) passed. Stopped at the old creator expectations above; that suite was subsequently fixed and passed separately. The full remaining chain was not completed, so this is not a full-validation pass |
| git diff --check (touched tracked implementation files) | Pass; only CRLF normalization notices |

Two seconds of full throttle from rest, packed-road / loose-sand speeds in m/s: compact 25.90 / 11.88; pickup 22.33 / 13.83; classic 27.08 / 11.37; formula 26.49 / 8.14; kart 30.00 / 6.49. These are controlled desktop fixture measurements, not phone performance claims.

## Evidence and remaining acceptance

[Sunset road](evidence/desert/sunset-road.png), [emitting dust](evidence/desert/dense-dust.png), [cloud three seconds after emission stops](evidence/desert/lingering-dust.png). Captures use the actual race renderer/camera with a scripted route-following presentation fixture; they are not a manually driven timed race. Inspected on desktop.

No Android build, installation, phone driving test or device profiling was performed. Physical device connection was not checked. Owner acceptance remains for grip, red tone, shadow visibility, dust obstruction and persistence in actual racing. Nine seconds is the configured particle lifetime; visible fade depends on age and overlapping puffs. Dust has increased transparent overdraw and needs phone frame-time/thermal measurement. Cross-device replay equivalence remains unverified.

The workspace contained extensive prior uncommitted changes, including several touched files. No merge or combined commit was made; the work remains a local reviewable slice with this explicit file list.

## Reference correction: red earth and broad billows

Owner follow-up rejects the pale pink cast and supplies a rust-red sunset illustration plus a rally dust photograph. These are visual references only, not shipping assets. Requirements V02/V04/V05/Q01; handling remains physics 0.39, compiler 19. Presentation is track-kit-54.

The road base is now #934923 with warmer brown terrain, amber ambient fill replacing mauve, and #ff873c sunlight at 0.82 energy. The low sun angle remains. Desert dust growth reaches 4x at 42% of particle life and 7x at the end, versus the former 1.6x/3.65x; it expands sideways with a 110-degree emission spread, more launch velocity and less damping. Higher lift, shaded puff lobes and feathered card boundaries give the reference's billowing shape. Nine-second persistence and the 2,880-particle total cap remain; screen coverage/overdraw increase despite unchanged count.

Changed files for this follow-up: `game/track/track_theme.gd`, `game/track/native_track_visual.gd`, `game/vehicle/sand_dust.gd`, `game/tests/test_desert.gd`, this report, status/phase notes and the three desert evidence PNGs.

Actual commands through pinned `scripts/dev.ps1`: `CaptureDesert` passed 25 checks and refreshed all three screenshots; after adding growth/spread assertions, `TestDesert` passed 24 checks. `TestSoil` passed 163 checks. Desktop screenshots were inspected. No new physics change, full regression rerun, Android export, device test or profiling. Owner visual acceptance and phone frame-time/thermal checks remain. The reference is approximated with the existing sprite-particle renderer, not volumetric fluid simulation.

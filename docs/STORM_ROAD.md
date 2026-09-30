# Storm wet road (2026-09-30)

Requirements: V02/V04/V05/Q01; owner road reference and Grass edge parity request.

Kit 90 uses neutral charcoal asphalt, multiscale irregular water patches, exposed aggregate colour/normal variation and smoother water-film normals. Wet areas use GGX specular response (roughness 0.40 versus 0.82 exposed asphalt), responding to the existing storm directional light and lightning. This is direct-light sheen, not mirrored scenery or screen-space reflections. Shared material logic covers creator roads, painted/native asphalt and bridge decks. Dry materials keep zero specular. The reference is guidance only and is not a shipping asset; no external assets or dependencies added.

Storm explicitly skipped the shared asphalt fringe; it now blends into the shoulder with the same broken transition as Grass. Rounded joins, faired internal contours, tapered kerbs, worn white lines, overlap-clipped sand shoulders and grass fringe already use the shared geometry/material path. Canonical handling, road boundaries and camera remain unchanged. Incrementing the visual kit invalidates prepared road material caches.

Changed files: surface_detail.gdshaderinc, creator_road.gdshader, terrain.gdshader, bridge_road.gdshader, track_theme.gd and native_track_visual.gd under game/track; game/diagnostics/surface_material_probe.gd; game/tests/test_storm.gd; scripts/dev.ps1; status/phase notes and this evidence. Existing unrelated bridge diffuse-lighting work is retained.

Actual commands (pinned Godot 4.7.2 via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`):

- `CaptureStorm`: baseline exposed an outdated test expecting Grass sunlight 1.0. Updated to the approved current 1.2; weather cleanup assertions remain intact.
- `CaptureStorm -Track track_acf29166cceaaa42`: final 55 checks, zero failures; wet handling/replay, weather lifecycle and actual graphical shader compilation. Track is loaded read-only and themed Storm in memory. Rain and lightning images inspected.
- `TestShoulders`: overlap/nearest-road regression plus 71 join and 18 contour checks pass, canonical cells/contacts retained.
- `TestSurfaceProfile`: initially failed shader compilation because historical/flat debug variants lacked the new helpers/coverage variable. Added explicit compatibility stubs and flat coverage; final 928 checks, zero failures, no shader errors.
- `git diff --check`: passed (line-ending notices only).

[Rain](evidence/storm-road-2026-09-30/rain.png) / [Lightning](evidence/storm-road-2026-09-30/lightning.png). The before.png uses the old default terrain fixture, so is not a geometry-matched before/after comparison.

No Android export or physical-device test performed; device attachment was not checked. Owner visual acceptance, moving-camera shimmer and mobile GPU cost remain to be checked. Puddle evaluation adds bounded texture/noise work, without extra lights, geometry or reflection passes. Bridge material compiles through the shared include, but a dedicated wet-bridge visual capture remains outstanding.

## Owner rejection and revision 2

The owner rejected kit 90's high-contrast blue patches. Its passed technical tests did not establish visual acceptance. Kit 91 replaces thresholded multiscale coverage with a wider continuous water-film mask, uses neutral charcoal, limits wet/dry pigment difference to 12%, bounds fine aggregate colour variation, and moves grain into roughness. Specular now ranges 0.16-0.30; roughness has a 0.70-0.36 base range with bounded grain. Tiny normal relief replaces the too-strong relief that produced speckled lighting. Grass road edges remain enabled. No camera, weather timing, simulation or mesh changes.

Changed: shared surface include, creator/terrain/bridge road shaders, storm palette, visual kit version, status/plan and this document. The existing uncommitted bridge Lambert change is preserved separately.

Actual verification: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureStorm -Track track_acf29166cceaaa42` run during visual iteration; final 55 checks pass. `TestSurfaceProfile` final 928 checks pass without shader errors. `git diff --check` passes. Same-fixture final rain and lightning captures inspected. An intermediate dark/plain result and an over-grained result were revised before saving final evidence.

[Revised rain](evidence/storm-road-2026-09-30/revision-2/rain.png) / [Revised lightning](evidence/storm-road-2026-09-30/revision-2/lightning.png). Compare the preceding revision's same-track captures above. The resulting wetness is deliberately more gradual; this is not a claim of an exact reference match or owner acceptance. Direct-light sheen remains, without reflected scenery. No Android export or physical-device test; moving-camera stability and phone performance remain unverified.

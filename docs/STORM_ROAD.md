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

## Wet sheen follow-up (kit 92)

The owner preferred revision 2's appearance but requested more wetness. Preserve its palette, albedo detail, broad film coverage and shared Grass edges. Wet roughness now reaches 0.18 before bounded grain (minimum 0.15), and specular reaches 0.55. A view-direction/Fresnel overcast reflection approximation adds soft silver sheen with filtered elongated surface variation. It is composited through EMISSION for Compatibility; this is an approximation of ambient reflected light, not a reflection of actual nearby scenery, and it does not illuminate other objects. The existing direct specular response receives lightning. The ambient reflection approximation stays at its overcast strength during lightning. Dry road, grass, markings and shoulders receive zero contribution; creator fringe weight tapers it away.

Shared include/material changes cover creator, painted/native and bridge asphalt. Camera, canonical state, weather brightness and accepted base asphalt texture are unchanged. No new assets, runtime dependencies, additional light, cubemap or capture pass ships.

Implementation exploration: an environment cubemap path initially used incorrect enum names, then exposed two GL texture-leak errors at shutdown after correction; removed it. A RADIANCE override compiled but did not provide the required visible response in these Compatibility captures, so the final implementation uses the bounded additive reflection approximation. No sky environment changes remain. Godot's documented shader outputs were checked at https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html and reflected-light behavior at https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html.

Changed files: game/track/surface_detail.gdshaderinc, creator_road.gdshader, terrain.gdshader, bridge_road.gdshader, native_track_visual.gd; game/tests/test_storm.gd; game/diagnostics/surface_material_probe.gd; status/phase notes and evidence. Earlier unrelated bridge Lambert work remains separate.

Actual commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `CaptureStorm -Track track_acf29166cceaaa42`: final 59 checks, zero failures/errors. Includes actual race wet-material bindings plus existing replay, grip and weather checks. Rain/lightning captures inspected; stronger exploratory sheen was reduced before saving final evidence.
- `TestSurfaceProfile`: 928 checks, zero failures/errors; historical/flat diagnostic variants have a zero-reflection compatibility helper.
- `git diff --cached --check`: passes.

[Wet road](evidence/storm-road-2026-09-30/revision-3/rain.png) / [Lightning](evidence/storm-road-2026-09-30/revision-3/lightning.png). Owner review of sheen strength remains. No phone/device test or Android export; physical-device frame pacing and moving-camera acceptance remain outstanding. Device attachment was not checked. Dedicated wet bridge imagery remains outstanding.

## Readable water highlights (kit 93)

The owner again found revision 3 too subtle to read as wet. The accepted neutral asphalt and shared road edges remain. Kit 93 adds a stronger, broken reflection band over shallow-wave slopes, reduces visible aggregate grain in pooled water and adds sparse expanding road-plane rain rings. Highlights are visibly distinct at the 1280x720 gameplay capture scale. Their first high-frequency prototype looked scratched, so the wave scales were broadened before final evidence.

The existing StormWeather presentation clock and flash strength now feed a vec2 shader global. Rain rings freeze during pause; they do not use shader TIME or access the simulation. Lightning scales the wet reflection term by up to 1+1.8*flash_strength; weather teardown resets the global. Static/editor Storm materials default to time zero. This is a stylized reflected-light approximation composited through EMISSION, not ray tracing or reflections of nearby cars/trees. The shared helper covers creator/native/bridge road materials without additional geometry, lights or render passes. Shader pixel cost increases; mobile cost remains unmeasured.

Changed files: game/track/surface_detail.gdshaderinc, game/track/storm_weather.gd, game/track/native_track_visual.gd (kit 93), game/project.godot (shader global), this document/evidence and status/phase notes. Canonical physics, camera and road-edge geometry are unchanged.

Actual checks through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `CaptureStorm -Track track_acf29166cceaaa42`: final 59 checks, zero failures and no shader errors. Existing handling/replay/weather pause tests pass. Final normal rain, lightning and 1.2-second-later captures manually inspected. The shader clock is updated from the same pause-gated weather path; no additional automated pixel-freeze assertion was added.
- `TestSurfaceProfile`: 928 checks, zero failures and no shader errors.
- `git diff --check` and `git diff --cached --check`: pass (line-ending notices only).

[Previous](evidence/storm-road-2026-09-30/revision-3/rain.png) / [Stronger wet surface](evidence/storm-road-2026-09-30/revision-4/rain.png) / [Lightning](evidence/storm-road-2026-09-30/revision-4/lightning.png) / [Later rain](evidence/storm-road-2026-09-30/revision-4/rain-later.png).

Owner acceptance of this stronger treatment remains outstanding. No physical-phone test or Android export performed; attachment not checked. Moving-camera aliasing, mobile GPU/frame pacing and dedicated bridge imagery remain unverified. Passing regression tests is not visual acceptance.

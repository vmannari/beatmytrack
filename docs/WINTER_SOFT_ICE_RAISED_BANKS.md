# Softer pale ice, raised banks and slender stakes — 2026-10-11

The owner accepts the previous direction as better and asks for weaker road threads, a slight shift toward white, more prominent snowbanks and narrower/taller red poles. This is a small local presentation adjustment; appearance remains subject to owner/device review.

Requirements WE17 (softer, paler directional ice), WE18 (more prominent blended banks), WE19 (slender taller poles), plus WE13–WE16, WE10, V04/V05, G01/R01 and Q01.

## Files and changes

- `game/track/winter_ice.gdshaderinc`: original directional artwork retained. Luminance grain contribution decreases 0.30→0.16 (47% lower); base colour changes from (0.33,0.405,0.49) to (0.385,0.445,0.51), lifting red/green more than blue for a slightly paler, less blue ice tone.
- `game/track/surface_detail.gdshaderinc`: static road-aligned polished paths fade from 0.13/0.07 to 0.07/0.04. Road-coordinate micro-slope strength decreases 0.12→0.09. Actual driven tire marks, original road coordinates, texture assets, terrain and wind behavior are retained.
- `game/track/native_track_visual.gd`: `track-kit-121` invalidates visual caches. Nominal crest increases 0.48→0.68 m, with slightly stronger natural variation (0.20/0.08 versus 0.18/0.07). Embedded deposits rise from 0.16–0.304 to 0.21–0.366 m. The same broad matching-snow apron and buried −0.065 m foot remain; no added rings, triangles, deposits or draws. Physical snowbank contact geometry is unchanged.
- `game/track/winter_scenery.gd`: marker body changes 0.09×1.20×0.09 to 0.06×1.90×0.06 m, with slim white reflective bands at 1.50/1.74 m and a narrower buried foot. Stakes are 58% taller and one-third narrower. Existing 18 m outer/28 m inner spacing, bridge clearance, instancing and 40-stake cap remain.
- `game/tests/test_winter_environment.gd`: only the diagnostic output directory changes to preserve previous evidence. No new tests or weakened assertions are introduced for these appearance values.

No camera, canonical simulation, compiler, collision generator, lap/scoring/backend, wind speed/audio, new texture/model/provider or runtime service changes. Earlier compiler-23 rollout requirements remain; this adjustment adds no contract change or deployment.

## Actual verification and evidence

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1` with process execution policy Bypass and normal Windows certificate-store access:

| Actual command | Result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--video')` | Compatibility 98 checks, 0 failures. Actual canonical diagnostic driving, bank/terrain endpoint, spacing, editor/scenery lifecycle and immutable simulation/cells checks retained. |
| Same, `-Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture')` | Mobile Vulkan 97 checks, 0 failures. |
| `test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video','--output-dir=res://../docs/evidence/winter-soft-ice-raised-banks-2026-10-11/wind-validation')` | Compatibility 47 checks, 0 failures. Static 723 / moving 761–751–750 opaque roof samples unchanged; AA interiors 557–555–547 exact. Lit delta 1022.831; dark delta 0. |
| Same, Mobile Vulkan and `--output-dir=.../wind-validation-mobile` | 47 checks, 0 failures. Static 743 / moving 771–758–759 opaque roof samples unchanged; AA interiors 596–597–580 exact. Lit delta 497.800; dark delta 0. |
| Android SDK `adb.exe devices` | Empty device list. No phone/device test performed. |

The actual compact scene retains 372978 submitted primitives and 314 Compatibility / 330 Mobile draws, exactly matching the previous fixture counts. Wind still adds three draws with 506–578 triangles; desktop presentation loops measured roughly 12–13 µs in these runs. Raw GPU measurements are noisy desktop smoke evidence, not measured Android efficiency. Taller banks cast more visible shadows without a geometry-count increase.

[Actual driving preview](evidence/winter-soft-ice-raised-banks-2026-10-11/driving.png), [150-frame motion](evidence/winter-soft-ice-raised-banks-2026-10-11/driving-motion.html), [material-only bend](evidence/winter-soft-ice-raised-banks-2026-10-11/materials.png), [rotated view](evidence/winter-soft-ice-raised-banks-2026-10-11/rotated.png), [Mobile bend](evidence/winter-soft-ice-raised-banks-2026-10-11/mobile/bend.png). Previous driving image/source snapshots and actual command logs are retained beside the new captures. Existing original artwork/native geometry provenance remains.

Restart the client to load `track-kit-121`. Remaining acceptance: owner appearance on the supplied track and full laps, slim pole readability at phone resolution, taller-bank shading/wind intersections in other bends/camera modes, Android frame time/thermals and touch play. No Android export/install, full Validate, application/backend suite rerun, live writes or production deployment was performed. Task-only checkpoint: `build/winter_polish/checkpoint-repo`; main branch/index and unrelated work are preserved.

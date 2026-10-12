# Directional Winter ice, integrated banks and restored terrain — 2026-10-11

The owner rejects the world-space v2 road texture, hard bank-to-terrain seam, faceted deposit ring, dense inner-curve stakes and added cloudy terrain shading. This local presentation revision uses the retained original directional ice artwork, restores the original snow detail and changes the bank construction and pole placement. Appearance remains subject to owner review; no AAA-quality claim is made.

Requirements WE13 (road-aligned original ice refinement), WE14 (integrated sculpted banks), WE15 (original snow terrain), WE16 (sparser poles), plus WE09/WE10, V04/V05, G01/R01 and Q01.

## Changes

- `game/track/native_track_visual.gd`: visual cache version `track-kit-120`; selects existing `winter_ice_v1.png` and a new numerical finish map. Existing road tessellation already assigns metres along/across each road piece, including spline bends. The bank now has a compact variable crest and a 3.6–5.2 m outer apron, which descends to −0.065 m under the −0.06 m creator terrain, with a flat outer slope. The old repeated angular clods are replaced by at most 240 irregular rounded embedded piles with interpolated vertex normals. The bank uses the road mask to prevent the apron covering another lane at narrow islands/junctions.
- `surface_detail.gdshaderinc`, `winter_ice.gdshaderinc`, `creator_road.gdshaderinc`, `bridge_road.gdshaderinc`: the original ice artwork is sampled in road coordinates (5 m across / 9 m along); grain follows the curve and rotated bridge. Cool colour and modest contrast refine the original image. The finish map shares those coordinates, and its micro-slope is transformed by the actual road UV Jacobian. Existing wheel wear remains. Standalone painted/native asphalt retains its original world-space fallback; this correction directly covers authored road pieces, splines and bridges.
- `surface_detail.gdshaderinc`: restores the original two-scale snow artwork and removes the added three-sample terrain normal field. A uniform 0.82 tint restores brightness under the retained lower warm sun without an extra blue tint or cloud-like normal shading.
- `winter_bank.gdshader`: uses the same `snow_detail()` function as the ground. Crown colouring fades back to exactly the surrounding snow; outward normals flatten and the mesh meets the ground below its surface. Bank toes use the same road-aligned ice sampling as the road. Near-road slope variations and embedded deposits remain visible, with no continuous hard outer lip.
- `winter_scenery.gd`: replaces one-stake-per-12 m square bucket with actual distance spacing. Ordinary/outer same-side spacing is at least 18 m; inside-curve spacing is at least 28 m. Opposite banks retain a 7.5 m clearance; all stakes still follow prepared bank geometry, skip bridges and are capped at 40. The oval review fixture has 18 stakes.
- `game/tests/bake_winter_ice_finish.gd`: `--original-road` produces `game/assets/textures/winter_ice_finish_v3.png` from unchanged original artwork. Numerical R/G slopes, B frost and A roughness share one 512×512 mipmapped texture; there is no runtime generation or new albedo. Old v2 assets are retained but no longer selected for the road.
- `test_winter_environment.gd`: reuses existing canonical driving, editor selection/deletion and alternate spline/bridge fixtures; adds meaningful spacing and bank-ground endpoint checks, original/rotated camera captures and actual imported-image budget checks. `test_winter_snow_wind.gd` gains an explicit diagnostic output directory so previous evidence is preserved.

No compiler, scenery collision generator, canonical bank-contact geometry, car forces, lap rules, camera settings, wind speed/audio, scoring or backend behavior changes in this revision. Existing compiler-23 rollout limitations from the earlier environment pass still apply; this work introduces no further contract change or live migration. Source hashes are retained in `asset-and-contract-receipt.json`.

## Actual commands and results

All Godot commands use `scripts/dev.ps1` and pinned Godot `4.7.2.stable.official.ed1daf0bf`, with process execution policy Bypass and normal Windows certificate-store access.

| Actual command | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/bake_winter_ice_finish.gd -TestArgument @('--original-road')` | Finish map generated at 512×512. Expected raw-image/export warning is confined to this offline tool. |
| `-Action Import` | New finish map, shader changes and typed scripts imported successfully. |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--video')` | Final Compatibility 98 checks, 0 failures; bank endpoint/marker spacing, original texture dimensions/mips, actual simulation snapshot/cells, solid/editor lifecycle and spline/bridge clearance preserved. |
| Same, `-Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture')` | Mobile renderer 97 checks, 0 failures. |
| `test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video','--output-dir=res://../docs/evidence/winter-directional-blend-2026-10-11/wind-validation')` | Compatibility 47 checks, 0 failures. Static 723 / moving 761–751–750 direct roof samples unchanged; normal-AA interior 557–555–547 exact. One mixed silhouette sample changes at frame 0; opaque interiors remain exact. Lit snow delta 1095.898, dark delta 0. |
| Same, Mobile Vulkan and `--output-dir=.../wind-validation-mobile` | 47 checks, 0 failures. Static 743 / moving 771–758–759 roof samples unchanged; normal-AA interior 596–596–580 exact. Lit delta 683.565, dark delta 0. |
| `-Action TestApp` | 99 checks, 0 failures. |
| `-Action CaptureWinterBridge` | Two views saved; collision cells preserved. Road grain follows the bridge span. |
| Python exact-byte comparisons of the compiler/scenery sources and SHA-256 receipt | Canonical source files remain exact; original v1 ice hash unchanged. |
| Android SDK `adb.exe devices` | Empty device list. No phone/device test performed. |

The first integrated-bank draft was too subdued; the crest/deposits were raised while the outer foot stayed buried. An initial snow brightness adjustment overemphasized blue/crown highlights; the final uniform tint and 1.03 crown gain restrain them. Final compact inspection scene submits 372978 primitives, versus 393228 in the previous same fixture, with 314 Compatibility / 330 Mobile draw calls. Wind still adds three draws and a fixed 506–578 triangles. Raw desktop render timings are noisy and are not an Android performance result or a guaranteed frame-budget improvement.

## Evidence and provenance

- [Actual driving](evidence/winter-directional-blend-2026-10-11/driving.png), [150-frame driving motion](evidence/winter-directional-blend-2026-10-11/driving-motion.html), [bend](evidence/winter-directional-blend-2026-10-11/bend.png), [material-only view](evidence/winter-directional-blend-2026-10-11/materials.png), [rotated view](evidence/winter-directional-blend-2026-10-11/rotated.png), [compact gameplay](evidence/winter-directional-blend-2026-10-11/compact.png).
- Mobile captures, actual bridge views, paired light/roof/wind sequences, source snapshots and command logs are retained in the same evidence directory. Inspection cameras are evidence-only; gameplay framing is unchanged.
- Original road artwork SHA-256: `59c8ad78ae86f0ec9fe5a68daf03a1c78278747831956b74857bf400de7beaa8`. New finish-data SHA-256: `0a18443953123bcef53aff499cb681867a88bf5ebd4763d085ec234108767277`. Existing artwork provenance remains; the new map is original mathematical data, not copied reference pixels or new AI artwork. No new model, provider, dependency or runtime service.

Restart the client to load `track-kit-120`. Owner appearance review on the supplied circuit, closely spaced bends, different camera angles/zoom and full-race wind/tire visibility remains. Low-end Android frame time/thermals, touch driving and real-device material/shadow consistency are not tested. No Android export/install, full project Validate, backend suite rerun, production deploy or online writes were performed. Prior pinned-contract rollout requirements remain separate from this visual correction.

One task-only checkpoint is stored in `build/winter_directional/checkpoint-repo`, preserving unrelated ongoing changes and the main branch/index.

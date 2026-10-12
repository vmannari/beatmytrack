# Winter banks, irregular snow edge and icy road

2026-10-11 local presentation revision, `track-kit-132`. Supersedes the bank profiles in [the previous polish pass](WINTER_SOFT_ICE_RAISED_BANKS.md). The owner's latest corrections reject a smooth road/bank boundary and request actual PC performance checks. The supplied reference is direction only; no reference pixels or new generated assets are shipped.

| Requirement | Delivered behavior |
| --- | --- |
| WE20 / V04 | Original directional ice artwork retained; fine crystalline abrasion and lower bare-ice roughness refine the surface without strengthening its broad threads. |
| WE21 / V05 | Road-to-snow uses Grass's existing `shoulder_fringe` method, with larger irregular deposited-snow tongues and a broader white edge. Actual authored widths follow tapers, splines and batched creator bridges. |
| WE22 | Connected banks have varying crests and broad aprons buried below the terrain, using exactly the ground's original snow material. Overlapping, mostly buried deposits replace separate large beads. |
| WE23 | The physical presentation mesh's road-side toe varies in position. Small shallow clods extend onto the ice and interrupt its silhouette; fine colour blending alone no longer defines a circular edge. |
| WE24 | Actual 1080p/4K driving profiles, indexed bank buffers, snow-only shading and exact cached bank rows. Cold Slippery road construction falls from about 7.7 to 3.4 seconds with byte-identical complete road mesh buffers; see [the performance report](WINTER_PERFORMANCE.md). |
| G01 / R01 / Q01 | Bounded cached meshes and opaque shading, actual renderer captures/checks, canonical separation and retained pole spacing. |

## Files

- `game/track/native_track_visual.gd`: width metadata survives road triangulation and flat-normal rebuilding through a packed vertex-colour attribute. Half-byte rounding fixes 8-bit truncation. Build-time seeded FastNoiseLite varies bank footprints and heights; no noise generation runs per frame. Deposits are capped at 80 clusters of three lobes (the existing maximum 240 lobes), with one shallow toe clod and two overlapping crown masses. Bank corners are indexed and each road piece reuses exact coordinates and nine-point rows during construction. Visual-cache version advances from the concurrent Night baseline's 122 to 132; the Night light-sized road partition work is preserved.
- `game/track/surface_detail.gdshaderinc`: road-aligned fine abrasion, width-aware frost with metre-scale irregularity, and shared Grass fringe blending. The original `winter_ice_v1` and restored `winter_snow_v1` bytes remain unchanged.
- `game/track/winter_bank.gdshader`: irregular deposited-snow coverage joins road ice to the matching ground snow. Opaque terrain/road masks prevent spill across adjacent lanes and authored overlays. The bank receives the same settled-snow factor texture as the road. Fine breakup ends at the snowy crest; snow-only areas skip road texture sampling and match the outer terrain.
- `game/track/creator_road.gdshaderinc`: decoded authored width drives frost colour and finish. Bare ice is smoother; edge snow becomes rougher and less reflective.
- `game/track/creator_bridge_visual.gd` and `bridge_road.gdshaderinc`: each Winter bridge writes its actual half-width into UV2, retaining one batched deck. The same directional frost/finish uses that width. Snow artwork is bound explicitly, preventing the new frost mix from sampling an empty snow texture.
- `game/track/bridge_presentation.gd`: also binds snow artwork for legacy native Winter decks. Their existing 5 m width fallback is retained; retired native fixtures are not a new creator contract.
- `game/track/terrain.gdshaderinc`: bare ice receives the same refined finish values.
- `game/tests/test_winter_environment.gd`: exercises the real 6-to-14 m taper mesh/material pipeline and two differently sized batched bridge decks. Optional `--edge-debug` captures the actual frost mask and restores materials afterward; no diagnostic UI is added to the product.

Snow texture, lighting, sparse/tall poles, wind speed/audio and camera framing retain the previous accepted adjustments. No compiler, physical bank/collision geometry, handling, gates, laps, scoring, backend or content-contract change. Earlier compiler-23 rollout limitations remain; this pass performs no rollout.

## Actual checks and evidence

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, invoked with `Set-ExecutionPolicy -Scope Process Bypass; & ./scripts/dev.ps1` and normal certificate-store access:

| Actual arguments | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--edge-debug','--video','--fresh-roads')` | Compatibility: 101 checks, 0 failures. Actual taper widths decode to 3.011765/7.027451 m after rebuilding; batched bridges preserve 3/7 m. Fresh bank construction is exercised instead of restoring an artifact. |
| Same script, `-Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture','--edge-debug','--fresh-roads')` | Mobile Vulkan: 100 checks, 0 failures. |
| `-Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video','--output-dir=res://../docs/evidence/winter-frost-fringe-2026-10-11/wind-validation')` | Compatibility: 47 checks, 0 failures. Static 723 and moving 761/751/750 opaque roof samples unchanged; lighting-dark delta zero. |
| Same wind script, Mobile Vulkan and `--output-dir=.../wind-validation-mobile` | 47 checks, 0 failures. Static 743 and moving 771/758/759 opaque roof samples unchanged; lighting-dark delta zero. |
| `-Action CaptureWinterBridge` | Two actual overpass views saved; collision cells unchanged. |
| `-Action TestApp` | 99 checks, 0 failures. |
| Android SDK `adb.exe devices`, normal Windows access | Empty attached-device list; no phone/device test. Initial restricted call could not create its Android directory; normal access resolved the read-only device check. |

Initial taper assertions exposed 8-bit truncation; rounding was fixed and their tolerance retained. The optional mask capture initially attempted `bool(null)` for unrelated materials; explicit flag comparison fixed it. A noisier bank prototype produced repeated dark grooves in actual renders and was replaced by larger, lower-frequency connected masses. Those prototypes are not the final appearance.

The final compact fixture submits 379998 primitives versus the previous 372978 (+7020, about 1.9%). Draws remain 314 Compatibility / 330 Mobile. Wind remains three draws; desktop presentation loops measured about 12–14 microseconds. This is desktop regression evidence, not an Android frame-time claim. No new runtime particles, texture assets, transparent passes or services are introduced.

[Final material-only bend](evidence/winter-frost-fringe-2026-10-11/materials.png), [actual driving](evidence/winter-frost-fringe-2026-10-11/driving.png), [150-frame motion](evidence/winter-frost-fringe-2026-10-11/driving-motion.html), [rotated bank view](evidence/winter-frost-fringe-2026-10-11/rotated.png), [Mobile material view](evidence/winter-frost-fringe-2026-10-11/mobile/materials.png), [frost-mask diagnostic](evidence/winter-frost-fringe-2026-10-11/edge-mask-diagnostic.png), [actual bridge](evidence/winter-frost-fringe-2026-10-11/bridges/gameplay.png). Before source snapshots, command logs and source/checkpoint receipts are stored beside the evidence.

Restart the client to invalidate earlier prepared worlds. Remaining acceptance: owner review on the supplied track and full laps, shallow toe/clod contact in the selected camera modes, very narrow/overlapping creator shoulders and authored surface changes, Android frame time/thermals and touch play. Reference-level appearance is not asserted by these tests. No Android export/install, full Validate, canonical physics regression, backend test/deploy or live writes were performed. Task-only Git checkpoint and patch live in `build/winter_frost/checkpoint-repo` and `build/winter_frost`; the main index/branch and unrelated work are preserved.

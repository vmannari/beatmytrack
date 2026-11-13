# Track asset simplification investigation — 7 November 2026

Selective simplification is worthwhile. The strongest prototypes are the ice-car sculpture, snow castle and shipping container: their first reduced levels remove approximately 50%, 50% and 61% of model triangles while retaining the main appearance in the inspected racing views. These are candidates for a production pass, subject to owner acceptance and in-game motion checks. This task changes no production scenery model or builder.

## Scope and requirements

TAS01 inventories the actual current catalogue and its production construction paths. TAS02 tests offline index-only detail levels without changing original vertex attributes or materials. TAS03 reviews native appearance at racing scale and enlarged scale, retains negative results and distinguishes geometry counts from performance measurements.

The inventory covers all 58 `CreatorObjects.KINDS` identifiers in all five biomes: **290 combinations**. Dirt and water have no separate placed-object mesh in this path. Placements use default scale, rotation and section span. Visible active meshes and MultiMesh instances are counted; hidden breakable phases, inactive debris and contact-lighting overlays are excluded. This is a per-object catalogue study, not a population-weighted estimate for any particular track.

Twelve representative assets receive native comparisons in Compatibility/OpenGL and desktop Mobile/Vulkan. Each has two opposite 56-degree racing views at the existing `35 / 1.15` orthographic extent and two enlarged inspection views, rendered at 1280×720 with 4× MSAA and directional shadows. The warehouse additionally uses neutral inspection lighting: isolated Night lighting was too dark to judge its structure. Its original dark captures are retained under `initial-night-lighting/`.

## Measured candidates and rejected reductions

These are referenced **model triangles**, before outline/other rendering passes. The reduced column is the first generated detail level forced for inspection, not a production setting. It can already be much too aggressive.

| Asset | Current | First reduced level | Reduction | Assessment from these captures |
|---|---:|---:|---:|---|
| Ice-car sculpture | 7,908 | 3,954 | 50.00% | Strong candidate; main contours and ice/snow finish remain very close at racing scale. |
| Snow castle | 7,950 | 3,974 | 50.01% | Strong racing candidate; tower edges and shading differ slightly. Retain original geometry for close inspection. |
| Shipping container | 7,782 | 3,050 | 60.81% | Strong racing candidate; corrugation, silhouette, logo and broad rust markings remain readable. Fine hardware changes need close-view protection. |
| Abandoned warehouse | 9,790 | 4,832 | 50.64% | Reject this automatic candidate: roof truss diagonals disappear under useful inspection lighting. Preserve those braces in any authored reduction. |
| Pine tree | 1,550 | 672 | 56.65% | Reject this level for ordinary near scenery: needle sprays and branch layering are visibly lost. A gentler, foliage-aware level may work. |
| Parked car | 2,976 | 1,260 | 57.66% | Silhouette remains; wheel centres and trim disappear. Requires protected wheels/trim or farther-only use. |
| Igloo | 6,926 | 3,430 | 50.48% | Reject this candidate: block/roof transitions and shading degrade. |
| Egyptian pyramid | 6,988 | 1,354 | 80.62% | Reject: large areas of masonry courses vanish. |
| Egyptian column | 3,708 | 590 | 84.09% | Reject: capital and ornamental shape are removed. |
| Grandstand | 4,720 | 838 | 82.25% | Reject: seats and open structure are lost. |
| Wooden crate | 2,121 | 56 | 97.36% | Reject: planks/strapping become a plain box. |
| Tyre wall, default six paired stacks | 7,200 | 7,200 | 0% | Automatic index LOD produces no reduction. A separate radial-sampling prototype is needed; retain open beads and movable-instance behaviour. |

The historical hidden-face study already removed 2,507 triangles / 2.95% from its then-current catalogue, with exact native pictures. Repeating only that technique is unlikely to produce the larger reductions sought here. This review uses the newer catalogue, so its model counts must not be substituted for the 16 October totals.

## Automatic selection versus a forced prototype

With the native viewport's one-pixel LOD threshold, only the ice-car sculpture reduces visible main geometry in these racing views: renderer-reported visible primitives change **7,922 → 3,968** in both renderers. The additional 14 primitives belong to the isolated stage. The original close-view geometry returns automatically.

Most other models retain their full visible geometry at that threshold. Some shadow rendering changes even when reported visible primitive counts remain unchanged. Simply running the same automatic process across every prop therefore does not deliver the forced-level savings shown in the table. Lowering a global threshold until those levels appear would expose the rejected shape losses.

Adding reduced index buffers also retains the original vertices and original indices. It is not a storage/RAM reduction by itself. Across the three strongest prototypes, the generated LOD index payloads add 27,900 bytes for the ice sculpture, 44,076 for the castle and 32,466 for the container. The existing generic cache estimator counts base streams, not these additional buffers; any production integration must account for them explicitly within the existing budgets. Shader-compilation cost, draw calls, track loading and device FPS have not been shown to improve.

## Recommended production approach

Start with the three strong candidates and retain the original near detail. Prepare reduced resources offline or once within the existing bounded immutable preparation path; do not run simplification during a race. Validate the intended transition distances against the current overhead, lower Follow car and speed-zoom views, higher device resolutions, shadows and camera motion.

Protect distinctive small structures before extending the pass: warehouse truss braces, grandstand seats, Egyptian courses/capitals, crate planks, foliage tips, tyre openings and car wheels. Author a gentler intermediate mesh where the generator jumps directly to a destructive level. Do not accept a percentage reduction merely because the silhouette's bounding box survives.

Static props are currently joined into material-family meshes and spatial draws; Winter nature and movable tyres use instancing. An asset's reduced indices will not automatically survive those joins. Integrate and verify reduction before compatible batching, or carry per-object levels through the prepared family/chunk pipeline while preserving current draw grouping and object-order rules. Keep independent movable/damage-phase geometry, immutable cache keys, retained editor models and original thumbnails fenced. Do not introduce one draw per prop to obtain a lower triangle count.

Roads, bridges, displaced terrain and snow/sand banks are not approved for reduction by this investigation. Their silhouettes, drivable edges, intersections, UVs and surface-dependent deformation require a separate study. No collision, document, checkpoint, physics or rules change is warranted by these cosmetic findings.

## Evidence and reproducibility

- [Inventory and structural checks](evidence/track-asset-simplification-2026-11-07/inventory/report.json).
- [Compatibility measurements](evidence/track-asset-simplification-2026-11-07/gl_compatibility/report.json) and [Mobile measurements](evidence/track-asset-simplification-2026-11-07/mobile/report.json).
- [Recommended racing comparisons](evidence/track-asset-simplification-2026-11-07/gl_compatibility/recommended-racing-comparison.png), [additional racing comparisons](evidence/track-asset-simplification-2026-11-07/gl_compatibility/comparison-0-race_front.png), [enlarged comparisons](evidence/track-asset-simplification-2026-11-07/gl_compatibility/comparison-0-close_front.png) and [rejected racing comparisons](evidence/track-asset-simplification-2026-11-07/gl_compatibility/comparison-1-race_front.png).
- [Pixel observations](evidence/track-asset-simplification-2026-11-07/pixel-observations.json) count pixels changing by more than eight channel levels. These measurements support inspection; they are not automatic appearance-acceptance thresholds.
- [Audited source snapshot](evidence/track-asset-simplification-2026-11-07/audited-source-snapshot.zip) and [source hashes](evidence/track-asset-simplification-2026-11-07/source-manifest-final-start.json) preserve the reviewed inputs. The shared car simplifier changed concurrently to reorder LOD indices for cache locality; a task-owned copy freezes its reviewed implementation for final runs. That concurrent change is not part of this task.

Reproduce with pinned `4.7.2.stable.official.ed1daf0bf`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-asset-simplification-2026-11-07/run_review.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-asset-simplification-2026-11-07/review_images.ps1
```

The runner invokes `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_track_asset_simplification_2026_11_07.gd` for headless inventory and each graphical renderer. Every engine launch uses `scripts/run_no_crash_dialog.py`. Each run has private workspace APPDATA/LOCALAPPDATA and a loopback-unavailable backend URL; no App/authentication/backend flow is invoked.

The [final receipt](evidence/track-asset-simplification-2026-11-07/receipt.json) records actual check counts, log paths and source stability. Every native case restores its original mesh after the automatic and forced alternatives, then requires an exact original-image match. Passing structural/restoration checks do not make an intentionally degraded prototype visually acceptable.

| Final actual run | Cases | Checks | Failures |
|---|---:|---:|---:|
| Headless catalogue/immutable geometry | 290 | 852 | 0 |
| Compatibility native comparisons | 48 | 85 | 0 |
| Desktop Mobile native comparisons | 48 | 85 | 0 |
| Total | 386 | 1,022 | 0 |

The two renderers retain 288 original/automatic/forced captures and 96 exact original-restoration controls. The frozen final source manifest is unchanged across the three final runs. Desktop rendering uses the local RTX 3090; it does not establish Android performance or appearance acceptance.

Retained initial findings: restricted engine startup failed to read the certificate store and reported Access denied; local engine execution then succeeded outside the sandbox. The first inventory harness called an ArrayMesh-only method on a BoxMesh and was corrected to inspect mesh arrays. An optional two-value PowerShell `-File` argument arrived as one string and produced an empty diagnostic run; it is not counted as qualification, its receipt is retained, and the harness now rejects empty reviews. Initial image composition selected an integer scaling overload and was corrected to use a floating-point scale. System Python and the checked backend virtual environment lacked Pillow; the retained image reviewer uses Windows System.Drawing instead. No assertions or acceptance limits were relaxed.

Changed files are the investigation script, its frozen test helper, this report and the evidence/runner scripts. The standard development entry point also refreshes generated build identity. Production track sources, owner saves, running owner processes, main Git index and concurrent work are preserved. A task-only source checkpoint is included with the final receipt.

No physical-device query or test, APK/export/install, live/backend request or deployment was performed. Production integration, full-track and in-motion verification, owner visual acceptance and device performance/memory qualification remain.

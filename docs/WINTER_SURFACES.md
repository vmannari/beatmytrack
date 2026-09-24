# Winter road, snowbanks and ground

## Owner colour adjustment: kit 76

2026-09-24, V02/V04/V05/Q01. Road pigment moves toward neutral icy white: shared `winter_ice.gdshaderinc` replaces blue artwork colour with luminance-only detail around linear RGB (0.47, 0.48, 0.49). The same helper covers creator roads, raster roads and bank transitions. Subdued grain remains; geometry and handling are unchanged. `native_track_visual.gd` increments the visual kit; `capture_winter.gd` saves new evidence without overwriting previous captures.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureWinter`, pinned Godot 4.7.2: 11 checks, zero failures. [Driving capture](evidence/winter-white/driving.png) inspected; [hairpin capture](evidence/winter-white/bend-detail.png) also saved. `git diff --check` passes. No Android export or physical-device test performed; owner colour approval and phone review remain. No new assets generated. Status/plan and this report updated; unrelated concurrent menu work excluded.


## Owner refinement: kit 75

2026-09-24, V02/V04/V05/Q01. Owner requested less distracting road detail and banks closer to the original ploughed-snow reference. A shared pigment function retains 28% of ice artwork contrast around a muted blue-grey base, consistently on creator roads, raster roads and the bank transition. Texture scale remains kit 74. Banks gain an uneven 0.40 m nominal crown, broad and local height variation, gradient normals, and clustered irregular outer snow deposits. Deposits sit around 1 m beyond the inset analytic edge, separate from its soft road-side toe. Their seven-sided irregular geometry has 21 triangles per deposit, capped at 1,800 in the existing bank batch. Crown artwork is brighter and finer than the surrounding ground. Existing generated assets are reused; no new raster artwork or dependency.

Changed runtime files: `game/track/native_track_visual.gd`, `surface_detail.gdshaderinc`, `winter_bank.gdshader`, new shared `winter_ice.gdshaderinc`. Capture fixture `game/tests/capture_winter.gd` additionally checks deposit generation. Canonical contacts, grip, camera and road widths remain unchanged.

Actual pinned-engine commands via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `-Action CaptureWinter` 11 checks, `-Action TestIce` 69 checks, `-Action TestSurfaces` 50 checks, all zero failures. `git diff --check` passes. Final [driving](evidence/winter-piled/driving.png) and [hairpin](evidence/winter-piled/bend-detail.png) desktop captures saved; driving capture inspected after the final deposit shading adjustment. Prior iterations showed overly dark deposit side faces; normals now soften these while retaining the varied silhouette.

No Android export, installation, phone test or performance comparison performed. Owner approval of road readability and reference resemblance, moving-camera review and device performance remain. Piled deposits apply to creator road-piece banks; raster-only banks retain the earlier fallback. These cosmetic deposits do not introduce additional collision. Concurrent menu-loading work in other files is outside this checkpoint.


## Owner refinement: kit 74

2026-09-24, V02/V04/V05/Q01. Owner rejected oversized-looking ice detail, sawtooth edges and abrupt road/bank transitions. Creator road banks now follow exposed analytic road outlines rather than raster contact triangles. Eight cross-section bands form a rounded 0.28 m nominal bank with broad, low-amplitude drift variation and smooth shading. Small faceted clumps are removed. A 2.27 m strip starts 0.62 m inside the inset outline; its first approximately 1.54 m blends directional ice into the shared ground snow, then the bank settles into the ground. Shader material respects the creator paint overlay. Bridge pieces and covered/internal edges remain excluded by the existing outline/exposure logic. Canonical bank contacts, road cells, width, camera and winter handling are unchanged. Legacy/raster-only layouts retain their contour geometry with smooth normals and broader height variation; analytic edge reconstruction applies to road-piece tracks.

Ice artwork repeats at 5 m across / 9 m along creator roads (formerly 9 / 18 m); raster ice repeats at 6 m (formerly 12 m). Existing original textures are reused. No new generated artwork.

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `-Action CaptureWinter` passes 10 checks, `-Action TestIce` passes 69, and `-Action TestSurfaces` passes 50. Final desktop [driving](evidence/winter-smooth/driving.png) and [hairpin](evidence/winter-smooth/bend-detail.png) captures inspected. Capture checks verify unchanged cells/contact triangles, mipmaps, smooth section creation, no edge-marking materials and successful image saving. Fixture: 2,416 bank sections / 38,656 triangles in one opaque bank batch, replacing raster-bank rendering and clumps for this piece track. No GPU performance comparison claimed. `git diff --check` passes.

Changed files: `game/track/native_track_visual.gd`, `surface_detail.gdshaderinc`, `winter_bank.gdshader`, `game/tests/capture_winter.gd`, status/plan, this report and the two new screenshots. No Android export or physical-device test performed. Owner approval of scale/softness, moving-camera review, mixed paint/bridge joins and phone performance remain acceptance checks. Historical kit 73 evidence and provenance below are retained.

2026-09-24; requirements V02/V04/V05/Q01; visual kit 73. Owner requested reference-informed road texture, more realistic roadside snowbanks and detailed off-track snow, explicitly excluding white edge lines.

Two original mipmapped textures replace the weak winter surface detail. Creator road pieces receive local along/across UVs with bounded subdivision, so polished ice streaks turn with bends. Raster/painted roads use world-space ice mapping. Ground and shoulders use two scales of the same snow artwork. Ploughed banks retain the canonical contact envelope, with modest visual crown variation and independent irregular truncated snow clumps. Clumps share the bank mesh/material (18 triangles each, maximum 6,000 per track; capture fixture 1,185 = 21,330 extra triangles). Winter hides painted edge stripes and covers the kerb presentation in snow; existing canonical kerb and bank contacts remain. No handling, timing, camera or player files changed.

Changed files: `game/track/native_track_visual.gd`, `creator_road.gdshader`, `surface_detail.gdshaderinc`, new `winter_bank.gdshader`; `game/assets/textures/winter_{ice,snow}_v1.png` and imports; `game/tests/capture_winter.gd`; `scripts/dev.ps1`; `game/diagnostics/surface_material_probe.gd` (historical shader adapter); this report, prompt provenance, status/plan and evidence.

## Actual validation

All engine commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot 4.7.2:

- `-Action Import`: passed; textures use mipmaps and 1024 size limit. Existing Android build-tools fallback to 35.0.1 appears during editor import.
- `-Action TestIce`: 69 checks, zero failures, including all five vehicles and exact winter replays/bank contact tests.
- `-Action TestSurfaces`: 50 checks, zero failures.
- `-Action TestSurfaceProfile`: 928 checks, zero failures, with the added historical winter-wear adapter.
- `-Action CaptureWinter`: final 11 checks, zero failures. Checks unchanged canonical cells/bank triangles, texture mipmaps, bank/clump creation, omission of creator edge-marking materials, and screenshot saving. Closed road-piece fixture round-trips JSON as a saved player document does.
- `git diff --check`: passed (line-ending normalization notices only).

Initial visual iterations were rejected locally for coarse procedural ice speckles and excessive snow brightness. A first road-piece capture failed because its in-memory newly inserted dictionary key was not a persisted JSON String; capture fixture now round-trips JSON before validation. That failure was not reported as a pass. The original default/raster fixture was also captured successfully before the final road-piece fixture.

Final desktop evidence, inspected: [driving](evidence/winter-surfaces/driving.png), [hairpin detail](evidence/winter-surfaces/bend-detail.png). The second uses a diagnostic camera only. [Exact prompts and asset provenance](WINTER_SURFACES_PROMPTS.md).

## Acceptance limits

No Android export, install, physical-phone test or GPU/thermal measurement was performed for this change. Owner visual approval and moving-camera/device review remain. Flat ground artwork provides apparent relief rather than new terrain collision. Reference bushes/rocks are outside this surface pass. Snow clumps are cosmetic and remain near existing bank contact geometry; the underlying road contour can still reveal raster-sized steps at close range. Check large winter layouts, painted intersections, bridges, joins and texture repetition on device before performance/visual acceptance.

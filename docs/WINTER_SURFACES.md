# Winter road, snowbanks and ground

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

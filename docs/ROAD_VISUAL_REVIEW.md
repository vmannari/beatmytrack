# Road visual ideas review - 2026-09-15

Scope: review the owner's attached road-material proposal; record driving-data wear for later. No implementation authorized by this review. Relevant requirements: V02/V04/V05 (art, rendering and shared creator presentation), Q01 (performance), R01 (simulation separation).

## Assessment

| Idea | Review against current implementation |
|---|---|
| World-space procedural asphalt | Strong fit. `surface_detail.gdshaderinc` already supplies world-space asphalt to terrain, creator roads and bridges. Refine this shared function rather than introduce another road material system. World coordinates avoid UV stretching but do not alone guarantee an attractive, repetition-free pattern. |
| Broad, softly quantized tonal patches | Best first experiment. Current broad noise uses `p * 0.65` and continuous shading; try larger 4-8 m shapes with restrained tonal bands. Keep transitions filtered in motion. Proposed strengths are starting points for visual comparison, not accepted values. |
| Fine grain | Keep subordinate. Existing grain is derivative-filtered; retain that protection and consider reducing contrast. Tiny cracks/stones are unlikely to improve the approved overhead view. A small reusable noise texture remains a possible measured optimization; a unique baked texture per track is unnecessary. |
| Irregular verge and dark contour | Good refinement, partly implemented. `_shoulder_width()` already varies creator shoulders around 1.35 m, and terrain has boundary darkening. Try slower, broader variation rather than adding duplicate strips. The proposed 0.35 m width is a substantial change, not a drop-in value. Preserve drivable boundaries, painted junction openings, exposed-edge clipping and raised kerbs; do not put dirt verges on bridge decks. |
| Sparse repair patches | Useful secondary detail. Keep patches clipped to asphalt and the correct elevation, away from visually obscuring oil/water, kerbs and finish markings. Road-local alignment works for pieces, but free-painted asphalt needs a fallback. Compare sparse patches at the actual gameplay camera before adopting density/size values. |
| Approximate racing-line wear | Conditional, later experiment. The editor has independent road pieces, free paint and a separate lap route, not one authoritative road spline. Outside-apex-outside offsets can cut across grass, obstacles, crossings or the wrong bridge level. Any synthetic line needs road/layer validation and should be omitted where ambiguous. Keep it subtle enough that it does not imply a verified optimal line or grip change. |
| Deterministic decoration | Agree. Specify a stable visual seed and visual-generator version, with independent streams for repairs/verges/etc. Track ID alone does not describe geometry edits or generator changes. Keep cosmetic generation outside the canonical step; do not promise pixel-identical GPU noise across devices. |
| Real driving history | Deferred by owner: see [wishlist](WISHLIST.md#road-wear-from-real-driving-data). Existing local `SkidTrails` already pools 240 segments triggered by slip angle or strong brake input; it overwrites old segments, without gradual fading or persistent/shared history. It is not a measured per-tire longitudinal-slip system. |

## Suggested future order

1. Compare broad asphalt variation and quieter grain using the shared material.
2. Refine existing verge scale/contour continuity across joins and painted intersections.
3. Evaluate sparse deterministic repairs.
4. Revisit validated synthetic wear separately. Driving-data accumulation stays on the wishlist.

The attachment's claim that all systems are cheap enough for immediate editor regeneration is unverified. Before accepting an implementation, capture matching before/after views and moving laps covering curves, joins, painted crossings, bridges, hazards and themes; measure editor rebuild cost and physical-phone frame pacing. Keep handling and camera unchanged.

## Actual work and verification

- Changed documentation: this review, `WISHLIST.md`, and a link in `DEVELOPMENT_STATUS.md`.
- Read the attachment, project status/Phase 0 plan, art direction, camera contract and rendering architecture; inspected shared asphalt shaders, creator shoulder geometry and `skid_trails.gd` with `Get-Content` and `rg`. Ran `git status --short` to identify existing unrelated changes.
- Ran `git diff --check -- docs/ROAD_VISUAL_REVIEW.md docs/WISHLIST.md DEVELOPMENT_STATUS.md`: passed.
- Documentation only: no runtime changes, automated game tests, new screenshots, export or device tests. Phone attachment was not checked. Visual and performance conclusions are review recommendations, not measured acceptance.

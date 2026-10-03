# Wishlist

Ideas recorded for later consideration. Inclusion does not authorize implementation. Keep each item here with its status and scope.

## Graphics options

Recorded 2026-09-16 at the owner's explicit request. **Deferred; do not implement yet.**

Add persistent player-facing graphics options, including antialiasing Off / 2x MSAA / 4x MSAA. Gameplay now defaults to 2x MSAA; expose the choice in a later settings pass. Consider resolution scale and shadow/effect quality after physical-phone profiling. Keep camera framing, HUD scale, simulation, collisions and timing unchanged across quality levels. Validate sustained frame pacing, memory and thermal behavior on target phones before choosing device defaults or recommending higher quality.

Requirements to revisit: V02/V04/V05, Q01, R01.

## Race-persisting tire marks

Recorded 2026-09-15 at the owner's explicit request. **Deferred; do not implement yet.**

Keep tire marks visible until the end of the race, including marks from earlier laps. Dirty tires should continue depositing progressively fainter marks as they clean; existing deposited marks should survive for the race. Clear them for a new race or restart. Decide untimed-practice retention separately, since sessions can be unbounded.

The current system overwrites a pool of 240 individual mesh segments. Investigate grouping marks into shared meshes by track area, with visibility culling and bounded memory, rather than indefinitely adding individual mesh objects. Preserve correct bridge layers and hazard readability. Benchmark a full five-lap race with heavy marking on a physical phone before accepting performance; no persistent-mark benchmark has been performed.

Requirements to revisit: V04/V05, Q01, R01. Related implementation: [soil recovery and dirty trails](SOIL_RECOVERY.md).

## Road wear from real driving data

Recorded 2026-09-15; reaffirmed as a separate wishlist item at the owner's explicit request. **Deferred; do not implement yet.**

Change road textures based on actual user driving data: accumulated tire wear, commonly driven lines and potentially track usage/popularity could give heavily raced tracks a different appearance from newly created tracks. This is accumulated road appearance, separate from keeping individual tire marks for one race.

Decide whether the source is saved local driving history or aggregated shared-track data; shared history belongs to a later online decision. Define retention/reset behavior, track-version and bridge-layer association, bounded storage/rendering cost and visibility around hazards before implementation. Wear should remain cosmetic, with no grip, timing or reward effects.

Requirements to revisit: V02/V04/V05, Q01, R01. Source: owner's road-visual ideas, reviewed in [ROAD_VISUAL_REVIEW.md](ROAD_VISUAL_REVIEW.md).

## My tracks publication status

Recorded 2026-09-19 at the owner's explicit request. **Deferred; do not implement yet.**

Show which tracks have been published and which are still saved only locally in My tracks. Distinguish a published immutable version from later unpublished local edits. Publication status must come from confirmed publication metadata, not from a successful local save or an attempted upload. Offline cached status and pending/failed publication need clear states when cloud publication is implemented.

Requirements to revisit: R01, T01-T04, V03/V05.

## Different game modes

Recorded 2026-10-01; reaffirmed as a separate wishlist item at the owner's explicit request. **Deferred; do not implement yet.**

Rather than racing 5 different laps, have a target to hit all the cones or other objects on the track. Race ends when all cones are hit. Another game mode would be the time gated laps, i.e. the first lap would have to be completed within 50% percentile time, then 40%, 30%, 20%, 10%, 5% and 1%. Only tracks with enough completions would be eligible for this mode, e.g. 100 players have completed the track in normal mode. 
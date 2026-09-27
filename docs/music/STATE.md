# Beat my track — Music State

_Last updated: 2026-09-27_

## Status
Mode: explore
Current baseline: production v6 remains installed. Owner rejected the 2026-09-27 Magenta workbench auditions as unsuitable for the game; no replacement composition is accepted.
Approved release assets: no new release approval established by this installation

## Source hierarchy
1. Latest explicit user feedback
2. Current project docs/code (`docs/MUSIC_MODULAR_BANK.md`, `docs/music/`, runtime controller)
3. This state file
4. Skill reference guidance
5. Older proposals / experiments

## Active preferences
These are preferences, not permanent rules.

- Primary function: unobtrusive background music during racing.
- Every stage must offer multiple options so drives can differ. Select once per drive; do not reshuffle merely because intensity changes. Current audition round uses two options at all six stages.
- New conceptual arc: Low Roar intimacy/atmosphere → CCR groove → Green Day urgency → the triumphant melodic payoff of The Final Countdown.
- Additional reference palette: Peer Gunt, Lynyrd Skynyrd, ZZ Top, Muse, Audioslave, Blondie and Molly Hatchet.
- These are conceptual references, not literal artist-by-artist sections. Proposed interpretation: one identifiable theme develops from reflective to grounded, propulsive and finally anthemic.
- Instrumental remains the working assumption; reference vocals are not an instruction to add singing.
- Avoid: disturbing mechanically repetitive openings.
- Earlier rejection of a distorted finale remains a rejection of those recordings, not a blanket ban on rock energy, distortion or melodic synths. New references reopen those arrangement choices for audition.
- Desired: a recognizable musical identity and meaningful development without crowding vehicle audio.
- Adaptive climax/intensity: still subject to listening approval; do not assume “more rock” or “more instruments” is better.

Latest source: owner feedback recorded in `rounds/2026-09-27-reference-arc.md`; older `docs/MUSIC_MODULAR_BANK.md` remains historical evidence.

## Runtime behaviour
Preserve current implementation unless explicitly redesigning it.
Collision/reset/recovery contract: VERIFY IN PROJECT DOCS/CODE BEFORE CHANGING.

## Keep
- honest listening claims
- scoped approvals
- immutable sources
- bounded experiments
- comparable audition loudness
- distinction between mix / stem / additive layer
- free local generation

## Change / investigate
- Establish a musical identity the user actually likes before scaling the bank.
- Determine how much development/intensity remains background enough in gameplay.
- Determine which MRT2 controls can preserve musical identity reliably.

## Avoid
- independent random layers assumed compatible
- seed chasing after repeated rejection
- using mastering to hide weak composition
- treating old assistant proposals as approvals

## Next experiment
Owner now authorizes the next generation and multiple stage options. Round R2 explores two alternate complete mixes per stage, using concise differentiated directions and stage-matched audition loudness. These are direction studies, not compatible stems or a verified shared melody. See `rounds/2026-09-27-reference-arc-r2.md` for actual results; artistic approval remains pending.

## Approvals
This template asserts no approvals. Preserve documented scoped approvals; unresolved history stays unverified.

## Reconciled project evidence
`docs/MUSIC_MODULAR_BANK.md` records rejection of the slow solo and distorted-rock finale, and the request for interchangeable per-race phrases and unobtrusive background music. The earlier rock driving trial was authorized, but does not approve later revisions. The subsequent owner request authorized offline generator/workbench steps 1–4; `docs/MUSIC_TOOLKIT.md` records delivered auditions, now rejected artistically. Runtime replacement remains outside that slice.

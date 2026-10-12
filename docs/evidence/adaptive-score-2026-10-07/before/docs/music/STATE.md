# Beat my track — Music State

_Last updated: 2026-09-28_

## Status
Tooling: local RT2 studio supports prompting, audition, saved-track deletion, configurable states and soundtrack packages. Owner confirmed one compatible subset per package: select package first, then one track per pool, fixed per drive. Browser/service checks pass; no new music approval. See `../MUSIC_PACKAGES.md` and `../MUSIC_STUDIO.md`.

Mode: explore
Current baseline: production v6 remains installed. Owner rejected the initial Magenta auditions as unsuitable and R2's separate state mixes as disconnected; no replacement composition is accepted.
Owner explicitly rejected the R3/R4 acoustic motif: too high, too brief and disturbing. R5 replaces it; approval remains pending.
Approved release assets: no new approval

## Source hierarchy
Latest owner feedback, current code/docs, this state, skill guidance, then historical experiments.

## Active preferences
- Primary function: unobtrusive background music during racing.
- Do not reuse high, short, plucked acoustic opening figures like R3/R4. Latest response uses low, long-held tones with softened attacks; tone and instrument choice remain subject to listening review.
- Every stage must offer multiple options so drives can differ. Select once per drive; do not reshuffle merely because intensity changes. R3 offers three alternatives per instrument at all six stages.
- Latest alternative: one simpler tune starts, then distinct instruments join cumulatively. All options must share musical timing and harmony. Preserve R2 for comparison.
- Additional mode requested: the same music evolves and BPM rises with each state. R4 re-renders the R3 score at 90/102/114/126/138/150 BPM, maintaining original pitch and per-drive choices. Fixed-tempo R3 remains available.
- New conceptual arc: Low Roar intimacy/atmosphere → CCR groove → Green Day urgency → the triumphant melodic payoff of The Final Countdown.
- Additional reference palette: Peer Gunt, Lynyrd Skynyrd, ZZ Top, Muse, Audioslave, Blondie and Molly Hatchet.
- These are conceptual references, not literal artist-by-artist sections. Proposed interpretation: one identifiable theme develops from reflective to grounded, propulsive and finally anthemic.
- Instrumental remains the working assumption; reference vocals are not an instruction to add singing.
- Avoid: disturbing mechanically repetitive openings.
- Earlier rejection of a distorted finale remains a rejection of those recordings, not a blanket ban on rock energy, distortion or melodic synths. New references reopen those arrangement choices for audition.
- Desired: a recognizable musical identity and meaningful development without crowding vehicle audio.
- Adaptive climax/intensity: still subject to listening approval; do not assume “more rock” or “more instruments” is better.

Latest source: `rounds/2026-09-28-low-opening-r5.md`; older rounds and `docs/MUSIC_MODULAR_BANK.md` are historical evidence.

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
R5 replaces the rejected acoustic opening with low sustained cello across all tempos. Backing remains at 0.85 gain. Tests pass; no subjective listening claimed. Review before musical expansion. See `rounds/2026-09-28-low-opening-r5.md`.

## Approvals
Preserve scoped approvals; unresolved history stays unverified.

## Reconciled project evidence
`docs/MUSIC_MODULAR_BANK.md` and recorded rounds retain earlier rejections/approvals. The rock driving trial and later tooling requests do not approve replacement release music. Runtime replacement remains outside the current authoring slice.

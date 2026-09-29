# Adaptive music and delivery

## Preserve the existing runtime contract
Before changing adaptive behaviour, inspect the actual project documentation and Godot implementation.

In particular, do not replace an existing collision reset/recovery mechanism with proportional intensity loss merely because that was once proposed in conversation.

Treat these as separate:
- collision SFX
- clean-streak measurement
- musical state/intensity
- transition policy
- musical clock / phrase position

## Asset types
**Complete mix:** a self-contained arrangement/state.

**Stem:** an isolated part from the same performance/arrangement, intended to reconstruct a mix.

**Additive runtime layer:** an independently controllable part deliberately authored to combine with the active baseline.

Do not relabel one as another.

Independent AI generations can differ in:
- harmony
- tempo drift
- phrasing
- tuning
- ambience/reverb
- transient placement
- melody
- arrangement

Therefore “same prompt,” “same key,” or “same BPM” does not establish layer compatibility.

## Compatibility checks
For intended additive layers, validate:
- exact duration
- sample rate/channels
- musical clock and bar alignment
- tempo stability
- harmonic agreement at every section
- role separation
- no competing lead lines
- transition points
- loop boundaries
- combined headroom
- actual listening of relevant combinations

If exact compatibility cannot be produced by MRT2, use a different production technique.

## Adaptive design principles
- Low state must be desirable, not a punishment.
- High state should normally develop identity rather than replace it.
- A state held for a long time needs internal variation.
- Transitions should respect musical phrasing unless immediate change is artistically intended.
- Collision handling should not make minor errors cause musically absurd discontinuity.
- Engine, tyre and impact information has priority over soundtrack density.

These are design principles, not permission to modify the current controller.

## Export gate
Before Godot integration:
- preserve source render
- export a named revision
- record provenance/licensing
- validate duration/format
- run in-game
- test repeated races
- check phone speaker and mono compatibility when practical

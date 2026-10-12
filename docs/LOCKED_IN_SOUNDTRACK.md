# The music locks in with you - 2026-10-07

2026-10-08: the owner rejected this clean-band version as too mellow. The active
bank now contains the original [sports-rock rewrite](SPORTS_ROCK_SOUNDTRACK.md),
with the same tempo, shared motif and confidence controller. This document and
its recordings retain the historical band-version evidence.

The owner selects an organic, modern, slightly raw band identity for short races,
flow, tiny improvements, user-created tracks and rivalry. The arc is fragmented
to coherent to driving to euphoric, with a reserved soaring layer, musical setbacks,
one shared 3-5-note motif, related biome instrumentation, a controlled PB breath
and a resolving PB sting. The follow-up requests a higher BPM because 120 remains
too calm. Current race tempo is **144 BPM**; menu tempo is **112 BPM**.

[Listen to the shared band world](evidence/locked-in-score-2026-10-07/audition.html).
This is an integrated composition/behavior slice for listening. The direction is
owner-supplied; no finished musical approval, agent subjective listening or AAA
quality claim is made.

## Requirements and result

| ID | Delivery |
| --- | --- |
| MUS20 | Recorded hollowbody electric guitars, finger bass and acoustic drum kit; soft room/ghost hits, alternating recorded takes, fixed velocity/timing nuance, original written cells. Small gravel/wind derivatives connect musical texture to the car world. |
| MUS21 | Six synchronized additive layers: Pulse, Lock, Groove, Hook, Wide and Soar. Missing bass notes/guitar figures fill the early fragment; recorded kit and four-note hook establish a band; width/counterpoint and the reserved octave melody develop it. |
| MUS22 | Invisible confidence from road motion/direction, a generous racing-line corridor, actual ordered-gate/quarter-lap sectors, clean streak, real PB/rival ghost pace and pace-relative clean corners. No maximum-speed/velocity-to-intensity mapping. Identical clean line at 2/35m/s has equal quality. Missing ghost data is neutral. |
| MUS23 | Small contacts wobble slightly; major hits shed confidence/momentum and clean evidence considerably. Bar-aligned smooth retreat/rebuild keeps the pulse/clock. Soar additionally requires confidence ≥0.9, ten clean seconds and three consecutive clean sectors; elapsed time alone cannot unlock it. |
| MUS24 | Original four-note D-E-A-F# gesture in menu, bass fragments, guitar/piano hook, octave expansion and stings. Grass/warm band, Desert/dry tremolo/gravel, Winter/piano/spacious guitar, Night/tighter filtered band and Storm/rough low guitar/heavier kit/wind-derived rain share the same score/grid. |
| MUS25 | Normal finish and PB motif-resolution events; a legitimate eligible race 0.08s ahead of its previous PB selects the PB event. First record, slower/ineligible/practice results get normal finish. Normal result/PB/lap UI and backend verification remain independent. |
| MUS26 | Once per later lap, exceptional confidence plus available positive PB pose timing near the line queues a breath on a bar. The score drops for two beats, one held note remains and the band returns; car buses stay audible. No invented PB/rival data, extrapolation or reward/score changes. |
| MUS27 | 144 BPM races, 112 BPM menus; matching loop/transition/breath timing. Final exceptional layer around one minute remains. Mouse hover/keyboard focus remain silent; the three activation WAVs retain their hashes. |

Thirty race loops are exactly 2,352,000 stereo frames/53.333333s at 44.1kHz,
32 bars at 144 BPM. Menu is 16 bars/1,512,000 frames/34.285714s. One synchronized
player starts six parts together. Entries are 6/16/30/44/56 qualifying seconds;
next-bar entry and two-bar fades place the recorded exceptional arrival at
**59.982 seconds**. Tempo stays fixed while confidence changes arrangement.

The tiny motif is project-authored and intentionally repeated/transformed. No
reference-game songs or source recordings are copied. This is an offline written
sample performance, not a claimed recording of a live band or separated AI mixes.
Analog/electronic character currently comes from subtle instrument processing;
a separate analog-synth part is not claimed.

## Confidence, references and boundaries

`DrivingScoreProgress` is presentation-only. Geometry/corridor control allows
inside/apex lines and ordinary braking; speed magnitude only distinguishes rest
from motion. A sector needs actual accepted road gates and clean observations.
Major contact removes up to 20 earned seconds and substantial confidence, with
recovery; small contact does not abruptly mute the drums. A short retreat grace
avoids a minor threshold crossing removing a part immediately.

`ScorePaceReference` builds at most 2,048 distance/time samples from existing
personal/rival ghost poses. It handles wrapped progress, backwards recovery and
sparse/decimated pose gaps, returns neutral outside available data and does not
extrapolate. Flying-lap reference is withheld on the standing first lap. Rivalry
uses the existing selected recording; personal recordings are retained separately.
No client PB/ghost value becomes a competitive score or reward write.

Pause/focus loss stops output/progression. Rewind retains the musical clock and
confidence while tick high-water guards duplicate earning. Retry rebuilds from the
fragment. Finish returns to the menu and the actual normal results path selects
the appropriate event, independent of cloud verification. Untimed/new creator
tracks can build clean flow without a stored PB or invented rival.

The existing vehicle loops, physics inputs/configuration, race/gate rules,
track identities and camera contract are not edited by this music slice. Concurrent
workspace work is preserved. New band bank is included in export; the prior
score_v1 bank remains preserved locally and excluded from shipping.

## Sources and traceability

134 pinned source files (131 recorded clips, three full licences), 59,199,072
bytes, from the creator's CC0 Karoryfer libraries:
[Black/Green guitars](https://shop.karoryfer.com/pages/free-black-and-green-guitars),
[Black/Blue basses](https://shop.karoryfer.com/pages/free-black-and-blue-basses),
[Big Rusty Drums](https://shop.karoryfer.com/pages/free-big-rusty-drums).
Immutable Git trees, source URLs/hashes and full CC0 licences are recorded under
`build/music/locked-in-v1/sources`. Original VSCO 2 CE piano/strings and unchanged
activation clips retain their earlier provenance; Nox gravel is CC0 and the wind
bed is project-authored. No paid generation or new runtime dependency/API/native
extension is added. Existing local Python/NumPy/SciPy/SoundFile/FFmpeg render assets.

Sounding-pitch inspection corrected the recorded bass/guitar register conventions.
Initial guitar-hook levels were measured too low relative to the band and corrected
in a new mix; prior renders are preserved. Initial 144 BPM Desert tremolo used
arbitrary 5Hz, which failed the loop-seam invariant. A focused repair locks it to
two cycles per beat; old WAV/OGG masters and before/after hashes remain retained.
No seam assertion was loosened. The repaired Desert has separate processing/source
provenance in the installed manifest.

Masters/mixes 1-4, render source snapshots, tempo previews and the targeted repair
are under `build/music/locked-in-v1/`. Installed 37 assets/metadata/notices are in
`game/assets/audio/locked_in_v1/`. Source recordings and earlier native/piano scores
remain outside the active export scope. The renderer source hash and every active
export hash are pinned; the owner has not artistically approved the outputs.

## Actual verification and failures

Engine entry point: `scripts/dev.ps1`, pinned `4.7.2.stable.official.ed1daf0bf`.
Actual commands include:

- `python tools/music_generator/fetch_band_sources.py`: 134 sources/all three CC0
  licences; initial absent ride RR4 path corrected before fetching.
- `wsl -d Ubuntu -- bash tools/music_generator/scripts/render_locked_in.sh --inspect`
  and `… --mix-revision 2/3/4`: measured pitches, preserved band/palette/menu/events;
  mix 4 implements 144/112 BPM. Original shared note/timing data stays traceable.
- `… run_from_windows_repo.sh python tools/music_generator/repair_band_tremolo.py`:
  focused Desert beat-locked repair. Initial missing FFmpeg PATH corrected using
  the existing tool's absolute path; prior sources retained.
- `… scripts/dev.ps1 Import`: successful final asset/class import.
- `… TestScript -ScriptPath res://tests/test_soundtrack.gd`: final **1,158 checks,
  zero failures**, including 960 exact canonical state/input comparisons.
- Same with `-Graphical`: final **1,163 checks, zero failures**, synchronized
  playback, silence/activation and actual Audio-settings screenshots. Foreground
  state of the programmatic activation fixture corrected after a focus-loss failure.
- `… TestScript -ScriptPath res://tests/test_score_flow.gd`: **29 checks, zero
  failures** after a real sparse-ghost/backtracking lookup failure was repaired.
  Earlier graphical flow pass had 28 checks before that regression was added.
- `… TestApp`, personal-ghost script, `… TestRewind`, vehicle-audio script:
  **99 / 38 / 57 / 1,434 checks**, zero assertion failures. Personal-ghost fixture
  retains its 27 ObjectDB warnings; no full-green whole-project claim is made.
- Actual graphical recording script uses scripted sector/confidence/PB/car signals,
  not a claimed naturally perfect player race. Story segment: **4 checks**, full
  at59.982s, real car mix/one PB breath. Palette segment: **10 checks**, refreshed
  faster palettes and clean exit. Menu/event segments record real loops, 0.08s PB
  sting and hover silence. Initial long/paused captures ended with resource errors;
  fragments remain preserved. Safe decoder replacement and explicit capture cleanup
  address the paused-stream/shutdown issue without deleting failures.

Source/combined/capture measurements, browser checks, scoped Git patch and final
inventories are under `docs/evidence/locked-in-score-2026-10-07/`. Remaining measured
verification is recorded in `audio-verification.json`, not inferred from planned
commands. No full Validate, phone attachment/audio test, Android export/install,
backend deployment, economy/purchase or production action was performed.

Final audio validation: **37 assets, 160 additive combinations, 18 actual mixer
captures, zero clipped samples**. Worst combination true peak -7.249dBTP;
53.333333s race and34.285714s menu loops retain their exact frames/continuous seams.
Actual two-beat breath, paused palette tails and hover/focus start are measured.
The final installed audio is **23,195,345 bytes**, plus notices/metadata.
The corrected short capture runs exit cleanly: menu3, palettes10 and events5 checks;
story4 checks. The old failed paused-decoder exits remain in their original logs.
Playwright/Edge loads all nine previews and verifies stage seeks/exclusive playback
with zero script errors; this is technical playback, not agent listening.

During this task other workspace work changed canonical simulation/rules/session
files. Their initial/current hashes and mismatches are preserved in
`canonical-audit.json`; these files are excluded from the music patch and were
not reverted or edited by this task. State/input equality tests run on current code.
No frozen whole-workspace or full-regression claim is made.

Checkpoint commands: `python build/music/locked-in-v1/checkpoint.py`,
`git apply --reverse --check --ignore-whitespace` on the scoped patch, scoped
`git diff --check`, and `python -m py_compile` on the four new band tools.
All exit0: **66 task text files / 103 changed source-export files** pinned, binary
audio hashes recorded separately. Existing Windows CRLF normalization notices
are retained. No mixed-workspace Git commit is made.

## Files and remaining acceptance

Changed: soundtrack controller/progress, new pace reference, game/app music context
and result hooks, export filters, band assets; general soundtrack/capture tests,
new flow/capture scripts; band fetch/render/verify/repair tools and WSL wrapper;
review helper, Music State/round/toolkit docs, status/phase and licence ledger.

The review checkpoint pins only this music task's changes and records concurrent
app/game edits separately. Prior sources/artifacts are preserved. Human checks:
band/motif identity, performance/timbre, upbeat energy at144 BPM, low-state comfort,
exceptional payoff/restraint, repetition, natural PB/rival/creator driving and
controlled breaks; Android mono/speaker/headphone/route/ad/focus handling, decoder
cost and thermals. The biome treatments are first score palettes, awaiting listening.

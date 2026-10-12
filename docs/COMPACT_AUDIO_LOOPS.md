# Compact loop follow-up — 2026-10-10

The owner hears a regular artefact while driving, suspects engine looping and
reports roughly the same rhythm as revs change. That does **not** conclusively
identify an engine loop. This slice fixes measurable compact-engine loop defects
and supplies separate wind/rolling references for the next listening check.
Requirements: **SND34** repeating-artefact investigation and compact loop repair;
**SND33/SND02–SND03/SND05–SND06/G01/R01/Q01** bank character, presentation-only
drivetrain, lifecycle/headroom/provenance and unchanged canonical simulation.

Fixed-duration linear crossfades blend differing phases, creating recurring
level dips. Filtering short open cuts with an FFT also treats their unmatched
ends as periodic discontinuities, adding ringing to the cut edges. The compact
mastering now filters the complete recording before cutting, seeks the most
correlated head/tail position within two engine periods, and filters the final
joined periodic loop. Mid/high source sections are doubled. The existing Nox CC0
recordings, calibrated engine orders, EQ intent and loudness targets remain.
No runtime audio/model/physics change is made in this follow-up.

Measured 40 ms asset-envelope minima relative to each file's median:

| Loop | Before | After | Length before → after |
| --- | --- | --- | --- |
| Mid load | -2.231 dB | -0.877 dB | 1.570 → 3.218 s |
| Mid coast | -2.211 dB | -0.965 dB | 1.570 → 3.218 s |
| High load | -1.649 dB | -0.333 dB | 0.735 → 1.549 s |
| High coast | -1.576 dB | -0.430 dB | 0.735 → 1.549 s |

Low-RPM recordings retain natural engine pulses; their total envelope variation
is not flattened or presented as a zero-modulation guarantee. Low load/coast peak
40 ms envelope excursions reduce from +2.290/+2.345 to +1.493/+1.498 dB relative
to their median. A nonzero adjacent endpoint sample difference alone is not a
click: a continuous waveform normally changes between successive samples.

[Listen to the steady-loop comparison and wind/rolling references](evidence/compact-loop-2026-10-10/audition.html).
Five isolated native captures per version play fixed pitch/gain for eight seconds
and pause for one. They contain no shifts, contact events or varying RPM; each
crosses at least two actual wraps. All ten captures are audible/unclipped, have no
tested 20 ms dropout and end with an exactly silent half-second. Wind/road are
recorded at raised diagnostic gain and **remain unchanged in the game**. Their
generic loops also have envelope variation; owner listening is required to tell
whether either matches the roughly fixed-rhythm symptom. This is not a claim that
every looping sound or the owner's exact artefact is resolved.

Changed files: `scripts/compact_audio_mastering.py`, `scripts/build_vehicle_audio.py`;
six compact WAVs/lossless imports and bank `manifest.json`/`NOTICE.txt`;
`game/tests/capture_compact_loops.gd` plus generated UID;
`scripts/review_compact_loops.py`; this document, `licenses/ASSETS.md`,
`DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and task evidence.
The six WAVs total **1,448,110 bytes**; all other **41 WAV hashes match** the saved
baseline, including wind, rolling, tires, impacts and the other four cars.
No downloads, licences, runtime dependencies, services or player data are added.

Actual commands using `4.7.2.stable.official.ed1daf0bf` via `scripts/dev.ps1`:

| Command | Actual result |
| --- | --- |
| `… dev.ps1 TestScript -ScriptPath res://tests/capture_compact_loops.gd -Graphical -TestArgument '--variant=before'` | Exit 0; load low/mid/high + wind/road wraps `[2,5,10,2,2]`, zero failures. |
| `python scripts/build_vehicle_audio.py --compact-only` | Six revised loops and compact revision `engine-2-phase-loops`. |
| `… dev.ps1 Import` | Exit 0; six WAVs reimported with lossless settings. |
| `… dev.ps1 TestScript -ScriptPath res://tests/capture_compact_loops.gd -Graphical -TestArgument '--variant=after'` | Exit 0; wraps `[2,2,5,2,2]`, zero failures. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,446 checks, zero failures**, including bank integrity/headroom, pause/retry/rewind lifecycle and exact 960-tick simulation equivalence. |
| `python scripts/review_compact_loops.py` | Six-only scope, moving-speed envelope correction, doubled lengths and ten native capture checks pass. |
| Repeat compact-only build and compare full bank SHA-256 | **47/47 identical** to the first revised build. |
| `git diff --check -- scripts/build_vehicle_audio.py scripts/compact_audio_mastering.py` | Exit 0. |
| `git apply --reverse --check --ignore-whitespace docs/evidence/compact-loop-2026-10-10/scoped-change.patch` | Exit 0; task-only text checkpoint valid. |

Native import/captures/regression used permitted Windows audio/certificate access.
Source waveform examination and candidate arrays were local offline diagnostics;
only the final six-loop rebuild ships. Original/revised captures, full baseline
hashes, numerical review, source snapshots, launcher logs, Git-format patch and
artifact hashes are retained in the evidence directory. Unrelated mixed-workspace
changes are preserved; no shared-index commit operation was made.

No visible UI change; playable sound is the presentation evidence. No phone
attachment check, phone/tablet listening or performance test, export/install,
full Validate, backend operation or deployment was performed **for this task**.
Remaining acceptance: restart the updated local game and compare the reported
artefact; identify a matching isolated reference if it remains; listen during
actual sustained driving, coasting, shifts, retries and rewind on device.
The defect reduction is measured; matching the owner's sound remains open.

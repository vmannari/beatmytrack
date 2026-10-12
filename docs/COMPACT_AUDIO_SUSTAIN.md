# Compact repeating-pitch follow-up — 2026-10-10

The owner reports that the artefact persists, approximately every **1.5 seconds**.
The current high bank lasts **1.549297 seconds**. The earlier amplitude/seam
checks missed pitch variation inside that recording: smoothing a join does not
remove a short recorded engine-pitch pattern that repeats at every wrap.
Requirements: **SND35** sustained-engine pitch-pattern correction;
**SND33–SND34/SND02–SND03/SND05–SND06/G01/R01/Q01** compact character,
presentation-only drivetrain, lifecycle/provenance/headroom and canonical isolation.

An offline narrow-band phase analysis of the dominant recorded engine order,
averaged over 20 ms, confirms the repeating source pattern. The high load bank's
5th–95th-percentile firing rate is **199.199–202.991 Hz**; the mid load bank's is
**99.592–101.462 Hz**. Load/coast have the same lengths and high waveform
correlation (~0.986); changing their crossfade gains alone does not remove the
source pitch drift. The high-loop period fits the reported interval, but the
owner's exact audible artefact and active platform/build remain unconfirmed.
The platform question explicitly distinguishes a restarted Windows project from
an installed Android build; this work changes the local project only.

The four mid/high derivatives now average phase-aligned firing cycles from the
existing pinned Nox CC0 recording, retaining the recorded pulse waveform while
sustaining exact **100/200 Hz** orders. An original offline noise texture at
16% of tonal RMS uses the recording residual's broad spectral shape, with narrow
wandering tones removed. It retains a restrained mechanical/air texture rather
than replaying the old 1.55-second source pattern. Eight-second output buffers
contain whole firing cycles; they are filtered as complete periodic signals,
without another cut-and-fade operation. Coast comes from the same sustain and
has exactly the same loop length and pulse timing as load.

This is an authored recorded/synthetic engine derivative, not an unmodified
field recording or an exact real-engine reproduction. There is no new runtime
synthesis, DSP voice, API, service, dependency, licence or source download. The
low/idle pair is **byte-identical**, as are all other cars, surface layers, wind,
weather and impact clips. Runtime drivetrain, gains, buses and canonical
simulation are untouched by this follow-up.

Measured 20 ms engine-order variation (asset 5th–95th percentile span):

| Asset | Before | After |
| --- | --- | --- |
| Mid load | 1.869891 Hz | 0.000371 Hz |
| Mid coast | 1.870534 Hz | 0.000381 Hz |
| High load | 3.792055 Hz | 0.014294 Hz |
| High coast | 3.789932 Hz | 0.014276 Hz |

[Listen to the matched native sustain captures](evidence/compact-period-2026-10-10/audition.html).
Each captures 25 seconds at fixed RPM with 65% load, then one second paused.
The first case includes high load/coast; the second includes the actual
4500-RPM mid/high weights and both load/coast voices. Each player crosses at
least two real wraps. The native high phase-rate span reduces **3.597253 →
0.015301 Hz**, and the neighboring-layer blend reduces **4.205220 → 0.011105 Hz**.
All four recordings are audible/unclipped, have no measured 20 ms dropout, and
end with an exactly silent half-second. These fixed-state diagnostic mixes have
no shifting, contacts, tires, weather or music; they are not a completed race or
a hardware microphone capture. They establish the source-pattern correction,
not that the owner's exact reported sound is definitively identified.

Changed files: `scripts/compact_audio_mastering.py`, `scripts/build_vehicle_audio.py`;
four `compact_1/2_load/coast.wav` and imports; bank `manifest.json`/`NOTICE.txt`;
`game/tests/capture_compact_sustain.gd` and generated UID;
`scripts/review_compact_sustain.py`; this document, `licenses/ASSETS.md`,
`DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and task evidence.
All **43 other WAV hashes match** the baseline. Selected compact PCM now totals
**3,429,558 bytes**, an increase of 1,981,448 bytes (~1.89 MiB); the six-voice
runtime bound is unchanged. Device memory/performance was not measured.

Actual commands, pinned `4.7.2.stable.official.ed1daf0bf` via `scripts/dev.ps1`:

| Command | Actual result |
| --- | --- |
| Local WAV spectral/phase diagnosis | Existing high loop 1.549297 s, internally changing pitch; baseline analysis saved as `phase-diagnosis.json`. |
| `python scripts/build_vehicle_audio.py --compact-only` | Six generated outputs, **four changed WAV hashes**, stable-sustain revision; low pair exact. |
| `… dev.ps1 Import` | Exit 0 with normal Windows certificate-store access; lossless imports retained. |
| `… dev.ps1 TestScript -ScriptPath res://tests/capture_compact_sustain.gd -Graphical` | Exit 0, zero failures. Before wraps high `[15,15,16,16]`, overlap `[11,11,12,12]`; after high `[6,6,3,3]`, overlap `[4,4,2,2]`. |
| `… dev.ps1 TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,446 checks, zero failures**; bank hashes/PCM/headroom, drivetrain/lifecycle, pause/retry/rewind and exact 960-tick simulation equivalence. |
| `python scripts/review_compact_sustain.py` | Asset pitch variation and whole-cycle length, four-only scope, native neighboring-layer/load blend phase stability, pause/continuity/headroom checks pass. |
| Repeat compact-only build and compare complete bank SHA-256 | **47/47 WAV hashes identical** to the first revised build. |
| `git diff --check -- scripts/build_vehicle_audio.py scripts/compact_audio_mastering.py` | Exit 0. |
| `git apply --reverse --check --ignore-whitespace docs/evidence/compact-period-2026-10-10/scoped-change.patch` | Exit 0; task-only checkpoint valid. |

Playable captures are the presentation evidence; no UI changed. Source snapshots,
baseline/final hashes, measured review, native launcher logs and a task-only
Git-format patch are retained in the evidence directory. The shared mixed
workspace/index is preserved; no commit or unrelated changes are included.

No phone attachment check, phone/tablet listening or performance test, Android
export/install, full Validate, backend operation or deployment was performed
for this task. Remaining acceptance: owner confirms the actual platform/build,
restarts the local project to audition the revised tone and reported artefact,
then tests real driving across shifts, lift-off, pause, retry and rewind.
An already-installed Android build does not receive local asset changes without
an explicitly authorized build/install. Human tone acceptance remains open.

# Continuous faint storm thunder, 2026-10-11

SND60/SND34/SND37/G01/R01/Q01: the owner requests faint continuous thunder
behind the existing stronger rumbles. Storm now adds one distant rolling loop
at gain 0.10 on the existing Vehicle bus. It follows rain's 0.75s entrance and
finish fade, freezes on pause/backgrounding, resumes the same cursor and stops
on exit. It does not consume the strike RNG or trigger additional lightning.
The accepted six-second strong thunder master, fresh-cue two-voice replacement,
rain level, vehicle audio, driving and scoring remain unchanged.

The new 16s mono 44.1kHz PCM is derived from 1.2-4.8s of the existing thunder
master's rolling body, excluding the clap. Eight periodic Hann overlaps with
slower source pace and 30Hz cleanup/420Hz lowpass make a soft continuous bed.
No new recording, synthesis, runtime PCM generation, API or dependency.
WAV size 1,411,244 bytes; SHA256
`f1943fd2d5a563fcd2ec724e7e10cfcc53fddac36acc1de37a8142939d2d71bc`.
Two builds produced the same hash. Owner-supplied source attribution and missing
original licence metadata are retained in the manifest and ambience NOTICE.

Changed files: `game/track/storm_weather.gd`,
`game/assets/audio/storm_rumble.{wav,wav.import}`, `storm_rumble_manifest.json`,
`game/assets/audio/ambience/NOTICE.txt`, `scripts/build_storm_rumble.py`,
`scripts/review_thunder_audio.py`, `game/tests/{test_wet_road_audio,
test_thunder_replacement,capture_thunder_audio}.gd`, this document,
`DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

Actual commands used the pinned build in `godot-version.txt` via
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `python scripts/build_storm_rumble.py`: exit 0 twice; identical PCM hash.
- `-Action Import -CommandTimeoutSeconds 240`: final exit 0; lossless PCM import.
- `-Action TestScript -ScriptPath res://tests/test_wet_road_audio.gd -Graphical
  -CommandTimeoutSeconds 180`: 50 checks, zero failures. Includes continuous loop,
  bounded voices, gain, pause/background/finish and canonical-state guards.
- `-Action TestScript -ScriptPath res://tests/test_thunder_replacement.gd
  -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/storm-background-rumble-2026-10-11'
  -CommandTimeoutSeconds 180`: 21 checks, zero failures; strong cues still start
  fresh, fade old tails and reuse exactly two strike voices.
- Same graphical TestScript command with `res://tests/capture_thunder_audio.gd`:
  29 checks, zero failures; actual race audio, 20s bed/strike/pause/mute captures.
- `python scripts/review_thunder_audio.py --evidence-dir
  docs/evidence/storm-background-rumble-2026-10-11 --owner-bass --background-rumble`:
  exit 0, zero failures. The continuous bed measures -35.098dBFS, 21.556dB below
  the strong cue across its capture, with no silent 200ms window through the
  16s wrap (quietest -41.647dBFS). Mixed peak 0.794; paused/muted output exactly
  zero. Strong thunder, rain, vehicle controller and strong generator hashes match.
- `-Action TestStorm -CommandTimeoutSeconds 180`: 94 checks, two existing visual
  spray failures (front/rear wake balance and fan distance), unchanged from
  `docs/WET_ROAD_AUDIO.md`. All other Storm checks pass; no assertions weakened.
- `-Action Doctor`: exit 0; no attached Android devices.

Initial direct script invocation hit Windows execution policy. Restricted
Import then hit certificate-store access; normal-access Import passed. Initial
headless audio fixture checked pause on an ambient voice that headless mode
never starts; explicitly starting that fixture voice corrects the check.
Initial headless replacement ran 20 checks without failures but retained its
resource shutdown error; final native runs completed cleanly.

[Native audio preview](evidence/storm-background-rumble-2026-10-11/review.html),
logs, hashes and task-only Git review patch are in that evidence directory.
Shared Git index and unrelated work remain untouched. No visible UI change,
phone listening/performance test, Android export/install, full Validate,
physics change, backend action or deployment. Restart the local client and
listen on a Storm track; final faint level/tone and phone acceptance remain.

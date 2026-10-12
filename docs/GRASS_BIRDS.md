# Grass birdsong, 2026-10-10

SND57 follow-up (2026-10-11): the owner requests slightly quieter Grass birds.
Call gain is now 0.216–0.304 instead of 0.27–0.38: 20% lower amplitude, or
approximately −1.94dB. Randomized ordering, waits, density, pitch and lifecycle
remain unchanged; insects/leaves, vehicle audio and other biomes are untouched.
Original bird WAVs/provenance remain unchanged. G01/R01 preserve canonical
separation and Q01 covers validation/documentation.

Changed files for this follow-up: `game/track/grass_birds.gd`, the existing gain
expectation in `game/tests/test_grass_birds.gd`, this document,
`DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.
Actual command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_birds.gd
```

Pinned Godot 4.7.2: 295 checks, zero failures, eight distinct race sequences.
Existing schedule, gain bounds, lifecycle, race ownership and canonical-isolation
checks pass. Evidence log and task-only Git checkpoint/patch are in
`docs/evidence/quieter-grass-birds-2026-10-11`. The main index/branch is untouched.
No native audio capture, phone/device listening or test, Android export/install,
full Validate or deployment performed for this volume-only adjustment.
Remaining acceptance: restart/rebuild and judge the slightly softer birds while
driving a Grass track. No visible UI changes require screenshots. The original
SND39 implementation/results below retain the historical gain values.

Follow-up SND41 adds much quieter insects and sparse leaf rustles under these
birds, with separate random timing and lifecycle. Bird assets/behavior remain
unchanged. Actual implementation, measurements and remaining listening checks:
[Grass nature sounds](GRASS_NATURE.md).

Owner request: background birds in the Grass biome, varying between races through
random intervals and different audio recordings. Requirement SND39 covers this
request; R01/G01 keep presentation separate from canonical driving, Q01 covers
actual verification and provenance.

Grass is the existing `pine` theme. `GrassBirds` adds one race-owned Vehicle-bus
voice, with three complete recorded phrases: two blackbird songs and a blackcap.
Each attempt, including Retry, selects a new initial delay (0.6–2.8 seconds),
spacing multiplier (0.85–1.25) and shuffled phrase order. A shuffle bag uses every
phrase before recycling, and prevents an immediate repeat across bag and retry
boundaries. Silence after each complete phrase is 2.5–8 seconds times the race
multiplier (overall 2.125–10 seconds). Quiet gain varies 0.27–0.38 and pitch only
0.98–1.02. Calls never overlap; a stalled presentation frame cannot cause a burst.

Race pause/rewind and OS background suspension freeze both playback and the
schedule. Finish fades out within 0.4 seconds and schedules no additional calls.
Changing biome stops birds immediately. Leaving the race frees its voice. The
existing sound slider/mute includes birds; there are no extra UI labels, settings,
runtime downloads, services or dependencies. Playback runs outside simulation
and uses its own `RandomNumberGenerator`. Night ambience remains separate.

The three sources are CC0 recordings by Le tiroir du fond from BigSoundBank:
[Common Blackbird #13](https://bigsoundbank.com/common-blackbird-13-s3486.html),
[Common Blackbird #23](https://bigsoundbank.com/common-blackbird-23-s3496.html),
[Eurasian Blackcap #7](https://bigsoundbank.com/eurasian-blackcap-7-s3472.html).
Source pages were checked and saved outside exports. The builder pins source
SHA256 hashes, retains complete phrases, removes DC/field rumble, gently softens
high frequencies, adds 60ms edge fades and matches levels. Mono44.1kHz16-bit PCM
clips last 5.121/3.620/4.405 seconds, totalling 1,159,608 bytes (~1.11MiB).
Source and derivative hashes are in `grass_birds_manifest.json`; the shipping
notice and asset ledger include attribution and licence links.

Changed files:

- `game/track/grass_birds.gd` and `.uid`: scheduling, local RNG and lifecycle.
- `game/core/game.gd`: race-owned setup, presentation tick and Retry reset (seven added lines).
- `game/assets/audio/ambience/grass_{blackbird_13,blackbird_23,blackcap_7}.wav` and `.wav.import`: three recorded, nonlooping, lossless PCM clips.
- `game/assets/audio/ambience/grass_birds_manifest.json` and `NOTICE.txt`.
- `scripts/build_grass_birds.py` and `scripts/review_grass_birds.py`: offline mastering and measured review.
- `game/tests/test_grass_birds.gd` and `.uid`: schedule/biome/lifecycle checks, actual race integration and optional native capture.
- `licenses/ASSETS.md`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands and outcomes, using pinned Godot4.7.2:

```powershell
python scripts/build_grass_birds.py --fetch
python scripts/build_grass_birds.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_birds.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_grass_birds.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_grass_birds.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_night_ambience.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python scripts/review_grass_birds.py
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
```

Final headless295/native295 grass checks pass, including eight distinct 90-second
race sequences, complete phrase coverage, no consecutive repeats, bounded
spacing/pitch/gain, Retry, pause, OS background, mute, finish, biome isolation,
long-frame protection, actual race ownership and unchanged canonical snapshot.
Night25 and App99 checks pass. The offline rebuild reproduces all three hashes.

The capture run saved two native ~22-second mixes and all three silence samples,
then hit a concurrently added, not-yet-imported `vehicles/scrape.wav` during
actual race setup. Its overall exit was a failure; this is not reported as a
full passing capture run. Once that unrelated import was available, the native
295-check race integration and App99 reruns both passed. PCM review verifies two
versus three calls, different race events, no overlap, peaks0.1898/0.1454, no
clipping and exactly zero output in pause/mute/finish samples. These are isolated
bird mixes, not full driving/listening acceptance. No subjective listening claim.

Initial corrections retained in evidence: sandbox blocked source sockets and
Godot certificate-store access (approved local escalations succeeded); first
295-check run had eight failures because default WAV imports compressed PCM and
headless players cannot retain paused state without playback. Explicit lossless
imports and the established headless pause assertion corrected both without
weakening schedule checks. A `-File` capture invocation misparsed the array flag;
the displayed `-Command` invocation is the actual successful capture start.
A later editor import retry hit an unrelated Windows audio DLL copy lock; no
other engine process was stopped, no DLL or vehicle source changed for this task.

Evidence: [review report](evidence/grass-birds-2026-10-10/review.json),
[race A](evidence/grass-birds-2026-10-10/race0.wav),
[race B](evidence/grass-birds-2026-10-10/race1.wav), event JSONs, silence samples,
focused logs and `task-only.patch` under the same evidence directory. The patch
comes from a separate local Git checkpoint, so shared uncommitted work is not
included or staged in the main repository.

Android inventory found one authorized OPD2403 tablet (`f0ba474a`), and no phone.
No Android export/install, device listening, full Validate, backend change or
deployment was performed. Remaining acceptance: restart/rebuild the game, listen
on a Grass track across several retries while driving, check background volume
against engine sound and confirm pause/rewind/finish on the actual Android device.
No screenshot is needed: this task changes audio only.

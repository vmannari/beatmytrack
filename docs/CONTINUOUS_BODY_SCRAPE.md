# Continuous low body scrape — 2026-10-11

The owner subsequently selects Pól's rally-car rail recording. The
[current source-preserving rail scrape](POL_RAIL_SCRAPE.md) replaces this
page's source and derivative; continuous contact behavior is retained.

Owner feedback: the last scraping sound knocks too much and should be more
continuous. **SND45**, refining SND40/SND41/SND44/SND08/SND05 and supporting
G01/R01/Q01/V06. This supersedes the rejected stroke recipe in
[Irregular low scrape](IRREGULAR_LOW_SCRAPE.md).

The struck-metal grains and recorded body thuds are removed. A new cleared
recording of **actual metal rubbing** supplies sustained friction instead.
Selection excludes high-energy strikes, contact starts and quiet gaps, retaining
only rubbing tails. Unequal excerpts crossfade over **180ms** with correlation
power correction, so joins do not add repeating impacts or fade holes. Gentle
150ms envelope control and small slow variations keep some texture while holding
a continuous sound. **0.65 pitch** and **85–1300Hz filtering** retain a low tone.

The source is [metal soft scrape.wav by taure](https://freesound.org/people/taure/sounds/341280/),
licensed **CC0 1.0** on the author's page. The author describes rubbing a marker
on a cookie-tin lid; this derivative is not claimed as a field recording of a
car body scraping a fence. The public HQ MP3 preview is decoded by the pinned
engine. Source/license copies, encoded/decoded hashes and shipping attribution
are retained. No account, purchase, runtime source access, API or dependency
is introduced. It is a new offline asset source, not a runtime network feature.

Only **scrape.wav** changes; **47 other WAV hashes**, including the attached
owner-selected crash, are exact. The loop remains **11.5s/1,014,344 bytes**,
mono 44.1kHz/16-bit PCM. Repeat mastering yields all **48 identical hashes**.
The runtime contact observer, volume/pitch response, 60ms hold, 22-player
budget and below-deck/pause/countdown/air/rollover/retry/rewind gates are unchanged.
No physics/rules/camera/backend or player-data file changes are part of this task.

The loop's 100ms envelope coefficient of variation drops **0.507 → 0.092**,
and its quiet-tenth/median level rises **0.420 → 0.877**: much less knock/gap
contrast, while retaining slight fluctuations. Spectral centroid is **566Hz**,
with **82.3%** of energy below 900Hz. These measurements check the requested
continuity and low tone; they are not subjective owner acoustic acceptance.

Changed files: `scripts/continuous_scrape_mastering.py`,
`scripts/collision_audio_mastering.py`, `scripts/build_vehicle_audio.py`,
`scripts/fetch_continuous_scrape.py`, `scripts/review_continuous_scrape_audio.py`,
`game/tests/decode_continuous_scrape.gd` and UID,
`game/assets/audio/vehicles/scrape.wav`, `manifest.json`, `NOTICE.txt`, this
document, `docs/IRREGULAR_LOW_SCRAPE.md`, `DEVELOPMENT_STATUS.md` and
`docs/PHASE_0_PLAN.md`.

Actual commands use pinned **4.7.2.stable.official.ed1daf0bf** through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Actual command / suffix | Outcome |
| --- | --- |
| Primary Freesound page opened through browser tool | Author/title/CC0 verified against the source page. |
| `python scripts/fetch_continuous_scrape.py` | Initial direct Python network request times out; Windows `Invoke-WebRequest -UseBasicParsing` successfully stages license page and **397,853-byte** HQ preview, then the fetch script validates/registers cached files. |
| `-Action TestScript -ScriptPath res://tests/decode_continuous_scrape.gd` | Successful **749,440 mono float frames at 44.1kHz/16.9941s**, exit 0. Earlier invocation after the failed fetch cannot decode missing data; that failure is retained. |
| `python scripts/fetch_continuous_scrape.py --finalize` | Registered float WAV and CC0 source/encoded/decoded hash manifest. |
| `python scripts/build_vehicle_audio.py --collisions-only` | Four scoped outputs **1,233,724 bytes**, only scrape changes; final repeated all 48 hashes exact. |
| `-Action Import` | **Exit 0**, new derivative and offline decoder imported. |
| `-Action TestScript -ScriptPath res://tests/test_bridge_scrape_audio.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/continuous-body-scrape-2026-10-11'` | **611 checks/zero failures**, all five cars/both sides/directions/three speeds, real Game integration and nine native recordings. |
| `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,450 checks/zero failures**, bank/lifecycle and simulation separation. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/continuous-body-scrape-2026-10-11/loop-continuity.json` | **41 loops/zero failures**, three repetitions/joins/no embedded gaps. |
| `python scripts/review_continuous_scrape_audio.py` | Steadier envelope/retained low tone/47 unchanged WAVs/native headroom and pause tails pass; friction **3.54/3.73/3.59dB below engine** at 4/12/24m/s. |
| `python -m py_compile scripts/collision_audio_mastering.py scripts/continuous_scrape_mastering.py scripts/fetch_continuous_scrape.py scripts/review_continuous_scrape_audio.py scripts/build_vehicle_audio.py` | Exit 0. |
| Configured SDK `adb devices -l` | **DN2103 phone attached**; no device listening/install performed. |

The actual compact Game bridge test remains **46 audible ticks out of 48**,
peak gain **0.402**, and stays above the compiled creator bridge. Native vehicle
mix peaks are below **0.5**, last 200ms exactly silent. Captures hold real contact
movement for mix assessment; they are not completed races. The three-second
native clips do not assert an entire runtime loop wrap; offline repetition
checks the eleven-and-a-half-second source join.

The first command contained a shell quoting error and did not execute. The
Python request then timed out; a premature decoder invocation failed on absent
media. Windows network staging resolved the fetch without changing checks or
disabling TLS verification. Full source selection/build remains reproducible
with cached files; a fresh Windows machine can stage the listed page/preview
with `Invoke-WebRequest` before running fetch/decode/finalize/master commands.
License and direct HQ preview URL are pinned in the source manifest.

Evidence under `docs/evidence/continuous-body-scrape-2026-10-11/`: prior scrape,
source/wave manifests, actual logs, contact matrix, loop/PCM review, nine native
WAVs and a task-only Git-format binary/source patch plus checkpoint. Listen to
the [vehicle mix](evidence/continuous-body-scrape-2026-10-11/after-12-mix.wav) or
[scrape alone](evidence/continuous-body-scrape-2026-10-11/after-12-scrape.wav).

No visible UI change, phone listening, Android export/install, full Validate,
physics/rules/camera change, backend work, deployment or score write was
performed. Restart the local game to load the new asset; installed Android
remains unchanged. Owner/device listening acceptance remains.

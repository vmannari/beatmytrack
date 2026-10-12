# Lower, irregular scraping — 2026-10-10

Owner feedback: the previous scrape sounds like radio disturbance and needs
less regularity and lower frequency. **SND44**, refining SND40-SND42/SND08/SND05
and supporting G01/R01/Q01/V06. This supersedes the rejected timbre described in
[Metallic scrape](METALLIC_SCRAPE.md). The preceding owner-supplied crash edit
is complete with its own [source/timing checkpoint](OWNER_CRASH_AUDIO.md).

The dense 6–16ms metal-grain spacing is replaced by longer, softer-edged rubbing
strokes at **uneven 90–310ms intervals**, pitched to **0.46–0.68** of the recording.
Lower body-panel rubbing supports the scrape, with only a restrained tire
strain layer. Nominal blend is **60% metal/35% panel/5% tire**. Slow uneven
pressure envelopes and a **2.4kHz low-pass** remove the rejected bright chatter.
The loop is now **11.5s** rather than 5.5s, reducing repeat cadence.

The common 100ms texture-envelope flattening is bypassed for this asset so its
authored strokes retain their intensity variation. Ordinary loop joins,
headroom, continuity/dropout checks and PCM interpolation padding still apply.
No runtime audio/contact/gain/hold/camera/physics/rules/backend file is changed.
The existing selected-car contact, below-deck isolation, pause/countdown,
air/rollover and retry/rewind behavior is retained. The 22-player budget is exact.

The same cleared KALeigh0218 stone/metal and Nox body recordings (CC0), plus
audible-edge (Tom Haigh)/qubodup tire strain (CC BY3.0), supply this offline
derivative. No source download, runtime synthesis, service or dependency is
introduced. It is authored friction foley, not a claimed real fence field recording.

Only **scrape.wav** changes; **47 other WAV hashes**, including all three
owner-selected crash derivatives, are exact. Repeat mastering yields all 48
identical hashes. The new mono 44.1kHz/16-bit loop occupies **1,014,344 bytes**
(+529,200 bytes). Actual asset spectral centroid falls from **1,603Hz to 513Hz**,
with **86.9%** of energy below 900Hz. Its 100ms envelope coefficient of variation
rises from **0.036 to 0.507**, demonstrating retained uneven strokes. These are
measurements of the intended changes, not subjective listening acceptance.

Changed files: `scripts/collision_audio_mastering.py`, `scripts/build_vehicle_audio.py`,
`game/assets/audio/vehicles/scrape.wav`, `manifest.json`, `NOTICE.txt`,
`scripts/review_irregular_scrape_audio.py`, this document, `docs/METALLIC_SCRAPE.md`,
`DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. The separate preceding crash
checkpoint remains under `docs/evidence/owner-crash-2026-10-10/`.

Actual commands use pinned **4.7.2.stable.official.ed1daf0bf** through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Actual command / suffix | Outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --collisions-only` | Four scoped outputs **1,233,724 bytes**, only scrape changes. Repeat all 48 hashes exact. |
| `-Action Import` | **Exit 0**, updated audio imported. |
| `-Action TestScript -ScriptPath res://tests/test_bridge_scrape_audio.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/irregular-low-scrape-2026-10-10'` | **611 checks/zero failures**, all five cars/both directions/sides/three speeds, real Game integration and nine native recordings. |
| `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | **1,450 checks/zero failures**, bank integrity and lifecycle/simulation separation. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/irregular-low-scrape-2026-10-10/loop-continuity.json` | **41 loops/zero failures**, three repetitions/joins/no embedded gaps. |
| `python scripts/review_irregular_scrape_audio.py` | Lower spectrum, increased envelope variation, 47 unchanged WAVs, audible native mix/headroom and silent pause tails pass. Friction **1.10/1.33/1.32dB below engine** at 4/12/24m/s. |
| `python -m py_compile scripts/collision_audio_mastering.py scripts/review_irregular_scrape_audio.py scripts/build_vehicle_audio.py` | Exit 0. |

The actual Game integration still produces **46 audible ticks out of 48**,
peak gain **0.402**, staying on the compiled creator bridge. Captures hold that
real contact position/movement to assess the vehicle mix, rather than claim a
completed player-driven race. The offline loop check covers the extended wrap;
the three-second native clips do not claim an entire runtime loop crossing.

Evidence under `docs/evidence/irregular-low-scrape-2026-10-10/`: prior scrape,
source/wave hashes, 60-case contact matrix, actual logs, loop/PCM review, nine
native WAVs and a task-only Git-format binary/source patch plus checkpoint.
Listen to the [vehicle mix](evidence/irregular-low-scrape-2026-10-10/after-12-mix.wav)
or [scrape alone](evidence/irregular-low-scrape-2026-10-10/after-12-scrape.wav).

No visible UI change, device listening, Android export/install, full Validate,
physics/rules/camera change, backend work, deployment or score write was
performed. Earlier in this same turn the attachment check found the OPD2403
tablet and **no phone**. Restart the local game to load both sound edits;
installed Android remains unchanged. Owner/device acoustic acceptance remains.

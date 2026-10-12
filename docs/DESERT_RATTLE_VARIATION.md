# Desert rattle variation — 2026-10-11

SND49 implements the owner's request to randomize the rattle itself. G01/R01
retain presentation-only randomness and canonical driving separation; Q01 covers
actual validation and provenance. This supersedes SND48's complete-clip playback;
the original audio sources, licensing and race wiring remain in place.

Each call selects a fresh recorded excerpt spanning 1.35–3.25 source seconds,
bounded by the selected recording's length, and a random start offset. Existing
0.97–1.03 pitch variation makes playback approximately 1.31–3.35 seconds long.
A new pattern of soft swells and dips changes the rattle's internal rhythm:
random 120–450ms spacing alternates stronger and gentler points, with smooth
interpolation, an audible floor and an 80ms entrance/180ms exit fade. The fine
recorded buzz stays intact. This varies content as well as waiting time/level.

The system retains one Vehicle-bus voice, alternating recorded sources, 4–10s
opening waits and 12–24s gaps after completed calls. Runtime work uses small
bounded arrays, no generated PCM, services or dependencies. Pause/rewind and
application suspension freeze the selected phrase, resume continues that shape,
finish fades and stops, Retry clears the phrase, and biome change/exit stop/free
the voice. Existing volume/mute and continuous Desert wind apply.

The original FWS public-domain WAVs remain byte-identical, totaling 599,848 bytes.
Source/derivative hashes and provenance remain in
`game/assets/audio/ambience/desert_rattlesnake_manifest.json` and the shipping
NOTICE. No new recordings are used. See [original source/provenance](DESERT_RATTLESNAKE.md).

Changed files: `game/track/desert_rattlesnake.gd`,
`game/tests/test_desert_rattlesnake.gd`, `scripts/review_desert_rattlesnake.py`,
this document, `docs/DESERT_RATTLESNAKE.md`, `DEVELOPMENT_STATUS.md`,
`docs/PHASE_0_PLAN.md` and `licenses/ASSETS.md`. Evidence and a task-only Git
checkpoint are under `docs/evidence/desert-rattle-variation-2026-10-11`.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_rattlesnake.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_desert_rattlesnake.gd -Graphical -TestArgument @('--capture')"
python scripts/review_desert_rattlesnake.py
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
```

Headless 474 checks and native 492 checks pass, with no failures. Six 90-second
schedules exercise excerpt bounds, many independent same-recording variations,
bounded ordered pulse patterns, nonoverlapping calls, and the original lifecycle
and actual-race canonical-isolation assertions. Headless/native logs are copied
from `build/logs/TestScript-35688` and `build/logs/TestScript-20796` respectively.

The PCM review passes: both source WAV hashes remain exact, with original
interior waveform correlation above 0.999999995. Native examples of recording A
last 2.672 versus 2.174 seconds and start at source offsets 0.235 versus 0.639
seconds. Recording B lasts 3.013 versus 2.385 seconds, with offsets 0.518 versus
1.088 seconds. Pulse timings/depths also differ. Onset-aligned, peak-normalized
25ms RMS envelopes differ by mean absolute 0.136/0.167; this checks audible shape
independently of opening wait and overall level.

Two 40-second wind mixes contain calls at 8.309/25.642 seconds versus
7.725/26.284 seconds, with no overlap. Settled 500ms RMS remains above
0.01964/0.02490; mix peaks 0.31372/0.18921 are unclipped. The controlled
15-second Compact 25m/s mixer includes a rattle and peaks at 0.29205, unclipped.
Pause, mute and finish captures are exactly silent.

Evidence: [Desert wind and varied rattles](evidence/desert-rattle-variation-2026-10-11/desert0.wav),
[another attempt](evidence/desert-rattle-variation-2026-10-11/desert1.wav),
[with engine](evidence/desert-rattle-variation-2026-10-11/driving.wav),
[first isolated rattle](evidence/desert-rattle-variation-2026-10-11/rattle_a.wav),
[same recording varied](evidence/desert-rattle-variation-2026-10-11/rattle_a_alt.wav),
[measured review](evidence/desert-rattle-variation-2026-10-11/review.json), event
JSONs, other isolated/silence captures and focused logs. The task-only patch is
checked for whitespace and reverse application in its isolated Git checkpoint;
the main index/branch and unrelated changes are untouched.

DN2103 phone attached; no phone listening/device test, Android export/install,
full Validate, backend or deployment performed. Sandbox ADB could not create its
default configuration directory; the same read-only device query succeeded in
the normal Windows environment. Remaining acceptance: listen to several Desert
retries on the phone, judge naturalness/level against wind and engine, and check
pause/rewind/finish. Native mixer diagnostics are not completed races or subjective
listening/device-performance claims. No UI changes require screenshots.

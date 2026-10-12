# Night cicada ambience, 2026-10-09

SND19: owner-requested cicadas in the night biome. SND05 covers local audio lifecycle/volume; G01/R01 preserve simulation and race behavior; Q01/V06 cover verification and mobile acceptance.

Night (`night_city`) races now play one recorded cicada ambience voice, including the countdown and untimed practice. The 18-second mono loop fades in/out over 0.75 seconds at a restrained level, pauses with the race and application, restarts on retry, stops when switching away from night, and is freed with the race. It follows the existing Vehicle volume and master mute. No menu labels/settings were added. Music, vehicle clips, weather behavior, canonical physics, inputs and race contracts are unchanged.

The source is [Clarisse's outdoor cicada recording, BigSoundBank 3002](https://bigsoundbank.com/cigales-s3002.html), published under CC0. The license-page snapshot and original BWF are retained outside export at `build/night_ambience_sources`. Offline edits: stable middle section, mono/44.1 kHz/16-bit conversion, rumble and high-frequency softening, one-second cyclic crossfade and -22 dBFS RMS mastering. Playback gain is 0.4, giving approximately -30 dBFS RMS before the existing Vehicle bus. Shipped PCM is 1,587,644 bytes. Attribution, source/derivative SHA-256 and processing details are in the asset NOTICE/manifest. NumPy is an existing offline tool, never a runtime dependency.

Changed files:

- `game/core/game.gd`: create/configure the race-owned ambience and present its lifecycle.
- `game/track/night_ambience.gd` and `.uid`: one bounded looping voice, fade, pause/background and finish handling.
- `game/assets/audio/ambience/{night_cicadas.wav,night_cicadas.wav.import,manifest.json,NOTICE.txt}`: cleared PCM, uncompressed import and provenance.
- `scripts/build_night_ambience.py`: reproducible offline mastering with optional public-source download.
- `game/tests/test_night_ambience.gd` and `.uid`, `scripts/review_night_ambience.py`: focused lifecycle/race integration and native PCM review.
- This document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`: actual delivery record.

Actual commands and outcomes (pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`):

```powershell
python scripts/build_night_ambience.py --fetch
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_night_ambience.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_night_ambience.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python scripts/review_night_ambience.py
python scripts/build_night_ambience.py
```

Final import passed. Headless ambience checks: **25/25**. Native Windows checks: **31/31**, including two observed playback wraps. Script parser: **406 scripts, zero failures**. App regression: **99/99**. PCM review: **17/17**. Offline rebuild reproduced asset SHA-256 `9ee4f6f42927cd86b85083be834de416aca2ffb90a2006312c3de094084c7eab`.

The [36.992-second native recording](evidence/night-cicadas-2026-10-09/cicadas-two-wraps.wav) has peak 0.19345, RMS 0.03163, and minimum 100-ms RMS 0.01955: no clipping or silent 100-ms gaps across the two observed boundaries. [Paused](evidence/night-cicadas-2026-10-09/paused.wav), [muted](evidence/night-cicadas-2026-10-09/muted.wav) and [finished](evidence/night-cicadas-2026-10-09/finished.wav) captures are digitally silent after a 200-ms mixer drain. [PCM review](evidence/night-cicadas-2026-10-09/pcm-review.json) retains exact measurements. These are digital playback checks, not subjective listening or acoustic-latency claims. No visible UI changed, so audio evidence replaces screenshots.

Initial failures retained in command history: restricted network socket and Godot Windows certificate-store access required approved local-access reruns; the guessed `/UPLOAD/wav` address returned HTML, corrected to the source page's published `/UPLOAD/bwf-en` URL; automatic WAV import selected QOA, explicitly corrected to uncompressed PCM before lifecycle tests. Two initial headless pause assertions assumed `stream_paused` remains observable without an active playback; headless checks now assert inactive output and retained gain, while the graphical test still checks actual paused playback. Initial immediate fixture destruction leaked queued nodes; draining frames before race deletion gives clean final exits. PowerShell `-File` rejected the double-dash test argument; `-Command` with a literal string array succeeded. No invariant was weakened.

Review checkpoint: [task-only patch](evidence/night-cicadas-2026-10-09/review-checkpoint.patch), created against the exact pre-task core/document content and including the new audio asset. Unrelated workspace edits are preserved.

Phone attachment was not checked; no phone/device audio test, Android export/install, full Validate, deployment or production action occurred. Remaining acceptance: owner listening for cicada character/volume against engine and music, actual phone speakers/headphones/Bluetooth, background/foreground and pause/retry on device, and mobile memory/performance. Desktop digital continuity does not establish those results.

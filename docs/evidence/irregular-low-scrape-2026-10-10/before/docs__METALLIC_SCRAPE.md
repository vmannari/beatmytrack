# Metallic body scrape — 2026-10-10

Owner request: scraping should sound metallic, indicating the body grinding
against the fence. **SND42**, refining SND40/SND41/SND08/SND05 and supporting
G01/R01/Q01/V06. This changes the sound's timbre; the accepted contact observer,
bridge continuity, movement gain and 60ms hold remain byte-identical.

The previous derivative was dominated by tire squeal (nominal mix weight 62%),
with short, widely transposed metal grains (28%) and gravel (10%). The new
derivative uses **76% resonant metal grains, 16% body-panel vibration and 8%
restrained tire strain** before final filtering/mastering. Gravel is removed.
Four recorded metal contacts supply longer ringing tails, densely overlapped
with only ±6% pitch variation to retain metal resonance. Recorded body movement
supports the low mechanical rasp. A smooth knee bends rare grain peaks so the
normal bank ceiling does not lower the sustained sound's loudness.

The existing cleared KALeigh0218 stone/metal and Nox vehicle-body recordings are
CC0; the small audible-edge (Tom Haigh)/qubodup tire component remains CC BY 3.0.
Shipping NOTICE and the bank's source/derivative SHA-256 metadata document all
edits. This is authored body-on-barrier foley, not a dedicated real fence-scrape
field recording. No new source download, license, runtime generation, voice,
dependency or service is introduced. Perceptual acceptance remains with the owner.

Changed files: `scripts/collision_audio_mastering.py`,
`scripts/build_vehicle_audio.py`, `game/assets/audio/vehicles/scrape.wav` and
its import metadata, `manifest.json`, `NOTICE.txt`,
`game/tests/test_bridge_scrape_audio.gd` (optional evidence destination only),
`scripts/review_metallic_scrape_audio.py`, this document, `docs/BRIDGE_SCREECH.md`,
`DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

Only **scrape.wav** changes among the **48** bank WAVs; **47 hashes**, including
all three crash clips and all engines, are exact. The loop remains 5.5 seconds,
mono 44.1kHz/16-bit PCM, **485,144 bytes**. Final SHA-256:
`b676cf5327696d2c27cdad74f4f5d3f2c8c57a13218822f667492107d520d59a`.
Asset RMS is -14.895dBFS, peak -1.860dBFS. Repeat scoped mastering produces
all 48 identical WAV hashes. No runtime audio/physics/camera/backend file changes.

Actual commands use pinned **4.7.2.stable.official.ed1daf0bf** through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Actual command / suffix | Outcome |
| --- | --- |
| `python scripts/build_vehicle_audio.py --collisions-only` | Four scoped derivatives, 549,148 bytes; only the scrape changes. Final repeated rebuild exact. |
| `-Action Import` | Initial candidate exit 0. Final candidate WAVs reimported, then editor shutdown exit **-1073741819**; two verbose retries stop at locked `~bmt_windows_audio_v3.dll`. Final native capture proves updated audio is loaded. Full clean importer completion is not claimed. |
| `-Action TestScript -ScriptPath res://tests/test_bridge_scrape_audio.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/metallic-scrape-2026-10-10'` | Final **611 checks/zero failures**, compiled creator rail, all five cars, both sides, forward/reverse, three speeds, separation/underpass/stationary/air/roll/countdown/pause and real Game integration. Nine native vehicle-mix/engine/friction recordings. |
| `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | Final **1,450 checks/zero failures**, bank hashes and lifecycle/simulation separation. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/metallic-scrape-2026-10-10/loop-continuity.json` | **41 loops/zero failures**, repeated playback and wrap boundaries. |
| `python scripts/review_metallic_scrape_audio.py` | Final mix/level/tail/hash checks pass. Friction **2.637/2.878/2.823dB below engine** at 4/12/24m/s, retained level within 0.5dB of the prior native scrape. Vehicle-mix peaks **0.424/0.467/0.458**, last 200ms exactly silent. |
| `python -m py_compile scripts/collision_audio_mastering.py scripts/review_metallic_scrape_audio.py scripts/build_vehicle_audio.py` | Exit 0. |
| Configured SDK `adb devices -l` | OPD2403 tablet attached; **no phone attached**. |

The first metallic candidate had higher crest peaks, causing about 0.78dB lower
sustained playback at the unchanged ceiling. The native level check failed;
offline peak shaping corrected it while keeping the assertion and runtime
volume unchanged. That first candidate WAV is retained. Import failures and
completed native logs are retained; no unrelated engine/editor was stopped or
source changed to resolve the Windows library lock. The import retries can be
repeated once the editor/library lock is released.

Evidence and a task-only Git-format binary/source checkpoint are under
`docs/evidence/metallic-scrape-2026-10-10/`. Compare the full vehicle mix
[before](evidence/metallic-scrape-2026-10-10/before-12-mix.wav) and
[after](evidence/metallic-scrape-2026-10-10/after-12-mix.wav), or listen to the
[metal scrape alone](evidence/metallic-scrape-2026-10-10/after-12-scrape.wav).
Spectral band measurements are recorded for comparison, not asserted as a
substitute for judging whether it sounds like body metal scraping a fence.

No visible UI change, phone/tablet listening, Android export/install, full
Validate, handling/rules change, backend work, deployment or score write was
performed. Restart the local game to load the revised asset; the installed
Android build is unchanged. Remaining acceptance: owner listening to the metal
tone in an actual drive, device listening and clean importer completion after
the unrelated Windows extension lock is released.
